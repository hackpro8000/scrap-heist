--!strict
--[[
	Junkrots config

	The cast: every junkrot a capsule can hatch into, the seven tiers they
	come in, and what each tier's capsule costs and takes to hatch. The
	numbers follow docs/plans/gameplay-content.md and tools/pacing/pacing.py;
	re-run the sim when a number here changes.

	A junkrot's id is its name without spaces. Saves hold ids, so a junkrot
	can be renamed (its display name) without touching saves, but never
	re-id'd.

	Public API:
		Junkrots.TIERS: { Tier }                 -- junk to manufactured
		Junkrots.TIER_INFO: { [Tier]: TierInfo }
		Junkrots.FAMILIES: { Family }
		Junkrots.LIST: { Junkrot }
		Junkrots.BY_ID: { [string]: Junkrot }
		Junkrots.BY_TIER: { [tier]: { Junkrot } }
		Junkrots.tierIndex(tier): number
]]

local Junkrots = {}

export type Tier = "Scrap" | "Salvaged" | "Refurbished" | "Factory" | "Precision" | "Prototype" | "Secret"
export type Family = "Kitchen" | "Garage" | "Gadget"

export type TierInfo = {
	-- What the capsule of this tier is, for prompts and messages.
	capsule: string,
	-- A capsule costs this many seconds of its junkrot's 1-star output.
	priceSeconds: number,
	-- Seconds to hatch while the owner whacks it.
	hatchSeconds: number,
	-- Placeholder colour for the capsule and the junkrot, and the tier's
	-- colour in the UI.
	color: Color3,
}

export type Junkrot = {
	id: string,
	name: string,
	-- The everyday object or creature it is.
	what: string,
	tier: Tier,
	family: Family,
	-- Scrap per second at 1 star.
	rate: number,
	-- A scrap-built take on a trending brainrot; the belt announces these.
	remix: boolean?,
}

Junkrots.TIERS = { "Scrap", "Salvaged", "Refurbished", "Factory", "Precision", "Prototype", "Secret" } :: { string }

Junkrots.TIER_INFO = {
	Scrap = { capsule = "Paint can", priceSeconds = 25, hatchSeconds = 5, color = Color3.fromRGB(150, 100, 70) },
	Salvaged = { capsule = "Lunchbox", priceSeconds = 60, hatchSeconds = 10, color = Color3.fromRGB(120, 150, 110) },
	Refurbished = { capsule = "Toolbox", priceSeconds = 120, hatchSeconds = 20, color = Color3.fromRGB(200, 70, 60) },
	Factory = { capsule = "Shipping box", priceSeconds = 240, hatchSeconds = 40, color = Color3.fromRGB(200, 160, 100) },
	Precision = { capsule = "Flight case", priceSeconds = 480, hatchSeconds = 75, color = Color3.fromRGB(180, 190, 200) },
	Prototype = { capsule = "Lab pod", priceSeconds = 960, hatchSeconds = 120, color = Color3.fromRGB(110, 220, 230) },
	Secret = { capsule = "Monolith", priceSeconds = 1920, hatchSeconds = 180, color = Color3.fromRGB(25, 25, 30) },
} :: { [string]: TierInfo }

Junkrots.FAMILIES = { "Kitchen", "Garage", "Gadget" } :: { Family }

-- A junkrot on a pad of its own family earns this much more.
Junkrots.FAMILY_BONUS = 0.1

-- Each star doubles a junkrot's output, up to MAX_STARS.
Junkrots.MAX_STARS = 5

-- Parts to go from star N to N + 1 for a Scrap junkrot; each tier above
-- costs STAR_TIER_FACTOR times the one below.
Junkrots.STAR_PARTS = { 10, 30, 90, 270 }
Junkrots.STAR_TIER_FACTOR = 3

-- Left alone, a capsule takes this many times longer to hatch.
Junkrots.UNATTENDED_HATCH_FACTOR = 2.5

-- A junkrot scrapped to make room pays back this share of its capsule's price.
Junkrots.SCRAP_REFUND = 0.25

local function entry(tier: Tier, family: Family, name: string, what: string, rate: number, remix: boolean?): Junkrot
	return {
		id = (string.gsub(name, "[^%w]", "")),
		name = name,
		what = what,
		tier = tier,
		family = family,
		rate = rate,
		remix = remix,
	}
end

