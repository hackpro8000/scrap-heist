"""What the hub tracks: a task cut into units (Task, share_out), a unit
leased to a machine (Lease), and a roster entry (Machine)."""
import os
import time

from hub_config import RESULTS


def share_out(asked, count, weights=None):
	"""The preview units of a task of `count` units: one name per unit when
	there are fewer models than units, each model given shares named
	<Name>@<i>@<n> in proportion to its weight (its measured machine-seconds,
	client.py preview_weights), at least one each, summing to count. A name
	ending in "!" is one machine's job whole, for timing a model on its own;
	the "!" is dropped. With as many models as units or more, the names as
	they are, each unit taking every count-th."""
	names = [name.rstrip("!") for name in asked]
	if not names or len(names) >= count:
		return names
	whole = {name[:-1] for name in asked if name.endswith("!")}
	split = [name for name in names if name not in whole]
	if not split:
		return names
	budget = count - (len(names) - len(split))
	weights = weights if isinstance(weights, dict) else {}
	weight = {}
	for name in split:
		given = weights.get(name)
		weight[name] = float(given) if isinstance(given, (int, float)) and not isinstance(given, bool) and given > 0 else 1.0
	total = sum(weight[name] for name in split)
	ideal = {name: budget * weight[name] / total for name in split}
	shares = {name: max(1, int(ideal[name])) for name in split}
	while sum(shares[name] for name in split) > budget:
		name = max((name for name in split if shares[name] > 1), key=lambda name: shares[name] - ideal[name])
		shares[name] -= 1
	while sum(shares[name] for name in split) < budget:
		name = max(split, key=lambda name: ideal[name] - shares[name])
		shares[name] += 1
	units = []
	for name in names:
		count_of = 1 if name in whole else shares[name]
		units += [name] if count_of == 1 else [f"{name}@{i}@{count_of}" for i in range(1, count_of + 1)]
	return units


class Lease:
	"""One unit held by one machine, from its deal until it is over or comes back."""

	def __init__(self, number, machine):
		self.number, self.machine = number, machine
		self.dealt = self.moved = time.time()
		# Jobs it claimed: [(model, kind), job, settled]. Unsettled ones go
		# back to the task when the lease does, so the replacement isn't starved.
		self.claims = []


class Machine:
	"""One roster entry: a connection that may drop and come back under the same name."""

	def __init__(self, name, kind):
		self.name, self.kind = name, kind  # kind: github, numbered or worker
		self.socket = None
		self.run = None
		self.closed_at = None
		self.heard = time.time()
		self.lease = None  # (task id, shard) it holds
		self.cancelling = {}  # (task id, shard) told to stop -> when last told, until it answers idle (or times out)
		self.progress = None  # its latest heartbeat, with the time it came
		self.dropped = set()  # (task id, shard) whose late messages were dropped, logged once

	def state(self, now):
		if self.socket is None:
			return {"name": self.name, "state": "gone", "gone_for": round(now - (self.closed_at or now)),
				"task": self.lease[0] if self.lease else None, "shard": self.lease[1] if self.lease else None}
		if self.lease:
			return {"name": self.name, "state": "unit", "task": self.lease[0], "shard": self.lease[1],
				"heard": round(now - self.heard)}
		return {"name": self.name, "state": "stopping" if self.cancelling else "idle"}


class Task:
	def __init__(self, identity, ref, upload, count, previews=(), build=True, weights=None, results=RESULTS):
		self.id, self.ref, self.upload, self.count = identity, ref, upload, count
		# Without a build the units only render the previews.
		self.build = build
		# Models whose previews the units render, shared out between them by
		# cost (share_out), and the units whose previews haven't all come yet;
		# shares_in counts the shares of each model that have come back.
		self.asked = list(previews)  # as posted, for the tasks file
		self.weights = dict(weights) if isinstance(weights, dict) else {}
		self.previews = [name.rstrip("!") for name in previews]
		self.units = share_out(self.asked, count, self.weights)
		self.shares_in = {}
		self.queues = {}  # (model, bake or render) -> the next job to hand out
		self.returned = {}  # (model, kind) -> jobs a returned lease claimed and never finished
		self.job_answers = {}  # (lease number, claim number) -> job, so a repeated claim gets the same one
		self.bakes = {}  # model -> share number -> commit of that machine's baked textures
		self.previews_waiting = set(range(1, count + 1)) if self.previews else set()
		self.queue = list(range(1, count + 1))  # units not leased, front first
		self.leases = {}  # shard -> its Lease
		self.moved_from = {}  # shard -> (machine, reason, its Lease) of a returned lease, until it is dealt again
		# Reloaded after a hub restart: not dealt before this time, so machines
		# still on its units reconnect and get them back first (load_tasks).
		self.held_until = 0
		self.started = time.time()
		self.done = {}  # shard -> summary text
		self.handed = {}  # object id -> (shard, label)
		self.labels = {}  # (shard, object id) -> label, from names.tsv
		self.sent = set()  # objects this task uploaded (the rest had assets)
		self.by_branch = False
		# Objects whose upload has been answered, each counted once however
		# often it is handed over (a re-dealt unit hands over the same ones).
		self.answered = set()
		self.received = {}  # shard -> [files, bytes] it sent, against MAX_SHARD_*
		self.watchers = set()  # control sockets of the session that posted it, for relayed files
		self.out = os.path.join(results, identity)
		os.makedirs(self.out, exist_ok=True)

	def text(self, shard=None):
		# When machine 1 uploads, objects go to it through GitHub, not this link.
		hand_over = "branch" if self.by_branch else "coordinator"
		# A unit re-dealt after its build came in only renders.
		build = self.build and shard not in self.done
		return (f"ref={self.ref}\nhand-over={hand_over}\n" + ("" if self.upload else "upload=no\n")
			+ ("" if build else "build=no\n")
			+ (f"preview={','.join(self.units)}\n" if self.units else ""))

	def unit_over(self, shard):
		return shard in self.done and shard not in self.previews_waiting
