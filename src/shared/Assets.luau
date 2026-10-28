--!strict
--[[
	Assets

	The single home for every asset ID in the game. Code never hardcodes an
	ID; it reads one from here and checks Assets.isSet() first, so the game
	runs with no errors or warnings while IDs are still placeholders.

	To drop in a real asset: upload it, then replace PLACEHOLDER for that
	entry with "rbxassetid://<id>". Nothing else needs to change.

	Public API:
		Assets.PLACEHOLDER
		Assets.Animations.<Name>
		Assets.Sounds.<Name>
		Assets.isSet(id): boolean   -- false for placeholders and missing IDs
]]

local PLACEHOLDER = "rbxassetid://0"

local Assets = {}

Assets.PLACEHOLDER = PLACEHOLDER

-- Combat animations are named by weapon and combo step so WeaponConfig
-- can point at them by key.
Assets.Animations = {
	BatSwing1 = PLACEHOLDER,
	BatSwing2 = PLACEHOLDER,
	BatSwing3 = PLACEHOLDER,
	SpannerSwing1 = PLACEHOLDER,
	SpannerSwing2 = PLACEHOLDER,
	SawSwing1 = PLACEHOLDER,
	BruiserSlam1 = PLACEHOLDER,
	BruiserSlam2 = PLACEHOLDER,
	ZapperShot1 = PLACEHOLDER,
	Block = PLACEHOLDER,
	Stunned = PLACEHOLDER,
	Carry = PLACEHOLDER,
}

Assets.Sounds = {
	Swing = PLACEHOLDER,
	Hit = PLACEHOLDER,
	Block = PLACEHOLDER,
	Parry = PLACEHOLDER,
	GuardBreak = PLACEHOLDER,
	Zap = PLACEHOLDER,
	Purchase = PLACEHOLDER,
	Collect = PLACEHOLDER,
	RaidAlert = PLACEHOLDER,
	Grab = PLACEHOLDER,
	Bank = PLACEHOLDER,
	TradeComplete = PLACEHOLDER,
	StormWarning = PLACEHOLDER,
	StormStart = PLACEHOLDER,
	StormEnd = PLACEHOLDER,
	LootRare = PLACEHOLDER,
	UiClick = PLACEHOLDER,
}

function Assets.isSet(id: string?): boolean
	return id ~= nil and id ~= "" and id ~= PLACEHOLDER
end

return Assets
