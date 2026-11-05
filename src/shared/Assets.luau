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
		Assets.UI.<Name>
	Assets.Models.<Name>
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

-- ToyKit HUD art, painted by scripts/build-ui.sh from art/ui/ToyKit.
Assets.UI = {
	Counter = "rbxassetid://126159084632956",
	IconScrap = "rbxassetid://140446368040187",
	IconBag = "rbxassetid://132179531176766",
	IconTrade = "rbxassetid://125672934325806",
	IconTrophy = "rbxassetid://92336713751632",
	IconShop = "rbxassetid://74092893287620",
	IconRewards = "rbxassetid://77984125268096",
	IconBot = "rbxassetid://138383704812127",
	IconStorm = "rbxassetid://98497967836768",
	IconAlert = "rbxassetid://103549172802784",
	PlankCount = "rbxassetid://124141536641452",
	PlankTimer = "rbxassetid://75148301123240",
	BannerRaid = "rbxassetid://138020418317297",
	BannerClear = "rbxassetid://124610273947141",
	SlotWood = "rbxassetid://95291819560418",
	TickBadge = "rbxassetid://135667301031586",
	PanelInventory = "rbxassetid://126278021543325",
	PanelTrade = "rbxassetid://76112170334523",
	PanelResults = "rbxassetid://132228184887734",
	PanelTradePick = "rbxassetid://124577562055305",
	PanelSettings = "rbxassetid://103208443650384",
	HeaderInventory = "rbxassetid://110793203489300",
	HeaderTrade = "rbxassetid://80741229167181",
	HeaderResults = "rbxassetid://137845273161315",
	HeaderTradePick = "rbxassetid://113521740907540",
	HeaderSettings = "rbxassetid://95937150296472",
	PlateInventoryGrid = "rbxassetid://116823617116827",
	PlateInventoryDetail = "rbxassetid://95805046028055",
	PlateShop = "rbxassetid://121606541165306",
	PlateTradeOffer = "rbxassetid://72938296551878",
	PlateTradeBag = "rbxassetid://135730605012888",
	PlateTradeWarning = "rbxassetid://71862321346863",
	PlateRewards = "rbxassetid://104933154327605",
	PlateGift = "rbxassetid://104978870136421",
	PlateTutorial = "rbxassetid://134012661406055",
	ButtonAction = "rbxassetid://113033989916335",
	ButtonDanger = "rbxassetid://129798603574658",
	ButtonDisabled = "rbxassetid://87068946023017",
	ButtonMedium = "rbxassetid://103921166448351",
	ButtonActionMedium = "rbxassetid://115253002404939",
	ButtonDangerMedium = "rbxassetid://126391317675845",
	ButtonDisabledMedium = "rbxassetid://83624373229406",
	ButtonActionSmall = "rbxassetid://94067109854538",
	ButtonClose = "rbxassetid://115989673129338",
	Slot = "rbxassetid://138462302111440",
	SlotCommon = "rbxassetid://118877967848571",
	SlotUncommon = "rbxassetid://94170891649953",
	SlotRare = "rbxassetid://85508044434059",
	SlotLegendary = "rbxassetid://85045289590715",
	SlotMedium = "rbxassetid://129345500927565",
	SlotMediumCommon = "rbxassetid://138688423410188",
	SlotMediumUncommon = "rbxassetid://111813565885295",
	SlotMediumRare = "rbxassetid://137527514323378",
	SlotMediumLegendary = "rbxassetid://125375395190311",
	SlotSmall = "rbxassetid://134180971374110",
	SlotSmallCommon = "rbxassetid://134426477141541",
	SlotSmallUncommon = "rbxassetid://89074446218515",
	SlotSmallRare = "rbxassetid://119667023990390",
	SlotSmallLegendary = "rbxassetid://115876406602667",
	Tab = "rbxassetid://111889612760765",
	TabActive = "rbxassetid://119173188210487",
	TabSmall = "rbxassetid://110223971441176",
	TabSmallActive = "rbxassetid://110225179103351",
	ResultsRow = "rbxassetid://112377308913175",
	ResultsRowAlt = "rbxassetid://134827463404958",
	LeaderboardRow = "rbxassetid://117635724817975",
	LeaderboardRowAlt = "rbxassetid://110210393354122",
	PlayerRow = "rbxassetid://98198066755607",
	PlayerRowAlt = "rbxassetid://75574051264997",
	TooltipUpgrade = "rbxassetid://127205222586216",
	TooltipBuyPad = "rbxassetid://83590485426156",
	CardShop = "rbxassetid://95692395005553",
	CardTradeRequest = "rbxassetid://121813254948138",
	Checkbox = "rbxassetid://89409910296506",
	CheckboxOn = "rbxassetid://119314285191339",
	ScrollTrack = "rbxassetid://90290762181669",
	ScrollThumb = "rbxassetid://130596905467495",
	BarTroughGift = "rbxassetid://99961833086070",
	BarFillGift = "rbxassetid://132920694668435",
	BarTroughSlider = "rbxassetid://83794284878515",
	BarFillSlider = "rbxassetid://134119960243405",
	IconTimer = "rbxassetid://81795052479743",
	IconShield = "rbxassetid://78785441615935",
	IconSettings = "rbxassetid://110087287378347",
	ItemRustyGear = "rbxassetid://130957358159057",
	ItemBentBolt = "rbxassetid://121033955590422",
	ItemCopperCoil = "rbxassetid://90336405197143",
	ItemOldBattery = "rbxassetid://133663340418298",
	ItemCircuitBoard = "rbxassetid://88039896245650",
	ItemServoMotor = "rbxassetid://89331435777916",
	ItemReactorCore = "rbxassetid://117274552062286",
	ItemGoldenCog = "rbxassetid://117499187566643",
	WeaponBat = "rbxassetid://96663703711706",
	WeaponSpanner = "rbxassetid://138844381366181",
	BannerStormWarning = "rbxassetid://116504985479444",
	BarFillHealth = "rbxassetid://103751102337549",
	BarFill = "rbxassetid://127463000861077",
	BarFillStorm = "rbxassetid://100532099555225",
	BarTroughHealth = "rbxassetid://140693303589797",
	BarTrough = "rbxassetid://71308136898879",
	ButtonDisabledSmall = "rbxassetid://127203489192905",
	ButtonHover = "rbxassetid://115345131416451",
	ButtonMenuHover = "rbxassetid://109327869041544",
	ButtonMenu = "rbxassetid://106834773878050",
	ButtonMenuPressed = "rbxassetid://109264734222089",
	Button = "rbxassetid://95945789769897",
	ButtonPressed = "rbxassetid://78638286309330",
	CounterCalm = "rbxassetid://100276689369802",
	CounterRaid = "rbxassetid://127836586435012",
	CounterStorm = "rbxassetid://75886336048755",
	CounterSurvivors = "rbxassetid://121302489702862",
	CounterWarning = "rbxassetid://100136308959040",
	HeaderLeaderboard = "rbxassetid://111276155435003",
	HeaderShop = "rbxassetid://89683779433905",
	IconBag28 = "rbxassetid://80204335500729",
	IconCalm = "rbxassetid://83158075300077",
	IconClover = "rbxassetid://123255404408140",
	IconCrate = "rbxassetid://110878255531303",
	IconCross = "rbxassetid://79118835008176",
	IconCrown = "rbxassetid://94976163457658",
	IconMagnet = "rbxassetid://113139908786546",
	IconOverdrive = "rbxassetid://140363182459276",
	IconRewards28 = "rbxassetid://130295438484712",
	IconScrap64 = "rbxassetid://87201207008437",
	IconScrapHeap = "rbxassetid://134807246240861",
	IconScrapMountain = "rbxassetid://93572466900211",
	IconSettings28 = "rbxassetid://123999629360422",
	IconShield64 = "rbxassetid://82898572040796",
	IconShop28 = "rbxassetid://113861945080168",
	IconTrade28 = "rbxassetid://140033114271027",
	IconTrophy28 = "rbxassetid://135218139635723",
	IconTrophy40 = "rbxassetid://75471165815073",
	InputField = "rbxassetid://102810552363769",
	LeaderboardRowYou = "rbxassetid://79179728081835",
	PanelLeaderboard = "rbxassetid://134357236882234",
	PanelRewards = "rbxassetid://136798002156782",
	PanelShop = "rbxassetid://126329400820583",
	PlateRaidShield = "rbxassetid://78443707986671",
	PlateShowcase = "rbxassetid://111118450322457",
	PreviewWell = "rbxassetid://118675943208617",
	SlotGlow = "rbxassetid://127303306943917",
	SlotMediumGlow = "rbxassetid://87082785125154",
	SlotSmallGlow = "rbxassetid://78161094379904",
	StatPipOn = "rbxassetid://135334696783491",
	StatPip = "rbxassetid://96894039049910",
	SlotWoodSelected = "rbxassetid://135886924562770",
	BarTroughHotbar = "rbxassetid://119813053998255",
	BarFillHotbar = "rbxassetid://113177059445025",
	BarFillHealthHotbar = "rbxassetid://79163999977704",
	BarTrailHotbar = "rbxassetid://100858730833062",
}

-- Whole models (bots, machines, weapons), written by scripts/upload-model.sh.
-- tools/studio/PlaceModels.luau loads them into the ServerStorage folders the
-- game clones them from.
Assets.Models = {
	Scrapper = "rbxassetid://125624298274074",
	Bruiser = "rbxassetid://130817677056789",
	Zapper = "rbxassetid://126854922286431",
	StarterWeapon = "rbxassetid://94523455870173",
	BigSpanner = "rbxassetid://127557058209611",
	SalvageMachine = "rbxassetid://121586650300081",
	PartBundle = "rbxassetid://133992033763606",
	StorageCrate = "rbxassetid://91609002959428",
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
