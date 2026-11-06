"""Pacing sim for the belt-and-bundle economy: one keen player, prints the
time to each rebirth rank. Deterministic (seeded)."""
import random, math, sys

RARITIES = ["Scrap", "Salvaged", "Refurbished", "Factory", "Precision", "Prototype", "Secret"]
# Scrap/s at 1 star, low..high across the junkrots of each rarity.
BASE = {"Scrap": (1, 4), "Salvaged": (12, 30), "Refurbished": (150, 320), "Factory": (2000, 4500),
	"Precision": (30000, 60000), "Prototype": (400000, 800000), "Secret": (5e6, 1e7)}
# Capsule price = PRICE_SECONDS of the junkrot's own 1-star output.
PRICE_SECONDS = {"Scrap": 25, "Salvaged": 60, "Refurbished": 120, "Factory": 240, "Precision": 480, "Prototype": 960,
	"Secret": 1920}
# Belt odds (percent) per sky tier.
ODDS = {
	1: {"Scrap": 72, "Salvaged": 22, "Refurbished": 5.2, "Factory": 0.75, "Precision": 0.05, "Prototype": 0, "Secret": 0.002},
	2: {"Scrap": 30, "Salvaged": 42, "Refurbished": 22, "Factory": 5.4, "Precision": 0.6, "Prototype": 0.03, "Secret": 0.002},
	3: {"Scrap": 8, "Salvaged": 30, "Refurbished": 38, "Factory": 20, "Precision": 4, "Prototype": 0.1, "Secret": 0.002},
}
LUCK_PER_RANK = 0.04  # rarer weights x(1 + this * rank), Salvaged and up
SPAWN_SECONDS = 10
CATCH = 0.4  # share of spawns this player gets (others compete)
# Hatch time while whacking with the spanner (left alone, a capsule takes 2.5x).
BUILD_SECONDS = {"Scrap": 5, "Salvaged": 10, "Refurbished": 20, "Factory": 40, "Precision": 75, "Prototype": 120,
	"Secret": 180}
WALK_SECONDS = 25  # carry home and back
# Parts: star n -> n+1 costs STAR_PARTS[n-1] * RARITY_PART_FACTOR**rarity.
STAR_PARTS = [10, 30, 90, 270]
RARITY_PART_FACTOR = 3
# Parts income: per storm round (every 395 s), plus the junk mound trickle.
ROUND_SECONDS = 395
PARTS_PER_ROUND = lambda tier, rank: 25 * tier * (1 + 0.15 * rank)
MOUND_PARTS_PER_MIN = 1
PADS_AT = lambda rank: min(20, 6 + rank)  # +1 pad per rebirth, 20 at rank 14
TIER_AT = lambda rank: 3 if rank >= 13 else 2 if rank >= 6 else 1
MULT = lambda rank: 1 + 0.5 * rank
# Rebirth ladder: (scrap cost, rarity each of the 3 named machines needs).
LADDER = []

def ladder():
	need = ["Scrap", "Salvaged", "Salvaged", "Salvaged", "Refurbished", "Refurbished", "Refurbished", "Refurbished",
		"Refurbished", "Factory", "Factory", "Factory", "Factory", "Factory", "Factory", "Precision", "Precision",
		"Precision", "Precision", "Precision"]
	costs = [2.5e3, 4e4, 2.5e5, 1.2e6, 6e6, 3e7, 1.6e8, 7e8, 2.6e9, 8e9, 2.4e10, 6.5e10, 1.6e11, 4e11, 1e12,
		2.5e12, 5.5e12, 1.2e13, 2.6e13, 5.5e13]
	return list(zip(costs, need))

TARGET = [0.5, 0.65, 0.7, 0.8, 0.9, 1.5, 1.7, 1.9, 2.1, 2.3, 2.5, 2.6, 2.8, 3.0, 3.2, 4.0, 4.2, 4.4, 4.6, 4.8]

