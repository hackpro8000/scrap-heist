--!strict
--[[
	WeaponConfig

	Every combat number in the game. Combat logic reads weapons by name from
	here and has no weapon-specific code, so a new weapon is a new entry in
	Weapons and nothing else.

	Player weapons are listed in PLAYER_WEAPONS; the rest belong to bots and
	the training dummy, and clients can't equip them.

	Public API:
		WeaponConfig.Weapons.<Name>: Weapon
		WeaponConfig.Combat: CombatSettings
		WeaponConfig.PLAYER_WEAPONS: { string }   -- in hotkey order (1, 2, ...)
		WeaponConfig.DEFAULT_PLAYER_WEAPON: string
		WeaponConfig.Dummy                        -- training dummy tuning
		WeaponConfig.isPlayerWeapon(name): boolean
]]

local CombatTypes = require(script.Parent.CombatTypes)

type Weapon = CombatTypes.Weapon

local WeaponConfig = {}

local Weapons: { [string]: Weapon } = {
	-- Starter weapon: quick three-hit combo, the last hit knocks back.
	Bat = {
		displayName = "Bat",
		combo = {
			{
				damage = 10,
				postureDamage = 15,
				windup = 0.15,
				recovery = 0.3,
				range = 6,
				width = 5,
				height = 6,
				knockback = 0,
				animation = "BatSwing1",
			},
			{
				damage = 10,
				postureDamage = 15,
				windup = 0.15,
				recovery = 0.3,
				range = 6,
				width = 5,
				height = 6,
				knockback = 0,
				animation = "BatSwing2",
			},
			{
				damage = 18,
				postureDamage = 30,
				windup = 0.25,
				recovery = 0.55,
				range = 6.5,
				width = 6,
				height = 6,
				knockback = 40,
				animation = "BatSwing3",
			},
		},
		comboResetTime = 0.8,
		blockDamageMultiplier = 0.25,
		blockAngle = 120,
		parryWindow = 0.2,
		parryStun = 1.2,
	},

	-- Upgrade: slower two-hit combo that hits harder and breaks guards.
	Spanner = {
		displayName = "Big Spanner",
		combo = {
			{
				damage = 16,
				postureDamage = 25,
				windup = 0.25,
				recovery = 0.45,
				range = 7,
				width = 5,
				height = 6,
				knockback = 10,
				animation = "SpannerSwing1",
			},
			{
				damage = 26,
				postureDamage = 45,
				windup = 0.35,
				recovery = 0.7,
				range = 7.5,
				width = 6,
				height = 6,
				knockback = 55,
				animation = "SpannerSwing2",
			},
		},
		comboResetTime = 0.9,
		blockDamageMultiplier = 0.2,
		blockAngle = 130,
		parryWindow = 0.18,
		parryStun = 1.4,
	},

	-- Scrapper bot: weak, fast buzzsaw jab.
	Saw = {
		displayName = "Buzzsaw",
		combo = {
			{
				damage = 5,
				postureDamage = 10,
				windup = 0.4,
				recovery = 0.8,
				range = 6.5,
				width = 5,
				height = 6,
				knockback = 0,
				animation = "SawSwing1",
			},
		},
		comboResetTime = 0,
		blockDamageMultiplier = 0.5,
		blockAngle = 0,
		parryWindow = 0,
		parryStun = 0,
	},

	-- Bruiser bot: slow, telegraphed slams. Long windups make them the
	-- easiest attacks to parry.
	Slam = {
		displayName = "Slam",
		combo = {
			{
				damage = 14,
				postureDamage = 35,
				windup = 0.7,
				recovery = 1,
				range = 9,
				width = 8,
				height = 8,
				knockback = 30,
				animation = "BruiserSlam1",
			},
			{
				damage = 22,
				postureDamage = 50,
				windup = 0.9,
				recovery = 1.4,
				range = 9.5,
				width = 9,
				height = 8,
				knockback = 60,
				animation = "BruiserSlam2",
			},
		},
		comboResetTime = 1.5,
		blockDamageMultiplier = 0.5,
		blockAngle = 0,
		parryWindow = 0,
		parryStun = 0,
	},

	-- Zapper bot: a long, narrow hitbox stands in for a bolt from its coil,
	-- so ranged attacks use the same hit rules as melee.
	Zap = {
		displayName = "Zap",
		combo = {
			{
				damage = 10,
				postureDamage = 20,
				windup = 0.9,
				recovery = 1.6,
				range = 30,
				width = 3,
				height = 7,
				knockback = 0,
				animation = "ZapperShot1",
			},
		},
		comboResetTime = 0,
		blockDamageMultiplier = 0.5,
		blockAngle = 0,
		parryWindow = 0,
		parryStun = 0,
	},

	-- Training dummy: a slow, obvious swing to practise blocks and parries.
	DummySwing = {
		displayName = "Dummy Swing",
		combo = {
			{
				damage = 5,
				postureDamage = 20,
				windup = 0.6,
				recovery = 0.6,
				range = 6,
				width = 5,
				height = 6,
				knockback = 0,
				animation = "BatSwing1",
			},
		},
		comboResetTime = 0,
		blockDamageMultiplier = 0.5,
		blockAngle = 0,
		parryWindow = 0,
		parryStun = 0,
	},
}

WeaponConfig.Weapons = Weapons

WeaponConfig.Combat = {
	maxPosture = 100,
	postureRegenPerSecond = 20,
	postureRegenDelay = 2,
	hitStun = 0.35,
	guardBreakStun = 1.5,
	parryCooldown = 0.6,
	knockbackLift = 8,
	walkSpeed = {
		normal = 16,
		attacking = 12,
		blocking = 8,
		stunned = 4,
	},
} :: CombatTypes.CombatSettings

WeaponConfig.PLAYER_WEAPONS = { "Bat", "Spanner" }
WeaponConfig.DEFAULT_PLAYER_WEAPON = "Bat"

WeaponConfig.Dummy = {
	weapon = "DummySwing",
	health = 150,
	-- Studs: the dummy swings at the nearest player this close.
	aggroRange = 9,
	-- Seconds between swing attempts.
	swingInterval = 2,
	respawnDelay = 3,
}

function WeaponConfig.isPlayerWeapon(name: any): boolean
	return type(name) == "string" and table.find(WeaponConfig.PLAYER_WEAPONS, name) ~= nil
end

return WeaponConfig
