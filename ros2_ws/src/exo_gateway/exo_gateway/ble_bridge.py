"""BLE GATT peripheral that translates a small, versioned protocol into ROS messages.

The bridge does not publish motor commands. SafetyGateway must independently
approve the selected exercise and every subsequent actuator request.
"""

import asyncio
import json
import threading

import rclpy
from rclpy.executors import MultiThreadedExecutor
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node

from exo_interfaces.msg import DeviceState, ExerciseCommand, ExerciseStatus, PrepareExercise

# GATT schema v2. A new UUID namespace forces Android to discard the stale
# cached permissions from the previous bonding experiments.
SERVICE_UUID = '6e400101-b5a3-f393-e0a9-e50e24dcca9e'
CONTROL_UUID = '6e400102-b5a3-f393-e0a9-e50e24dcca9e'
STATUS_UUID = '6e400103-b5a3-f393-e0a9-e50e24dcca9e'
MAX_PAYLOAD_BYTES = 384


class BleBridge(Node):
    def __init__(self, loop):
        super().__init__('ble_bridge')
        self._loop = loop
        self._status_queue = asyncio.Queue()
        self._prepare_pub = self.create_publisher(PrepareExercise, '/exo/exercise/prepare', 10)
        self._exercise_pub = self.create_publisher(ExerciseCommand, '/exo/exercise/request', 10)
        self.create_subscription(ExerciseStatus, '/exo/exercise/status', self._on_status, 10)
        self.create_subscription(DeviceState, '/exo/state', self._on_device_state, 10)

    def _on_status(self, status):
        payload = {
            'v': 1, 'type': 'exercise_status', 'session_id': status.session_id,
            'exercise_code': status.exercise_code,
            'state': status.state, 'reason': status.reason,
            'completed_repetitions': status.completed_repetitions,
        }
        self._loop.call_soon_threadsafe(self._status_queue.put_nowait, payload)

    def _on_device_state(self, state):
        state_name = {
            DeviceState.STATE_DISARMED: 'disarmed',
            DeviceState.STATE_READY: 'ready',
            DeviceState.STATE_ASSISTING: 'assisting',
            DeviceState.STATE_FAULT: 'fault',
        }.get(state.state, 'unknown')
        self._loop.call_soon_threadsafe(self._status_queue.put_nowait, {
            'v': 1, 'type': 'device_status', 'state': state_name,
            'battery_percent': state.battery_percent,
            'battery_voltage': state.battery_voltage,
            'estop_active': state.estop_active,
            'command_watchdog_ok': state.command_watchdog_ok,
            'fault_reason': state.fault_reason,
        })

    def handle_control(self, raw_value):
        try:
            if len(raw_value) > MAX_PAYLOAD_BYTES:
                raise ValueError('payload too large')
            payload = json.loads(bytes(raw_value).decode('utf-8'))
            if payload.get('v') != 1:
                raise ValueError('unsupported protocol version')
            packet_type = payload.get('type')
            if packet_type == 'prepare_exercise':
                self._handle_prepare(payload)
            elif packet_type == 'exercise_command':
                self._handle_exercise_command(payload)
            else:
                raise ValueError('unsupported BLE packet type')
        except (UnicodeDecodeError, ValueError, TypeError, json.JSONDecodeError) as error:
            self.get_logger().warning(f'Rejected BLE control packet: {error}')
            self._loop.call_soon_threadsafe(self._status_queue.put_nowait, {
                'v': 1, 'type': 'exercise_status', 'state': 'rejected', 'reason': str(error),
            })

    def _handle_prepare(self, payload):
        required = ('session_id', 'plan_item_id', 'exercise_code', 'sets', 'repetitions')
        if any(key not in payload for key in required):
            raise ValueError('missing prepare_exercise field')
        sets = int(payload['sets'])
        repetitions = int(payload['repetitions'])
        if not 1 <= sets <= 20 or not 1 <= repetitions <= 100:
            raise ValueError('exercise target is outside configured BLE limits')
        message = PrepareExercise()
        message.session_id = str(payload['session_id'])[:64]
        message.plan_item_id = str(payload['plan_item_id'])[:64]
        message.exercise_code = str(payload['exercise_code'])[:64]
        message.sets = sets
        message.repetitions = repetitions
        if not message.session_id or not message.exercise_code:
            raise ValueError('invalid exercise target')
        self._prepare_pub.publish(message)

    def _handle_exercise_command(self, payload):
        required = ('session_id', 'exercise_code', 'action')
        if any(key not in payload for key in required):
            raise ValueError('missing exercise_command field')
        actions = {'start': ExerciseCommand.ACTION_START,
                   'pause': ExerciseCommand.ACTION_PAUSE,
                   'stop': ExerciseCommand.ACTION_STOP}
        sides = {'both': ExerciseCommand.SIDE_BOTH,
                 'left': ExerciseCommand.SIDE_LEFT,
                 'right': ExerciseCommand.SIDE_RIGHT}
        action = str(payload['action']).lower()
        side = str(payload.get('side', 'both')).lower()
        if action not in actions or side not in sides:
            raise ValueError('invalid exercise action or side')
        message = ExerciseCommand()
        message.sequence = int(payload.get('sequence', 0))
        message.session_id = str(payload['session_id'])[:64]
        message.plan_item_id = str(payload.get('plan_item_id', ''))[:64]
        message.exercise_code = str(payload['exercise_code'])[:64]
        message.action = actions[action]
        message.side = sides[side]
        message.repetitions = int(payload.get('repetitions', 1))
        message.assist_percent = float(payload.get('assist_percent', 0.0))
        if not message.session_id or not message.exercise_code:
            raise ValueError('invalid exercise command')
        self._exercise_pub.publish(message)


