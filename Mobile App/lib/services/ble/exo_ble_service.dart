import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exo_ble_protocol.dart';

/// BLE central for a nearby exoskeleton. It never sends motor-level commands.
class ExoBleService {
  static final shared = ExoBleService();

  ExoBleService({FlutterReactiveBle? ble}) : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  static const _native = MethodChannel('exo_leg/native_ble');
  static const _nativeStatus = EventChannel('exo_leg/native_ble_status');
  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<dynamic>? _statusSubscription;
  bool _statusRetryScheduled = false;
  Future<void> _writeQueue = Future<void>.value();
  Future<void>? _connecting;
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
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _connectToDevice(id);
        return;
      } catch (error) {
        if (attempt == 3 || !_isTransientConnectionError(error)) rethrow;
        developer.log(
            'Transient BLE connect failure; retrying '
            '(attempt ${attempt + 1}/3): $error',
            name: 'ExoBle');
        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
      }
    }
  }

  bool _isTransientConnectionError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('timed out') ||
        message.contains('status=257') ||
        message.contains('disconnected') ||
        message.contains('status=133');
  }

  Future<void> _resetConnection() async {
    await _connection?.cancel();
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    _connection = null;
    _control = null;
    await _native.invokeMethod<void>('disconnect');
    // Android needs a short gap after close() before a new GATT client is
    // allocated for the same peripheral.
    await Future<void>.delayed(const Duration(milliseconds: 350));
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
    try {
      await _native.invokeMethod<void>('connect', {'deviceId': deviceId});
      developer.log('Native GATT connected and services discovered',
          name: 'ExoBle');
    } catch (error) {
      await _resetConnection();
      developer.log('Native GATT connection failed: $error', name: 'ExoBle');
      rethrow;
    }

    _control = QualifiedCharacteristic(
      serviceId: serviceId,
      characteristicId: Uuid.parse(ExoBleProtocol.controlUuid),
      deviceId: deviceId,
    );
    await _startStatusSubscription(deviceId);
    // Status subscription is best-effort and retried because Android may still
    // be finishing bonding/service discovery. It must not make transport
    // connection fail; control writes remain explicitly user-triggered.
    developer.log('GATT transport connected; awaiting user command',
        name: 'ExoBle');
  }

  Future<void> _startStatusSubscription(String deviceId) async {
    await _statusSubscription?.cancel();
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        _statusSubscription = _nativeStatus.receiveBroadcastStream().listen(
          (event) {
            try {
              final bytes = List<int>.from(event as List<dynamic>);
              final payload = decodeBleStatus(bytes);
              final type = payload['type'];
              if (type == 'exercise_status') {
                _status.add(ExerciseDeviceStatus.fromJson(payload));
              } else if (type == 'device_status') {
                _deviceStatus.add(LiveDeviceStatus.fromJson(payload));
              }
            } catch (error, stackTrace) {
              developer.log('BLE status decode failed: $error',
                  name: 'ExoBle', error: error, stackTrace: stackTrace);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            developer.log('BLE status subscription unavailable: $error',
                name: 'ExoBle', error: error, stackTrace: stackTrace);
            if (!_statusRetryScheduled) {
              _statusRetryScheduled = true;
              unawaited(Future<void>.delayed(const Duration(seconds: 3), () {
                _statusRetryScheduled = false;
                return _startStatusSubscription(deviceId);
              }));
            }
          },
        );
        await _native.invokeMethod<void>('subscribe');
        return;
      } catch (error, stackTrace) {
        developer.log('BLE status subscription retry $attempt failed: $error',
            name: 'ExoBle', error: error, stackTrace: stackTrace);
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
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
    int sets = 1,
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
      sets: sets,
      repetitions: repetitions,
      assistPercent: assistPercent,
    );
  }

  Future<void> pauseExercise({
    required String sessionId,
    String exerciseCode = 'walk',
    int sets = 1,
  }) =>
      _sendExerciseCommand(
        sessionId: sessionId,
        exerciseCode: exerciseCode,
        action: 'pause',
        sets: sets,
      );

  Future<void> stopExercise({
    required String sessionId,
    String exerciseCode = 'walk',
    int sets = 1,
  }) =>
      _sendExerciseCommand(
        sessionId: sessionId,
        exerciseCode: exerciseCode,
        action: 'stop',
        sets: sets,
      );

  Future<void> _sendExerciseCommand({
    required String sessionId,
    required String exerciseCode,
    required String action,
    String planItemId = '',
    String side = 'both',
    int sets = 1,
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
      'sets': sets,
      'repetitions': repetitions,
      'assist_percent': assistPercent,
    });
  }

  Future<void> _write(Map<String, Object?> payload) async {
    final next = _writeQueue.then((_) => _writeUnlocked(payload));
    _writeQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _writeUnlocked(Map<String, Object?> payload) async {
    final characteristic = _control;
    if (characteristic == null) {
      throw StateError('Chưa kết nối ExoLeg-1 qua Bluetooth');
    }
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        // The protocol defines the control point as write-with-response. This
        // also gives Android a definitive ATT completion before a subsequent
        // command or status subscription starts.
        await _native.invokeMethod<void>('write', {
          'value': Uint8List.fromList(ExoBleProtocol.encode(payload)),
        });
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
            'BLE control write waiting for Android GATT (attempt $attempt): $error',
            name: 'ExoBle',
            error: error);
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw StateError(
        'Bluetooth chưa sẵn sàng để gửi lệnh. Hãy giữ kết nối và thử lại.');
  }

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
