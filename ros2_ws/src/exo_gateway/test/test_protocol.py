import base64
import json
import unittest

from exo_gateway.ble_bridge import BleBridge
from exo_gateway.uart_bridge import decode_frame, encode_frame


class ProtocolTests(unittest.TestCase):
    def test_uart_frame_round_trip(self):
        payload = {
            'type': 'home_command',
            'action': 'prepare',
            'session_id': 'routine-test',
        }

        self.assertEqual(payload, decode_frame(encode_frame(payload)))

    def test_ble_chunks_reassemble_a_payload_larger_than_one_write(self):
        node = object.__new__(BleBridge)
        node._routine_transfers = {}
        captured = []
        node._handle_routine_command = captured.append
        routine = {
            'v': 1,
            'type': 'routine_command',
            'action': 'start',
            'session_id': 'routine-test',
            'routine_id': 'routine-id',
            'repetitions': 5,
            'steps': [
                {
                    'motor': 'C2', 'direction': 'OUT', 'duration_ms': 5000,
                    'rest_after_ms': 1000, 'repeat_count': 1,
                    'label': 'Nâng đùi cao',
                }
            ] * 8,
        }
        raw = json.dumps(routine, separators=(',', ':')).encode()
        chunks = [raw[index:index + 180] for index in range(0, len(raw), 180)]
        self.assertGreater(len(raw), 384)

        node._handle_routine_begin({
            'transfer_id': 'transfer-1', 'session_id': 'routine-test',
            'total_bytes': len(raw), 'total_chunks': len(chunks),
        })
        for index, chunk in enumerate(chunks):
            node._handle_routine_chunk({
                'transfer_id': 'transfer-1', 'index': index,
                'data': base64.b64encode(chunk).decode(),
            })
        node._handle_routine_commit({'transfer_id': 'transfer-1'})

        self.assertEqual([routine], captured)
