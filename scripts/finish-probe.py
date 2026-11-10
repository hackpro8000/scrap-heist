#!/usr/bin/env python3
"""Measures the paint finish on a round's review renders, so a change meant for
one model shows up as a number when it moves another.

    scripts/finish-probe.py <round dir> [<previous round dir>]

Each probe is a column of boxes down one surface of one render; the script
prints the median brightness of each box (0-255), so stepped bands read as
plateaus and a smooth fade as a steady slope. With a previous round it prints
the change per box and flags any over FLAG. Renders are 1024 px square; the
boxes are given in that frame.
"""
import json
import statistics
import sys
from pathlib import Path

from PIL import Image

FLAG = 8

# name: (file, x0, x1, y_first, y_step, count, box_height)
PROBES = {
	"fence panel column": ("f.png", 735, 775, 150, 36, 15, 36),
	"gate left post": ("g.png", 212, 236, 200, 90, 7, 40),
	"shed left wall": ("h.png", 275, 350, 370, 40, 7, 25),
	"press frame": ("i.png", 330, 690, 340, 60, 6, 30),
	"tree trunk": ("j.png", 380, 402, 60, 60, 7, 30),
	"footing side": ("j.png", 430, 470, 590, 8, 6, 6),
	"junk mound body": ("k.png", 420, 640, 560, 30, 6, 20),
	"drum pile body": ("l.png", 380, 700, 420, 45, 7, 25),
	"big boulder": ("a.png", 488, 538, 341, 21, 11, 16),
	"sand by boulder": ("a.png", 100, 180, 600, 40, 4, 30),
}


def luminance(pixel):
	r, g, b = pixel[:3]
	return 0.2126 * r + 0.7152 * g + 0.0722 * b


def measure(folder):
	out = {}
	for name, (file, x0, x1, y0, step, count, height) in PROBES.items():
		path = Path(folder) / file
		if not path.exists():
			continue
		image = Image.open(path).convert("RGB")
		if image.size[0] != 1024:
			scale = image.size[0] / 1024
		else:
			scale = 1
		values = []
		for k in range(count):
			y = y0 + k * step
			box = [
				luminance(image.getpixel((int(x * scale), int(yy * scale))))
				for x in range(x0, x1, 2)
				for yy in range(y, y + height, 2)
			]
			values.append(round(statistics.median(box), 1))
		out[name] = values
	return out


def main():
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	now = measure(sys.argv[1])
	before = measure(sys.argv[2]) if len(sys.argv) > 2 else {}
	flagged = []
	for name, values in now.items():
		print(f"{name:20} " + " ".join(f"{v:5.0f}" for v in values))
		if name in before:
			diffs = [a - b for a, b in zip(values, before[name])]
			marks = " ".join(f"{d:+5.0f}" for d in diffs)
			print(f"{'  change':20} {marks}")
			if any(abs(d) > FLAG for d in diffs):
				flagged.append(name)
	if before:
		print("moved more than", FLAG, ":", ", ".join(flagged) if flagged else "nothing")
	Path(sys.argv[1], "probes.json").write_text(json.dumps(now, indent=1))


if __name__ == "__main__":
	main()
