#!/usr/bin/env python3
"""Paints the sky's flat sprites, one PNG with alpha each, into art/ui/Sky:
the sky's gradient, the galaxy wisp and a twinkle. Baked once and uploaded
(scripts/upload-ui.sh Sky ...); AtmosphereController shows them far out in
the sky. The clouds come from scripts/paint-clouds.py, and the solid bodies
(planet, moons, cog, islands, windmills) are models in art/src/items/Sky*.

    scripts/paint-sky.py [--sheet out.png]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "art/ui/Sky"


# Helpers -----------------------------------------------------------------

def grid(w, h):
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    return xs, ys


def noise(w, h, scale, seed, octaves=4):
    """Fractal value noise in 0..1, features about `scale` pixels across."""
    rng = np.random.default_rng(seed)
    total = np.zeros((h, w))
    weight = 0.0
    amp = 1.0
    for octave in range(octaves):
        cell = max(scale / (2 ** octave), 2)
        gw, gh = int(w / cell) + 2, int(h / cell) + 2
        small = Image.fromarray((rng.random((gh, gw)) * 255).astype(np.uint8))
        big = small.resize((int(gw * cell), int(gh * cell)), Image.BICUBIC)
        total += np.asarray(big, float)[:h, :w] / 255 * amp
        weight += amp
        amp *= 0.5
    return total / weight


def ramp(t, stops):
    """Colours along t in 0..1 through evenly spaced stops."""
    stops = np.array(stops, float)
    t = np.clip(t, 0, 1) * (len(stops) - 1)
    i = np.clip(t.astype(int), 0, len(stops) - 2)
    f = (t - i)[..., None]
    return stops[i] * (1 - f) + stops[i + 1] * f


def mix(a, b, f):
    f = np.asarray(f, float)
    if f.ndim == 2:
        f = f[..., None]
    return a * (1 - f) + b * f


def save(name, rgb, alpha, sheet):
    alpha = np.asarray(Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)))
    image = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    image.putalpha(Image.fromarray(alpha))
    image.save(OUT / f"{name}.png")
    sheet.append((name, image))



def sparkle_stars(w, h, points, rng, size):
    """Four-point twinkles at the given points."""
    xs, ys = grid(w, h)
    alpha = np.zeros((h, w))
    for x, y in points:
        s = size * rng.uniform(0.5, 1.2)
        dx, dy = np.abs(xs - x), np.abs(ys - y)
        star = np.clip(1 - (dx * dy) / (s * 0.6) - (dx + dy) / (s * 4), 0, 1)
        glow = np.exp(-((dx ** 2 + dy ** 2) / (s * 0.5) ** 2))
        alpha = np.maximum(alpha, np.maximum(star, glow * 0.8))
    return alpha


# Galaxy --------------------------------------------------------------------

def paint_galaxy(sheet):
    w, h = 1024, 512
    xs, ys = grid(w, h)
    dx, dy = (xs - 512) / 520, (ys - 256) / 250
    r = np.sqrt(dx * dx + dy * dy) + 1e-6
    a = np.arctan2(dy, dx)
    arms = np.cos(2 * (a - np.log(r) * 3.2)) * 0.5 + 0.5
    wisps = noise(w, h, 40, 41)
    density = np.clip(arms ** 2 * np.exp(-r * 2.0) * 2.6 + np.exp(-r * r * 40) * 1.2, 0, 1)
    density *= 0.6 + 0.6 * wisps
    color = ramp(np.clip(r * 1.6, 0, 1), [(255, 250, 235), (226, 210, 255), (160, 190, 255), (120, 170, 255)])
    rng = np.random.default_rng(42)
    pts = [(512 + rng.normal(0, 230), 256 + rng.normal(0, 110)) for _ in range(70)]
    stars = sparkle_stars(w, h, pts, rng, 3)
    alpha = np.clip(density * 0.85 + stars * 0.9, 0, 1)
    # Fade out before the canvas edge, so no rectangle shows in the sky.
    alpha *= np.clip(np.minimum(xs, w - 1 - xs) / 110, 0, 1) * np.clip(np.minimum(ys, h - 1 - ys) / 80, 0, 1)
    color = mix(color, np.array([255, 255, 255.0]), stars)
    save("Galaxy", color, alpha, sheet)


# Twinkle ---------------------------------------------------------------------

def paint_twinkle(sheet):
    """A four-point glint, for the sparkles along the planet's ring."""
    w = h = 128
    rng = np.random.default_rng(5)
    alpha = sparkle_stars(w, h, [(64, 64)], rng, 26)
    save("Twinkle", np.full((h, w, 3), [255, 252, 235.0]), alpha, sheet)


# Sky gradient --------------------------------------------------------------

def paint_sky(sheet):
    w = h = 512
    _, ys = grid(w, h)
    t = ys / (h - 1)
    side = ramp(t ** 1.6, [(28, 104, 228), (64, 146, 246), (150, 204, 252)])
    save("SkySide", side, np.ones((h, w)), sheet)
    save("SkyUp", np.full((h, w, 3), [28, 104, 228.0]), np.ones((h, w)), sheet)
    save("SkyDown", np.full((h, w, 3), [150, 204, 252.0]), np.ones((h, w)), sheet)


def main():
    args = sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = []
    paint_sky(sheet)
    paint_galaxy(sheet)
    paint_twinkle(sheet)
    if "--sheet" in args:
        out = args[args.index("--sheet") + 1]
        cell = 300
        board = Image.new("RGBA", (cell * len(sheet), cell), (90, 166, 255, 255))
        for i, (_, image) in enumerate(sheet):
            thumb = image.copy()
            thumb.thumbnail((cell, cell))
            board.alpha_composite(thumb, (i * cell, 0))
        board.convert("RGB").save(out)


if __name__ == "__main__":
    main()
