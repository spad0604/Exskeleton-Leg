"""Pi USB serial (CP210x) <-> ESP32 USB Type-C bridge.

The wire format is deliberately inspectable while the hardware protocol is
being commissioned:

    EXO1|{"type":"exercise_command",...}|AB12\n
AB12 is CRC-16/CCITT over the JSON bytes. Only messages already accepted by
SafetyGateway are sent to the MCU. The MCU must still enforce its own limits
and watchdog.
"""

import json
import threading
import time

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node

from exo_interfaces.msg import DeviceCommand, DeviceState, ExerciseCommand, ExerciseStatus


def crc16(data):
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def encode_frame(payload):
    raw = json.dumps(payload, separators=(',', ':'), ensure_ascii=True).encode('utf-8')
    return b'EXO1|' + raw + b'|' + f'{crc16(raw):04X}'.encode('ascii') + b'\n'


def decode_frame(line):
    parts = line.strip().split(b'|')
    if len(parts) != 3 or parts[0] != b'EXO1':
        raise ValueError('invalid UART frame prefix')
    raw, received = parts[1], parts[2]
    if len(raw) > 768 or received.upper() != f'{crc16(raw):04X}'.encode('ascii'):
        raise ValueError('UART CRC or payload length check failed')
    return json.loads(raw.decode('utf-8'))


