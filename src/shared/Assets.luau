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
		Assets.MapChunks.<Layout><NN>
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

-- The map's pieces, each a Model asset under Open Cloud's 20 MB upload limit.
-- Written by scripts/upload-chunks.sh; tools/studio/PlaceMap.luau places them
-- in Studio.
Assets.MapChunks = {
	ServerMap01 = "rbxassetid://108340466206906",
	ServerMap02 = "rbxassetid://87785935892734",
	ServerMap03 = "rbxassetid://117957400093032",
	ServerMap04 = "rbxassetid://136235439168574",
	ServerMap05 = "rbxassetid://82258298174664",
	ServerMap06 = "rbxassetid://72569102606664",
	ServerMap07 = "rbxassetid://80435423370631",
	ServerMap08 = "rbxassetid://88678664931080",
	ServerMap09 = "rbxassetid://133061352455514",
	ServerMap10 = "rbxassetid://127888263623580",
	ServerMap11 = "rbxassetid://97241133541575",
	ServerMap12 = "rbxassetid://119558136293198",
	ServerMap13 = "rbxassetid://87856578542474",
	ServerMap14 = "rbxassetid://94331395411316",
	ServerMap15 = "rbxassetid://116737682889688",
	ServerMap16 = "rbxassetid://136325963027136",
	ServerMap17 = "rbxassetid://71785422392476",
	ServerMap18 = "rbxassetid://85957677922965",
	ServerMap19 = "rbxassetid://84008362228569",
	ServerMap20 = "rbxassetid://91209006318228",
	ServerMap21 = "rbxassetid://85936976532785",
	ServerMap22 = "rbxassetid://132123845112680",
	ServerMap23 = "rbxassetid://72231029550881",
	ServerMap24 = "rbxassetid://95421363523657",
	ServerMap25 = "rbxassetid://106675197146216",
	ServerMap26 = "rbxassetid://88022809158345",
	ServerMap27 = "rbxassetid://80934573434767",
	ServerMap28 = "rbxassetid://92252823378209",
	ServerMap29 = "rbxassetid://116021656914230",
	ServerMap30 = "rbxassetid://75506309368238",
	ServerMap31 = "rbxassetid://106434852147379",
	ServerMap32 = "rbxassetid://124454258164230",
	ServerMap33 = "rbxassetid://118399623435844",
	ServerMap34 = "rbxassetid://75443310436716",
	ServerMap35 = "rbxassetid://74144107245677",
	ServerMap36 = "rbxassetid://74060068205732",
}

function Assets.isSet(id: string?): boolean
	return id ~= nil and id ~= "" and id ~= PLACEHOLDER
end

return Assets
