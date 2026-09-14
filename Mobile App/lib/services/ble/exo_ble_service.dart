import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exo_ble_protocol.dart';

/// BLE central for a nearby exoskeleton. It never sends motor-level commands.
class ExoBleService {
  static final shared = ExoBleService();

  ExoBleService({FlutterReactiveBle? ble}) : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<List<int>>? _statusSubscription;
  Timer? _statusPollTimer;
  bool _statusPollInFlight = false;
  int _connectionGeneration = 0;
  QualifiedCharacteristic? _control;
  final _status = StreamController<ExerciseDeviceStatus>.broadcast();
  final _deviceStatus = StreamController<LiveDeviceStatus>.broadcast();

  Stream<ExerciseDeviceStatus> get status => _status.stream;
  Stream<LiveDeviceStatus> get deviceStatus => _deviceStatus.stream;
  bool get isConnected => _control != null;

  Future<List<ExoBleDevice>> discoverExoskeletons() async {
    developer.log('Starting BLE scan for ExoLeg devices', name: 'ExoBle');
    await _ensureReady();
    final devices = <String, ExoBleDevice>{};
    Object? scanError;
    final scan = _ble
        // Filter by the GATT service, not the advertised name. Android can
        // return an empty device.name when the name is carried in scan
        // response data, while the service UUID remains available.
        .scanForDevices(
      withServices: [Uuid.parse(ExoBleProtocol.serviceUuid)],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      final name = device.name.isEmpty ? 'ExoLeg-1' : device.name;
      devices[device.id] = ExoBleDevice(
        id: device.id,
        name: name,
        rssi: device.rssi,
      );
      developer.log('Discovered $name (${device.id}), RSSI ${device.rssi}',
          name: 'ExoBle');
    }, onError: (Object error, StackTrace stackTrace) {
      scanError = error;
      developer.log('BLE scan failed: $error',
          name: 'ExoBle', error: error, stackTrace: stackTrace);
    });
    try {
      await Future<void>.delayed(const Duration(seconds: 5));
    } finally {
      await scan.cancel();
    }
    if (scanError != null) throw StateError('BLE scan failed: $scanError');
    return devices.values.toList()
      ..sort((left, right) => right.rssi.compareTo(left.rssi));
  }

  Future<void> connect({String? deviceId}) async {
    if (isConnected) return;
    await _resetConnection();
    final id = deviceId ?? (await _firstDiscoveredDeviceId());
    await _connectToDevice(id);
  }

  Future<void> _resetConnection() async {
    _connectionGeneration++;
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _statusPollInFlight = false;
    await _connection?.cancel();
    _connection = null;
    _control = null;
  }

  Future<void> _ensureReady() async {
    final permissions =
        await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    if (permissions.values.any((value) => !value.isGranted)) {
      throw StateError('Bluetooth permission was not granted');
    }
    final adapterStatus = await _ble.statusStream
        .firstWhere((status) => status != BleStatus.unknown)
        .timeout(const Duration(seconds: 5));
    if (adapterStatus != BleStatus.ready) {
      throw StateError('Bluetooth adapter is not ready: $adapterStatus');
    }
  }

  Future<String> _firstDiscoveredDeviceId() async {
    final devices = await discoverExoskeletons();
    if (devices.isEmpty) throw StateError('No nearby ExoLeg device was found');
    return devices.first.id;
  }

  Future<void> _connectToDevice(String deviceId) async {
    await _resetConnection();
    developer.log('Connecting GATT to $deviceId', name: 'ExoBle');
    final serviceId = Uuid.parse(ExoBleProtocol.serviceUuid);
    final generation = _connectionGeneration;
    final connected = Completer<void>();
    _connection = _ble
        .connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 30),
    )
        .listen((update) {
      developer.log('GATT state: ${update.connectionState}', name: 'ExoBle');
      if (update.connectionState == DeviceConnectionState.connected &&
          !connected.isCompleted) {
        connected.complete();
      } else if (update.connectionState == DeviceConnectionState.disconnected &&
          !connected.isCompleted) {
        connected
            .completeError(StateError('Device disconnected while connecting'));
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        if (generation == _connectionGeneration) {
          unawaited(_resetConnection());
        }
      }
    }, onError: (Object error, StackTrace stackTrace) {
      developer.log('GATT connection failed: $error',
          name: 'ExoBle', error: error, stackTrace: stackTrace);
      if (!connected.isCompleted) connected.completeError(error, stackTrace);
    });
    try {
      await connected.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      developer.log('GATT connection timed out after 30 seconds',
          name: 'ExoBle');
      await _resetConnection();
      throw StateError('GATT connection timed out after 30 seconds');
    } catch (error) {
      await _resetConnection();
      rethrow;
    }

    _control = QualifiedCharacteristic(
      serviceId: serviceId,
      characteristicId: Uuid.parse(ExoBleProtocol.controlUuid),
      deviceId: deviceId,
    );
    final statusCharacteristic = QualifiedCharacteristic(
      serviceId: serviceId,
      characteristicId: Uuid.parse(ExoBleProtocol.statusUuid),
      deviceId: deviceId,
    );
    await _pollStatus(statusCharacteristic);
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollStatus(statusCharacteristic),
    );
  }

  Future<void> _pollStatus(QualifiedCharacteristic characteristic) async {
    if (_statusPollInFlight || _control == null) return;
    _statusPollInFlight = true;
    try {
      final value = await _ble.readCharacteristic(characteristic);
      developer.log('BLE status read: ${value.length} bytes', name: 'ExoBle');
      final payload = decodeBleStatus(value);
      switch (payload['type']) {
        case 'exercise_status':
          _status.add(ExerciseDeviceStatus.fromJson(payload));
        case 'device_status':
          _deviceStatus.add(LiveDeviceStatus.fromJson(payload));
      }
    } catch (error, stackTrace) {
      developer.log('BLE status read failed: $error',
          name: 'ExoBle', error: error, stackTrace: stackTrace);
    } finally {
      _statusPollInFlight = false;
    }
  }

  Future<void> prepareExercise({
    required String sessionId,
    required String planItemId,
    required String exerciseCode,
    required int sets,
    required int repetitions,
  }) async {
    await connect();
    await _write({
      'type': 'prepare_exercise',
      'session_id': sessionId,
      'plan_item_id': planItemId,
      'exercise_code': exerciseCode,
      'sets': sets,
      'repetitions': repetitions,
    });
  }

  Future<void> startExercise({
    required String sessionId,
    required String exerciseCode,
    String planItemId = '',
    String side = 'both',
    int repetitions = 1,
    double assistPercent = 0,
  }) =>
      _sendExerciseCommand(
        sessionId: sessionId,
        exerciseCode: exerciseCode,
        planItemId: planItemId,
        action: 'start',
        side: side,
        repetitions: repetitions,
        assistPercent: assistPercent,
      );

  Future<void> pauseExercise({
    required String sessionId,
    String exerciseCode = 'walk',
  }) =>
      _sendExerciseCommand(
        sessionId: sessionId,
        exerciseCode: exerciseCode,
        action: 'pause',
      );

  Future<void> stopExercise({
    required String sessionId,
    String exerciseCode = 'walk',
  }) =>
      _sendExerciseCommand(
        sessionId: sessionId,
        exerciseCode: exerciseCode,
        action: 'stop',
      );

  Future<void> _sendExerciseCommand({
    required String sessionId,
    required String exerciseCode,
    required String action,
    String planItemId = '',
    String side = 'both',
    int repetitions = 1,
    double assistPercent = 0,
  }) async {
    await connect();
    await _write({
      'type': 'exercise_command',
      'session_id': sessionId,
      'plan_item_id': planItemId,
      'exercise_code': exerciseCode,
      'action': action,
      'side': side,
      'repetitions': repetitions,
      'assist_percent': assistPercent,
    });
  }

  Future<void> _write(Map<String, Object?> payload) =>
      _ble.writeCharacteristicWithResponse(
        _control!,
        value: ExoBleProtocol.encode(payload),
      );

  Future<void> dispose() async {
    await _statusSubscription?.cancel();
    await _connection?.cancel();
    await _status.close();
    await _deviceStatus.close();
  }
}

class ExoBleDevice {
  final String id;
  final String name;
  final int rssi;

  const ExoBleDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
}
