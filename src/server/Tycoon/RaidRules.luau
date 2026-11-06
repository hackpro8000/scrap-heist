--!strict
--[[
	RaidRules

	Whether a raider may grab from a crate, and how much they get.
	RaidService gathers the facts from the world (positions, profiles,
	round state) and asks canGrab; every check lives here so the full list
	of raid rules can be read, and tested, in one place.

	Public API:
		RaidRules.canGrab(context): reason?
		RaidRules.worthRaiding(crateCapacity): number
		RaidRules.bundleSize(crateScrap, multiplier?): number
		RaidRules.shieldUntil(now, seconds?): number
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
	-- Scrap waiting in the crate, and the least worth raiding for.
	crateScrap: number,
	crateCapacity: number,
	-- os.time() values.
	ownerShieldUntil: number,
	now: number,
}

RaidRules.REASON_TEXT = {
	OwnCrate = "That's your own crate. Collect it instead.",
	NoYard = "You need a yard to bring scrap back to.",
	NotInYard = "Get inside their yard first.",
	TooFar = "Get closer to the crate.",
	AlreadyCarrying = "You're already carrying a bundle.",
	CrateTooEmpty = "Not enough scrap in that crate to steal.",
	Shielded = "This yard was raided recently and is shielded.",
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
	if context.crateScrap < RaidRules.worthRaiding(context.crateCapacity) then
		return "CrateTooEmpty"
	end

	return nil
end

-- A crate holding less than this can't be raided at all.
function RaidRules.worthRaiding(crateCapacity: number): number
	return math.floor(crateCapacity * RaidConfig.MIN_CRATE_FRACTION)
end

-- What one grab takes: a share of the crate, `multiplier` times as much in
-- a blackout, and never more than the crate holds.
function RaidRules.bundleSize(crateScrap: number, multiplier: number?): number
	local share = math.floor(crateScrap * RaidConfig.BUNDLE_FRACTION * (multiplier or 1))
	return math.min(share, math.floor(crateScrap))
end

-- `seconds` defaults to the plain shield; the Long Shield pass passes more.
function RaidRules.shieldUntil(now: number, seconds: number?): number
	return now + (seconds or RaidConfig.SHIELD_SECONDS)
end

return RaidRules
