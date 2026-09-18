// EXO-SLT ESP32 controller (USB Type-C / CP210x serial).
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

static constexpr uint32_t BAUD = 115200;
#define ExoUart Serial
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
// Keep false until the real actuator, encoder, current-limit and E-stop
// adapters are wired and verified. The state machine below is the contract
// that the actuator adapter must drive; it must never be used to bypass safety.
static constexpr bool MOTION_ADAPTER_READY = false;
// Commissioning dry-run: accepts Pi requests and reports timed
// flexion/extension cycles without driving any motor. Disable before hardware.
static constexpr bool COMMISSIONING_AUTO_COMPLETE = true;
static constexpr uint32_t FLEXION_MS = 1500;
static constexpr uint32_t EXTENSION_MS = 1500;

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
uint16_t targetSets = 1;
uint16_t targetRepetitions = 1;
uint16_t completedSets = 0;
uint32_t sessionStartedMs = 0;
uint32_t activeStartedMs = 0;
uint32_t activeAccumulatedMs = 0;
uint32_t lastRepetitionStartedMs = 0;
uint32_t lastProgressStatusMs = 0;
uint32_t lastRepetitionDurationMs = 0;
uint32_t totalRepetitions = 0;
bool exercisePaused = false;
enum MotionPhase { PHASE_IDLE, PHASE_FLEXION, PHASE_EXTENSION };
MotionPhase motionPhase = PHASE_IDLE;
uint32_t phaseStartedMs = 0;
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

int jsonInt(const String& line, const char* key, int fallback = 0) {
  String needle = String("\"") + key + "\":";
  int start = line.indexOf(needle);
  if (start < 0) return fallback;
  start += needle.length();
  int end = start;
  while (end < line.length() && (isDigit(line[end]) || line[end] == '-')) ++end;
  return line.substring(start, end).toInt();
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
  const uint32_t now = millis();
  const uint32_t elapsedMs = sessionStartedMs == 0 ? 0 : now - sessionStartedMs;
  const uint32_t activeMs = activeAccumulatedMs +
      (exerciseRunning ? now - activeStartedMs : 0);
  const uint32_t targetTotal = static_cast<uint32_t>(targetSets) * targetRepetitions;
  String payload = String("{\"v\":1,\"type\":\"exercise_status\",\"session_id\":\"") +
    session + "\",\"exercise_code\":\"" + EXERCISES[selectedExercise].code +
    "\",\"state\":\"" + state + "\",\"reason\":\"" + reason +
    "\",\"completed_repetitions\":" + String(completedRepetitions) +
    ",\"completed_sets\":" + String(completedSets) +
    ",\"target_sets\":" + String(targetSets) +
    ",\"target_repetitions\":" + String(targetRepetitions) +
    ",\"elapsed_ms\":" + String(elapsedMs) +
    ",\"active_ms\":" + String(activeMs) +
    ",\"repetition_duration_ms\":" + String(lastRepetitionDurationMs) +
    ",\"total_repetitions\":" + String(totalRepetitions) +
    ",\"target_total_repetitions\":" + String(targetTotal) + "}";
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
  completedSets = 0;
  totalRepetitions = 0;
  lastRepetitionDurationMs = 0;
  sessionStartedMs = millis();
  activeStartedMs = sessionStartedMs;
  activeAccumulatedMs = 0;
  lastRepetitionStartedMs = sessionStartedMs;
  exercisePaused = false;
  exerciseRunning = false;
  if ((!MOTION_ADAPTER_READY && !COMMISSIONING_AUTO_COMPLETE) ||
      (estopActive && !COMMISSIONING_AUTO_COMPLETE)) {
    sendStatus("not_ready", activeSession, faultReason);
    return;
  }
  exerciseRunning = true;
  motionPhase = PHASE_FLEXION;
  phaseStartedMs = millis();
  sendStatus("running", activeSession);
}

void stopExercise() {
  if (exerciseRunning) activeAccumulatedMs += millis() - activeStartedMs;
  exerciseRunning = false;
  exercisePaused = false;
  motionPhase = PHASE_IDLE;
  sendStatus("stopped", activeSession);
  sendDeviceStatus();
}

void updateExercise() {
  if (!exerciseRunning || motionPhase == PHASE_IDLE) return;
  const uint32_t elapsed = millis() - phaseStartedMs;
  // The future actuator adapter replaces these phase markers with safe motor
  // commands. Completion is emitted only after the final extension phase.
  if (motionPhase == PHASE_FLEXION && elapsed >= FLEXION_MS) {
    motionPhase = PHASE_EXTENSION;
    phaseStartedMs = millis();
    sendStatus("extending", activeSession);
  } else if (motionPhase == PHASE_EXTENSION && elapsed >= EXTENSION_MS) {
    const uint32_t now = millis();
    lastRepetitionDurationMs = now - lastRepetitionStartedMs;
    lastRepetitionStartedMs = now;
    ++completedRepetitions;
    ++totalRepetitions;
    if (completedRepetitions >= targetRepetitions) {
      completedRepetitions = 0;
      ++completedSets;
    }
    if (completedSets >= targetSets) {
      activeAccumulatedMs += now - activeStartedMs;
      exerciseRunning = false;
      motionPhase = PHASE_IDLE;
      sendStatus("completed", activeSession);
      sendDeviceStatus();
    } else {
      motionPhase = PHASE_FLEXION;
      phaseStartedMs = millis();
      sendStatus("flexing", activeSession);
  }
  if (exerciseRunning && millis() - lastProgressStatusMs >= 500) {
    lastProgressStatusMs = millis();
    sendStatus(motionPhase == PHASE_FLEXION ? "flexing" : "extending", activeSession);
  }
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
    targetSets = constrain(jsonInt(payload, "sets", 1), 1, 20);
    targetRepetitions = constrain(jsonInt(payload, "repetitions", 1), 1, 100);
    if (action == "stop") stopExercise();
    else if (action == "start") {
      const bool resume = exercisePaused && activeSession == session;
      if (!resume) {
        activeSession = session;
        completedRepetitions = 0;
        completedSets = 0;
        totalRepetitions = 0;
        lastRepetitionDurationMs = 0;
        sessionStartedMs = millis();
        activeAccumulatedMs = 0;
        lastRepetitionStartedMs = sessionStartedMs;
      }
      if ((!MOTION_ADAPTER_READY && !COMMISSIONING_AUTO_COMPLETE) ||
          (estopActive && !COMMISSIONING_AUTO_COMPLETE)) {
        sendStatus("not_ready", session, faultReason);
      } else {
        exerciseRunning = true;
        exercisePaused = false;
        activeStartedMs = millis();
        motionPhase = PHASE_FLEXION;
        phaseStartedMs = millis();
        lastProgressStatusMs = millis();
        sendStatus("running", session);
      }
    } else if (action == "pause") {
      if (exerciseRunning) activeAccumulatedMs += millis() - activeStartedMs;
      exerciseRunning = false;
      exercisePaused = true;
      motionPhase = PHASE_IDLE;
      sendStatus("paused", session);
    } else sendStatus("rejected", session, "unsupported exercise action");
  } else if (type == "device_command" || type == "ping") sendDeviceStatus();
}

void setup() {
  // CP210x USB bridge is connected to the ESP32 USB Type-C port.
  ExoUart.begin(BAUD);
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
  updateExercise();
  if (millis() - lastBatteryMs >= 1000) {
    lastBatteryMs = millis();
    readBattery();
    sendDeviceStatus();
  }
  renderDisplay();
}
