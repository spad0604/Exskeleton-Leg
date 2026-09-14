import 'dart:convert';

/// Stable GATT UUIDs. Change only with an explicit protocol-version migration.
abstract final class ExoBleProtocol {
  static const serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const controlUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const statusUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
  static const protocolVersion = 1;

  static List<int> encode(Map<String, Object?> value) =>
      utf8.encode(jsonEncode({'v': protocolVersion, ...value}));
}

class ExerciseDeviceStatus {
  final String state;
  final String? sessionId;
  final String? reason;
  final int? completedRepetitions;

  const ExerciseDeviceStatus({
    required this.state,
    this.sessionId,
    this.reason,
    this.completedRepetitions,
  });

  factory ExerciseDeviceStatus.fromJson(Map<String, dynamic> json) =>
      ExerciseDeviceStatus(
        state: json['state'] as String,
        sessionId: json['session_id'] as String?,
        reason: json['reason'] as String?,
        completedRepetitions: (json['completed_repetitions'] as num?)?.toInt(),
      );
}

class LiveDeviceStatus {
  final String state;
  final double batteryPercent;
  final bool estopActive;
  final bool commandWatchdogOk;
  final String? faultReason;

  const LiveDeviceStatus({
    required this.state,
    required this.batteryPercent,
    required this.estopActive,
    required this.commandWatchdogOk,
    this.faultReason,
  });

  factory LiveDeviceStatus.fromJson(Map<String, dynamic> json) =>
      LiveDeviceStatus(
        state: json['state'] as String,
        batteryPercent: (json['battery_percent'] as num).toDouble(),
        estopActive: json['estop_active'] as bool,
        commandWatchdogOk: json['command_watchdog_ok'] as bool,
        faultReason: json['fault_reason'] as String?,
      );
}

Map<String, dynamic> decodeBleStatus(List<int> bytes) {
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (json['v'] != ExoBleProtocol.protocolVersion) {
    throw const FormatException('Unsupported exoskeleton BLE protocol');
  }
  return json;
}
