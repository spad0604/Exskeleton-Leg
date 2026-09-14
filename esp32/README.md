# ESP32 UART2 controller

`exo_controller.ino` is a transport/commissioning skeleton for the ESP32
UART2 connection. Wire Pi UART1 (`/dev/serial1`) TX/RX crossed to ESP32 UART2
RX2/TX2 (GPIO16/17 in the example) and connect grounds. Confirm the exact Pi
header pins and ESP32 board pin mapping before powering the actuator system.

The firmware accepts frames from the Pi in this format:

```text
EXO1|{"type":"exercise_command",...}|CRC16\n
```

It currently reports `not_ready` for motion commands by design. Implement motor
drivers only after adding encoder validation, current/temperature limits,
hardware E-stop, watchdog timeout, and a bench/HIL test. Supported exercise
codes are:

* `walk`
* `raise_left_leg`, `raise_right_leg`
* `sit_to_stand`
* `kick_left_leg`, `kick_right_leg`
* `kick_left_knee`, `kick_right_knee`
