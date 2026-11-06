# Gameplay content: first version (48 hours of play)

Everything a keen player does in their first ~48 hours of active play,
with the numbers to build it from. It follows the "Steal a ___" loop that
leads Roblox right now: grab a mystery capsule off the shared belt, carry
it home, hatch it in your yard with the Big Spanner, and out pops a
**junkrot** (a junk brainrot) that earns scrap. Add upgrades with parts,
rebirth, and steal other players' capsules on the way.

Theme and art stay Scrap Heist's own: chunky hand-painted junk on sky
islands. The cast is our own. No names, looks or sounds are taken from
existing meme characters; check every new name against the popular
brainrot casts before it ships.

The numbers come from `tools/pacing/pacing.py`, a seeded sim of one keen
player. Running it gives rank 20 at **35-52 hours** across seeds; the
spread comes from the rare Prototype and Secret pulls. Re-run it whenever
a number here changes.

```bash
python3 tools/pacing/pacing.py
```

## Session arc

| Hours | What the player is doing | New things |
|---|---|---|
| 0-1 | Whacks the junk mound, grabs Scrap capsules, fills 6 pads, first rebirth | Belt, carrying, hatching, crate, raids on them, build mode |
| 1-6 | Salvaged and first Refurbished junkrots, upgrades with gears and coils, ranks 2-6 | Upgrades, parts, Belt Alert, Limited Edition chance, second build bay |
| 6-24 | Gantry Isle belt (tier 2), Refurbished to Factory, ranks 7-13 | Tier 2 zone, storm haul priority, auto-collect |
| 24-48 | Crown Heap belt (tier 3), Factory to Precision, ranks 14-20 | Tier 3 zone, all 20 pads, Prototype hunting, logbook completion, the Scrap Baron title |
| 48+ | Chasing Prototypes, Secrets and Limited Editions | |

## Rarity ladder: junk to manufactured

The higher the tier, the better made the item: the player starts digging
through trash and works up to things nobody should have thrown away. A
junkrot and its capsule both show their tier.

| Tier | Rarity | Capsule | Junkrot look |
|---|---|---|---|
| 1 | **Scrap** | Paint can or bin bag tied with string | Taped together, mismatched parts, one eye hanging off |
| 2 | **Salvaged** | Dented lunchbox | Patched and bolted, but working |
| 3 | **Refurbished** | Toolbox with a fresh coat of paint | Cleaned up, new paint over old dents, a few shiny parts |
| 4 | **Factory** | Cardboard shipping box: tape, stencils, "FRAGILE" | Mass-made: clean plastic, logos, stickers still on |
| 5 | **Precision** | Aluminium flight case with foam inserts and clasps | Brushed metal, tight panel gaps, little LEDs |
| 6 | **Prototype** | Vacuum-sealed lab pod with a glass window and a QR tag | Sleek, glowing, cables tucked away, test-unit labels |
| 7 | **Secret** | Black monolith case, no markings, faint hum | Too perfect: seamless and floating. Nobody knows who made it |

Art rules:
- **Shapes** get cleaner going up: lumpy and asymmetric at Scrap; bevels, symmetry and fine detail at Precision and above.
- **Materials:** rust and tape, then patched tin, fresh paint, plastic, brushed aluminium, and finally glass and glowing parts.
- **Labels:** a scrawled marker tag, then a printed sticker, a stencil, a serial plate, a QR code, and then nothing at all.
- **Palette:** low tiers stay in the warm junkyard browns. High tiers bring in cool whites and steel with one accent glow, so a Prototype on the belt stands out against the junk.
- You can read the rarity from across the map by the capsule's shape. The capsule never shows which junkrot is inside.

## The belt

- **Where:** a magnet crane on each zone's belt drops capsules onto a looping belt. A capsule rides one lap of **90 s**; if no one buys it, it falls into a crusher at the end.
- **Spawns:**
  - one capsule every **10 s** with 3+ players in the zone;
  - every **15 s** with 2;
  - every **20 s** solo.
  - That pushes players to busy servers. The sim assumes a player gets 40% of the spawns.
