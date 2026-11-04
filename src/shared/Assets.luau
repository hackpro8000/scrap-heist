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
	ServerMap01 = "rbxassetid://132805189838770",
	ServerMap02 = "rbxassetid://86856016998516",
	ServerMap03 = "rbxassetid://110266846154270",
	ServerMap04 = "rbxassetid://132492747515479",
	ServerMap05 = "rbxassetid://118294900333686",
	ServerMap06 = "rbxassetid://73681751059849",
	ServerMap07 = "rbxassetid://94218614270122",
	ServerMap08 = "rbxassetid://121815632236467",
	ServerMap09 = "rbxassetid://85430404866213",
	ServerMap10 = "rbxassetid://127969571139814",
	ServerMap11 = "rbxassetid://101709756542493",
	ServerMap12 = "rbxassetid://101889634517935",
	ServerMap13 = "rbxassetid://101247785269453",
	ServerMap14 = "rbxassetid://74704785708727",
	ServerMap15 = "rbxassetid://133118780680227",
	ServerMap16 = "rbxassetid://97691475649687",
	ServerMap17 = "rbxassetid://81384355535730",
	ServerMap18 = "rbxassetid://76824872017671",
	ServerMap19 = "rbxassetid://75462259722307",
	ServerMap20 = "rbxassetid://80677687205660",
	ServerMap21 = "rbxassetid://98420450587586",
	ServerMap22 = "rbxassetid://121326716255589",
	ServerMap23 = "rbxassetid://90141579890906",
	ServerMap24 = "rbxassetid://94731001184922",
	ServerMap25 = "rbxassetid://97226623855496",
	ServerMap26 = "rbxassetid://140076483733613",
	ServerMap27 = "rbxassetid://93080306871679",
	ServerMap28 = "rbxassetid://84715132191072",
	ServerMap29 = "rbxassetid://75904498631346",
	ServerMap30 = "rbxassetid://106340468392365",
	ServerMap31 = "rbxassetid://88656954711392",
	ServerMap32 = "rbxassetid://117097998369945",
	ServerMap33 = "rbxassetid://112037349942325",
	ServerMap34 = "rbxassetid://127945313699751",
	ServerMap35 = "rbxassetid://119760060417150",
	ServerMap36 = "rbxassetid://99509163970873",
}

function Assets.isSet(id: string?): boolean
	return id ~= nil and id ~= "" and id ~= PLACEHOLDER
end

return Assets
