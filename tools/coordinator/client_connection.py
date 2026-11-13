"""client.py's connection to the coordinator: where it listens, the signed
control connection every command talks through, and reconnecting mid-task."""
import asyncio
import contextlib
import json
import os
import re
import subprocess
import time

import websockets

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
STATE =os.path.expanduser("~/.cache/scrap-heist/coordinator.json")
# Made once by scripts/coordinator.sh key; never leaves this computer.
CONTROL_KEY = os.path.expanduser("~/.cache/scrap-heist/control-key")
CONTROL_NAMESPACE = "scrap-heist-control"
MAX_MESSAGE = 64 * 1024 * 1024


def control_url():
	if os.environ.get("COORDINATOR_CONTROL"):
		return os.environ["COORDINATOR_CONTROL"]
	if not os.path.isfile(STATE):
		return None
	state = json.load(open(STATE))
	# A remote coordinator (coordinator.sh attach) has no pid here.
	if state.get("remote"):
		return state["control"]
	try:
		os.kill(state["pid"], 0)
	except (OSError, KeyError):
		return None
	return state["control"]


class Control:
	"""A control connection with its request sent and any challenge
	answered; recv gives the coordinator's replies, the first one included."""

	def __init__(self, socket, first):
		self.socket = socket
		self.first = first

	async def recv(self):
		if self.first is not None:
			first, self.first = self.first, None
			return first
		return await self.socket.recv()


def sign(nonce):
	"""Signs a coordinator's challenge with this session's control key."""
	if not isinstance(nonce, str) or not re.fullmatch(r"[0-9a-f]{64}", nonce):
		raise SystemExit("the coordinator sent a challenge that is not a 64-character hex nonce; not signing it")
	if not os.path.isfile(CONTROL_KEY):
		raise SystemExit("the coordinator wants a signed answer and there is no key here (scripts/coordinator.sh key)")
	signed = subprocess.run(["ssh-keygen", "-q", "-Y", "sign", "-f", CONTROL_KEY, "-n", CONTROL_NAMESPACE],
		input=nonce.encode(), capture_output=True)
	if signed.returncode != 0:
		raise SystemExit(f"could not sign the challenge: {signed.stderr.decode().strip()}")
	return signed.stdout.decode()


async def connect(url, request, **options):
	"""Opens a control connection, sends the request and, when the
	coordinator was started with --control-key, answers its challenge.
	The caller closes it (Control.socket)."""
	socket = await websockets.connect(url, **options)
	try:
		await socket.send(json.dumps(request))
		first = await socket.recv()
		message = json.loads(first)
		if message.get("type") == "challenge":
			await socket.send(json.dumps({"type": "answer", "signature": sign(message["nonce"])}))
			first = await socket.recv()
	except BaseException:
		await socket.close()
		raise
	return Control(socket, first)


def alert(line):
	"""An ALERT or CLEARED line, alone on its line, at once."""
	print(line, flush=True)


def http_status(error):
	"""The HTTP status a refused websocket handshake answered with, or None
	(websockets 10 names it status_code, 13 keeps it on the response)."""
	code = getattr(error, "status_code", None)
	return code or getattr(getattr(error, "response", None), "status_code", None)


@contextlib.asynccontextmanager
async def control(url, request, **options):
	"""Every command talks through this (connect, closed on the way out)."""
	try:
		connection = await connect(url, request, **options)
	except websockets.ConnectionClosed:
		raise SystemExit("the coordinator closed the connection (is this session's control key the one it was started with?)")
	except (OSError, asyncio.TimeoutError, websockets.InvalidHandshake) as error:
		code = http_status(error)
		answered = f"answered HTTP {code}" if code else f"could not be reached ({error})"
		alert(f"ALERT TUNNEL_DOWN: the coordinator's control address {url} {answered} "
			"| machine 1's tunnel or coordinator is down; check the run (scripts/standby-status.sh) and start a new one if it stays down")
		raise SystemExit(2)
	try:
		yield connection
	finally:
		await connection.socket.close()


RECONNECT_SECONDS = 60
# For a whole build: past either, a coordinator that keeps dropping is given up on.
MAX_RECONNECTS = 5
RECONNECT_BUDGET_SECONDS = 180


async def watch_again(url, task, seconds=RECONNECT_SECONDS):
	"""After the control connection drops mid-task: reconnects for up to
	`seconds` and watches the same task again. None if the task is
	unknown there or the coordinator stays gone."""
	print(f"control connection dropped; reconnecting for up to {seconds:.0f}s to watch task {task} again", flush=True)
	deadline = time.time() + seconds
	while time.time() < deadline:
		try:
			connection = await asyncio.wait_for(connect(url, {"type": "watch-task", "task": task}, max_size=MAX_MESSAGE), 10)
			answer = json.loads(await connection.recv())
		except (OSError, asyncio.TimeoutError, websockets.InvalidHandshake, websockets.ConnectionClosed):
			await asyncio.sleep(1)
			continue
		if answer.get("type") != "watching":
			print(f"could not watch task {task} again: {answer.get('text', answer)}", flush=True)
			await connection.socket.close()
			return None
		print(f"reconnected; watching task {task} again ({answer['up']} of {answer['count']} machines up)", flush=True)
		return connection
	print(f"the coordinator stayed unreachable for {seconds:.0f}s; giving up on task {task} (it may carry on there)", flush=True)
	return None
