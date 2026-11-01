--!strict
--[[
	CombatTypes

	Shapes of the combat tuning data in WeaponConfig. Shared so the server
	rules, the client controller and bot config all agree on field names.
]]

-- One swing in a weapon's combo.
export type ComboStep = {
	damage: number,
	-- Posture removed from a defender who blocks this swing.
	postureDamage: number,
	-- Seconds from pressing attack to the hitbox check. The swing can be
	-- interrupted by a stun during this time.
	windup: number,
	-- Seconds after the hit before the attacker may act again.
	recovery: number,
	-- Hitbox: a box `range` studs deep in front of the attacker.
	range: number,
	width: number,
	height: number,
	-- Push speed (studs per second) applied to whoever is hit.
	knockback: number,
	-- Key into Assets.Animations.
	animation: string,
}

export type Weapon = {
	displayName: string,
	combo: { ComboStep },
	-- Seconds after a swing's recovery during which the next attack
	-- continues the combo instead of starting it over.
	comboResetTime: number,
	-- Fraction of damage that gets through a block.
	blockDamageMultiplier: number,
	-- Full width, in degrees, of the cone in front that a block covers.
	blockAngle: number,
	-- Seconds after raising a block during which a hit is parried.
	parryWindow: number,
	-- Stun given to an attacker whose swing is parried.
	parryStun: number,
}

export type CombatSettings = {
	maxPosture: number,
	postureRegenPerSecond: number,
	-- Seconds after blocking a hit before posture starts regenerating.
	postureRegenDelay: number,
	hitStun: number,
	guardBreakStun: number,
	-- A block only gets a parry window if the previous block ended at least
	-- this long ago, so tapping block can't parry everything.
	parryCooldown: number,
	-- Upward speed added to knockback so targets lift a little.
	knockbackLift: number,
	walkSpeed: {
		normal: number,
		attacking: number,
		blocking: number,
		stunned: number,
	},
}

-- Roblox modules must return a value; this one only exports types.
return {}
