#!/usr/bin/env python3
"""Paints the sky's cloud sprites: flat anime cumulus, one PNG each with alpha.

Painted the way an anime background cloud is: two hard tones and no
airbrushing. The body of the cloud is a pale cyan shadow, and over it lie
pure white lit shapes with crisp, jagged edges that break into brush flicks.
The light comes from the upper left, so each puff's upper left is white
and the white thins out down the cloud, until only a few tongues of it
reach the shadowed base. A lighter cyan picks out a few in-between shapes,
and a deeper one the creases where a puff sits in front of another. Small
cloudlets drift loose round the main heap, and the base fades out into the
sky.

Baked once and uploaded; the game only places them on SurfaceGuis far out in
the sky.

    scripts/paint-clouds.py [count] [below] [--sheet out.png]

Writes art/ui/Clouds/CloudNNN.png, the side-on clouds round the horizon, and
CloudBelowNN.png, clouds seen from above for the layer under the map (1024 x
512 each).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

W, H = 1024, 512
OUT = Path(__file__).resolve().parent.parent / "art/ui/Clouds"

SIDE_COUNT = 100
BELOW_COUNT = 30

WHITE = np.array([255, 255, 255], float)
PALE = np.array([214, 242, 249], float)
SHADOW = np.array([170, 223, 237], float)
CREASE = np.array([140, 200, 222], float)
# Light from the upper left.
LIGHT = np.array([-0.55, -0.65, 0.52])
LIGHT /= np.linalg.norm(LIGHT)
# Where the lit field turns white, and where the paler cyan starts.
WHITE_AT, PALE_AT = 0.5, 0.36


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


def puffs_for(rng):
    """Puffs in unit space: x across 0..1, y up from the base at 0.
    Each is (x, y, r, depth): higher depth is further back, and loose
    cloudlets are depth -1."""
    count = int(rng.integers(6, 11))
    height = rng.uniform(0.22, 0.4)
    tower = rng.uniform(0.6, 2.4)
    main = []
    for i in range(count):
        t = (i + 0.5) / count
        r = rng.uniform(0.6, 1.2) / count
        main.append((t + rng.uniform(-0.25, 0.25) / count, r * rng.uniform(0.25, 0.6), r, 0.0))
    for i in range(count - 1):
        t = (i + 1) / count
        bulge = np.sin(t * np.pi) ** tower
        r = height * (0.16 + 0.28 * bulge) * rng.uniform(0.7, 1.3)
        main.append((t + rng.uniform(-0.03, 0.03), r * 0.5 + bulge * height * 0.5, r, 1.0))
    for _ in range(int(count * 0.7)):
        x, y, r, _ = main[count + int(rng.integers(0, count - 1))]
        a = rng.uniform(0.35, 2.8)
        main.append((x + np.cos(a) * r * 0.55, y + np.sin(a) * r * 0.55, r * rng.uniform(0.5, 0.8), 2.0))
    # Small puffs bubbling along the upper rim of every puff.
    small = []
    for x, y, r, depth in main:
        for _ in range(int(rng.integers(3, 7))):
            a = rng.uniform(0.2, np.pi - 0.2)
            d = r * rng.uniform(0.8, 0.98)
            small.append((x + np.cos(a) * d, y + np.sin(a) * d, r * rng.uniform(0.14, 0.38), depth + 0.5))
    # Loose cloudlets drifting round the heap: little clusters of their own.
    loose = []
    for _ in range(int(rng.integers(2, 6))):
        cx = rng.uniform(-0.02, 1.02)
        cy = rng.uniform(0.15, height * 1.3)
        size = rng.uniform(0.012, 0.03)
        for _ in range(int(rng.integers(3, 6))):
            loose.append((cx + rng.uniform(-2, 2) * size, cy + rng.uniform(0, 1) * size, size * rng.uniform(0.6, 1.2), -1.0))
    return main + small + loose


def puffs_from_above(rng):
    """A cloud seen from above, for the layer under the map: puffs heaped in
    a lumpy blob with no base, bubbling all round the edge. Same units and
    tuple as puffs_for; nearer the image's bottom is nearer the viewer."""
    count = int(rng.integers(14, 24))
    stretch = rng.uniform(1.4, 2.4)
    main = []
    for _ in range(count):
        a, d = rng.uniform(0, 2 * np.pi), np.sqrt(rng.uniform(0, 1))
        r = rng.uniform(0.045, 0.11)
        main.append((0.5 + np.cos(a) * d * 0.3, 0.5 + np.sin(a) * d * 0.3 / stretch, r, 0.0))
    small = []
    for x, y, r, _ in main:
        for _ in range(int(rng.integers(4, 8))):
            a = rng.uniform(0, 2 * np.pi)
            d = r * rng.uniform(0.8, 0.98)
            small.append((x + np.cos(a) * d, y + np.sin(a) * d, r * rng.uniform(0.15, 0.38), 0.5))
    loose = []
    for _ in range(int(rng.integers(2, 6))):
        a = rng.uniform(0, 2 * np.pi)
        cx, cy, size = 0.5 + np.cos(a) * 0.42, 0.5 + np.sin(a) * 0.42 / stretch, rng.uniform(0.012, 0.03)
        for _ in range(int(rng.integers(3, 6))):
            loose.append((cx + rng.uniform(-2, 2) * size, cy + rng.uniform(-1, 1) * size, size * rng.uniform(0.6, 1.2), -1.0))
    return main + small + loose


