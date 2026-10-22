import math
import random

import bpy
import scrapkit

# Storage crate: the yard's open-top bin that machines fill with parts and
# raiders grab bundles from. Sits on the ground with its base at the origin.
WIDTH = 5.0
DEPTH = 3.5
HEIGHT = 2.6
WALL = 0.2

# Hand-painted flat tones, like the bat: lighter on edges that stick out,
# darker in recesses, so it reads the same under any light.
PANEL = (0.36, 0.42, 0.33)
PANEL_DARK = (0.2, 0.24, 0.19)
FRAME = (0.62, 0.52, 0.38)
RUST = (0.55, 0.28, 0.12)
SCRAP_COLORS = [(0.7, 0.7, 0.68), (0.5, 0.52, 0.55), (0.75, 0.55, 0.2), (0.6, 0.3, 0.15)]


def box(name: str, size, location, rotation=(0.0, 0.0, 0.0)) -> bpy.types.Object:
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
	obj = bpy.context.object
	obj.name = name
	obj.scale = size
	bpy.ops.object.transform_apply(scale=True)
	return obj


collection = scrapkit.new_scene()
panel = scrapkit.material("Panel", PANEL, metallic=0.3)
panel_dark = scrapkit.material("PanelDark", PANEL_DARK)
frame = scrapkit.material("Frame", FRAME, metallic=0.5, roughness=0.5)
rust = scrapkit.material("Rust", RUST, roughness=0.9)

# Walls and floor, with the dark inside face so the bin reads as hollow.
scrapkit.link(box("Floor", (WIDTH, DEPTH, WALL), (0, 0, WALL / 2)), collection, panel_dark)
for sign in (-1, 1):
	scrapkit.link(box("WallLong", (WIDTH, WALL, HEIGHT), (0, sign * (DEPTH - WALL) / 2, HEIGHT / 2)), collection, panel)
	scrapkit.link(box("WallShort", (WALL, DEPTH - 2 * WALL, HEIGHT), (sign * (WIDTH - WALL) / 2, 0, HEIGHT / 2)), collection, panel)

# Corner posts and a rim around the top, slightly proud of the walls.
post = 0.32
for x in (-1, 1):
	for y in (-1, 1):
		scrapkit.link(box("Post", (post, post, HEIGHT + 0.1), (x * WIDTH / 2, y * DEPTH / 2, (HEIGHT + 0.1) / 2)), collection, frame)
for sign in (-1, 1):
	scrapkit.link(box("RimLong", (WIDTH, 0.3, 0.16), (0, sign * DEPTH / 2, HEIGHT)), collection, frame)
	scrapkit.link(box("RimShort", (0.3, DEPTH, 0.16), (sign * WIDTH / 2, 0, HEIGHT)), collection, frame)

# Vertical ribs on the long walls and a rust streak under each.
for sign in (-1, 1):
	for x in (-WIDTH / 4, 0, WIDTH / 4):
		scrapkit.link(box("Rib", (0.14, 0.08, HEIGHT - 0.3), (x, sign * (DEPTH / 2 + 0.04), HEIGHT / 2)), collection, frame)
		scrapkit.link(box("RustStreak", (0.3, 0.02, 0.7), (x + 0.3, sign * (DEPTH / 2 + 0.01), 0.8)), collection, rust)

# Parts heaped above the rim so a raider can see what's worth taking.
rng = random.Random(7)
for index in range(14):
	size = (rng.uniform(0.4, 1.0), rng.uniform(0.3, 0.8), rng.uniform(0.2, 0.5))
	location = (rng.uniform(-1.6, 1.6), rng.uniform(-0.9, 0.9), HEIGHT - 0.3 + rng.uniform(0, 0.5))
	rotation = tuple(rng.uniform(-0.6, 0.6) for _ in range(2)) + (rng.uniform(0, math.pi),)
	color = SCRAP_COLORS[index % len(SCRAP_COLORS)]
	scrapkit.link(box("Scrap", size, location, rotation), collection, scrapkit.material(f"Scrap{index % len(SCRAP_COLORS)}", color, metallic=0.6, roughness=0.5))

scrapkit.finish(collection)
