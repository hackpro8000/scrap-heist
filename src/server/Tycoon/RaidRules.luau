--!strict
--[[
	RaidRules

	Whether a raider may grab from a crate, and how much they get.
	RaidService gathers the facts from the world (positions, profiles,
	round state) and asks canGrab; every check lives here so the full list
	of raid rules can be read, and tested, in one place.

	Public API:
		RaidRules.canGrab(context): reason?
		RaidRules.bundleSize(crateParts): number
		RaidRules.shieldUntil(now): number
		RaidRules.REASON_TEXT: { [reason]: string }   -- what the raider is told
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaidConfig = require(ReplicatedStorage.Shared.Config.Raid)

local RaidRules = {}

export type GrabContext = {
	isOwner: boolean,
	-- The raider needs a yard of their own to carry the bundle back to.
	raiderHasYard: boolean,
	raiderInsideYard: boolean,
	-- Studs from the raider to the crate.
	distance: number,
	alreadyCarrying: boolean,
	raidsPaused: boolean,
	crateParts: number,
	raiderLevel: number,
	ownerLevel: number,
	-- os.time() values.
	ownerShieldUntil: number,
	now: number,
}

RaidRules.REASON_TEXT = {
	OwnCrate = "That's your own crate. Collect it instead.",
	NoYard = "You need a yard to bring parts back to.",
	NotInYard = "Get inside their yard first.",
	TooFar = "Get closer to the crate.",
	AlreadyCarrying = "You're already carrying a bundle.",
	RaidsPaused = "Raiding is paused during the storm.",
	CrateTooEmpty = "Not enough parts in that crate to steal.",
	Shielded = "This yard was raided recently and is shielded.",
	LevelGap = "That yard is too far below your level to raid.",
} :: { [string]: string }

function RaidRules.canGrab(context: GrabContext): string?
	-- SECURITY: each of these is checked on the server from the server's
	-- own data. The client's prompt press only says "I tried to grab".
	if context.isOwner then
		return "OwnCrate"
	end
	if not context.raiderHasYard then
		return "NoYard"
	end
	if context.raidsPaused then
		return "RaidsPaused"
	end
	if not context.raiderInsideYard then
		return "NotInYard"
	end
	if context.distance > RaidConfig.GRAB_DISTANCE then
		return "TooFar"
	end
	if context.alreadyCarrying then
		return "AlreadyCarrying"
	end
	if context.now < context.ownerShieldUntil then
		return "Shielded"
	end
	-- Anti-grief: strong players can't farm much newer yards.
	if context.raiderLevel - context.ownerLevel > RaidConfig.MAX_LEVEL_GAP then
		return "LevelGap"
	end
	if context.crateParts < RaidConfig.MIN_CRATE_PARTS then
		return "CrateTooEmpty"
	end

	return nil
end

function RaidRules.bundleSize(crateParts: number): number
	local share = math.floor(crateParts * RaidConfig.BUNDLE_FRACTION)
	local size = math.clamp(share, RaidConfig.BUNDLE_MIN, RaidConfig.BUNDLE_MAX)

	-- Never more than the crate actually holds.
	return math.min(size, math.floor(crateParts))
end

function RaidRules.shieldUntil(now: number): number
	return now + RaidConfig.SHIELD_SECONDS
end

return RaidRules
