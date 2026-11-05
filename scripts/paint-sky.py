#!/usr/bin/env python3
"""Paints the sky's sprites in a hand-drawn anime style, one PNG with alpha
each, into art/ui/Sky. Baked once and uploaded (scripts/upload-ui.sh Sky
...); AtmosphereController hangs them on SurfaceGuis far out in the sky.

Everything is lit from the upper left, shaded in soft steps and edged with
a thin ink line a shade darker than the paint under it.

    scripts/paint-sky.py [--sheet out.png]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "art/ui/Sky"
LIGHT = np.array([-0.55, -0.6, 0.58])
LIGHT /= np.linalg.norm(LIGHT)


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


def steps(t, count=4, soft=0.25):
    """Soft cel steps: t pulled toward `count` flat levels."""
    q = np.floor(t * count) / count
    frac = t * count - np.floor(t * count)
    edge = np.clip((frac - (1 - soft)) / soft, 0, 1)
    return np.clip(q + edge / count, 0, 1)


def mix(a, b, f):
    f = np.asarray(f, float)
    if f.ndim == 2:
        f = f[..., None]
    return a * (1 - f) + b * f


def normals_from(mask, blur):
    """A rounded bevel from a mask: the blurred mask read as a height field."""
    height = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)), float) / 255
    gy, gx = np.gradient(height * blur * 1.5)
    n = np.dstack([-gx, -gy, np.ones_like(gx)])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def lambert(n):
    return np.clip(n[..., 0] * LIGHT[0] + n[..., 1] * LIGHT[1] + n[..., 2] * LIGHT[2], 0, 1)


def ink(rgb, alpha, width=2, darken=0.5):
    """A thin ink line round the shape, a shade darker than the paint inside."""
    mask = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8))
    inner = np.asarray(mask.filter(ImageFilter.MinFilter(width * 2 + 1)), float) / 255
    line = np.clip(alpha - inner, 0, 1)
    return mix(rgb, rgb * darken, line)


def save(name, rgb, alpha, sheet):
    alpha = np.asarray(Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)))
    image = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    image.putalpha(Image.fromarray(alpha))
    image.save(OUT / f"{name}.png")
    sheet.append((name, image))


def disc(xs, ys, cx, cy, r):
    dx, dy = (xs - cx) / r, (ys - cy) / r
    d2 = dx * dx + dy * dy
    inside = d2 < 1
    nz = np.sqrt(np.clip(1 - d2, 0, 1))
    return inside, np.dstack([dx, dy, nz]), d2


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


# The planet ---------------------------------------------------------------

PLANET_BANDS = [
    (250, 206, 172), (232, 196, 236), (252, 242, 214), (186, 228, 222),
    (244, 190, 204), (192, 214, 246), (250, 226, 180), (214, 200, 244),
]
NIGHT = np.array([96, 88, 156], float)
RING = [(255, 244, 214), (236, 214, 255), (206, 238, 255), (255, 226, 236)]
TILT = math.radians(-14)
FLAT = 0.24


def ring_coords(xs, ys, cx, cy, r):
    """Each pixel's radius on the tilted ring plane (in planet radii), and
    whether that point of the ring is on the near side."""
    dx, dy = xs - cx, ys - cy
    u = dx * math.cos(TILT) + dy * math.sin(TILT)
    v = -dx * math.sin(TILT) + dy * math.cos(TILT)
    return np.sqrt(u * u + (v / FLAT) ** 2) / r, v > 0, u, v


def ring_paint(rr, xs, ys, seed, inner=1.3, outer=1.85):
    across = (rr - inner) / (outer - inner)
    on = (across > 0) & (across < 1)
    # Bands and gaps across the ring.
    bands = np.sin(across * 38) * 0.5 + 0.5
    gap = (np.abs(across - 0.62) < 0.035) | (np.abs(across - 0.2) < 0.015)
    density = np.where(on & ~gap, 0.55 + 0.4 * bands, 0) * np.clip(np.minimum(across, 1 - across) * 12, 0, 1)
    color = ramp(np.clip(across, 0, 1), RING)
    color = mix(color, np.array([255, 255, 255.0]), bands * 0.35)
    return color, density


def paint_planet(sheet):
    w = h = 1024
    xs, ys = grid(w, h)
    cx, cy, r = 512, 512, 262
    inside, n, d2 = disc(xs, ys, cx, cy, r)
    # Bands by latitude along the ring's tilt, warped by noise so they swirl.
    lat = (-(xs - cx) * math.sin(TILT) + (ys - cy) * math.cos(TILT)) / r
    warp = noise(w, h, 90, 3) - 0.5
    swirl = noise(w, h, 30, 4) - 0.5
    t = lat * 4.2 + warp * 0.9 + swirl * 0.25
    index = np.floor(t).astype(int) % len(PLANET_BANDS)
    nxt = (index + 1) % len(PLANET_BANDS)
    f = np.clip((t - np.floor(t) - 0.75) / 0.25, 0, 1)
    colors = np.array(PLANET_BANDS, float)
    body = mix(colors[index], colors[nxt], f)
    # Fine streaks within the bands.
    body = mix(body, np.array([255, 255, 255.0]), (noise(w, h, 12, 5, 2) > 0.62) * 0.18)
    light = steps(lambert(n), 4, 0.5)
    body = mix(NIGHT, body, 0.35 + 0.65 * light)
    # A bright rim on the sunlit limb.
    rim = np.clip((d2 - 0.86) / 0.14, 0, 1) * np.clip(-(n[..., 0] + n[..., 1]) * 0.9, 0, 1)
    body = mix(body, np.array([255, 252, 240.0]), rim * 0.8)
    body = ink(body, inside.astype(float), 2, 0.7)

    rr, near, _, _ = ring_coords(xs, ys, cx, cy, r)
    ring_rgb, ring_a = ring_paint(rr, xs, ys, 7)
    # The planet's shadow falls across the ring behind it, to the lower right.
    shadow = (rr > 1.2) & (np.abs((ys - cy) * 0.8 - (xs - cx) * 0.25) < r * 0.75) & ((xs - cx) + (ys - cy) * 0.4 > r * 0.4) & ~near
    ring_rgb = mix(ring_rgb, NIGHT, shadow * 0.45)
    glow = np.asarray(Image.fromarray((ring_a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14)), float) / 255

    rgb = np.zeros((h, w, 3))
    alpha = np.zeros((h, w))
    # Back of the ring and its glow, then the planet, then the near ring.
    back = ring_a * (~near)
    rgb = mix(rgb, np.array([255, 245, 255.0]), np.clip(glow * 0.6, 0, 1))
    alpha = np.maximum(alpha, glow * 0.45)
    rgb = mix(rgb, ring_rgb, back)
    alpha = np.maximum(alpha, back)
    halo = np.clip(1 - (np.sqrt(d2) - 1) / 0.08, 0, 1) * (d2 >= 1)
    rgb = mix(rgb, np.array([235, 225, 255.0]), halo * 0.7)
    alpha = np.maximum(alpha, halo * 0.5)
    rgb = mix(rgb, body, inside)
    alpha = np.maximum(alpha, inside)
    front = ring_a * near
    rgb = mix(rgb, ring_rgb, front)
    alpha = np.maximum(alpha, front)
    save("Planet", rgb, alpha, sheet)

    # Two twinkle layers along the ring, faded in turn by the game.
    rng = np.random.default_rng(11)
    for name in ("RingSparkleA", "RingSparkleB"):
        points = []
        while len(points) < 26:
            a = rng.uniform(0, 2 * math.pi)
            rad = rng.uniform(1.35, 1.8) * r
            u, v = math.cos(a) * rad, math.sin(a) * rad * FLAT
            x = cx + u * math.cos(TILT) - v * math.sin(TILT)
            y = cy + u * math.sin(TILT) + v * math.cos(TILT)
            if (x - cx) ** 2 + (y - cy) ** 2 < r * r and v < 0:
                continue
            points.append((x, y))
        a = sparkle_stars(w, h, points, rng, 9)
        save(name, np.full((h, w, 3), [255, 252, 235.0]), a, sheet)


def paint_ring_moon(sheet):
    w = h = 512
    xs, ys = grid(w, h)
    cx, cy, r = 256, 256, 110
    inside, n, d2 = disc(xs, ys, cx, cy, r)
    craters = noise(w, h, 26, 21) > 0.6
    body = ramp(noise(w, h, 60, 22), [(196, 190, 226), (224, 220, 240), (180, 196, 230)])
    body = mix(body, body * 0.82, craters)
    body = mix(NIGHT, body, 0.35 + 0.65 * steps(lambert(n), 3, 0.5))
    body = ink(body, inside.astype(float), 2, 0.65)
    global TILT, FLAT
    keep = TILT, FLAT
    TILT, FLAT = math.radians(28), 0.32
    rr, near, _, _ = ring_coords(xs, ys, cx, cy, r)
    ring_rgb, ring_a = ring_paint(rr, xs, ys, 23, 1.35, 2.1)
    TILT, FLAT = keep
    rgb = mix(np.zeros((h, w, 3)), ring_rgb, ring_a * ~near)
    alpha = ring_a * ~near
    rgb = mix(rgb, body, inside)
    alpha = np.maximum(alpha, inside)
    rgb = mix(rgb, ring_rgb, ring_a * near)
    alpha = np.maximum(alpha, ring_a * near)
    save("RingMoon", rgb, alpha, sheet)


def paint_moon(sheet, name, stops, seed, crater_dark):
    w = h = 256
    xs, ys = grid(w, h)
    inside, n, d2 = disc(xs, ys, 128, 128, 116)
    body = ramp(noise(w, h, 50, seed), stops)
    spots = noise(w, h, 22, seed + 1)
    body = mix(body, body * crater_dark, np.clip((spots - 0.58) * 8, 0, 1))
    body = mix(NIGHT, body, 0.4 + 0.6 * steps(lambert(n), 3, 0.5))
    rim = np.clip((d2 - 0.85) / 0.15, 0, 1) * np.clip(-(n[..., 0] + n[..., 1]), 0, 1)
    body = mix(body, np.array([255, 245, 230.0]), rim * 0.6)
    body = ink(body, inside.astype(float), 2, 0.65)
    save(name, body, inside.astype(float), sheet)


# The cog ------------------------------------------------------------------

def paint_cog(sheet):
    w = h = 1024
    xs, ys = grid(w, h)
    cx, cy = 512, 512
    dx, dy = xs - cx, ys - cy
    rad = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    teeth = 18
    # Teeth: a trapezoid wave on the rim.
    phase = (ang / (2 * math.pi) * teeth) % 1
    tooth = np.clip(1.6 - np.abs(phase - 0.5) * 5, 0, 1)
    outer = 430 + 60 * tooth
    rim = (rad < outer) & (rad > 330)
    hub = rad < 90
    spokes = np.zeros_like(rim)
    for k in range(5):
        a = k / 5 * 2 * math.pi + 0.3
        along = dx * math.cos(a) + dy * math.sin(a)
        across = -dx * math.sin(a) + dy * math.cos(a)
        width = 34 - along * 0.03
        spokes |= (along > 0) & (along < 340) & (np.abs(across) < width)
    mask = (rim | hub | spokes).astype(float)
    # Chips knocked out of the rim and a missing tooth.
    chips = (noise(w, h, 40, 31) > 0.74) & (rad > outer - 30)
    missing = (np.abs(((ang + math.pi) / (2 * math.pi) * teeth) - 4.5) < 0.5) & (rad > 425)
    mask = mask * ~chips * ~missing
    n = normals_from(mask, 10)
    light = steps(lambert(n), 4, 0.4)
    rust = noise(w, h, 50, 32)
    base = ramp(rust, [(118, 74, 46), (164, 106, 60), (186, 132, 78), (140, 96, 66)])
    pits = noise(w, h, 8, 33, 2) > 0.66
    base = mix(base, base * 0.7, pits * 0.6)
    rgb = mix(base * 0.45, base * 1.15, light)
    # Bolt heads round the hub and along the rim.
    for k in range(8):
        a = k / 8 * 2 * math.pi
        for rr, size in ((60, 9), (380, 12)):
            bx, by = cx + math.cos(a) * rr, cy + math.sin(a) * rr
            d = np.sqrt((xs - bx) ** 2 + (ys - by) ** 2)
            bolt = d < size
            rgb = mix(rgb, np.array([210, 160, 100.0]) * (1.1 - (ys - by + size) / (4 * size))[..., None], bolt * mask)
    # Moss and vines on the upward faces of the upper half.
    moss = (noise(w, h, 36, 34) > 0.55) & (n[..., 1] < 0.05) & (ys < cy + 160)
    moss_color = ramp(noise(w, h, 18, 35), [(86, 124, 52), (122, 162, 64), (160, 190, 80)])
    moss_color = mix(moss_color * 0.6, moss_color, light)
    rgb = mix(rgb, moss_color, moss * mask)
    for k in range(7):
        x0 = cx + (k - 3) * 120 + 30
        vine = np.abs(xs - x0 - np.sin(ys / 40 + k) * 10) < 3
        top = cy - math.sqrt(max(0, 480 ** 2 - (x0 - cx) ** 2))
        vine &= (ys > top) & (ys < top + 160 + k * 25)
        rgb = mix(rgb, np.array([80, 120, 50.0]), vine * mask)
    rgb = ink(rgb, mask, 3, 0.45)
    save("Cog", rgb, mask, sheet)


# Galaxy --------------------------------------------------------------------

def paint_galaxy(sheet):
    w, h = 1024, 512
    xs, ys = grid(w, h)
    dx, dy = (xs - 512) / 420, (ys - 256) / 150
    r = np.sqrt(dx * dx + dy * dy) + 1e-6
    a = np.arctan2(dy, dx)
    arms = np.cos(2 * (a - np.log(r) * 3.2)) * 0.5 + 0.5
    wisps = noise(w, h, 40, 41)
    density = np.clip(arms ** 2 * np.exp(-r * 2.6) * 1.8 + np.exp(-r * r * 40) * 1.2, 0, 1)
    density *= 0.6 + 0.6 * wisps
    color = ramp(np.clip(r * 1.6, 0, 1), [(255, 250, 235), (226, 210, 255), (160, 190, 255), (120, 170, 255)])
    rng = np.random.default_rng(42)
    pts = [(512 + rng.normal(0, 160), 256 + rng.normal(0, 60)) for _ in range(40)]
    stars = sparkle_stars(w, h, pts, rng, 3)
    alpha = np.clip(density * 0.85 + stars * 0.9, 0, 1)
    color = mix(color, np.array([255, 255, 255.0]), stars)
    save("Galaxy", color, alpha, sheet)


# Floating islands and rocks ------------------------------------------------

GRASS = [(84, 128, 56), (118, 166, 66), (156, 196, 82)]
ROCK = [(92, 88, 96), (132, 126, 128), (170, 162, 156)]


def rock_body(xs, ys, cx, top, half, depth, seed):
    """A floating rock: flat top, tapering jagged underside."""
    edge = noise(xs.shape[1], xs.shape[0], 30, seed, 3) - 0.5
    t = np.clip((ys - top) / depth, 0, 1)
    width = half * (1 - t ** 1.4) + edge * 26 * (1 - t * 0.5)
    shape = (np.abs(xs - cx + edge * 18 * t) < width) & (ys >= top) & (ys < top + depth)
    return shape


def tree(rgb, alpha, xs, ys, x, ground, size, rng):
    trunk = (np.abs(xs - x - np.sin((ys - ground) / 14) * 2) < size * 0.07) & (ys < ground) & (ys > ground - size * 0.9)
    rgb[:] = mix(rgb, np.array([96, 70, 48.0]), trunk)
    alpha[:] = np.maximum(alpha, trunk)
    # A flat-topped canopy of overlapping puffs, like a wind-shaped pine.
    canopy = np.zeros_like(alpha)
    shade = np.zeros_like(alpha)
    for _ in range(7):
        px = x + rng.normal(0, size * 0.28)
        py = ground - size * rng.uniform(0.85, 1.15)
        pr = size * rng.uniform(0.2, 0.32)
        inside, n, _ = disc(xs, ys * 1.0, px, py, pr)
        inside &= ys < py + pr * 0.55
        canopy = np.maximum(canopy, inside)
        shade = np.where(inside, steps(lambert(n), 3, 0.4), shade)
    leaf = ramp(shade, [(52, 92, 50), (92, 140, 60), (150, 190, 80)])
    leaf = ink(leaf, canopy, 2, 0.6)
    rgb[:] = mix(rgb, leaf, canopy)
    alpha[:] = np.maximum(alpha, canopy)


def paint_island(sheet, name, seed, tiers):
    w, h = 1024, 768
    xs, ys = grid(w, h)
    rng = np.random.default_rng(seed)
    rgb = np.zeros((h, w, 3))
    alpha = np.zeros((h, w))
    cx = 512
    top = 300
    half = 330
    # Lowest tier first; each higher tier is smaller and set back.
    ledges = []
    for k in range(tiers):
        lt = top - k * 95
        lh = half * (1 - k * 0.32)
        lx = cx + rng.uniform(-60, 60) * k
        shape = rock_body(xs, ys, lx, lt, lh, 420 - k * 150, seed + k)
        n = normals_from(shape.astype(float), 12)
        strata = (np.sin(ys / 13 + noise(w, h, 60, seed + 10 + k) * 6) > 0.6)
        stone = ramp(noise(w, h, 40, seed + 20 + k), ROCK)
        stone = mix(stone * 0.5, stone, steps(lambert(n), 4, 0.4))
        stone = mix(stone, stone * 0.8, strata * 0.5)
        # The underside fades into the sky's blue.
        stone = mix(stone, np.array([120, 160, 220.0]), np.clip((ys - lt) / 420, 0, 1) * 0.35)
        # A mossy grass cap with drips down the cliff.
        drip = noise(w, h, 18, seed + 30 + k, 2) * 50
        cap = shape & (ys < lt + 18 + drip * (noise(w, h, 50, seed + 40 + k) > 0.5))
        grass = ramp(noise(w, h, 20, seed + 50 + k), GRASS)
        grass = mix(grass * 0.7, grass, steps(lambert(n), 3, 0.4))
        layer = mix(stone, grass, cap)
        layer = ink(layer, shape.astype(float), 2, 0.55)
        rgb = mix(rgb, layer, shape)
        alpha = np.maximum(alpha, shape)
        ledges.append((lx, lt, lh))
    # Vines hanging off the lowest rim.
    for _ in range(9):
        vx = cx + rng.uniform(-half * 0.9, half * 0.9)
        length = rng.uniform(60, 200)
        vine = (np.abs(xs - vx - np.sin(ys / 25) * 4) < 2.5) & (ys > top + 10) & (ys < top + length)
        rgb = mix(rgb, np.array([70, 112, 48.0]), vine)
        alpha = np.maximum(alpha, vine)
    # Trees on each tier.
    for lx, lt, lh in ledges:
        for _ in range(rng.integers(2, 5)):
            tree(rgb, alpha, xs, ys, lx + rng.uniform(-lh * 0.75, lh * 0.75), lt + 6, rng.uniform(60, 110), rng)
    save(name, rgb, alpha, sheet)


def paint_rock(sheet, name, seed):
    w = h = 256
    xs, ys = grid(w, h)
    shape = rock_body(xs, ys, 128, 70, 100, 170, seed)
    n = normals_from(shape.astype(float), 8)
    stone = ramp(noise(w, h, 24, seed), ROCK)
    stone = mix(stone * 0.5, stone, steps(lambert(n), 4, 0.4))
    cap = shape & (ys < 70 + 10 + noise(w, h, 10, seed + 1, 2) * 20)
    grass = ramp(noise(w, h, 12, seed + 2), GRASS)
    rgb = mix(stone, grass, cap)
    rgb = mix(rgb, np.array([120, 160, 220.0]), np.clip((ys - 70) / 170, 0, 1) * 0.3)
    rgb = ink(rgb, shape.astype(float), 2, 0.55)
    save(name, rgb, shape.astype(float), sheet)


# Horizon structures ---------------------------------------------------------

HAZE = np.array([150, 186, 236], float)


def paint_tower(sheet):
    """A far-off scrap windmill: a lattice tower on a rock. Hazy blue."""
    w, h = 512, 1024
    xs, ys = grid(w, h)
    mask = np.zeros((h, w), bool)
    # Two legs tapering up to the hub at the top, with cross braces.
    for side in (-1, 1):
        x0, x1 = 256 + side * 150, 256 + side * 24
        t = np.clip((ys - 120) / (900 - 120), 0, 1)
        legx = x1 + (x0 - x1) * t
        mask |= (np.abs(xs - legx) < 10) & (ys > 120) & (ys < 900)
    for k in range(9):
        y0 = 180 + k * 80
        t0, t1 = (y0 - 120) / 780, (y0 + 80 - 120) / 780
        a = (256 - 24 - 126 * t0, y0)
        b = (256 + 24 + 126 * t1, y0 + 80)
        for p, q in ((a, b), ((512 - a[0], a[1]), (512 - b[0], b[1]))):
            vx, vy = q[0] - p[0], q[1] - p[1]
            L = math.hypot(vx, vy)
            along = ((xs - p[0]) * vx + (ys - p[1]) * vy) / L
            across = np.abs((xs - p[0]) * vy - (ys - p[1]) * vx) / L
            mask |= (along > 0) & (along < L) & (across < 4)
    hub = disc(xs, ys, 256, 120, 30)[0]
    mask |= hub
    base = rock_body(xs, ys, 256, 880, 210, 140, 61)
    mask |= base
    n = normals_from(mask.astype(float), 5)
    metal = mix(np.array([110, 96, 100.0]), np.array([176, 150, 140.0]), steps(lambert(n), 3, 0.4))
    rgb = mix(metal, HAZE, 0.5)
    rgb = ink(rgb, mask.astype(float), 2, 0.75)
    save("Tower", rgb, mask.astype(float), sheet)


def paint_rotor(sheet):
    w = h = 512
    xs, ys = grid(w, h)
    dx, dy = xs - 256, ys - 256
    rad = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    mask = rad < 34
    for k in range(4):
        a = k * math.pi / 2
        along = dx * math.cos(a) + dy * math.sin(a)
        across = -dx * math.sin(a) + dy * math.cos(a)
        width = 18 + along * 0.1
        mask |= (along > 20) & (along < 240) & (np.abs(across - along * 0.08) < width)
    n = normals_from(mask.astype(float), 6)
    metal = mix(np.array([120, 100, 96.0]), np.array([190, 160, 140.0]), steps(lambert(n), 3, 0.4))
    rgb = mix(metal, HAZE, 0.45)
    rgb = ink(rgb, mask.astype(float), 2, 0.75)
    save("Rotor", rgb, mask.astype(float), sheet)


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
    paint_planet(sheet)
    paint_ring_moon(sheet)
    paint_moon(sheet, "RedMoon", [(196, 74, 40), (226, 112, 56), (240, 150, 84)], 51, 0.78)
    paint_moon(sheet, "PaleMoon", [(214, 222, 236), (236, 240, 248), (200, 210, 230)], 53, 0.88)
    paint_cog(sheet)
    paint_galaxy(sheet)
    for k, tiers in enumerate((3, 2, 3), start=1):
        paint_island(sheet, f"Island{k}", 70 + k * 13, tiers)
    for k in range(1, 4):
        paint_rock(sheet, f"Rock{k}", 90 + k * 7)
    paint_tower(sheet)
    paint_rotor(sheet)
    if "--sheet" in args:
        out = args[args.index("--sheet") + 1]
        cell = 300
        cols = 6
        rows = (len(sheet) + cols - 1) // cols
        board = Image.new("RGBA", (cell * cols, cell * rows), (90, 166, 255, 255))
        for i, (_, image) in enumerate(sheet):
            thumb = image.copy()
            thumb.thumbnail((cell, cell))
            board.alpha_composite(thumb, ((i % cols) * cell, (i // cols) * cell))
        board.convert("RGB").save(out)


if __name__ == "__main__":
    main()
