// EXO-SLT ESP32 controller (UART2).
// GPIO13=previous, GPIO4=next, GPIO2=select/start (active-low INPUT_PULLUP).
// OLED 0.96in SSD1306 128x64: I2C SDA=21, SCL=22, address=0x3C.
// Motors intentionally remain locked until the safety/actuator adapters exist.
#include <Arduino.h>

#if __has_include(<Adafruit_GFX.h>) && __has_include(<Adafruit_SSD1306.h>)
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#define EXO_HAS_OLED 1
#else
#define EXO_HAS_OLED 0
#endif

HardwareSerial ExoUart(2);
static constexpr uint32_t BAUD = 115200;
static constexpr int RX2_PIN = 16;
static constexpr int TX2_PIN = 17;
static constexpr int BUTTON_PREVIOUS = 13;
static constexpr int BUTTON_NEXT = 4;
static constexpr int BUTTON_SELECT = 2;
static constexpr int BATTERY_ADC_PIN = 14;  // D14, after 56k/10k divider
static constexpr float BATTERY_DIVIDER_RATIO = (56.0f + 10.0f) / 10.0f;
// 12V LiFePO4 (4S) profile. Voltage-only percentage is approximate because
// LiFePO4 has a very flat discharge curve; use a BMS coulomb counter later.
static constexpr float BATTERY_EMPTY_V = 10.0f;
static constexpr float BATTERY_FULL_V = 14.6f;
static constexpr uint32_t DEBOUNCE_MS = 35;
static constexpr uint32_t LONG_PRESS_MS = 1200;

struct Exercise { const char* code; const char* title; const char* side; };
static constexpr Exercise EXERCISES[] = {
  {"walk", "WALK", "BOTH"},
  {"raise_left_leg", "RAISE L", "LEFT"},
  {"raise_right_leg", "RAISE R", "RIGHT"},
  {"sit_to_stand", "SIT-STAND", "BOTH"},
  {"kick_left_leg", "KICK L", "LEFT"},
  {"kick_right_leg", "KICK R", "RIGHT"},
  {"kick_left_knee", "KNEE L", "LEFT"},
  {"kick_right_knee", "KNEE R", "RIGHT"},
};
static constexpr size_t EXERCISE_COUNT = sizeof(EXERCISES) / sizeof(EXERCISES[0]);

#if EXO_HAS_OLED
Adafruit_SSD1306 display(128, 64, &Wire, -1);
#endif

uint8_t selectedExercise = 0;
bool exerciseRunning = false;
bool uartSeen = false;
bool estopActive = true;
String faultReason = "MCU motor adapter not configured";
String activeSession;
uint16_t completedRepetitions = 0;
uint32_t lastUartRxMs = 0;
uint32_t lastDisplayMs = 0;
uint32_t lastBatteryMs = 0;
float batteryVoltage = -1.0f;
float batteryPercent = -1.0f;

struct ButtonState {
  uint8_t pin; bool stableLevel; bool lastReading;
  uint32_t changedAt; uint32_t pressedAt; bool longPressSent;
};
ButtonState buttons[] = {
  {BUTTON_PREVIOUS, HIGH, HIGH, 0, 0, false},
  {BUTTON_NEXT, HIGH, HIGH, 0, 0, false},
  {BUTTON_SELECT, HIGH, HIGH, 0, 0, false},
};