- **Buying:** hold a prompt on the capsule (cost in scrap). The buyer carries it, slowed and unable to attack. If knocked down, the capsule drops and anyone can pick it up. That is the heist.
- **Server seed:** each server rolls its own sequence of capsules.
- **Odds** (percent by rarity), per zone:

| Zone | Unlocked at | Scrap | Salvaged | Refurbished | Factory | Precision | Prototype | Secret |
|---|---|---|---|---|---|---|---|---|
| Salvage hub (tier 1) | start | 72 | 22 | 5.2 | 0.75 | 0.05 | - | 0.002 |
| Gantry Isle (tier 2) | rank 6 | 30 | 42 | 22 | 5.4 | 0.6 | 0.03 | 0.002 |
| Crown Heap (tier 3) | rank 13 | 8 | 30 | 38 | 20 | 4 | 0.1 | 0.002 |

- **Secret** (1 in 50,000 anywhere) is a server-wide event: an announcement, the crane's lights go dark, and everyone runs for the belt.
- **Rebirth luck:** every rank multiplies the Salvaged-and-up weights by 1 + 0.04 × rank.
- **Price:** a capsule costs a fixed number of seconds of its junkrot's 1-star output: Scrap 25 s, Salvaged 60 s, Refurbished 120 s, Factory 240 s, Precision 480 s, Prototype 960 s, Secret 1,920 s.

### Special capsules

These are variants of any tier's capsule:

| Special | Look | Effect |
|---|---|---|
| **Storm** | Crackles with lightning | During storms only. Rolls one tier higher |
| **Limited Edition** | Gold-plated serial badge on the capsule | About 1 in 500. The junkrot comes out Limited Edition (×3, logged forever) |
| **Opened box** | Lid half open | You can see which junkrot is inside. Costs 1.5× |
| **Ticking** | Beeps and flashes | Hatches in half the time, but everyone can hear where it is |

Owners can also buy **booby traps** for their build bays from rank 9 (see the rebirth unlocks): a capsule stolen from a trapped bay shocks the thief and drops.

## Hatching

