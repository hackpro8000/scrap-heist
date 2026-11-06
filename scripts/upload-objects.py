#!/usr/bin/env python3
"""Uploads a layout's handed-over objects to Roblox as Models through Open
Cloud, as many at once as Roblox will take.

  ROBLOX_API_KEY=... ROBLOX_CREATOR_ID=<user id> scripts/upload-objects.py ServerMap <folder>

The key needs the Assets API's asset:write permission. <folder> holds one
folder per shard, named by its number, with the objects that shard handed
over (scripts/standby-task.sh): <id>.glb files and names.tsv, each object's
id and label. An object is skipped when it already has an asset: its id is
in the layout's ledger, art/src/layouts/<Name>Uploads.tsv, or in this
machine's own record of what it has uploaded, art/models/<Name>/uploaded.tsv,
which outlives a failed run so the next one sends only what is still missing.

It writes <folder>/uploaded.tsv: the id, asset ID and shard of every
handed-over object this machine has uploaded, now or earlier, for
scripts/merge-shards.sh to add to the ledger.

One machine sends everything, so one throttle sees every answer. It starts
with UPLOAD_START uploads in flight and allows one more after each that
succeeds, up to UPLOAD_MOST. When Roblox turns a request away (429) it halves
the number and holds every new request for as long as Roblox asks.

  UPLOAD_START=8              uploads in flight to begin with
  UPLOAD_MOST=64              most uploads in flight
  UPLOAD_TRIES=8              attempts per request before giving up
  UPLOAD_PROCESS_TIMEOUT=360  seconds to wait for Roblox to process an object
"""
import json
import os
import random
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid

API = os.environ.get("ROBLOX_ASSETS_API", "https://apis.roblox.com/assets/v1")
START = int(os.environ.get("UPLOAD_START", "8"))
MOST = int(os.environ.get("UPLOAD_MOST", "64"))
TRIES = int(os.environ.get("UPLOAD_TRIES", "8"))
PROCESS_TIMEOUT = int(os.environ.get("UPLOAD_PROCESS_TIMEOUT", "360"))


def say(message):
	print(f"upload: {message}", file=sys.stderr, flush=True)


class Throttle:
	"""How many uploads may be in flight, found by trying: one more after each
	success, half as many after each refusal."""

	def __init__(self):
		self.limit, self.flying, self.held_until = float(START), 0, 0.0
		self.changed = threading.Condition()

	def enter(self):
		with self.changed:
			while self.flying >= int(self.limit):
				self.changed.wait()
			self.flying += 1

	def leave(self, succeeded):
		with self.changed:
			self.flying -= 1
			if succeeded:
				self.limit = min(MOST, self.limit + 1)
			self.changed.notify_all()

	def refused(self, wait):
		with self.changed:
			self.limit = max(1.0, self.limit / 2)
			self.held_until = max(self.held_until, time.time() + wait)
			say(f"turned away; now {int(self.limit)} at once, holding {wait:.0f}s")

	def hold(self):
		"""Waits out a refusal any request has met."""
		while True:
			wait = self.held_until - time.time()
			if wait <= 0:
				return
			time.sleep(wait)


def request(throttle, url, body=None, content_type=None):
	"""One Open Cloud request, returning its JSON. A refusal (429) is waited
	out and sent again; a transient failure (5xx, no connection) is tried
	again up to UPLOAD_TRIES times."""
	backoff, failures = 1.0, 0
	while True:
		throttle.hold()
		headers = {"x-api-key": os.environ["ROBLOX_API_KEY"]}
		if content_type:
			headers["Content-Type"] = content_type
		try:
			with urllib.request.urlopen(urllib.request.Request(url, data=body, headers=headers), timeout=120) as response:
				return json.load(response)
		except urllib.error.HTTPError as error:
			status, answer = error.code, error.read().decode(errors="replace")
			if status == 429:
				after = error.headers.get("Retry-After", "")
				throttle.refused(float(after) if after.isdigit() else backoff * (0.5 + random.random()))
				backoff = min(60.0, backoff * 2)
				continue
			if status < 500:
				raise RuntimeError(f"HTTP {status}: {answer}")
		except (urllib.error.URLError, TimeoutError):
			status = 0
		failures += 1
		if failures == TRIES:
			raise RuntimeError(f"gave up after {TRIES} tries (last HTTP {status})")
		time.sleep(backoff * (0.5 + random.random()))
		backoff = min(60.0, backoff * 2)


