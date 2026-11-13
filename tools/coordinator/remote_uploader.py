"""Uploads done by build machine 1 over its live connection
(--uploads-on-machine), behind the uploader's interface."""
import asyncio
import json
import os

import uploader as uploading
import wire
from hub_config import ROOT


class RemoteUploader:
	"""The uploader's interface, with the uploading done by build machine 1:
	objects are sent to it as they land and asset ids come back. Objects
	wait here until machine 1 is connected."""

	def __init__(self, layout):
		self.ledger_path = os.path.join(ROOT, "art", "src", "layouts", f"{layout}Uploads.tsv")
		# Machines come and go; the width machine 1 learns is kept here and
		# handed to each new machine 1 (uploader.py keeps it the same way).
		self.width_path = os.path.join(ROOT, "art", "models", layout, "upload-width.txt")
		self.record, self.failed, self.pending = {}, {}, set()
		self.waiting = []  # (identity, path, label, shard) not yet sent
		self.fetches = []  # fetch-objects messages not yet sent
		self.sent_fetches = []  # sent, in case machine 1 drops before answering
		self.agent = None
		self.loop = None
		self.changed = asyncio.Event()
		self.throttle = type("Width", (), {"limit": 0})()

	def add(self, identity, path, label, shard):
		if identity in self.pending or identity in self.record or identity in uploading.ids_in(self.ledger_path):
			return False
		self.pending.add(identity)
		self.waiting.append((identity, path, label, shard))
		asyncio.get_event_loop().create_task(self.flush())
		return True

	async def flush(self):
		while self.agent and self.waiting:
			identity, path, label, shard = self.waiting.pop(0)
			with open(path, "rb") as file:
				data = file.read()
			try:
				await self.agent.send(wire.pack({"type": "upload", "id": identity, "label": label, "shard": shard}, data))
			except Exception:
				self.waiting.insert(0, (identity, path, label, shard))
				return

	def track(self, identity):
		"""Counts an object as on its way, without sending it from here."""
		if identity in self.pending or identity in self.record or identity in uploading.ids_in(self.ledger_path):
			return False
		self.pending.add(identity)
		return True

	async def request_fetch(self, message):
		self.fetches.append(message)
		await self.send_fetches()

	async def send_fetches(self):
		while self.agent and self.fetches:
			message = self.fetches[0]
			try:
				await self.agent.send(json.dumps(message))
			except Exception:
				return
			self.sent_fetches.append(self.fetches.pop(0))

	async def connected(self, agent):
		self.agent = agent
		# Anything sent to a machine 1 that dropped goes again.
		for identity in list(self.pending):
			if not any(entry[0] == identity for entry in self.waiting) and identity in self.sent_paths:
				self.waiting.append(self.sent_paths[identity])
		await self.flush()
		# Fetches a dropped machine 1 never answered go again.
		for message in self.sent_fetches:
			if any(identity in self.pending for identity in message["ids"]):
				self.fetches.append(message)
		self.sent_fetches = []
		await self.send_fetches()

	def answered(self, event):
		identity = event["id"]
		if event.get("asset"):
			self.record[identity] = (str(event["asset"]), str(event.get("shard", 1)))
			# A retry that worked clears an earlier failure.
			self.failed.pop(identity, None)
		else:
			self.failed[identity] = event.get("error", "failed")
		self.pending.discard(identity)
		if event.get("width"):
			self.throttle.limit = event["width"]
			os.makedirs(os.path.dirname(self.width_path), exist_ok=True)
			with open(self.width_path, "w") as file:
				file.write(f"{event['width']:.2f} {event.get('known', event['width']):.2f}\n")
		self.changed.set()

	def wait(self, identities, timeout=None):
		raise RuntimeError("use wait_async")

	async def wait_async(self, identities):
		while self.pending & set(identities):
			self.changed.clear()
			await self.changed.wait()

	def asset_of(self, identity):
		return self.record.get(identity, (None, None))[0]

	def finish(self):
		pass
