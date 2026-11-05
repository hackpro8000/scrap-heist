"""Synthesises Scrap Heist's sound effects as WAVs in art/sounds/out.

    python3 art/sounds/synth.py

Every sound is made from sines, noise and envelopes, so there are no
licences to track. scripts/upload-sounds.sh uploads them.
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, decay=None, seconds=None):
    """Quick attack, exponential decay (decay = seconds to fall to ~4%)."""
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    d = np.exp(-x / (decay / 3)) if decay else 1
    return a * d


def tone(freq, seconds, decay=None, shape="sine", attack=0.005):
    x = t(seconds)
    if callable(freq):
        phase = 2 * np.pi * np.cumsum(freq(x)) / RATE
    else:
        phase = 2 * np.pi * freq * x
    wave_ = np.sin(phase)
    if shape == "square":
        wave_ = np.tanh(wave_ * 4)
    elif shape == "tri":
        wave_ = 2 / np.pi * np.arcsin(np.sin(phase))
    return wave_ * env(len(x), attack, decay or seconds)


def noise(seconds, decay=None, colour="white", attack=0.002):
    n = int(RATE * seconds)
    w = rng.standard_normal(n)
    if colour == "brown":
        w = np.cumsum(w)
        w -= np.convolve(w, np.ones(400) / 400, "same")
        w /= np.abs(w).max() + 1e-9
    return w * env(n, attack, decay or seconds)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, s in enumerate(x):
        acc = (1 - a) * s + a * acc
        y[i] = acc
    return y


def sweep_band(x, f0, f1):
    """Crude moving band-pass: lowpass with a sweeping cutoff minus a slower one."""
    n = len(x)
    cut = np.linspace(f0, f1, n)
    y = np.zeros(n)
    lo = np.zeros(n)
    acc = acc2 = 0.0
    for i in range(n):
        a = np.exp(-2 * np.pi * cut[i] / RATE)
        acc = (1 - a) * x[i] + a * acc
        b = np.exp(-2 * np.pi * cut[i] * 0.3 / RATE)
        acc2 = (1 - b) * x[i] + b * acc2
        y[i] = acc - acc2
    return y


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(seconds, x):
    return np.concatenate([np.zeros(int(RATE * seconds)), x])


def bell(freq, seconds, decay):
    return mix(tone(freq, seconds, decay), 0.4 * tone(freq * 2.76, seconds, decay * 0.5), 0.2 * tone(freq * 5.4, seconds, decay * 0.3))


def note(n):
    return 440 * 2 ** ((n - 69) / 12)


def save(name, x, gain=0.9):
    x = x / (np.abs(x).max() + 1e-9) * gain
    fade = min(len(x), int(RATE * 0.01))
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((x * 32767).astype("<i2").tobytes())


SOUNDS = {}


def sound(fn):
    SOUNDS[fn.__name__] = fn
    return fn


@sound
def Swing():
    n = noise(0.28, attack=0.08)
    shaped = sweep_band(n, 600, 2600) * np.sin(np.linspace(0, np.pi, len(n))) ** 2
    return shaped


@sound
def Hit():
    body = tone(lambda x: 140 * np.exp(-x * 9) + 50, 0.22, 0.18)
    crack = lowpass(noise(0.06, 0.05), 3000)
    return mix(body, 0.7 * crack)


@sound
def Block():
    partials = [620, 1340, 2210, 3170]
    ring = mix(*[tone(f, 0.4, 0.25 / (i + 1)) / (i + 1) for i, f in enumerate(partials)])
    return mix(ring, 0.6 * noise(0.02, 0.02))


@sound
def Parry():
    return mix(bell(1760, 0.7, 0.6), 0.6 * at(0.03, bell(2640, 0.6, 0.5)), 0.3 * noise(0.015, 0.015))


@sound
def GuardBreak():
    crunch = lowpass(noise(0.4, 0.3), 1800)
    drop = tone(lambda x: 320 * np.exp(-x * 5) + 70, 0.4, 0.35, "square")
    return mix(crunch, 0.6 * drop, 0.5 * Block()[: int(RATE * 0.2)])


@sound
def Zap():
    x = t(0.32)
    freq = 1400 * np.exp(-x * 7) + 180
    carrier = np.sin(2 * np.pi * np.cumsum(freq) / RATE + 3 * np.sin(2 * np.pi * 90 * x))
    return mix(np.tanh(carrier * 3) * env(len(x), 0.003, 0.3), 0.3 * noise(0.32, 0.25))


@sound
def Purchase():
    return mix(bell(note(84), 0.5, 0.35), at(0.08, bell(note(88), 0.6, 0.45)), 0.3 * at(0.08, noise(0.05, 0.05)))


@sound
def Collect():
    return mix(*[at(i * 0.06, tone(note(76 + s), 0.18, 0.15, "tri")) for i, s in enumerate([0, 4, 7])])


@sound
def RaidAlert():
    x = t(1.3)
    freq = np.where((x * 3.2) % 1 < 0.5, 720, 960)
    s = np.tanh(3 * np.sin(2 * np.pi * np.cumsum(freq) / RATE))
    return s * np.clip(x / 0.02, 0, 1) * np.clip((1.3 - x) / 0.1, 0, 1)


@sound
def Grab():
    return mix(tone(lambda x: 300 + 900 * x / 0.12, 0.12, 0.1, "tri"), 0.3 * noise(0.03, 0.03))


@sound
def Bank():
    thunk = tone(lambda x: 110 * np.exp(-x * 6) + 60, 0.25, 0.2)
    return mix(thunk, 0.8 * at(0.1, bell(note(81), 0.6, 0.5)), 0.6 * at(0.18, bell(note(88), 0.6, 0.5)))


@sound
def TradeComplete():
    return mix(*[at(i * 0.09, bell(note(72 + s), 0.7, 0.55)) for i, s in enumerate([0, 4, 7, 12])])


@sound
def StormWarning():
    rumble = lowpass(noise(1.6, 1.6, "brown", attack=0.3), 300)
    fall = tone(lambda x: 520 - 220 * x / 1.6, 1.6, 1.6, "tri", attack=0.05)
    return mix(rumble, 0.4 * fall)


@sound
def StormStart():
    crack = lowpass(noise(0.3, 0.25), 5000)
    roll = lowpass(noise(2.2, 2.0, "brown", attack=0.05), 250)
    return mix(0.7 * crack, at(0.05, roll))


@sound
def StormEnd():
    return mix(*[at(i * 0.12, bell(note(79 + s), 0.9, 0.7)) for i, s in enumerate([0, 5, 9, 12])])


@sound
def LootRare():
    sparkle = mix(*[at(i * 0.05, bell(note(88 + s), 0.5, 0.4) * 0.7) for i, s in enumerate([0, 3, 7, 10, 12, 15, 19])])
    return mix(sparkle, 0.2 * noise(0.6, 0.5, attack=0.1))


@sound
def UiClick():
    return mix(tone(1800, 0.03, 0.025), 0.4 * noise(0.01, 0.01))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        save(name, fn())
        print(name)