Junkrots.LIST = {
	entry("Scrap", "Kitchen", "Canetto Rustini", "tin can", 1),
	entry("Scrap", "Kitchen", "Spoonzo Bentolo", "bent spoon", 1.4),
	entry("Scrap", "Kitchen", "Kettlina Dentata", "dented kettle", 1.8),
	entry("Scrap", "Garage", "Tyro Flattino", "flat tyre", 2.1),
	entry("Scrap", "Garage", "Boltolo Lonelo", "one lost bolt", 2.5),
	entry("Scrap", "Garage", "Hubcappa Wobbla", "hubcap", 2.8),
	entry("Scrap", "Gadget", "Remotino Muto", "dead remote", 3.2),
	entry("Scrap", "Gadget", "Cablo Tanglino", "tangled cable", 3.6),
	entry("Scrap", "Gadget", "Bulbo Fulminato", "blown bulb", 4),

	entry("Salvaged", "Kitchen", "Crumbo Poppalot", "toaster", 12),
	entry("Salvaged", "Kitchen", "Pannetto Patchato", "patched pan", 14),
	entry("Salvaged", "Kitchen", "Blendro Cigolante", "squeaky blender", 16),
	entry("Salvaged", "Garage", "Jackolo Crickato", "car jack", 18),
	entry("Salvaged", "Garage", "Oilcanna Gluglu", "oil can", 21),
	entry("Salvaged", "Garage", "Mufflero Tossetto", "coughing exhaust", 23),
	entry("Salvaged", "Gadget", "Radiolo Fruscio", "crackly radio", 25),
	entry("Salvaged", "Gadget", "Fanetto Wobblino", "desk fan", 28),
	entry("Salvaged", "Gadget", "Clocko Tictacco", "alarm clock", 30),
	entry("Salvaged", "Kitchen", "Drippi Droppi", "copper-tube shrimp with a tin cat head", 20, true),
	entry("Salvaged", "Garage", "Ding Ding Ding Dongo", "snail with a bike-bell shell", 26, true),

	entry("Refurbished", "Kitchen", "Frostbox Gelatone", "fridge", 150),
	entry("Refurbished", "Kitchen", "Microndo Bippetto", "microwave", 170),
	entry("Refurbished", "Kitchen", "Mixerella Vroom", "stand mixer", 190),
	entry("Refurbished", "Garage", "Mopa Mopetta", "moped", 210),
	entry("Refurbished", "Garage", "Drillo Trapanino", "power drill", 235),
	entry("Refurbished", "Garage", "Grindella Scintilla", "angle grinder", 255),
	entry("Refurbished", "Gadget", "Telefono Ringaling", "rotary phone", 275),
	entry("Refurbished", "Gadget", "Typewritto Clackini", "typewriter", 300),
	entry("Refurbished", "Gadget", "Camerino Flashetto", "camera", 320),
	entry("Refurbished", "Garage", "Vrr Vrr Patatrim", "pipe-trunk monkey with boot feet", 200, true),
	entry("Refurbished", "Kitchen", "Chimneyzini Spannerini", "tin chimp in a peeled stove pipe", 240, true),
	entry("Refurbished", "Gadget", "Rusteli Rustela", "barrel elephant with rebar spikes", 290, true),

	entry("Factory", "Kitchen", "Grindo Beanbasher", "coffee machine", 2000),
	entry("Factory", "Kitchen", "Airfryo Croccante", "air fryer", 2300),
	entry("Factory", "Kitchen", "Dishwashino Splashetto", "dishwasher", 2600),
	entry("Factory", "Garage", "Lawnmowo Ruggito", "lawnmower", 2900),
	entry("Factory", "Garage", "Leafblowa Whooshini", "leaf blower", 3250),
	entry("Factory", "Garage", "Pressurwasho Sprizzo", "pressure washer", 3550),
	entry("Factory", "Gadget", "Consolo Joypaddino", "game console", 3850),
	entry("Factory", "Gadget", "Speakerone Boomba", "party speaker", 4200),
	entry("Factory", "Gadget", "Robovacco Girotondo", "robot vacuum", 4500),
	entry("Factory", "Garage", "Clank Clank Clank Scrapur", "pipe-section figure with a rebar bat", 3000, true),
	entry("Factory", "Kitchen", "Ballerina Tincuppina", "wire ballerina with a tin mug head", 2700, true),
	entry("Factory", "Kitchen", "Trashalero Trashala", "tin shark on three pipe legs", 3400, true),
	entry("Factory", "Garage", "Socketto Sei-Sette", "raccoon with a socket-set belly", 4000, true),

	entry("Precision", "Kitchen", "Chefbot Precisio", "kitchen robot", 30000),
	entry("Precision", "Kitchen", "Sousvide Silvano", "sous-vide wand", 34000),
	entry("Precision", "Kitchen", "Knifeblock Slicetta", "knife block", 38000),
	entry("Precision", "Garage", "Torquo Wrenchelli", "torque wrench", 41000),
	entry("Precision", "Garage", "Laserlevel Lineo", "laser level", 45000),
	entry("Precision", "Garage", "Weldetta Sparkalot", "welding rig", 49000),
	entry("Precision", "Gadget", "Dronetto Buzzatti", "drone", 52000),
	entry("Precision", "Gadget", "Tickworth Pocketti", "pocket watch", 56000),
	entry("Precision", "Gadget", "Headphono Bassimo", "headphones", 60000),
	entry("Precision", "Garage", "Gascanini Honkini", "chrome goose with gas-can jets", 36000, true),
	entry("Precision", "Kitchen", "Percolatto Ninjatto", "steel coffee cup ninja", 44000, true),
	entry("Precision", "Kitchen", "Boilerdiro Crockpotilo", "boiler-belly crocodile plane", 50000, true),

	entry("Prototype", "Kitchen", "Snackomatic Prototipo", "food replicator", 400000),
	entry("Prototype", "Garage", "Hoverbikko Zoomzoom", "hoverbike", 600000),
	entry("Prototype", "Gadget", "Holofono Shimmerra", "hologram phone", 800000),
	entry("Prototype", "Gadget", "La Vacuuma Saturnita", "vacuum-canister planet with a cow head", 700000, true),

	entry("Secret", "Garage", "The Monolito", "humming black slab", 5000000),
	entry("Secret", "Gadget", "Unit Zero", "floating chrome sphere", 10000000),
} :: { Junkrot }

Junkrots.BY_ID = {} :: { [string]: Junkrot }
Junkrots.BY_TIER = {} :: { [string]: { Junkrot } }

for _, tier in Junkrots.TIERS do
	Junkrots.BY_TIER[tier] = {}
end
for _, junkrot in Junkrots.LIST do
	assert(Junkrots.BY_ID[junkrot.id] == nil, `Junkrots: two junkrots share the id {junkrot.id}`)
	Junkrots.BY_ID[junkrot.id] = junkrot
	table.insert(Junkrots.BY_TIER[junkrot.tier], junkrot)
end

function Junkrots.tierIndex(tier: string): number
	return table.find(Junkrots.TIERS, tier) or error(`Junkrots: unknown tier {tier}`)
end

return Junkrots
