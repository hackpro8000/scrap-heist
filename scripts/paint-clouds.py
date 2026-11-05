#!/usr/bin/env python3
"""Paints the sky's cloud sprites: flat anime cumulus, in depth slices.

Painted the way an anime background cloud is: two hard tones and no
airbrushing. The body is a pale cyan shadow, and over it lie pure white lit
shapes with crisp, jagged edges that break into brush flicks. The light
comes from the upper left, so each puff's upper left is white and the white
thins out down the cloud. A lighter cyan picks out a few in-between shapes,
a deeper one the creases where a puff sits in front of another, and the flat
base is a crisp, slightly wavy edge with a darker underside. Small cloudlets
drift loose round the heap.

Every cloud is painted as a stack of slices the game sets apart in depth, so
moving the camera slides them against each other and the cloud reads as a
volume, not a card:

- side-on clouds (round the horizon) split into front, middle and back
  puffs: CloudNNN_1 (front) to CloudNNN_3 (back), 512 x 256;
- clouds seen from above (the layer under the map) are cut into horizontal
  slices through a heap of puffs: CloudBelowNN_1 (lowest, in shadow) to
  CloudBelowNN_4 (the sunlit tops), 1024 x 512.

The slices of one cloud line up exactly, and nothing reaches a frame's edge.
Baked once and uploaded; the game only places them on SurfaceGuis.

    scripts/paint-clouds.py [count] [below] [--sheet out.png]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "art/ui/Clouds"
SIDE_COUNT = 100
BELOW_COUNT = 30
SIDE_SIZE = (512, 256)
BELOW_SIZE = (1024, 512)
SIDE_SLICES = 3
BELOW_SLICES = 4

WHITE = np.array([255, 255, 255], float)
PALE = np.array([214, 242, 249], float)
SHADOW = np.array([170, 223, 237], float)
CREASE = np.array([140, 200, 222], float)
UNDERSIDE = np.array([128, 188, 214], float)
# Light from the upper left.
LIGHT = np.array([-0.55, -0.65, 0.52])
LIGHT /= np.linalg.norm(LIGHT)
# Where the lit field turns white, and where the paler cyan starts.
WHITE_AT, PALE_AT = 0.5, 0.36
# Paint within this many texels of the frame's edge counts as cut off.
BORDER = 4


def value_noise(w, h, cell_x, cell_y, rng):
    """Smooth noise in 0..1 with features cell_x by cell_y pixels."""
    gw, gh = int(w / cell_x) + 3, int(h / cell_y) + 3
    small = Image.fromarray((rng.random((gh, gw)) * 255).astype(np.uint8))
    big = small.resize((int(gw * cell_x), int(gh * cell_y)), Image.BICUBIC)
    return np.asarray(big, float)[:h, :w] / 255


def warp(field, dx, dy):
    """Samples `field` displaced by (dx, dy) pixels: nearest texel."""
    ys, xs = np.mgrid[0 : field.shape[0], 0 : field.shape[1]]
    sx = np.clip((xs + dx).round().astype(int), 0, field.shape[1] - 1)
    sy = np.clip((ys + dy).round().astype(int), 0, field.shape[0] - 1)
    return field[sy, sx]


class Brush:
    """One cloud's brush: the jitter that makes its edges jagged and the
    patches of paler cyan, shared by all its slices so they line up."""

    def __init__(self, w, h, rng, reach):
        def displacement(cell_x, cell_y, amount):
            return (value_noise(w, h, max(cell_x * reach, 2), max(cell_y * reach, 2), rng) - 0.5) * 2 * amount * reach

        self.dx = displacement(26, 60, 24) + displacement(7, 11, 8)
        self.dy = displacement(60, 20, 18) + displacement(9, 6, 7)
        self.pale = value_noise(w, h, 40 * reach, 30 * reach, rng) > 0.45
        self.base_wave = (value_noise(w, 1, 50 * reach, 1, rng)[0] - 0.5) * 8 * reach


def shade(w, h, discs, light_bias, brush, base=None):
    """Paints discs (x, y, r, light fn of unit offsets; front-most last)
    into one slice: two-tone light with jagged edges, creases where a disc
    overlaps one behind it, and a crisp flat base at `base` if given.
    Returns colour and alpha."""
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    lit = np.zeros((h, w))
    cover = np.zeros((h, w))
    crease = np.zeros((h, w))
    for x, y, r, light in discs:
        x0, x1 = int(max(x - r * 1.15, 0)), int(min(x + r * 1.15 + 1, w))
        y0, y1 = int(max(y - r * 1.15, 0)), int(min(y + r * 1.15 + 1, h))
        if x0 >= x1 or y0 >= y1:
            continue
        dx, dy = (xs[y0:y1, x0:x1] - x) / r, (ys[y0:y1, x0:x1] - y) / r
        d2 = dx * dx + dy * dy
        ring = (d2 >= 1) & (d2 < 1.12) & (cover[y0:y1, x0:x1] > 0)
        crease[y0:y1, x0:x1] = np.where(ring, 1, crease[y0:y1, x0:x1])
        inside = d2 < 1
        lit[y0:y1, x0:x1] = np.where(inside, light(dx, dy, d2, ys[y0:y1, x0:x1]), lit[y0:y1, x0:x1])
        crease[y0:y1, x0:x1] = np.where(inside, 0, crease[y0:y1, x0:x1])
        cover[y0:y1, x0:x1] = np.maximum(cover[y0:y1, x0:x1], inside)
    lit += light_bias

    field = warp(lit, brush.dx, brush.dy)
    shape = warp(cover, brush.dx * 0.35, brush.dy * 0.35)
    creases = warp(crease, brush.dx * 0.5, brush.dy * 0.5)
    pale = (field > PALE_AT) & brush.pale
    color = np.where((field > WHITE_AT)[..., None], WHITE, np.where(pale[..., None], PALE, SHADOW))
    color = np.where(((creases > 0.5) & (field < WHITE_AT))[..., None], CREASE, color)

    if base is not None:
        # A crisp, slightly wavy flat base with a darker underside above it.
        line = base + brush.base_wave[None, :]
        shape = shape * (ys < line)
        underside = (ys > line - 6 * (h / 256)) & (field < WHITE_AT + 0.15)
        color = np.where(underside[..., None], UNDERSIDE, color)

    edge = Image.fromarray((np.clip(shape, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    return color, np.asarray(edge, float) / 255


# Side-on clouds -------------------------------------------------------------


def side_puffs(rng):
    """Puffs in unit space: x across 0..1, y up from the base at 0. Each is
    (x, y, r, slice): slice 0 is the front, 2 the back."""
    count = int(rng.integers(6, 11))
    height = rng.uniform(0.22, 0.4)
    tower = rng.uniform(0.6, 2.4)
    main = []
    for i in range(count):
        t = (i + 0.5) / count
        r = rng.uniform(0.6, 1.2) / count
        main.append((t + rng.uniform(-0.25, 0.25) / count, r * rng.uniform(0.3, 0.6), r, 0))
    for i in range(count - 1):
        t = (i + 1) / count
        bulge = np.sin(t * np.pi) ** tower
        r = height * (0.16 + 0.28 * bulge) * rng.uniform(0.7, 1.3)
        main.append((t + rng.uniform(-0.03, 0.03), r * 0.5 + bulge * height * 0.5, r, 1))
    for _ in range(int(count * 0.7)):
        x, y, r, _ = main[count + int(rng.integers(0, count - 1))]
        a = rng.uniform(0.35, 2.8)
        main.append((x + np.cos(a) * r * 0.55, y + np.sin(a) * r * 0.55, r * rng.uniform(0.5, 0.8), 2))
    # Small puffs bubbling along the upper rim of every puff, in its slice.
    small = []
    for x, y, r, layer in main:
        for _ in range(int(rng.integers(3, 7))):
            a = rng.uniform(0.2, np.pi - 0.2)
            d = r * rng.uniform(0.8, 0.98)
            small.append((x + np.cos(a) * d, y + np.sin(a) * d, r * rng.uniform(0.14, 0.38), layer))
    # Loose cloudlets drift in the middle slice.
    loose = []
    for _ in range(int(rng.integers(2, 6))):
        cx, cy, size = rng.uniform(0.02, 0.98), rng.uniform(0.15, height * 1.3), rng.uniform(0.012, 0.03)
        for _ in range(int(rng.integers(3, 6))):
            loose.append((cx + rng.uniform(-2, 2) * size, cy + rng.uniform(0, 1) * size, size * rng.uniform(0.6, 1.2), 1))
    return main + small + loose


def paint_side(seed, room):
    w, h = SIDE_SIZE
    rng = np.random.default_rng(seed)
    puffs = side_puffs(rng)
    left = min(x - r for x, _, r, _ in puffs)
    right = max(x + r for x, _, r, _ in puffs)
    top = max(y + r for _, y, r, _ in puffs)
    scale = min(w * 0.88 / (right - left), h * 0.82 / top) * room
    base = h * 0.9
    ox = (w - (right - left) * scale) / 2 - left * scale
    placed = [(x * scale + ox, base - y * scale, r * scale, s) for x, y, r, s in puffs]
    highest = min(y - r for _, y, r, _ in placed)
    brush = Brush(w, h, rng, w / 1024)

    def lighting(dx, dy, d2, ys):
        nz = np.sqrt(np.clip(1 - d2, 0, 1))
        down = np.clip((ys - highest) / (base - highest), 0, 1)
        return dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2] - down**1.3 * 0.62

    slices = []
    for layer in range(SIDE_SLICES):
        # Within a slice the higher puffs lie behind, so lower ones overlap them.
        discs = [(x, y, r, lighting) for x, y, r, s in sorted(placed, key=lambda p: p[1]) if s == layer]
        slices.append(shade(w, h, discs, 0.18, brush, base))
    return slices


# Clouds seen from above -------------------------------------------------------


def below_puffs(rng):
    """A heap of puffs seen from above: (x, y, z, r) with x, y across the
    image (0..1) and z up from the heap's floor."""
    count = int(rng.integers(14, 24))
    stretch = rng.uniform(1.4, 2.4)
    main = []
    for _ in range(count):
        a, d = rng.uniform(0, 2 * np.pi), np.sqrt(rng.uniform(0, 1))
        r = rng.uniform(0.045, 0.11)
        # Puffs in the middle of the heap ride higher.
        z = r * (0.3 + 1.2 * (1 - d)) * rng.uniform(0.7, 1.3)
        main.append((0.5 + np.cos(a) * d * 0.3, 0.5 + np.sin(a) * d * 0.3 / stretch, z, r))
    small = []
    for x, y, z, r in main:
        for _ in range(int(rng.integers(4, 8))):
            a = rng.uniform(0, 2 * np.pi)
            d = r * rng.uniform(0.75, 0.95)
            small.append((x + np.cos(a) * d, y + np.sin(a) * d, z + r * rng.uniform(-0.2, 0.4), r * rng.uniform(0.18, 0.4)))
    loose = []
    for _ in range(int(rng.integers(2, 6))):
        a = rng.uniform(0, 2 * np.pi)
        cx, cy, size = 0.5 + np.cos(a) * 0.4, 0.5 + np.sin(a) * 0.4 / stretch, rng.uniform(0.012, 0.03)
        for _ in range(int(rng.integers(3, 6))):
            loose.append((cx + rng.uniform(-2, 2) * size, cy + rng.uniform(-1, 1) * size, size, size * rng.uniform(0.6, 1.2)))
    return main + small + loose