def run(seed=1, verbose=True, fit=False):
	rng = random.Random(seed)
	lad = ladder()
	t, scrap, parts, rank = 0.0, 50.0, 0.0, 0
	machines = []  # dicts: rarity, base, stars
	step = 5.0
	next_spawn, next_round = 0.0, ROUND_SECONDS
	busy_until = 0.0
	marks = []
	def rate():
		return sum(m["base"] * 2 ** (m["stars"] - 1) for m in machines) * MULT(rank)
	while rank < len(lad) and t < 400 * 3600:
		# Belt.
		while t >= next_spawn:
			next_spawn += SPAWN_SECONDS
			if t >= busy_until and rng.random() < CATCH:
				odds = dict(ODDS[TIER_AT(rank)])
				for r in RARITIES[1:]:
					odds[r] *= 1 + LUCK_PER_RANK * rank
				r = rng.choices(RARITIES, weights=[odds[x] for x in RARITIES])[0]
				lo, hi = BASE[r]
				base = lo + (hi - lo) * rng.random()
				price = base * PRICE_SECONDS[r]
				worst = min(machines, key=lambda m: m["base"] * 2 ** (m["stars"] - 1)) if machines else None
				full = len(machines) >= PADS_AT(rank)
				better = not full or base > worst["base"] * 2 ** (worst["stars"] - 1)
				if scrap >= price and better:
					scrap -= price
					if full:
						machines.remove(worst)
					machines.append({"rarity": r, "base": base, "stars": 1})
					busy_until = t + BUILD_SECONDS[r] + WALK_SECONDS
		# Parts.
		if t >= next_round:
			next_round += ROUND_SECONDS
			parts += PARTS_PER_ROUND(TIER_AT(rank), rank)
		parts += MOUND_PARTS_PER_MIN / 60 * step
		# Spend parts on the best value star.
		while True:
			best, bestgain = None, 0
			for m in machines:
				if m["stars"] >= 5:
					continue
				cost = STAR_PARTS[m["stars"] - 1] * RARITY_PART_FACTOR ** RARITIES.index(m["rarity"])
				if cost <= parts:
					gain = m["base"] * 2 ** (m["stars"] - 1) / cost
					if gain > bestgain:
						best, bestgain = m, gain
			if not best:
				break
			parts -= STAR_PARTS[best["stars"] - 1] * RARITY_PART_FACTOR ** RARITIES.index(best["rarity"])
			best["stars"] += 1
		scrap += rate() * step
		# Rebirth.
		cost, need = lad[rank]
		have = sum(1 for m in machines if RARITIES.index(m["rarity"]) >= RARITIES.index(need))
		since = t / 3600 - (marks[-1][1] if marks else 0)
		if fit and since >= TARGET[rank] and have >= 3:
			lad[rank] = (scrap, need)
		if (scrap >= lad[rank][0] and have >= 3) and (not fit or since >= TARGET[rank]):
			rank += 1
			marks.append((rank, t / 3600, rate()))
			scrap = 0
		t += step
	if verbose:
		prev = 0
		for r, h, inc in marks:
			print(f"rank {r:2d} at {h:6.2f} h  (+{h - prev:5.2f} h)  income {inc:,.0f}/s")
			prev = h
	if fit:
		return [c for c, _ in lad]
	return marks[-1][1] if len(marks) == len(lad) else None

def nice(x):
	e = 10 ** math.floor(math.log10(x))
	return round(x / e * 4) / 4 * e

if __name__ == "__main__":
	fits = [run(s, False, True) for s in range(1, 4)]
	costs = [nice(sorted(f[i] for f in fits)[1]) for i in range(20)]
	print("fitted costs:", ", ".join(f"{c:.3g}" for c in costs))
	need = [n for _, n in ladder()]
	ladder = lambda: list(zip(costs, need))
	run(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
	ends = [run(s, False) for s in range(2, 6)]
	print("rank 20 over 4 seeds:", [round(e, 1) if e else None for e in ends])
