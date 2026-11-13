"""client.py's preview shares: each model's measured machine-seconds, kept
on this computer and turned into the weights a build posts."""
import json
import os

from client_connection import ROOT

# Measured machine-seconds per model's previews, for cost-sized shares.
PREVIEW_SECONDS = os.path.expanduser("~/.cache/scrap-heist/preview-seconds.json")


def model_bytes(name):
	path = os.path.join(ROOT, "art", "models", name, "model.luau")
	return os.path.getsize(path) if os.path.isfile(path) else 0


def load_preview_seconds():
	try:
		known = json.load(open(PREVIEW_SECONDS))
	except (OSError, ValueError):
		return {}
	if not isinstance(known, dict):
		return {}
	return {name: float(seconds) for name, seconds in known.items()
		if isinstance(seconds, (int, float)) and not isinstance(seconds, bool) and seconds > 0}


def preview_weights(previews, known=None):
	"""Each model's expected machine-seconds: measured if known; else its
	model.luau's bytes at the median seconds-per-byte of the known models
	(or the median seconds when it has no file). Empty when nothing is known:
	the hub then shares equally."""
	known = load_preview_seconds() if known is None else known
	if not known:
		return {}
	middle = lambda values: sorted(values)[len(values) // 2] if values else None
	rate = middle([seconds / model_bytes(name) for name, seconds in known.items() if model_bytes(name)])
	typical = middle(list(known.values()))
	weights = {}
	for name in (name.rstrip("!") for name in previews):
		if name in known:
			weights[name] = known[name]
		elif rate and model_bytes(name):
			weights[name] = model_bytes(name) * rate
		else:
			weights[name] = typical
	return {name: round(weight, 3) for name, weight in weights.items()}


def save_preview_seconds(shares):
	"""shares: (model, unit name) -> machine-seconds one unit spent on it.
	Each model's total replaces what was known."""
	totals = {}
	for (name, _unit), seconds in shares.items():
		totals[name] = totals.get(name, 0.0) + seconds
	totals = {name: round(seconds, 1) for name, seconds in totals.items() if seconds > 0}
	if not totals:
		return
	known = load_preview_seconds()
	known.update(totals)
	os.makedirs(os.path.dirname(PREVIEW_SECONDS), exist_ok=True)
	with open(PREVIEW_SECONDS + ".new", "w") as file:
		json.dump(known, file, indent=1, sort_keys=True)
	os.replace(PREVIEW_SECONDS + ".new", PREVIEW_SECONDS)
	print(f"preview machine-seconds kept: {' '.join(f'{name}={seconds}' for name, seconds in sorted(totals.items()))}", flush=True)