class UartBridge(Node):
    def __init__(self):
        super().__init__('uart_bridge')
        self.declare_parameter('device', '/dev/ttyUSB0')
        self.declare_parameter('baudrate', 115200)
        self.declare_parameter('reconnect_sec', 2.0)
        self._serial = None
        self._serial_lock = threading.Lock()
        self._stop = threading.Event()
        self._state_pub = self.create_publisher(DeviceState, '/exo/state', 10)
        self._exercise_status_pub = self.create_publisher(ExerciseStatus, '/exo/exercise/status', 10)
        self.create_subscription(DeviceCommand, '/exo/command/accepted', self._on_device_command, 10)
        self.create_subscription(ExerciseCommand, '/exo/exercise/accepted', self._on_exercise_command, 10)
        self._reader = threading.Thread(target=self._read_loop, name='exo-uart-reader', daemon=True)
        self._reader.start()

    def _connect(self):
        try:
            import serial
            device = str(self.get_parameter('device').value)
            baudrate = int(self.get_parameter('baudrate').value)
            self._serial = serial.Serial(device, baudrate=baudrate, timeout=0.5, write_timeout=0.5)
            self.get_logger().info(f'Connected ESP32 USB serial at {device} ({baudrate} baud)')
        except Exception as error:  # pyserial reports several OS-specific errors
            self._serial = None
            self.get_logger().warning(f'ESP32 UART unavailable: {error}')

    def _send(self, payload):
        with self._serial_lock:
            if self._serial is None:
                return
            try:
                self._serial.write(encode_frame(payload))
                self._serial.flush()
                self.get_logger().info(f"UART TX {payload.get('type', 'unknown')}")
            except Exception as error:
                self.get_logger().error(f'UART write failed: {error}')
                try:
                    self._serial.close()
                finally:
                    self._serial = None

    def _on_device_command(self, command):
        self._send({
            'type': 'device_command', 'sequence': int(command.sequence),
            'mode': int(command.mode), 'enable': bool(command.enable),
            'assist_percent': float(command.assist_percent),
        })

    def _on_exercise_command(self, command):
        actions = {ExerciseCommand.ACTION_START: 'start',
                   ExerciseCommand.ACTION_PAUSE: 'pause',
                   ExerciseCommand.ACTION_STOP: 'stop'}
        sides = {ExerciseCommand.SIDE_BOTH: 'both', ExerciseCommand.SIDE_LEFT: 'left',
                 ExerciseCommand.SIDE_RIGHT: 'right'}
        self._send({
            'type': 'exercise_command', 'sequence': int(command.sequence),
            'session_id': command.session_id, 'plan_item_id': command.plan_item_id,
            'exercise_code': command.exercise_code, 'action': actions.get(command.action, 'stop'),
            'side': sides.get(command.side, 'both'), 'repetitions': int(command.repetitions),
            'sets': int(command.sets),
            'assist_percent': float(command.assist_percent),
        })

    def _handle_rx(self, payload):
        kind = payload.get('type')
        if kind == 'device_status':
            state = DeviceState()
            state.state = {
                'disarmed': DeviceState.STATE_DISARMED,
                'ready': DeviceState.STATE_READY,
                'assisting': DeviceState.STATE_ASSISTING,
                'fault': DeviceState.STATE_FAULT,
            }.get(payload.get('state'), DeviceState.STATE_FAULT)
            state.estop_active = bool(payload.get('estop_active', True))
            state.command_watchdog_ok = bool(payload.get('command_watchdog_ok', False))
            state.battery_percent = float(payload.get('battery_percent', -1.0))
            state.battery_voltage = float(payload.get('battery_voltage', -1.0))
            state.fault_reason = str(payload.get('fault_reason', ''))[:256]
            state.header.stamp = self.get_clock().now().to_msg()
            self._state_pub.publish(state)
        elif kind == 'exercise_status':
            status = ExerciseStatus()
            status.session_id = str(payload.get('session_id', ''))[:64]
            status.exercise_code = str(payload.get('exercise_code', ''))[:64]
            status.state = str(payload.get('state', 'rejected'))[:32]
            status.reason = str(payload.get('reason', ''))[:256]
            status.completed_repetitions = int(payload.get('completed_repetitions', 0))
            status.completed_sets = int(payload.get('completed_sets', 0))
            status.target_sets = int(payload.get('target_sets', 0))
            status.target_repetitions = int(payload.get('target_repetitions', 0))
            status.elapsed_ms = int(payload.get('elapsed_ms', 0))
            status.active_ms = int(payload.get('active_ms', 0))
            status.repetition_duration_ms = int(payload.get('repetition_duration_ms', 0))
            status.total_repetitions = int(payload.get('total_repetitions', 0))
            status.target_total_repetitions = int(payload.get('target_total_repetitions', 0))
            self._exercise_status_pub.publish(status)
        elif kind == 'exercise_selected':
            exercise_code = str(payload.get('exercise_code', ''))[:64]
            self.get_logger().info(f'ESP32 selected exercise {exercise_code}')
            status = ExerciseStatus()
            status.session_id = 'local-ui'
            status.exercise_code = exercise_code
            status.state = 'selected'
            status.reason = ''
            status.completed_repetitions = 0
            status.completed_sets = 0
            status.target_sets = 0
            status.target_repetitions = 0
            status.elapsed_ms = 0
            status.active_ms = 0
            status.repetition_duration_ms = 0
            status.total_repetitions = 0
            status.target_total_repetitions = 0
            self._exercise_status_pub.publish(status)
        else:
            self.get_logger().warning(f'Ignoring unknown ESP32 UART message: {kind}')

    def _read_loop(self):
        while not self._stop.is_set() and rclpy.ok():
            if self._serial is None:
                self._connect()
                if self._serial is None:
                    self._stop.wait(float(self.get_parameter('reconnect_sec').value))
                    continue
            try:
                line = self._serial.readline()
                if not line:
                    continue
            except Exception as error:
                self.get_logger().warning(f'UART read failed: {error}')
                try:
                    self._serial.close()
                finally:
                    self._serial = None
                continue
            try:
                payload = decode_frame(line)
            except Exception as error:
                # USB-UART ESP32 boot messages and monitor text are not
                # protocol frames. Ignore them without resetting the port.
                self.get_logger().debug(f'Ignoring non-protocol USB input: {error}')
                continue
            try:
                self.get_logger().info(f"UART RX {payload.get('type', 'unknown')}")
                self._handle_rx(payload)
            except Exception as error:
                self.get_logger().warning(f'UART frame handling failed: {error}')
                try:
                    self._serial.close()
                finally:
                    self._serial = None

    def destroy_node(self):
        self._stop.set()
        with self._serial_lock:
            if self._serial is not None:
                self._serial.close()
                self._serial = None
        self._reader.join(timeout=1.0)
        return super().destroy_node()


def main():
    rclpy.init()
    node = UartBridge()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
