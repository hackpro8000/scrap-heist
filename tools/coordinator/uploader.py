"""Uploads a layout's objects to Roblox as Models through Open Cloud, as many
at once as Roblox will take, from one place so one throttle sees every
answer.

Objects are added as they arrive (Uploader.add) and go up in bundles: the
objects that arrive within GATHER seconds of each other, up to BUNDLE_MOST
bytes (under Open Cloud's 20 MB limit), are joined into one file (bundle.py) and uploaded as one Model, which
holds each object as a child named by its id. Every object in a bundle gets
the bundle's asset id. The caller waits for the ones it cares about
(Uploader.wait). An object is
skipped when it already has an asset: its id is in the layout's ledger,
art/src/layouts/<Name>Uploads.tsv, or in this machine's record of what it
has uploaded, art/models/<Name>/uploaded.tsv, which outlives a failed run.

The throttle finds the width Roblox allows the way TCP finds a network's:
it starts fast, each success adding one more upload in flight (so the
width doubles every round), until Roblox first turns a request away (429).
Then the width halves and that half becomes the known limit; above it,
growth slows to about one more per round, and each refusal halves again.
Every request waits out Roblox's Retry-After, or else a pause that doubles
from 1 s to 60 s, with jitter. The width and the known limit are kept in
art/models/<Name>/upload-width.txt, so the next run starts near the best
width instead of finding it again.

With dry=True nothing is sent: each upload waits a moment and returns a
made-up asset id, and nothing is written to the record, for testing.

Needs ROBLOX_API_KEY (or the file ~/.config/scrap-heist/roblox-api-key)
and ROBLOX_CREATOR_ID unless dry.
"""
import json
import os
import random
import threading
import time
import urllib.error
import urllib.request
import uuid

import bundle

API = os.environ.get("ROBLOX_ASSETS_API", "https://apis.roblox.com/assets/v1")
START = float(os.environ.get("UPLOAD_START", "4"))
MOST = int(os.environ.get("UPLOAD_MOST", "128"))
TRIES = int(os.environ.get("UPLOAD_TRIES", "8"))
PROCESS_TIMEOUT = int(os.environ.get("UPLOAD_PROCESS_TIMEOUT", "360"))
FIRST_PAUSE, MOST_PAUSE = 1.0, 60.0
KEY_FILE = os.path.expanduser("~/.config/scrap-heist/roblox-api-key")
CREATOR_ID = os.environ.get("ROBLOX_CREATOR_ID", "670715109")
GATHER = float(os.environ.get("UPLOAD_GATHER", "1.0"))
BUNDLE_MOST = int(os.environ.get("UPLOAD_BUNDLE_MOST", str(18 * 2**20)))


def api_key():
	key = os.environ.get("ROBLOX_API_KEY", "").strip()
	if not key and os.path.isfile(KEY_FILE):
		key = open(KEY_FILE).read().strip()
	return key


class Throttle:
	def __init__(self, width_path, say):
		self.width_path, self.say = width_path, say
		self.limit, self.known = START, float(MOST)
		if os.path.isfile(width_path):
			try:
				fields = open(width_path).read().split()
				self.limit = min(MOST, max(1.0, float(fields[0])))
				if len(fields) > 1:
					self.known = min(MOST, max(1.0, float(fields[1])))
			except (ValueError, IndexError):
				pass
		self.flying, self.held_until, self.pause = 0, 0.0, FIRST_PAUSE
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
				# Fast below the known limit, careful above it.
				step = 1.0 if self.limit < self.known else 1.0 / self.limit
				self.limit = min(MOST, self.limit + step)
				self.pause = FIRST_PAUSE
			self.changed.notify_all()

	def refused(self, retry_after):
		with self.changed:
			self.known = max(1.0, self.limit / 2)
			self.limit = self.known
			wait = retry_after if retry_after is not None else self.pause * (1 + random.random() * 0.5)
			if retry_after is None:
				self.pause = min(MOST_PAUSE, self.pause * 2)
			self.held_until = max(self.held_until, time.time() + wait)
			self.say(f"turned away; now {int(self.limit)} at once, holding {wait:.0f}s")

	def hold(self):
		while True:
			wait = self.held_until - time.time()
			if wait <= 0:
				return
			time.sleep(wait)

	def remember(self):
		with open(self.width_path, "w") as file:
			file.write(f"{self.limit:.2f} {self.known:.2f}\n")