uint16_t crc16(const uint8_t* data, size_t length) {
  uint16_t crc = 0xFFFF;
  while (length--) {
    crc ^= static_cast<uint16_t>(*data++) << 8;
    for (uint8_t bit = 0; bit < 8; ++bit)
      crc = (crc & 0x8000) ? static_cast<uint16_t>((crc << 1) ^ 0x1021)
                           : static_cast<uint16_t>(crc << 1);
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

int exerciseIndex(const String& code) {
  for (size_t i = 0; i < EXERCISE_COUNT; ++i)
    if (code == EXERCISES[i].code) return static_cast<int>(i);
  return -1;
}

void sendPayload(const String& payload) {
  char checksum[5];
  snprintf(checksum, sizeof(checksum), "%04X",
           crc16(reinterpret_cast<const uint8_t*>(payload.c_str()), payload.length()));
  ExoUart.print("EXO1|"); ExoUart.print(payload); ExoUart.print('|');
  ExoUart.print(checksum); ExoUart.print('\n');
}

void sendStatus(const String& state, const String& session = "", const String& reason = "") {
  String payload = String("{\"v\":1,\"type\":\"exercise_status\",\"session_id\":\"") +
    session + "\",\"exercise_code\":\"" + EXERCISES[selectedExercise].code +
    "\",\"state\":\"" + state + "\",\"reason\":\"" + reason +
    "\",\"completed_repetitions\":" + String(completedRepetitions) + "}";
  sendPayload(payload);
}

void sendDeviceStatus() {
  String payload = String("{\"v\":1,\"type\":\"device_status\",\"state\":\"") +
    (exerciseRunning ? "assisting" : "disarmed") +
    "\",\"battery_voltage\":" + String(batteryVoltage, 2) +
    ",\"battery_percent\":" + String(batteryPercent, 1) +
    ",\"estop_active\":" + (estopActive ? "true" : "false") +
    ",\"command_watchdog_ok\":false,\"fault_reason\":\"" + faultReason + "\"}";
  sendPayload(payload);
}

void readBattery() {
  uint32_t totalMv = 0;
  constexpr int samples = 16;
  for (int i = 0; i < samples; ++i) totalMv += analogReadMilliVolts(BATTERY_ADC_PIN);
  float adcVoltage = (static_cast<float>(totalMv) / samples) / 1000.0f;
  batteryVoltage = adcVoltage * BATTERY_DIVIDER_RATIO;
  batteryPercent = constrain(
      (batteryVoltage - BATTERY_EMPTY_V) * 100.0f / (BATTERY_FULL_V - BATTERY_EMPTY_V),
      0.0f, 100.0f);
}

void sendSelection() {
  String payload = String("{\"v\":1,\"type\":\"exercise_selected\",\"exercise_code\":\"") +
    EXERCISES[selectedExercise].code + "\",\"index\":" + String(selectedExercise) + "}";
  sendPayload(payload);
  sendStatus("selected", "local-ui");
}

void startExercise() {
  // Replace this body only after encoder/current-limit/E-stop/watchdog adapters
  // are implemented. No PWM or motor command is allowed at this layer yet.
  activeSession = "local-ui";
  completedRepetitions = 0;
  exerciseRunning = false;
  sendStatus("not_ready", activeSession, faultReason);
}

void stopExercise() {
  exerciseRunning = false;
  sendStatus("stopped", activeSession);
  sendDeviceStatus();
}

void renderDisplay() {
#if EXO_HAS_OLED
  if (millis() - lastDisplayMs < 200) return;
  lastDisplayMs = millis();
  display.clearDisplay(); display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1); display.setCursor(0, 0); display.print("EXOLEG  ");
  display.print(uartSeen && millis() - lastUartRxMs < 5000 ? "UART OK" : "UART ?");
  display.setCursor(0, 13); display.setTextSize(2); display.print(EXERCISES[selectedExercise].title);
  display.setTextSize(1); display.setCursor(0, 34); display.print("SIDE: ");
  display.print(EXERCISES[selectedExercise].side); display.setCursor(0, 45);
  display.print("BAT "); display.print(batteryVoltage, 2); display.print("V ");
  display.print(batteryPercent, 0); display.print("%"); display.setCursor(0, 56);
  display.print(estopActive ? "SAFE LOCK" : (exerciseRunning ? "RUNNING" : "READY")); display.display();
#endif
}

void handleButton(ButtonState& button) {
  bool reading = digitalRead(button.pin); uint32_t now = millis();
  if (reading != button.lastReading) button.changedAt = now;
  button.lastReading = reading;
  if (now - button.changedAt < DEBOUNCE_MS) return;
  if (reading != button.stableLevel) {
    button.stableLevel = reading;
    if (reading == LOW) { button.pressedAt = now; button.longPressSent = false; }
    else if (button.pin != BUTTON_SELECT) {
      selectedExercise = button.pin == BUTTON_PREVIOUS
        ? (selectedExercise + EXERCISE_COUNT - 1) % EXERCISE_COUNT
        : (selectedExercise + 1) % EXERCISE_COUNT;
      sendSelection();
    } else if (!button.longPressSent) startExercise();
  }
  if (button.pin == BUTTON_SELECT && button.stableLevel == LOW &&
      !button.longPressSent && now - button.pressedAt >= LONG_PRESS_MS) {
    button.longPressSent = true; stopExercise();
  }
}

void handleFrame(const String& frame) {
  if (!frame.startsWith("EXO1|")) return;
  int separator = frame.lastIndexOf('|'); if (separator <= 5) return;
  String payload = frame.substring(5, separator), provided = frame.substring(separator + 1);
  provided.trim(); char expected[5];
  snprintf(expected, sizeof(expected), "%04X",
           crc16(reinterpret_cast<const uint8_t*>(payload.c_str()), payload.length()));
  if (!provided.equalsIgnoreCase(expected)) { sendStatus("rejected", "", "UART CRC failed"); return; }
  uartSeen = true; lastUartRxMs = millis(); String type = jsonString(payload, "type");
  if (type == "exercise_command") {
    String session = jsonString(payload, "session_id"), code = jsonString(payload, "exercise_code");
    int index = exerciseIndex(code);
    if (index < 0) { sendStatus("rejected", session, "unsupported exercise code"); return; }
    selectedExercise = static_cast<uint8_t>(index); String action = jsonString(payload, "action");
    if (action == "stop") stopExercise();
    else if (action == "start") { activeSession = session; sendStatus("not_ready", session, faultReason); }
    else sendStatus("paused", session, "motor adapter not configured");
  } else if (type == "device_command" || type == "ping") sendDeviceStatus();
}

void setup() {
  Serial.begin(115200); ExoUart.begin(BAUD, SERIAL_8N1, RX2_PIN, TX2_PIN);
  pinMode(BUTTON_PREVIOUS, INPUT_PULLUP); pinMode(BUTTON_NEXT, INPUT_PULLUP); pinMode(BUTTON_SELECT, INPUT_PULLUP);
  analogReadResolution(12);
  analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);
#if EXO_HAS_OLED
  Wire.begin(21, 22); display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay(); display.display();
#endif
  delay(250); readBattery(); sendDeviceStatus(); sendSelection();
}

void loop() {
  static String line;
  while (ExoUart.available()) {
    char character = static_cast<char>(ExoUart.read());
    if (character == '\n') { handleFrame(line); line = ""; }
    else if (line.length() < 900) line += character; else line = "";
  }
  for (ButtonState& button : buttons) handleButton(button);
  if (millis() - lastBatteryMs >= 1000) {
    lastBatteryMs = millis();
    readBattery();
    sendDeviceStatus();
  }
  renderDisplay();
}
