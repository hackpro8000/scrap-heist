"""client.py's maintenance commands: `update <sha>` (hot update of the hub
and every machine, hub_update.py) and `engine <sha>` (an engine compile on
one machine, hub_engine.py), and the code lines `status` prints."""
import asyncio
import json
import time

import websockets

from client_connection import MAX_MESSAGE, alert, connect, control

POLL_SECONDS = 1.0  # between status polls while the hub and machines come back (tests shorten it)


async def ask_status(url):
	"""The hub's status answer, or None while it is restarting."""
	try:
		connection = await asyncio.wait_for(connect(url, {"type": "status"}), 10)
	except (OSError, asyncio.TimeoutError, websockets.InvalidHandshake, websockets.ConnectionClosed):
		return None
	try:
		return json.loads(await asyncio.wait_for(connection.recv(), 10))
	except (asyncio.TimeoutError, websockets.ConnectionClosed, ValueError):
		return None
	finally:
		await connection.socket.close()


async def update(url, commit, force, wait):
	"""Asks the hub to update; then polls until it is back on the commit and
	every machine connected is on it too, or `wait` seconds. 0 when all are."""
	began = time.time()
	async with control(url, {"type": "update", "commit": commit, "force": force}) as connection:
		try:
			answer = json.loads(await connection.recv())
		except websockets.ConnectionClosed:
			answer = {"type": "error", "text": "the hub closed the connection without answering (does it know update?)"}
	if answer.get("type") != "updating":
		print(f"update refused: {answer.get('text', answer)}", flush=True)
		return 1
	told, boot = answer.get("machines", 0), answer.get("boot")
	print(f"update {commit[:12]}: the hub checked it out and told {told} machines; waiting for it to come back", flush=True)
	back, up, on = None, [], []
	while time.time() < began + wait:
		state = await ask_status(url)
		if state and state.get("boot") != boot and state.get("code") == commit:
			if back is None:
				back = time.time() - began
				print(f"hub back on {commit[:12]} after {back:.0f}s", flush=True)
			codes, up = state.get("codes", {}), state.get("up", [])
			on = [name for name in up if codes.get(name) == commit]
			if len(up) >= told and len(on) == len(up):
				break
		await asyncio.sleep(POLL_SECONDS)
	if back is None:
		print(f"the hub did not come back on {commit[:12]} within {wait}s (machine 1's coordinator.log says why)", flush=True)
		return 1
	behind = [name for name in up if name not in on]
	print(f"{len(on)} of {len(up)} machines on {commit[:12]} after {time.time() - began:.0f}s"
		+ (f"; not yet: {' '.join(behind)}" if behind else "") + (f"; {told} were up before" if len(up) < told else ""), flush=True)
	return 0 if not behind and len(up) >= told else 1


async def engine(url, commit, wait):
	"""Runs an engine check and prints its output as it comes; 0 when it compiled."""
	began = time.time()
	async with control(url, {"type": "engine", "commit": commit}, max_size=MAX_MESSAGE) as connection:
		first = json.loads(await connection.recv())
		if first.get("type") != "engine-posted":
			print(f"engine check refused: {first.get('text', first)}", flush=True)
			return 1
		task = first["task"]
		print(f"engine check {task} of {commit[:12]}; machines with cargo: {' '.join(first['cargo']) or 'none yet (it waits for one)'}", flush=True)
		seen = 0
		while True:
			left = began + wait - time.time()
			if left <= 0:
				print(f"ENGINE TIMEOUT: no result in {wait}s", flush=True)
				return 1
			try:
				event = json.loads(await asyncio.wait_for(connection.recv(), left))
			except asyncio.TimeoutError:
				continue
			except websockets.ConnectionClosed:
				print("the control connection dropped before the engine check ended", flush=True)
				return 3
			if event.get("task") != task:
				continue
			if event["type"] == "engine-output":
				for line in event.get("lines", []):
					print(line, flush=True)
				seen += len(event.get("lines", []))
			elif event["type"] == "redealt":
				alert(f"ALERT REDEALT: engine check from {event['from']} to {event['to']}: {event['reason']} | nothing; it starts again there")
			elif event["type"] == "engine-finished":
				if not event["ok"] and not seen:
					print("\n".join(event.get("tail", [])), flush=True)
				print(f"ENGINE {'OK' if event['ok'] else 'FAILED'} on {event['machine']} in {event.get('seconds')}s"
					+ ("" if event["ok"] else f" (exit {event.get('code')})"), flush=True)
				return 0 if event["ok"] else 1


def code_lines(answer):
	"""For status: machines whose code differs from the hub's."""
	code, codes = answer.get("code"), answer.get("codes", {})
	if not code:
		return []
	other = [f"{name}={codes[name][:12] if codes.get(name) else '?'}" for name in answer.get("up", []) if codes.get(name) != code]
	return [f"machines on other code than the hub's {code[:12]}: {' '.join(other)}"] if other else []