def fit_above(puffs, room=1.0):
    """Scales a from-above cloud to fill the image, centred (pixels, y
    down). The base returned is past the bottom, so nothing is cut."""
    left = min(x - r for x, _, r, _ in puffs)
    right = max(x + r for x, _, r, _ in puffs)
    low = min(y - r for _, y, r, _ in puffs)
    high = max(y + r for _, y, r, _ in puffs)
    scale = min(W * 0.84 / (right - left), H * 0.82 / (high - low)) * room
    ox = (W - (right - left) * scale) / 2 - left * scale
    oy = (H - (high - low) * scale) / 2 + high * scale
    return [(x * scale + ox, oy - y * scale, r * scale, d) for x, y, r, d in puffs], H * 2


def fit(puffs, room=1.0):
    """Scales the puffs to fill the image, base along the bottom (pixels,
    y down)."""
    left = min(x - r for x, _, r, _ in puffs)
    right = max(x + r for x, _, r, _ in puffs)
    top = max(y + r for _, y, r, _ in puffs)
    scale = min(W * 0.86 / (right - left), H * 0.8 / top) * room
    base = H * 0.9
    ox = (W - (right - left) * scale) / 2 - left * scale
    return [(x * scale + ox, base - y * scale, r * scale, d) for x, y, r, d in puffs], base


# Paint within this many texels of the frame's edge counts as cut off.
BORDER = 6


def paint(seed, above=False):
    """One cloud, wholly inside its frame: painted again smaller until no
    paint reaches the border."""
    room = 1.0
    while True:
        image = paint_once(seed, above, room)
        alpha = np.asarray(image, float)[..., 3]
        edges = np.concatenate([alpha[:BORDER].ravel(), alpha[-BORDER:].ravel(), alpha[:, :BORDER].ravel(), alpha[:, -BORDER:].ravel()])
        if edges.max() < 3 or room < 0.5:
            return image
        room *= 0.9