def ids_in(path):
	return {line.split("\t")[0] for line in open(path)} if os.path.isfile(path) else set()


class Uploader:
	def __init__(self, root, name, say=print, dry=False, on_done=None):
		self.name, self.say, self.dry = name, say, dry
		# Called as on_done(id, asset or None, error or None) after each upload.
		self.on_done = on_done
		models = os.path.join(root, "art", "models", name)
		os.makedirs(models, exist_ok=True)
		self.ledger_path = os.path.join(root, "art", "src", "layouts", f"{name}Uploads.tsv")
		self.record_path = os.path.join(models, "uploaded.tsv")
		self.throttle = Throttle(os.path.join(models, "upload-width.txt"), say)
		self.lock = threading.Lock()
		self.done = threading.Condition(self.lock)
		# id -> (asset, shard) for everything with an asset this machine knows of.
		self.record = {}
		if os.path.isfile(self.record_path) and not dry:
			for line in open(self.record_path):
				fields = line.split()
				if len(fields) == 3:
					self.record[fields[0]] = (fields[1], fields[2])
		self.pending = set()
		# Objects waiting to be bundled: (identity, path, label, shard).
		self.queue = []
		self.queued = threading.Condition(self.lock)
		threading.Thread(target=self._bundle_up, daemon=True).start()
		self.failed = {}
		self.sent = 0
		# Seconds an upload usually takes until Roblox has the asset ready.
		self.typical_processing = 3.0
		if not dry and not api_key():
			raise RuntimeError(f"no Roblox API key: set ROBLOX_API_KEY or put it in {KEY_FILE}")

	def known(self, identity):
		return identity in self.record or identity in ids_in(self.ledger_path)

	def add(self, identity, path, label, shard):
		"""Queues one object unless it has an asset or is already on its way."""
		with self.lock:
			if identity in self.pending or identity in self.record:
				return False
			if identity in ids_in(self.ledger_path):
				return False
			self.pending.add(identity)
			self.failed.pop(identity, None)
			self.queue.append((identity, path, label, shard))
			self.queued.notify_all()
		return True

	def wait(self, identities, timeout=None):
		"""Waits until none of `identities` is still uploading."""
		deadline = None if timeout is None else time.time() + timeout
		with self.done:
			while self.pending & set(identities):
				left = None if deadline is None else deadline - time.time()
				if left is not None and left <= 0:
					return False
				self.done.wait(left)
		return True

	def asset_of(self, identity):
		return self.record.get(identity, (None, None))[0]

	def finish(self):
		# A dry run's width says nothing about Roblox's limit.
		if not self.dry:
			self.throttle.remember()

	def _bundle_up(self):
		"""Takes what has gathered in the queue, one bundle at a time."""
		while True:
			with self.queued:
				while not self.queue:
					self.queued.wait()
			# Give the objects arriving with this one a moment to join it.
			time.sleep(GATHER)
			# Everything gathered goes at once, cut into bundles of up to
			# BUNDLE_MOST bytes that upload side by side.
			with self.lock:
				gathered, self.queue = self.queue, []
			bundles, size = [[]], 0
			for entry in gathered:
				# A missing file fails in _send, with the rest of its bundle.
				grows = os.path.getsize(entry[1]) if os.path.isfile(entry[1]) else 0
				if bundles[-1] and size + grows > BUNDLE_MOST:
					bundles.append([])
					size = 0
				bundles[-1].append(entry)
				size += grows
			for objects in bundles:
				threading.Thread(target=self._send, args=(objects,), daemon=True).start()

	def _send(self, objects):
		self.throttle.enter()
		succeeded = False
		label = objects[0][2] if len(objects) == 1 else f"{len(objects)} objects"
		try:
			if self.dry:
				asset = self._pretend()
			else:
				data = bundle.join([(identity, open(path, "rb").read()) for identity, path, _, _ in objects])
				asset = self._upload(data, label)
			with self.lock:
				for identity, _, _, shard in objects:
					self.record[identity] = (str(asset), str(shard))
				self.sent += len(objects)
				if not self.dry:
					with open(self.record_path, "a") as file:
						for identity, _, _, shard in objects:
							file.write(f"{identity}\t{asset}\t{shard}\n")
			succeeded = True
			self.say(f"bundle of {len(objects)} is asset {asset}")
		except Exception as error:
			with self.lock:
				for identity, *_ in objects:
					self.failed[identity] = str(error)
			self.say(f"bundle of {label} ({' '.join(o[0] for o in objects[:4])}) {error}")
		finally:
			self.throttle.leave(succeeded)
			with self.done:
				for identity, *_ in objects:
					self.pending.discard(identity)
				self.done.notify_all()
			if self.on_done:
				for identity, *_ in objects:
					asset = self.record.get(identity, (None, None))[0] if succeeded else None
					self.on_done(identity, asset, None if succeeded else self.failed.get(identity))

	def _pretend(self):
		self.throttle.hold()
		time.sleep(0.2 + random.random() * 0.3)
		return random.randrange(10**13, 10**14)

	def _request(self, url, body=None, content_type=None):
		backoff, failures = 1.0, 0
		while True:
			self.throttle.hold()
			headers = {"x-api-key": api_key()}
			if content_type:
				headers["Content-Type"] = content_type
			try:
				with urllib.request.urlopen(urllib.request.Request(url, data=body, headers=headers), timeout=120) as response:
					return json.load(response)
			except urllib.error.HTTPError as error:
				status, answer = error.code, error.read().decode(errors="replace")
				if status == 429:
					after = error.headers.get("Retry-After", "")
					self.throttle.refused(float(after) if after.replace(".", "", 1).isdigit() else None)
					continue
				if status < 500:
					raise RuntimeError(f"HTTP {status}: {answer[:300]}")
			except (urllib.error.URLError, TimeoutError):
				status = 0
			failures += 1
			if failures >= TRIES:
				raise RuntimeError(f"gave up after {TRIES} tries (last HTTP {status})")
			time.sleep(backoff * (0.5 + random.random()))
			backoff = min(MOST_PAUSE, backoff * 2)

	def _upload(self, data, label):
		boundary = uuid.uuid4().hex
		metadata = json.dumps({
			"assetType": "Model",
			"displayName": f"Scrap Heist {self.name} {label}"[:50],
			"description": "Scrap Heist map objects, one child per object",
			"creationContext": {"creator": {"userId": CREATOR_ID}},
		})
		body = b"".join([
			f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n{metadata}\r\n'.encode(),
			f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="bundle.glb"\r\nContent-Type: model/gltf-binary\r\n\r\n'.encode(),
			data,
			f"\r\n--{boundary}--\r\n".encode(),
		])
		started = time.time()
		created = self._request(f"{API}/assets", body, f"multipart/form-data; boundary={boundary}")
		operation = created.get("path")
		if not operation:
			raise RuntimeError("rejected: no operation returned")
		# Roblox doesn't push a finished upload, so it has to be asked; but a
		# finished answer is taken at once, and the first question waits about
		# as long as Roblox has lately taken, not a fixed time.
		answer = created
		gap = max(0.5, self.typical_processing * 0.8)
		checks = 0
		while not answer.get("done"):
			if time.time() - started > PROCESS_TIMEOUT:
				raise RuntimeError(f"still processing after {PROCESS_TIMEOUT}s: {operation}")
			time.sleep(gap)
			answer = self._request(f"{API}/{operation}")
			# After the first, informed wait: soon again, then less often.
			gap = 1.0 if checks == 0 else min(5.0, gap * 1.5)
			checks += 1
		asset = answer.get("response", {}).get("assetId")
		if not asset:
			raise RuntimeError(f"failed: {json.dumps(answer)[:300]}")
		self._learn(time.time() - started)
		return asset

	def _learn(self, seconds):
		"""Keeps a running estimate of how long an upload takes, end to end."""
		with self.lock:
			self.typical_processing = 0.7 * self.typical_processing + 0.3 * seconds