def paint_below(seed, room):
    w, h = BELOW_SIZE
    rng = np.random.default_rng(seed)
    puffs = below_puffs(rng)
    left = min(x - r for x, _, _, r in puffs)
    right = max(x + r for x, _, _, r in puffs)
    low = min(y - r for _, y, _, r in puffs)
    high = max(y + r for _, y, _, r in puffs)
    scale = min(w * 0.88 / (right - left), h * 0.86 / (high - low)) * room
    ox = (w - (right - left) * scale) / 2 - left * scale
    oy = (h - (high - low) * scale) / 2 - low * scale
    floor = min(z - r for _, _, z, r in puffs)
    ceiling = max(z + r for _, _, z, r in puffs)
    brush = Brush(w, h, rng, w / 1024)

    slices = []
    for k in range(BELOW_SLICES):
        # Cut through the heap at this height; each puff shows the disc where
        # it crosses the cut, shaded from the side by the light and brighter
        # the higher the cut.
        # Cuts stop short of the very top, where only a few crowns reach.
        cut = floor + (ceiling - floor) * (0.15 + 0.55 * k / (BELOW_SLICES - 1))
        rise = k / (BELOW_SLICES - 1)
        discs = []
        for x, y, z, r in sorted(puffs, key=lambda p: p[2]):
            gap = cut - z
            if abs(gap) >= r * 0.95:
                continue
            disc = np.sqrt(r * r - gap * gap)

            def light(dx, dy, d2, _ys, tilt=gap / r):
                nz = np.sqrt(np.clip(1 - d2, 0, 1))
                return (dx * LIGHT[0] + dy * LIGHT[1]) * 0.7 + nz * 0.3 + tilt * 0.35

            discs.append((x * scale + ox, y * scale + oy, disc * scale, light))
        slices.append(shade(w, h, discs, -0.25 + rise * 0.55, brush))
    return slices


