"""How a file travels over a coordinator connection: one binary message,
so a file's description and its bytes can never be separated by another
message sent at the same moment. The message is a 4-byte big-endian length,
that many bytes of JSON describing the file, then the file's bytes."""
import hashlib
import hmac
import json
import struct


def pack(header, data):
	encoded = json.dumps(header).encode()
	return struct.pack(">I", len(encoded)) + encoded + data


def machine_token(key, machine):
	"""The lasting token of numbered machine `machine`, made from the worker
	key that only the coordinator and the owner's computer hold."""
	return hmac.new(key.encode(), f"machine:{machine}".encode(), hashlib.sha256).hexdigest()


def unpack(message):
	length = struct.unpack(">I", message[:4])[0]
	return json.loads(message[4:4 + length]), message[4 + length:]