- **Where:** drop the capsule in your yard's build bay, or straight onto an empty pad.
- **Hatch time** while you whack it with the Big Spanner: Scrap 5 s, Salvaged 10 s, Refurbished 20 s, Factory 40 s, Precision 75 s, Prototype 2 min, Secret 3 min. Left alone it takes 2.5× as long.
- **Until it hatches, raiders can grab it from your bay.** Rarer capsules take longer, so they stay at risk longer.
- **Crits** (WeaponConfig crit chance) fill the bar three times faster, with a "CLANK!" spark burst.
- **The reveal:** the capsule bursts in its own way (the paint can's lid pops off, the shipping box tears open, the lab pod hisses and fogs) and the junkrot does a short intro pose with its name in big letters.
- **Full yard:** if every pad is full, the new junkrot replaces one you pick, and the old one is scrapped for 25% of its price.

## Junkrots (63)

Junkrots are everyday junk objects with faces, little legs and a goofy idle loop. Each one earns in its own silly way: the toaster pops bolts into the crate, the moped does wheelies that fling scrap, the radio dances and coins rattle out. There are three families, and each pad is typed. A junkrot on a pad of its own family earns **+10%**.

- **Kitchen:** pans, kettles, toasters, fridges, appliances.
- **Garage:** tyres, tools, oil cans, mopeds, mowers.
- **Gadget:** remotes, radios, phones, consoles, drones.

Names are sing-song mock-Italian in the brainrot style, made up for this game. The core cast has 50: each tier from Scrap to Precision has nine junkrots, three per family. The rate is scrap per second at 1 star.

| Rarity | Kitchen | Garage | Gadget |
|---|---|---|---|
| **Scrap** (1-4/s) | Canetto Rustini (tin can) 1, Spoonzo Bentolo (bent spoon) 1.4, Kettlina Dentata (dented kettle) 1.8 | Tyro Flattino (flat tyre) 2.1, Boltolo Lonelo (one lost bolt) 2.5, Hubcappa Wobbla (hubcap) 2.8 | Remotino Muto (dead remote) 3.2, Cablo Tanglino (tangled cable) 3.6, Bulbo Fulminato (blown bulb) 4 |
| **Salvaged** (12-30/s) | Crumbo Poppalot (toaster) 12, Pannetto Patchato (patched pan) 14, Blendro Cigolante (squeaky blender) 16 | Jackolo Crickato (car jack) 18, Oilcanna Gluglu (oil can) 21, Mufflero Tossetto (coughing exhaust) 23 | Radiolo Fruscio (crackly radio) 25, Fanetto Wobblino (desk fan) 28, Clocko Tictacco (alarm clock) 30 |
| **Refurbished** (150-320/s) | Frostbox Gelatone (fridge) 150, Microndo Bippetto (microwave) 170, Mixerella Vroom (stand mixer) 190 | Mopa Mopetta (moped) 210, Drillo Trapanino (power drill) 235, Grindella Scintilla (angle grinder) 255 | Telefono Ringaling (rotary phone) 275, Typewritto Clackini (typewriter) 300, Camerino Flashetto (camera) 320 |
| **Factory** (2k-4.5k/s) | Grindo Beanbasher (coffee machine) 2,000, Airfryo Croccante (air fryer) 2,300, Dishwashino Splashetto (dishwasher) 2,600 | Lawnmowo Ruggito (lawnmower) 2,900, Leafblowa Whooshini (leaf blower) 3,250, Pressurwasho Sprizzo (pressure washer) 3,550 | Consolo Joypaddino (game console) 3,850, Speakerone Boomba (party speaker) 4,200, Robovacco Girotondo (robot vacuum) 4,500 |
| **Precision** (30k-60k/s) | Chefbot Precisio (kitchen robot) 30k, Sousvide Silvano (sous-vide wand) 34k, Knifeblock Slicetta (knife block) 38k | Torquo Wrenchelli (torque wrench) 41k, Laserlevel Lineo (laser level) 45k, Weldetta Sparkalot (welding rig) 49k | Dronetto Buzzatti (drone) 52k, Tickworth Pocketti (pocket watch) 56k, Headphono Bassimo (headphones) 60k |
| **Prototype** (400k-800k/s) | Snackomatic Prototipo (food replicator) 400k | Hoverbikko Zoomzoom (hoverbike) 600k | Holofono Shimmerra (hologram phone) 800k |
| **Secret** (5M-10M/s) | | The Monolito (humming black slab) 5M | Unit Zero (a floating chrome sphere that hums) 10M |

The family sets the silhouette, and the tier sets the build quality and paint.

### Remix junkrots (13)

These are scrap-built versions of the brainrots trending right now. Each one
keeps the **same animal combination** as the original it riffs on, so
players recognise it at once, but it is rebuilt from junk: tin-sheet skin,
rivets, bolt eyes, pipe limbs, foil and tyre rubber. The rules that keep it
our own:
- **Names:** the rhythm echoes the original, but never the same words.
- **Art:** drawn from scratch in our style and palette. Never traced or copied from any existing render, and never the original's colours, pose or face.
- **Sound:** our own clanks and honks, never the original voice lines or songs.
- **Legal:** same-concept characters carry more risk than original ones, and some brainrot names have trademark filings. Get each one checked before it ships, and keep the cast swappable so one can be renamed or reskinned quickly if a claim comes in.

| Junkrot | Riffs on (same combination) | Tier | Family | Rate/s | Scrap version |
|---|---|---|---|---|---|
| **Clank Clank Clank Scrapur** | Tung Tung Tung Sahur: a log figure with a bat | Factory | Garage | 3,000 | A rusty pipe-section figure with a rebar bat. It bangs the bat on its own side: clank, clank, clank. Every few minutes it clanks the whole yard awake, and nearby junkrots earn +5% for 10 s |
| **Drippi Droppi** | Trippi Troppi: a shrimp with a cat's head | Salvaged | Kitchen | 20 | A copper-tube shrimp with a tin cat head and wire whiskers that drips oil |
| **Ding Ding Ding Dongo** | Udin Din Din Dun | Salvaged | Garage | 26 | A snail with a bike-bell shell, for now. The original's look still needs confirming, then this one gets matched to it |
| **Vrr Vrr Patatrim** | Brr Brr Patapim: a tree-trunk monkey with big feet | Refurbished | Garage | 200 | A rusted-pipe trunk with wire branches, a tin monkey face and huge boot feet |
| **Chimneyzini Spannerini** | Chimpanzini Bananini: a chimp inside a banana | Refurbished | Kitchen | 240 | A tin chimp peeking out of a yellow-painted stove pipe peeled like a banana |
| **Rusteli Rustela** | Lirili Larila: a cactus elephant in sandals | Refurbished | Gadget | 290 | A barrel elephant studded with rebar spikes, wearing flip-flops cut from tyre rubber |
| **Ballerina Tincuppina** | Ballerina Cappuccina: a ballerina with a cup for a head | Factory | Kitchen | 2,700 | A wire-frame ballerina with a dented tin mug for a head and a crumpled-foil tutu |
| **Trashalero Trashala** | Tralalero Tralala: a shark on three legs in sneakers | Factory | Kitchen | 3,400 | A riveted tin shark on three pipe legs in tyre-rubber sneakers |
| **Socketto Sei-Sette** | the "6-7" meme (no animal) | Factory | Garage | 4,000 | A raccoon with a socket-set belly, juggling a 6 and a 7 |
| **Gascanini Honkini** | Bombombini Gusini: a goose crossed with a jet | Precision | Garage | 36k | A chrome tin goose with gas-can jet engines; it honks |
| **Percolatto Ninjatto** | Cappuccino Assassino: a coffee cup with a ninja body and blades | Precision | Kitchen | 44k | A brushed-steel coffee cup with a ninja body, a tea-towel mask and twin spanner blades |
| **Boilerdiro Crockpotilo** | Bombardiro Crocodilo: a crocodile crossed with a bomber plane | Precision | Kitchen | 50k | A riveted crocodile with a boiler-tank belly, plane wings and propellers; it loops overhead and drops bolts into the crate |
| **La Vacuuma Saturnita** | La Vaca Saturno Saturnita: a cow-headed Saturn on legs | Prototype | Gadget | 700k | A vacuum-canister planet with its hose as the ring, a tin cow head and two legs |

The rates sit inside their tier's band, so pacing is unchanged. The rebirth ladder doesn't require any of these, so they're pure collection and hype. They roll from the same belt odds as the rest of their tier, and the belt announces a remix junkrot when one hatches.

## Upgrades and parts

- **Upgrades** are shown as **stars** from 1 to 5. Each one bolts a visible mod onto the junkrot (a bigger antenna, racing stripes, an extra arm, a chrome trim, a glowing core) and doubles its output, so 5 stars earns ×16.
- **Cost:** each step costs one kind of part, at the tinkerer stand in the hub market. Counts per tier, Scrap to Secret:

| Step | Part | Count (Scrap / Salvaged / Refurbished / Factory / Precision / Prototype / Secret) |
|---|---|---|
| 1→2 ★ | Rusty Gear | 10 / 30 / 90 / 270 / 810 / 2,430 / 7,290 |
| 2→3 ★ | Copper Coil | 30 / 90 / 270 / 810 / 2,430 / 7,290 / 21,870 |
| 3→4 ★ | Servo Motor | 90 / 270 / 810 / 2,430 / 7,290 / 21,870 / 65,610 |
| 4→5 ★ | Circuit Board | 270 / 810 / 2,430 / 7,290 / 21,870 / 65,610 / 196,830 |

- **Where parts come from:**
  - Storms rain parts as pickups: about **25 × zone tier × (1 + 0.15 × rank)** for a player who stays out the whole storm, about every 6.5 minutes.
  - The junk mound pays about 1 per minute of whacking.
  - Missions and raids pay some too.
- **Drop mix:** gears are the most common and circuit boards the rarest. Keep each part's share of drops in line with its share of what the upgrade costs ask for. The sim pools all parts together.

## Pads

- **Start:** 6 pads to place, two of each family.
- **Rebirths:** each rebirth adds one pad of the family you choose, up to **20 at rank 14**. "Pad N" in the rebirth table means one more pad to place.
- **Where they go** is up to the player (see Yard).

## Rebirth ladder ("Scrap the Yard")

Rebirthing pays the scrap cost and resets your scrap to 0. You keep your junkrots, upgrades, parts, logbook and unlocks.

- **Requirement:** three named junkrots placed in your yard, at any star level.
- **Reward:** each rank adds **+0.5×** to income, permanently, so rank 20 earns ×11.
- **Where:** the rebirth press in your yard. It's a hydraulic press that flattens your scrap pile into a medal.
- Prototypes and Secrets are never required: they're the chase.

| Rank | Scrap | Needs placed | Unlocks |
|---|---|---|---|
| 1 | 400k | Canetto Rustini, Tyro Flattino, Remotino Muto | Pad 7, junk mound level 2 |
| 2 | 5.25M | Crumbo Poppalot, Jackolo Crickato, Radiolo Fruscio | Pad 8, Belt Alert (pings when a junkrot you need spawns) |
| 3 | 15M | Pannetto Patchato, Oilcanna Gluglu, Fanetto Wobblino | Pad 9, Lucky Badge I (Limited Edition 1 in 350) |
| 4 | 62.5M | Blendro Cigolante, Mufflero Tossetto, Clocko Tictacco | Pad 10, crate size ×2 |
| 5 | 100M | Frostbox Gelatone, Mopa Mopetta, Telefono Ringaling | Pad 11, second build bay |
| 6 | 425M | Microndo Bippetto, Drillo Trapanino, Typewritto Clackini | Pad 12, **Gantry Isle** (tier 2 belt) |
| 7 | 2.25B | Mixerella Vroom, Grindella Scintilla, Camerino Flashetto | Pad 13, junk mound level 3 |
| 8 | 4.75B | Frostbox Gelatone ★3, Drillo Trapanino ★3, Typewritto Clackini ★3 | Pad 14, storm haul priority (your Belt Alert fires 5 s early) |
| 9 | 12.5B | Mixerella Vroom ★4, Mopa Mopetta ★4, Telefono Ringaling ★4 | Pad 15, crate size ×3, bay booby traps |
| 10 | 22.5B | Grindo Beanbasher, Lawnmowo Ruggito, Consolo Joypaddino | Pad 16, crate auto-collect |
| 11 | 37.5B | Airfryo Croccante, Leafblowa Whooshini, Speakerone Boomba | Pad 17, third build bay |
| 12 | 50B | Dishwashino Splashetto, Pressurwasho Sprizzo, Robovacco Girotondo | Pad 18, Lucky Badge II (1 in 250) |
| 13 | 67.5B | Grindo Beanbasher ★3, Lawnmowo Ruggito ★3, Consolo Joypaddino ★3 | Pad 19, **Crown Heap** (tier 3 belt) |
| 14 | 125B | Airfryo Croccante ★4, Pressurwasho Sprizzo ★4, Speakerone Boomba ★4 | Pad 20, capsule guard (only you can pick up your dropped capsule for 8 s) |
| 15 | 250B | Any 3 Factory ★5 | Offline cap 2 h → 6 h |
| 16 | 400B | Chefbot Precisio, Torquo Wrenchelli, Dronetto Buzzatti | Lucky Badge III (1 in 150) |
| 17 | 650B | Sousvide Silvano, Laserlevel Lineo, Tickworth Pocketti | Yard trim: brushed-steel fence |
| 18 | 950B | Knifeblock Slicetta, Weldetta Sparkalot, Headphono Bassimo | Storm haul doubles in Crown Heap for you |
| 19 | 1.25T | Any 3 Precision ★3 | Yard trim: lab glow |
| 20 | 1.5T | Any Limited Edition Precision + 2 Precision ★5 | **Scrap Baron** title, gold yard trim, end of first-version rank goals |

Times per rank in the sim:
- ranks 1-5: about 0.5-1 hour each;
- ranks 6-15: about 1.7-3.7 hours each;
- ranks 16-20: about 5-7 hours each.

Rank 20 lands at about 35-52 hours, depending on Prototype luck. The ★ requirements and the Limited Edition Precision at ranks 8-9, 13-15 and 19-20 are tighter than the sim's "any junkrot of that tier" check, so re-tune the sim once they're modelled.

## Zones

- **Salvage hub (tier 1).** The centre of the server map, with the shop, the tinkerer and spawn.
- **Gantry Isle (tier 2, rank 6).** A higher island reached by a cargo lift from the hub. It has its own crane and belt, shared by everyone on the server who has rank 6. The capsules are richer and the walk home is longer, so there's more heist risk.
- **Crown Heap (tier 3, rank 13).** The top island, a junk mountain with a giant magnet crane, reached by a zipline from Gantry Isle. Prototypes mostly come from here.
- **Your yard stays where it is.** Capsules from higher zones are carried down the lift and zipline, which become the ambush routes.

## Yard

The yard has no fixed layout. A player starts with an abandoned lot and lays it out in **build mode**, placing everything where they like. Raiders walk in through the gate, and the blackout opens every gate, so where the crate and the build bays stand matters.

### The lot

- **Plot:** 96 x 112 studs inside a fixed fence, with the gate in the middle of the side facing the Line. The fence, the gate and the plot marker never move.
- **Land:** the plot is 12 parcels, 3 across and 4 deep, each 32 x 28 studs. The front row is clear from the start. The other 9 are buried under rubble heaps, weeds and old tyres, scattered differently for every player. They can be walked through but not built on.
- **Clearing:** ranks 1, 2, 3, 4, 6, 8, 10, 12 and 14 each clear one parcel of the player's choice, next to land they already have.
- **Doorstep:** the 12 x 8 studs just inside the gate always stay clear.

### Build mode

- **Grid:** things snap to 2 studs and turn in quarter turns.
- **What can be placed:**
  - pads, 10 x 10 (a junkrot stands on each; the pad's family gives its +10%)
  - build bays, 10 x 10: one at the start, a second at rank 5, a third at rank 11
  - the crate (bigger at ranks 4 and 9, auto-collecting from rank 10)
  - the junk mound (levels 1-3)
  - the rebirth press, 16 x 8
  - the logbook board and the medal rack
  - path pavers, free and unlimited
  - inner fence panels, 12 long: 4 at the start and 2 more per rank
  - decorations as they unlock: string lights (rank 3), a tinkering shack (rank 7), signs and trims
- **Rules,** checked on the server:
  - everything stands on cleared land, and nothing overlaps
  - every pad, bay, crate and press can be walked to from the gate along a way at least 4 studs wide, a player's width, so nothing can be walled in
  - the doorstep stays clear
- **When:** any time, except during a storm or while a raider is inside the yard. Moving a junkrot keeps its upgrades.
- **Starter layout:** a new player's first 6 pads, bay, crate, mound and press are placed for them, so the game is playable before they ever open build mode.
- **Controls:** pick a thing up, move a ghost of it (green where it fits, red where it doesn't), turn it, drop it. The same on phone, gamepad and mouse.
- **Saved** as a list of what stands where.

### What the map holds

The map bakes only each yard's shell: the island, the ground, the fence, the gate and the plot marker. Pads, bays, the crate, the mound, the press, the boards, fence panels, decorations and the rubble heaps (4 baked variants) are separate models the game places for each player.

## Storms

There are no bots and no arena. A storm is weather: it makes the belt richer and the map more dangerous, and it ends with every yard's defences down.

- **Rounds:** 4 min calm, then a 20 s warning (the sky darkens and the crane's siren sounds), then a 2 min storm.
- **Scrap storm** (the whole 2 minutes):
  - **Storm haul:** the belt runs at double speed, so a lap takes 45 s, and capsules spawn twice as often. Every one is a Storm capsule, rolled one tier higher: Scrap becomes Salvaged, Salvaged becomes Refurbished, and so on.
  - **Parts rain** onto the hub's walkways and plazas as pickups. A player who stays out for the whole storm collects about **25 × zone tier × (1 + 0.15 × rank)** parts.
  - **Lightning** strikes the hub and the bridges. A warning ring 10 studs across shows for 1 s, then the bolt lands. Anyone inside it is knocked down for 2 s and drops their capsule. Strikes favour players who are carrying one.
  - **Yards are safe from lightning.** Hiding costs you the haul and the parts.
- **Blackout** (the last 30 seconds): the power fails across the map.
  - Every yard gate swings open.
  - Booby traps and capsule guard switch off.
  - Crates unlock, so a raider takes twice the usual share.
  - Capsules still hatching in build bays are there for the taking.
- **Raids** stay on through the whole storm (this replaces the old rule that turned them off).
- **Each zone** has its own storm at the same time, with its own belt's odds.

## Logbook

- **What it tracks:** each of the 63 junkrots once hatched, and each Limited Edition separately.

| Unique junkrots | Bonus |
|---|---|
| 10 | +5% income |
| 20 | +10% |
| 30 | +15% |
| 45 | +20% |
| 55 | +25% and a logbook trophy in the yard |
| 63 | Gold logbook frame |

| Limited Editions | Reward |
|---|---|
| 1 | Gold-plated spanner skin |
| 5 | Gold yard sign |
| 15 | Gold crane hook on your capsules |

## Missions

- **Onboarding chain** (first hour, in order; each pays scrap or parts):
  1. Whack the junk mound 10 times.
  2. Buy a capsule off the belt.
  3. Carry it home.
  4. Hatch it.
  5. Collect your crate.
  6. Fill 3 pads.
  7. Fill 6 pads.
  8. Pick up 20 parts in a storm.
  9. Add an upgrade.
  10. Buy a Salvaged capsule.
  11. Steal a capsule from someone, or defend one.
  12. Move a pad in build mode, and place a junkrot on a matching pad.
  13. Reach 2,500 scrap/s.
  14. Rebirth once.
- **Daily jobs:** 3 rotating each day, worth about 20 minutes of parts. Examples: hatch 5 capsules; pick up 60 parts in storms; grab 3 Storm capsules; raid a crate; hatch a Refurbished junkrot.

## Offline and economy guard rails

- **Offline:** junkrots earn at 50% rate, capped at 2 hours (6 hours from rank 15). The 48-hour pacing counts active play only.
- **Server authority:** all scrap changes go through `DataService.addScrap` and `trySpend`, as now, and capsule ownership is server-side.
- **Big numbers:** use the existing short-format helper with K, M, B and T, and check it reaches T.

## Build order

This is the order from the approved plan (`~/.claude/plans/merry-watching-cray.md`), with machines replaced by capsules and junkrots:
1. Sketches: the map, the yard, the crane and belt, then the capsules and junkrots.
2. Belt and capsules.
3. Build mode, hatching, income, upgrades and parts.
4. Rebirth and logbook.
5. Storms: the storm haul, parts rain, lightning and the blackout.
6. Gantry Isle, Crown Heap and the full cast, tuned with `tools/pacing/pacing.py`.