def fits(slices):
    """Whether no slice's paint reaches the frame's edge."""
    for _, alpha in slices:
        edges = np.concatenate([alpha[:BORDER].ravel(), alpha[-BORDER:].ravel(), alpha[:, :BORDER].ravel(), alpha[:, -BORDER:].ravel()])
        if edges.max() > 0.01:
            return False
    return True


def paint(seed, above=False):
    """One cloud's slices, wholly inside their frames: painted again smaller
    until no paint reaches the border."""
    room = 1.0
    while True:
        slices = (paint_below if above else paint_side)(seed, room)
        if fits(slices) or room < 0.5:
            return [to_image(color, alpha) for color, alpha in slices]
        room *= 0.92


def to_image(color, alpha):
    image = Image.fromarray(np.clip(color, 0, 255).astype(np.uint8))
    image.putalpha(Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)))
    return image


def stacked(slices):
    """Slices composited in the order given, for the review sheet."""
    out = Image.new("RGBA", slices[0].size, (0, 0, 0, 0))
    for image in slices:
        out.alpha_composite(image)
    return out


def main():
    args = sys.argv[1:]
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i : i + 2]
    count = int(args[0]) if len(args) > 0 else SIDE_COUNT
    below = int(args[1]) if len(args) > 1 else BELOW_COUNT
    OUT.mkdir(parents=True, exist_ok=True)
    shown = []
    for index in range(1, count + 1):
        slices = paint(index * 7919)
        for k, image in enumerate(slices, start=1):
            image.save(OUT / f"Cloud{index:03d}_{k}.png")
        if len(shown) < 6:
            # The back slice first, so the front lies over it.
            shown.append(stacked(slices[::-1]).resize(BELOW_SIZE, Image.LANCZOS))
    for index in range(1, below + 1):
        slices = paint(index * 104729, above=True)
        for k, image in enumerate(slices, start=1):
            image.save(OUT / f"CloudBelow{index:02d}_{k}.png")
        if index <= 3:
            shown.append(stacked(slices))
    if sheet:
        cols = 3
        rows = (len(shown) + cols - 1) // cols
        cw, ch = BELOW_SIZE[0] // 2, BELOW_SIZE[1] // 2
        board = Image.new("RGBA", (cw * cols, ch * rows), (40, 140, 240, 255))
        for i, image in enumerate(shown):
            board.alpha_composite(image.resize((cw, ch), Image.LANCZOS), ((i % cols) * cw, (i // cols) * ch))
        board.convert("RGB").save(sheet)


if __name__ == "__main__":
    main()
