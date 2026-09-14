// EXO-SLT ESP32 controller (UART2).
//
// This is a commissioning-safe transport skeleton. It acknowledges and
// reports high-level exercise commands but intentionally does not drive motors
// until the encoder, current-limit, E-stop, and watchdog adapters are wired.
#include <Arduino.h>

HardwareSerial ExoUart(2);  // UART2: set RX2/TX2 pins for the board wiring.
static constexpr uint32_t BAUD = 115200;
static constexpr int RX2_PIN = 16;
static constexpr int TX2_PIN = 17;

uint16_t crc16(const uint8_t* data, size_t length) {
  uint16_t crc = 0xFFFF;
  while (length--) {
    crc ^= static_cast<uint16_t>(*data++) << 8;
    for (uint8_t bit = 0; bit < 8; ++bit) {
      crc = (crc & 0x8000) ? static_cast<uint16_t>((crc << 1) ^ 0x1021)
                           : static_cast<uint16_t>(crc << 1);
    }
  }
  return crc;
}

String jsonString(const String& line, const char* key, const char* fallback = "") {
  String needle = String("\"") + key + "\":\"";
  int start = line.indexOf(needle);
  if (start < 0) return String(fallback);
  start += needle.length();
  int end = line.indexOf('"', start);
  return end < 0 ? String(fallback) : line.substring(start, end);
}

void sendStatus(const String& state, const String& session = "", const String& reason = "") {
  String payload = String("{\"type\":\"exercise_status\",\"session_id\":\"") +
                   session + "\",\"state\":\"" + state +
                   "\",\"reason\":\"" + reason +
                   "\",\"completed_repetitions\":0}";
  uint16_t crc = crc16(reinterpret_cast<const uint8_t*>(payload.c_str()), payload.length());
  char checksum[5];
  snprintf(checksum, sizeof(checksum), "%04X", crc);
  ExoUart.print("EXO1|");
  ExoUart.print(payload);
  ExoUart.print('|');
  ExoUart.print(checksum);
  ExoUart.print('\n');
}

void sendDeviceStatus() {
  const String payload =
      "{\"type\":\"device_status\",\"state\":\"disarmed\","
      "\"battery_percent\":-1,\"estop_active\":true,"
      "\"command_watchdog_ok\":false,\"fault_reason\":"
      "\"MCU motor adapter not configured\"}";
  uint16_t crc = crc16(reinterpret_cast<const uint8_t*>(payload.c_str()), payload.length());
  char checksum[5];
  snprintf(checksum, sizeof(checksum), "%04X", crc);
  ExoUart.print("EXO1|");
  ExoUart.print(payload);
  ExoUart.print('|');
  ExoUart.print(checksum);
  ExoUart.print('\n');
}

void handleFrame(const String& frame) {
  if (!frame.startsWith("EXO1|")) return;
  int separator = frame.lastIndexOf('|');
  if (separator <= 5) return;
  String payload = frame.substring(5, separator);
  String provided = frame.substring(separator + 1);
  provided.trim();
  char expected[5];
  snprintf(expected, sizeof(expected), "%04X",
           crc16(reinterpret_cast<const uint8_t*>(payload.c_str()), payload.length()));
  if (!provided.equalsIgnoreCase(expected)) {
    sendStatus("rejected", "", "UART CRC failed");
    return;
  }

  String type = jsonString(payload, "type");
  if (type == "exercise_command") {
    String session = jsonString(payload, "session_id");
    String action = jsonString(payload, "action");
    // Transport is ready; actual motion remains blocked by the safety gate.
    if (action == "stop") sendStatus("stopped", session);
    else sendStatus("not_ready", session, "MCU motor adapter not configured");
  } else if (type == "device_command") {
    sendDeviceStatus();
  }
}

void setup() {
  Serial.begin(115200);
  ExoUart.begin(BAUD, SERIAL_8N1, RX2_PIN, TX2_PIN);
  delay(250);
  sendDeviceStatus();
}

void loop() {
  static String line;
  while (ExoUart.available()) {
    const char character = static_cast<char>(ExoUart.read());
    if (character == '\n') {
      handleFrame(line);
      line = "";
    } else if (line.length() < 900) {
      line += character;
    } else {
      line = "";
    }
  }
}
