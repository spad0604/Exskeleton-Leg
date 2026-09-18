"""ROS safety boundary. Hardware drivers must remain downstream of this node."""

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node

from exo_interfaces.msg import (
    DeviceCommand,
    DeviceState,
    ExerciseCommand,
    ExerciseStatus,
    PrepareExercise,
)


class SafetyGateway(Node):
    def __init__(self):
        super().__init__('safety_gateway')
        self.declare_parameter('max_assist_percent', 40.0)
        self.declare_parameter('command_timeout_sec', 0.5)
        # False until a real, independently fail-safe E-stop input is wired in.
        self.declare_parameter('estop_active', True)
        self.declare_parameter('exercise_commissioning_mode', False)
        self._last_command_time = None
        self._fault_reason = 'E-stop hardware adapter not configured'
        self._prepared_session_id = None
        self._state_pub = self.create_publisher(DeviceState, '/exo/state', 10)
        self._accepted_pub = self.create_publisher(DeviceCommand, '/exo/command/accepted', 10)
        self.create_subscription(DeviceCommand, '/exo/command/request', self._on_request, 10)
        self.create_subscription(PrepareExercise, '/exo/exercise/prepare', self._on_prepare_exercise, 10)
        self._exercise_accepted_pub = self.create_publisher(
            ExerciseCommand, '/exo/exercise/accepted', 10)
        self.create_subscription(ExerciseCommand, '/exo/exercise/request', self._on_exercise_request, 10)
        self._exercise_status_pub = self.create_publisher(ExerciseStatus, '/exo/exercise/status', 10)
        self.create_timer(0.1, self._publish_state)

        # Single source of truth for the commissioning dataset. The actuator
        # adapter will later use the same code to select its motion profile.
        self._exercise_catalog = {
            'walk': {'side': ExerciseCommand.SIDE_BOTH, 'profile': 'gait'},
            'raise_left_leg': {'side': ExerciseCommand.SIDE_LEFT, 'profile': 'leg_raise'},
            'raise_right_leg': {'side': ExerciseCommand.SIDE_RIGHT, 'profile': 'leg_raise'},
            'sit_to_stand': {'side': ExerciseCommand.SIDE_BOTH, 'profile': 'sit_stand'},
            'kick_left_leg': {'side': ExerciseCommand.SIDE_LEFT, 'profile': 'leg_kick'},
            'kick_right_leg': {'side': ExerciseCommand.SIDE_RIGHT, 'profile': 'leg_kick'},
            'kick_left_knee': {'side': ExerciseCommand.SIDE_LEFT, 'profile': 'knee_kick'},
            'kick_right_knee': {'side': ExerciseCommand.SIDE_RIGHT, 'profile': 'knee_kick'},
        }

    def _on_prepare_exercise(self, exercise):
        status = ExerciseStatus()
        status.session_id = exercise.session_id
        status.exercise_code = exercise.exercise_code
        if self._estop_active() and not self._commissioning_mode():
            status.state = 'not_ready'
            status.reason = 'E-stop active or hardware adapter not configured'
        elif exercise.exercise_code not in self._exercise_catalog:
            status.state = 'rejected'
            status.reason = 'unsupported exercise code'
        elif not exercise.exercise_code or not exercise.sets or not exercise.repetitions:
            status.state = 'rejected'
            status.reason = 'exercise code, sets, and repetitions are required'
        else:
            self._prepared_session_id = exercise.session_id
            status.state = 'prepared'
            status.reason = ''
        self._exercise_status_pub.publish(status)

    def _on_exercise_request(self, command):
        status = ExerciseStatus()
        status.session_id = command.session_id
        status.exercise_code = command.exercise_code
        status.completed_repetitions = 0

        if command.action == ExerciseCommand.ACTION_STOP:
            self._exercise_accepted_pub.publish(command)
            status.state = 'stopped'
            status.reason = ''
            self._exercise_status_pub.publish(status)
            return
        if self._estop_active() and not self._commissioning_mode():
            status.state = 'not_ready'
            status.reason = 'E-stop active or hardware adapter not configured'
        elif command.exercise_code not in self._exercise_catalog:
            status.state = 'rejected'
            status.reason = 'unsupported exercise code'
        elif (self._exercise_catalog[command.exercise_code]['side'] != ExerciseCommand.SIDE_BOTH
              and command.side != self._exercise_catalog[command.exercise_code]['side']):
            status.state = 'rejected'
            status.reason = 'exercise side does not match the selected profile'
        elif not self._prepared_session_id or command.session_id != self._prepared_session_id:
            status.state = 'rejected'
            status.reason = 'exercise session was not prepared'
        elif command.action not in (
                ExerciseCommand.ACTION_START, ExerciseCommand.ACTION_PAUSE):
            status.state = 'rejected'
            status.reason = 'unsupported exercise action'
        elif not 1 <= command.repetitions <= 100:
            status.state = 'rejected'
            status.reason = 'repetitions must be between 1 and 100'
        elif not 0.0 <= command.assist_percent <= self.get_parameter('max_assist_percent').value:
            status.state = 'rejected'
            status.reason = 'assist_percent is outside the configured limit'
        else:
            self._exercise_accepted_pub.publish(command)
            status.state = 'running' if command.action == ExerciseCommand.ACTION_START else 'paused'
            status.reason = ''
            self._last_command_time = self.get_clock().now()

        self._exercise_status_pub.publish(status)

    def _estop_active(self):
        return self.get_parameter('estop_active').value

    def _commissioning_mode(self):
        return self.get_parameter('exercise_commissioning_mode').value

    def _on_request(self, command):
        if command.mode == DeviceCommand.MODE_STOP or not command.enable:
            self._accepted_pub.publish(command)
            self._fault_reason = ''
            return
        if self._estop_active():
            self._fault_reason = 'E-stop active or hardware adapter not configured'
            self.get_logger().warning(f'Rejected enable request: {self._fault_reason}')
            return
        maximum = self.get_parameter('max_assist_percent').value
        if not 0.0 <= command.assist_percent <= maximum:
            self._fault_reason = f'assist_percent must be in [0, {maximum}]'
            self.get_logger().warning(
                f'Rejected command {command.sequence}: {self._fault_reason}')
            return
        self._last_command_time = self.get_clock().now()
        self._fault_reason = ''
        self._accepted_pub.publish(command)

    def _publish_state(self):
        state = DeviceState()
        state.header.stamp = self.get_clock().now().to_msg()
        state.estop_active = self._estop_active()
        timeout = self.get_parameter('command_timeout_sec').value
        state.command_watchdog_ok = (
            self._last_command_time is not None
            and (self.get_clock().now() - self._last_command_time).nanoseconds / 1e9 <= timeout
        )
        state.state = DeviceState.STATE_FAULT if state.estop_active else DeviceState.STATE_READY
        state.battery_percent = -1.0  # replaced by BMS adapter
        state.battery_voltage = -1.0  # replaced by ESP32 ADC/BMS telemetry
        state.fault_reason = self._fault_reason
        self._state_pub.publish(state)


def main():
    rclpy.init()
    node = SafetyGateway()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
