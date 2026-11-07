"""How a file travels over a coordinator connection: one binary message,
so a file's description and its bytes can never be separated by another
message sent at the same moment. The message is a 4-byte big-endian length,
that many bytes of JSON describing the file, then the file's bytes."""
import json
import struct


def pack(header, data):
	encoded = json.dumps(header).encode()
	return struct.pack(">I", len(encoded)) + encoded + data


def unpack(message):
	length = struct.unpack(">I", message[:4])[0]
	return json.loads(message[4:4 + length]), message[4 + length:]