async def run():
    try:
        from bless import BlessServer, GATTAttributePermissions, GATTCharacteristicProperties
        from bless.backends.bluezdbus.dbus.advertisement import BlueZLEAdvertisement
    except ImportError as error:
        raise RuntimeError('Install BLE dependencies: pip install -r requirements-ble.txt') from error

    # bless 0.3.0 exposes optional TxPower/interval properties by default.
    # BlueZ on Raspberry Pi rejects those properties with Invalid Parameters
    # when registering the advertisement. Keep the portable core fields only.
    for property_name in (
            'TxPower', 'MinInterval', 'MaxInterval',
            'ManufacturerData', 'ServiceData'):
        if hasattr(BlueZLEAdvertisement, property_name):
            delattr(BlueZLEAdvertisement, property_name)

    loop = asyncio.get_running_loop()
    rclpy.init()
    node = BleBridge(loop)
    executor = MultiThreadedExecutor()
    executor.add_node(node)
    executor_thread = threading.Thread(target=executor.spin, daemon=True)
    executor_thread.start()

    # Keep the advertised name short: the 128-bit service UUID plus a long
    # local name can exceed the BLE legacy advertisement limit (31 bytes).
    server = BlessServer(name='ExoLeg-1', loop=loop)
    await server.add_new_service(SERVICE_UUID)
    # Nordic UART clients normally send command frames without waiting for an
    # ATT response.  Expose both write modes: older clients can still use a
    # response while Android can use the low-latency no-response path.
    writable = (
        GATTCharacteristicProperties.write
        | GATTCharacteristicProperties.write_without_response
    )
    await server.add_new_characteristic(
        SERVICE_UUID, CONTROL_UUID, writable, None, GATTAttributePermissions.writeable)
    readable_notifiable = GATTCharacteristicProperties.read | GATTCharacteristicProperties.notify
    await server.add_new_characteristic(
        SERVICE_UUID, STATUS_UUID, readable_notifiable, bytearray(b'{}'),
        GATTAttributePermissions.readable)

    def on_write(characteristic, value, **_kwargs):
        if characteristic.uuid.lower() == CONTROL_UUID:
            node.get_logger().info(f'Received BLE control write ({len(value)} bytes)')
            node.handle_control(value)
        characteristic.value = value

    def on_read(characteristic, **_kwargs):
        value = characteristic.value or bytearray()
        node.get_logger().info(
            f'Read BLE characteristic {characteristic.uuid} ({len(value)} bytes)')
        return bytearray(value)

    server.write_request_func = on_write
    server.read_request_func = on_read
    server.app.StartNotify = lambda characteristic: node.get_logger().info(
        'BLE central subscribed to status notifications')
    server.app.StopNotify = lambda characteristic: node.get_logger().info(
        'BLE central unsubscribed from status notifications')
    await server.start()
    node.get_logger().info('Advertising ExoLeg-1 BLE GATT service')
    try:
        while rclpy.ok():
            status = await node._status_queue.get()
            characteristic = server.get_characteristic(STATUS_UUID)
            characteristic.value = bytearray(json.dumps(status, separators=(',', ':')).encode())
            server.update_value(SERVICE_UUID, STATUS_UUID)
    finally:
        await server.stop()
        executor.shutdown()
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


def main():
    try:
        asyncio.run(run())
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
