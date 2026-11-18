"""IPC reply framing without starting a player."""
import json

from conftest import IpcClient


def test_reply_waits_for_newline_across_utf8_and_read_boundaries():
    client = IpcClient('unused')
    client.request_id = 7
    reply = (json.dumps({'request_id': 7, 'error': 'success', 'data': '审阅' * 22000},
                        ensure_ascii=False) + '\n').encode('utf-8')
    split = reply.index('审'.encode('utf-8')) + 1
    assert not client._contains_reply(reply[:split])
    assert not client._contains_reply(reply[:65536])
    assert not client._contains_reply(reply[:-1])
    assert client._contains_reply(reply)
    event = b'{"event":"property-change"}\n'
    assert not client._contains_reply(event + reply[:split])
    assert client._contains_reply(event + reply)


def test_reply_ignores_events_and_other_request_ids():
    client = IpcClient('unused')
    client.request_id = 2
    assert not client._contains_reply(b'{"event":"shutdown"}\n{"request_id":1}\n')
    assert client._contains_reply(b'{"event":"shutdown"}\n{"request_id":1}\n{"request_id":2}\n')