def upload(throttle, name, path, label):
	"""Uploads one file and returns its asset ID once Roblox has processed it,
	checking the operation at gaps that widen from 2 to 15 seconds."""
	boundary = uuid.uuid4().hex
	metadata = json.dumps({
		"assetType": "Model",
		"displayName": f"Scrap Heist {name} {label}"[:50],
		"description": "Scrap Heist map object",
		"creationContext": {"creator": {"userId": os.environ["ROBLOX_CREATOR_ID"]}},
	})
	body = b"".join([
		f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n{metadata}\r\n'.encode(),
		f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{os.path.basename(path)}"\r\nContent-Type: model/gltf-binary\r\n\r\n'.encode(),
		open(path, "rb").read(),
		f"\r\n--{boundary}--\r\n".encode(),
	])
	operation = request(throttle, f"{API}/assets", body, f"multipart/form-data; boundary={boundary}").get("path")
	if not operation:
		raise RuntimeError("rejected: no operation returned")
	gap, waited = 2.0, 0.0
	while waited < PROCESS_TIMEOUT:
		time.sleep(gap)
		waited += gap
		answer = request(throttle, f"{API}/{operation}")
		if answer.get("done"):
			asset = answer.get("response", {}).get("assetId")
			if not asset:
				raise RuntimeError(f"failed: {json.dumps(answer)}")
			return asset
		gap = min(15.0, gap * 1.5)
	raise RuntimeError(f"still processing after {waited:.0f}s: {operation}")


def ids_in(path):
	return {line.split("\t")[0] for line in open(path)} if os.path.isfile(path) else set()


def main():
	name, folder = sys.argv[1], sys.argv[2]
	root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
	ledger = ids_in(os.path.join(root, "art", "src", "layouts", f"{name}Uploads.tsv"))
	record_path = os.path.join(root, "art", "models", name, "uploaded.tsv")
	record = {}
	if os.path.isfile(record_path):
		for line in open(record_path):
			fields = line.split()
			if len(fields) == 3:
				record[fields[0]] = (fields[1], fields[2])

	# Each object once, from the lowest shard that handed it over.
	handed = {}
	for shard in sorted((entry for entry in os.listdir(folder) if entry.isdigit()), key=int):
		names = os.path.join(folder, shard, "names.tsv")
		for line in open(names) if os.path.isfile(names) else []:
			identity, label = line.rstrip("\n").split("\t")
			handed.setdefault(identity, (shard, label))
	wanted = [identity for identity in handed if identity not in ledger and identity not in record]
	megabytes = sum(os.path.getsize(os.path.join(folder, handed[i][0], f"{i}.glb")) for i in wanted) / 1e6
	say(f"{len(handed)} objects handed over, {len(wanted)} to upload ({megabytes:.0f} MB)")

	throttle, failures, writing = Throttle(), [], threading.Lock()
	started = time.time()

	def send(identity):
		shard, label = handed[identity]
		throttle.enter()
		succeeded = False
		try:
			asset = upload(throttle, name, os.path.join(folder, shard, f"{identity}.glb"), label)
			with writing:
				record[identity] = (asset, shard)
				with open(record_path, "a") as file:
					file.write(f"{identity}\t{asset}\t{shard}\n")
			succeeded = True
		except Exception as error:
			with writing:
				failures.append(identity)
			say(f"{label} ({identity}) {error}")
		finally:
			throttle.leave(succeeded)

	threads = [threading.Thread(target=send, args=(identity,)) for identity in wanted]
	for thread in threads:
		thread.start()
	for thread in threads:
		thread.join()

	with open(os.path.join(folder, "uploaded.tsv"), "w") as file:
		for identity in handed:
			if identity in record:
				file.write(f"{identity}\t{record[identity][0]}\t{record[identity][1]}\n")
	seconds = time.time() - started
	if failures:
		say(f"FAILED: {len(failures)} of {len(wanted)} uploads; run again to send just these")
		sys.exit(1)
	say(f"done: {len(wanted)} uploaded in {seconds:.0f}s, ending at {int(throttle.limit)} at once")


if __name__ == "__main__":
	main()
