"""Agent mixin: machine 1 as the uploader: objects arrive over the
connection or from a builder's commit and go to tools/coordinator/uploader.py."""
import asyncio
import json
import os
import time

from standby_agent.common import ROOT, say
import uploader as uploading  # noqa: E402


class Uploads:
	def answer(self, identity, asset, error):
		"""From the uploader's threads: send the result on the live socket."""
		say(f"upload {identity}: " + (f"asset {asset}" if asset else f"FAILED {error}"))
		message = json.dumps({"type": "uploaded", "id": identity, "asset": asset, "error": error,
			"width": round(self.uploader.throttle.limit, 1), "known": round(self.uploader.throttle.known, 1)})
		socket, loop = self.socket, self.loop
		if socket and loop:
			loop.call_soon_threadsafe(lambda: asyncio.ensure_future(socket.send(message)))

	async def receive_fetch(self, socket, event):
		"""Machine 1: a builder pushed objects; fetch them and upload the ones asked for."""
		if self.uploader is None:
			self.uploader = uploading.Uploader(ROOT, self.layout, say,
				dry=os.environ.get("AGENT_DRY_UPLOAD") == "1", on_done=self.answer)
			if getattr(self, "start_width", None):
				# A run starts at least START wide, its known limit forgotten:
				# what turned uploads away last time may not hold now.
				self.uploader.throttle.limit = max(uploading.START, min(uploading.MOST, float(self.start_width)))
		into = os.path.join(self.inbox, f"{event['task']}-S{event['shard']}")
		started = time.monotonic()
		try:
			await asyncio.to_thread(self.fetch_objects, event["commit"], into)
		except Exception as error:
			say(f"S{event['shard']}'s objects: {error}")
			for identity in event["ids"]:
				await socket.send(json.dumps({"type": "uploaded", "id": identity, "error": str(error)}))
			return
		say(f"fetched S{event['shard']}'s {len(event['ids'])} objects in {time.monotonic() - started:.1f}s")
		for identity, label in event["ids"].items():
			path = os.path.join(into, f"{identity}.glb")
			if not self.uploader.add(identity, path, label, event["shard"]):
				asset = self.uploader.asset_of(identity)
				if asset:
					await socket.send(json.dumps({"type": "uploaded", "id": identity, "asset": asset}))

	async def receive_upload(self, socket, header, data):
		say(f"upload {header['label']} ({header['id']}, {len(data) // 1000} KB) received")
		if self.uploader is None:
			# AGENT_DRY_UPLOAD fakes uploads, for local tests only.
			self.uploader = uploading.Uploader(ROOT, header.get("layout", self.layout), say,
				dry=os.environ.get("AGENT_DRY_UPLOAD") == "1", on_done=self.answer)
			if getattr(self, "start_width", None):
				# A run starts at least START wide, its known limit forgotten:
				# what turned uploads away last time may not hold now.
				self.uploader.throttle.limit = max(uploading.START, min(uploading.MOST, float(self.start_width)))
		os.makedirs(self.inbox, exist_ok=True)
		path = os.path.join(self.inbox, f"{header['id']}.glb")
		with open(path, "wb") as file:
			file.write(data)
		if not self.uploader.add(header["id"], path, header["label"], header.get("shard", 1)):
			# Already uploaded by this machine (or still going: its answer follows).
			asset = self.uploader.asset_of(header["id"])
			if asset:
				await socket.send(json.dumps({"type": "uploaded", "id": header["id"], "asset": asset}))
