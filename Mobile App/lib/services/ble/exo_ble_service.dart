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
  Future<void>? _connecting;
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

  Future<void> connect({String? deviceId}) {
    if (isConnected) return Future<void>.value();

    // Device selection and exercise preparation can arrive almost together.
    // FlutterReactiveBle closes the first Android GATT client if a second
    // connectToDevice subscription is created, so all callers must share one
    // in-flight connection attempt.
    final connecting = _connecting;
    if (connecting != null) return connecting;

    late final Future<void> tracked;
    final operation = _connectOnce(deviceId);
    tracked = operation.whenComplete(() {
      if (identical(_connecting, tracked)) _connecting = null;
    });
    _connecting = tracked;
    return tracked;
  }

  Future<void> _connectOnce(String? deviceId) async {
    await _resetConnection();
    final id = deviceId ?? (await _firstDiscoveredDeviceId());
    await _connectToDevice(id);
  }

  Future<void> _resetConnection() async {
    _connectionGeneration++;
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
    // Do not read or subscribe immediately after connecting. On Android this
    // forces a second service-discovery while the OS may still be resolving a
    // stale bond, causing repeated GATT failures. Control writes are deferred
    // until the user explicitly prepares an exercise.
    developer.log('GATT transport connected; awaiting user command',
        name: 'ExoBle');
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
  }) {
    final resolvedSide = side != 'both'
        ? side
        : (exerciseCode.contains('left')
            ? 'left'
            : (exerciseCode.contains('right') ? 'right' : 'both'));
    return _sendExerciseCommand(
      sessionId: sessionId,
      exerciseCode: exerciseCode,
      planItemId: planItemId,
      action: 'start',
      side: resolvedSide,
      repetitions: repetitions,
      assistPercent: assistPercent,
    );
  }

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

  Future<void> _write(Map<String, Object?> payload) async {
    final characteristic = _control;
    if (characteristic == null) {
      throw StateError('Chưa kết nối ExoLeg-1 qua Bluetooth');
    }
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        // The Pi exposes a Nordic-UART style control characteristic.  Do not
        // wait for an ATT write response here: some Android stacks start an
        // unnecessary bond/service-resolution cycle for a response write,
        // even though this characteristic has no encryption requirement.
        await _ble.writeCharacteristicWithoutResponse(
          characteristic,
          value: ExoBleProtocol.encode(payload),
        );
        developer.log('BLE control write succeeded (attempt $attempt)',
            name: 'ExoBle');
        return;
      } catch (error) {
        final message = error.toString().toLowerCase();
        final transient = message.contains('bonding') ||
            message.contains('service_discovery') ||
            message.contains('gatt');
        if (!transient || attempt == 3) break;
        developer.log(
            'BLE control write waiting for Android GATT (attempt $attempt)',
            name: 'ExoBle');
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw StateError(
        'Bluetooth chưa sẵn sàng để gửi lệnh. Hãy giữ kết nối và thử lại.');
  }

  Future<void> dispose() async {
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
