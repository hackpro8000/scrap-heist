#!/usr/bin/env python3
"""Paints the sky's cloud sprites: anime cumulus, one PNG each with alpha.

Each cloud is a cluster of round puffs read as a height field (a sphere cap
per puff), lit from the upper right and shaded through a soft ramp from the
blue-grey underside to a white top, with a painterly grain. Baked once and
uploaded; the game only places them on SurfaceGuis far out in the sky.

    scripts/paint-clouds.py [count] [--sheet out.png]

Writes art/ui/Clouds/CloudNN.png (512 x 256).
"""
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageFilter

W, H = 512, 256
OUT = Path(__file__).resolve().parent.parent / "art/ui/Clouds"

SHADOW = np.array([118, 140, 186], float)
MID = np.array([205, 216, 238], float)
LIT = np.array([255, 255, 253], float)
LIGHT = np.array([0.45, 0.55, 0.7])
LIGHT /= np.linalg.norm(LIGHT)


def fbm(rng, octaves=5):
    """Fractal value noise in 0..1: each octave halves the cell and the weight."""
    total = np.zeros((H, W))
    weight = 0.0
    for o in range(octaves):
        cell = 128 >> o
        grid = rng.random((H // cell + 2, W // cell + 2))
        layer = Image.fromarray((grid * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
        amp = 0.5**o
        total += amp * np.asarray(layer, float) / 255
        weight += amp
    return total / weight


def puffs_for(rng):
    """Puffs in unit space: x across 0..1, y down from the base at 0."""
    count = int(rng.integers(7, 14))
    height = rng.uniform(0.22, 0.42)
    tower = rng.uniform(0.6, 2.5)
    puffs = []
    for i in range(count):
        t = (i + 0.5) / count
        r = rng.uniform(1.0, 1.4) / count
        puffs.append((t, -r * 0.35, r))
    for i in range(count - 2):
        t = (i + 1.5) / count
        bulge = np.sin(t * np.pi) ** tower
        r = height * (0.22 + 0.25 * bulge) * rng.uniform(0.8, 1.2)
        puffs.append((t + rng.uniform(-0.03, 0.03), -r * 0.4 - bulge * height * 0.45, r))
    for _ in range(count):
        x, y, r = puffs[count + int(rng.integers(0, count - 2))]
        rr = r * rng.uniform(0.35, 0.6)
        a = rng.uniform(-2.6, -0.5)
        puffs.append((x + np.cos(a) * r * 0.75, y + np.sin(a) * r * 0.75, rr))
    return puffs


def fit(puffs):
    """Scales and moves the puffs to fill the image, base along the bottom."""
    left = min(x - r for x, _, r in puffs)
    right = max(x + r for x, _, r in puffs)
    top = min(y - r for _, y, r in puffs)
    scale = min(W * 0.94 / (right - left), H * 0.86 / (0 - top))
    base = H * 0.93
    ox = (W - (right - left) * scale) / 2 - left * scale
    return [(x * scale + ox, y * scale + base, r * scale) for x, y, r in puffs], base


def painterly(image, rng):
    """Brushes the flat shading: edge-preserving smoothing, then faint horizontal strokes."""
    pixels = np.asarray(image)
    rgb = np.ascontiguousarray(pixels[..., :3])
    smooth = cv2.edgePreservingFilter(rgb, flags=1, sigma_s=12, sigma_r=0.25)
    stroke = cv2.blur(rng.normal(0, 1, (H, W)).astype(np.float32), (21, 3))
    stroke /= np.abs(stroke).max() + 1e-6
    out = np.clip(smooth.astype(np.float32) + stroke[..., None] * 4, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([out, pixels[..., 3]]), "RGBA")


def paint(seed):
    rng = np.random.default_rng(seed)
    puffs, base = fit(puffs_for(rng))
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    # Smooth union of sphere caps: puffs merge with soft creases, not seams.
    k = 4.0
    total = np.zeros((H, W))
    for x, y, r in puffs:
        cap = r * r - (xs - x) ** 2 - (ys - y) ** 2
        z = np.sqrt(np.clip(cap, 0, None))
        total += np.where(cap > 0, np.exp(np.minimum(z / k, 60)), 0)
    covered = (total > 0) & (ys < base)
    height = np.where(total > 0, k * np.log(np.maximum(total, 1e-9)), 0)
    gy, gx = np.gradient(height)
    normal = np.dstack([-gx, -gy, np.ones_like(gx)])
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    # Image y runs down, so light from above is -y.
    light = normal[..., 0] * LIGHT[0] - normal[..., 1] * LIGHT[2] + normal[..., 2] * LIGHT[1]
    # The lower half sits in the cloud's own shadow.
    depth = np.clip((ys - H * 0.35) / (base - H * 0.35), 0, 1)
    light -= depth ** 1.5 * 0.55
    light += rng.normal(0, 0.025, (H, W))
    light += (fbm(rng, octaves=6) - 0.5) * 0.5
    t = np.clip((light + 0.15) / 1.0, 0, 1)
    # Soft steps: painted rather than airbrushed.
    t = np.clip(t + 0.07 * np.sin(t * np.pi * 4), 0, 1)[..., None]
    color = np.where(t < 0.5, SHADOW + (MID - SHADOW) * (t / 0.5), MID + (LIT - MID) * ((t - 0.5) / 0.5))
    mask = Image.fromarray((covered * 255).astype(np.uint8))
    # A bright rim along the sunlit top edge.
    inner = np.asarray(mask.filter(ImageFilter.MinFilter(5))) > 0
    rim = covered & ~inner & (normal[..., 1] < -0.2)
    color[rim] = LIT
    # Soft transparency: edges feather out, and the shadowed underside is
    # thinner than the sunlit top.
    soft = np.asarray(mask.filter(ImageFilter.GaussianBlur(5)), float) / 255
    soft = np.clip(soft * 1.6 - 0.25, 0, 1) * (0.92 - 0.3 * depth)
    # Ragged edges: noise eats into the rim so the outline breaks into puffs.
    rim_noise = np.clip(1 - (fbm(rng, octaves=6) - 0.5) * 1.2, 0, 1)
    soft = np.where(soft < 0.5, soft * rim_noise, soft)
    alpha = Image.fromarray((soft * 255).astype(np.uint8))
    rgb = Image.fromarray(np.clip(color, 0, 255).astype(np.uint8)).filter(ImageFilter.SMOOTH)
    rgb.putalpha(alpha)
    return painterly(rgb, rng)


def main():
    args = sys.argv[1:]
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i : i + 2]
    count = int(args[0]) if args else 50
    OUT.mkdir(parents=True, exist_ok=True)
    images = []
    for index in range(1, count + 1):
        image = paint(index * 7919)
        image.save(OUT / f"Cloud{index:02d}.png")
        images.append(image)
    if sheet:
        cols = 3
        rows = (min(len(images), 9) + cols - 1) // cols
        board = Image.new("RGBA", (W * cols, H * rows), (90, 166, 255, 255))
        for i, image in enumerate(images[:9]):
            board.alpha_composite(image, ((i % cols) * W, (i // cols) * H))
        board.convert("RGB").save(sheet)


if __name__ == "__main__":
    main()
