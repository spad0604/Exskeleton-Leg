# BLE exercise preparation protocol v1

The Pi advertises as `ExoLeg-1`. The short name is intentional because the
128-bit service UUID and a long local name can exceed the legacy BLE
advertisement payload limit.

Pi exposes one service:

| Characteristic | UUID suffix | Direction | Purpose |
| --- | --- | --- | --- |
| Exoskeleton service | `6e400001-b5a3-f393-e0a9-e50e24dcca9e` | — | GATT service |
| Control | `...0002-b5a3-f393-e0a9-e50e24dcca9e` | app → Pi, write with response | Request preparation |
| Status | `...0003-b5a3-f393-e0a9-e50e24dcca9e` | Pi → app, notification | Exercise readiness/status |

All values are UTF-8 JSON, at most 384 bytes. A client must wait for the write
response and then the status notification; a successful BLE write is only receipt,
not approval to operate the device.

Preparation request:

```json
{"v":1,"type":"prepare_exercise","session_id":"server-session-id","plan_item_id":"plan-id","exercise_code":"sit_to_stand","sets":3,"repetitions":10}
```

Status notification:

```json
{"v":1,"type":"exercise_status","session_id":"server-session-id","state":"prepared","reason":"","completed_repetitions":0}
```

Allowed status states in this base are `prepared`, `not_ready`, `rejected`,
`running`, `paused`, and `stopped`.
`prepared` only says Pi has accepted the exercise metadata; it does not arm motors.
Later hardware/session nodes may publish progress status on `/exo/exercise/status`,
which the bridge forwards without changing its GATT contract.

Exercise command:

```json
{"v":1,"type":"exercise_command","session_id":"server-session-id","exercise_code":"raise_left_leg","action":"start","side":"left","repetitions":8,"assist_percent":20}
```

Supported exercise codes are `walk`, `raise_left_leg`, `raise_right_leg`,
`sit_to_stand`, `kick_left_leg`, `kick_right_leg`, `kick_left_knee`, and
`kick_right_knee`. Actions are `start`, `pause`, and `stop`; sides are `both`,
`left`, or `right`. SafetyGateway rejects commands unless the session was
prepared and the E-stop, watchdog, assist limit, and exercise code checks pass.