def paint_once(seed, above, room):
    """One cloud at `room` times its fitted size. `above` paints it as seen
    from above, for the layer under the map: no flat base and no darkening
    down the heap."""
    rng = np.random.default_rng(seed)
    puffs, base = fit_above(puffs_from_above(rng), room) if above else fit(puffs_for(rng), room)
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    top = min(y - r for _, y, r, depth in puffs if depth >= 0)

    # Each texel takes the light of the front-most puff over it (painted back
    # to front), and creases mark where a puff overlaps one behind it.
    lit = np.zeros((H, W))
    cover = np.zeros((H, W))
    crease = np.zeros((H, W))
    for x, y, r, depth in sorted(puffs, key=lambda p: (-p[3], p[1])):
        x0, x1 = int(max(x - r * 1.15, 0)), int(min(x + r * 1.15 + 1, W))
        y0, y1 = int(max(y - r * 1.15, 0)), int(min(y + r * 1.15 + 1, H))
        if x0 >= x1 or y0 >= y1:
            continue
        dx, dy = (xs[y0:y1, x0:x1] - x) / r, (ys[y0:y1, x0:x1] - y) / r
        d2 = dx * dx + dy * dy
        ring = (d2 >= 1) & (d2 < 1.12) & (cover[y0:y1, x0:x1] > 0)
        crease[y0:y1, x0:x1] = np.where(ring, 1, crease[y0:y1, x0:x1])
        inside = d2 < 1
        nz = np.sqrt(np.clip(1 - d2, 0, 1))
        own = dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2]
        lit[y0:y1, x0:x1] = np.where(inside, own, lit[y0:y1, x0:x1])
        crease[y0:y1, x0:x1] = np.where(inside, 0, crease[y0:y1, x0:x1])
        cover[y0:y1, x0:x1] = np.maximum(cover[y0:y1, x0:x1], inside)

    # The white thins out down the heap: the base is mostly shadow.
    down = np.clip((ys - top) / (base - top), 0, 1)
    lit = lit + 0.05 if above else lit - down**1.3 * 0.62 + 0.18

    # Brush flicks: warp the light field by stretched noise (long strokes)
    # and a finer jitter, so every white shape's edge is jagged and drawn out
    # into tapered tongues.
    def displacement(cell_x, cell_y, amount):
        return (value_noise(W, H, cell_x, cell_y, rng) - 0.5) * 2 * amount

    dx = displacement(26, 60, 24) + displacement(7, 11, 8)
    dy = displacement(60, 20, 18) + displacement(9, 6, 7)
    field = warp(lit, dx, dy)
    shape = warp(cover, dx * 0.35, dy * 0.35)
    creases = warp(crease, dx * 0.5, dy * 0.5)

    pale = (field > PALE_AT) & (value_noise(W, H, 40, 30, rng) > 0.45)
    color = np.where((field > WHITE_AT)[..., None], WHITE, np.where(pale[..., None], PALE, SHADOW))
    # Creases only up in the heap: lower down they'd read as cracks.
    color = np.where(((creases > 0.5) & (field < WHITE_AT) & (down < 0.6))[..., None], CREASE, color)

    # Crisp edges with one texel of smoothing, the base fading into the sky.
    edge = Image.fromarray((np.clip(shape, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    alpha = np.asarray(edge, float) / 255
    if not above:
        fade = np.clip((ys - (base - H * 0.16)) / (H * 0.16), 0, 1)
        alpha *= 1 - fade**1.5 * 0.9
        alpha *= ys < base + 4

    rgb = Image.fromarray(np.clip(color, 0, 255).astype(np.uint8))
    rgb.putalpha(Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)))
    return rgb


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
        image = paint(index * 7919)
        image.save(OUT / f"Cloud{index:03d}.png")
        if len(shown) < 6:
            shown.append(image)
    for index in range(1, below + 1):
        image = paint(index * 104729, above=True)
        image.save(OUT / f"CloudBelow{index:02d}.png")
        if index <= 3:
            shown.append(image)
    if sheet:
        cols = 3
        rows = (len(shown) + cols - 1) // cols
        cw, ch = W // 2, H // 2
        board = Image.new("RGBA", (cw * cols, ch * rows), (40, 140, 240, 255))
        for i, image in enumerate(shown):
            board.alpha_composite(image.resize((cw, ch), Image.LANCZOS), ((i % cols) * cw, (i // cols) * ch))
        board.convert("RGB").save(sheet)


if __name__ == "__main__":
    main()
