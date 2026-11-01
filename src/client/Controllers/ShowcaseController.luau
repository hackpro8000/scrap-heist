--!strict
--[[
	ShowcaseController

	The showcase panel and debug overlay, for players the server marked
	IsAdmin (Studio, or Config/Game.ADMIN_USER_IDS).

	Panel: one-tap buttons for the commands that make clips quick to record
	(storm now, spawn bots, give items, fake raid, ...). Each button just
	sends a command; the server checks permission and runs it.

	Overlay (toggled from the panel): draws server hitboxes and bot paths
	as the server reports them, labels every bot with its AI state, and
	lists how many remote calls the server has rejected and why.

	Public API: none.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Showcase)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local HudController = require(script.Parent.HudController)
local Pop = require(script.Parent.Parent.UI.Pop)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local localPlayer = Players.LocalPlayer

local HITBOX_SECONDS = 0.3
local PATH_SECONDS = 2
local HITBOX_COLOR = Color3.fromRGB(255, 60, 60)
local PATH_COLOR = Color3.fromRGB(80, 200, 255)
local STATE_LABEL_NAME = "BotStateLabel"

-- Label, command, arguments.
local BUTTONS: { { any } } = {
	{ "Storm now", "storm", {} },
	{ "Calm now", "phase", { "Calm" } },
	{ "5 Scrappers", "spawnbots", { "Scrapper", "5" } },
	{ "Bruiser", "spawnbots", { "Bruiser", "1" } },
	{ "2 Zappers", "spawnbots", { "Zapper", "2" } },
	{ "Clear bots", "clearbots", {} },
	{ "Training dummy", "dummy", {} },
	{ "Fake raid", "fakeraid", {} },
	{ "Fill crate", "fillcrate", {} },
	{ "+1000 scrap", "givescrap", { "1000" } },
	{ "Golden Cog", "giveitem", { "GoldenCog" } },
	{ "Reactor Core", "giveitem", { "ReactorCore" } },
	{ "Debug overlay", "overlay", {} },
}

local ShowcaseController = {}

local screen: ScreenGui
local panel: Frame
local statsPanel: Frame
local statsList: ScrollingFrame
local overlayOn = false
local overlayFolder: Folder
local botConnections: { RBXScriptConnection } = {}

local function drawPart(cframe: CFrame, size: Vector3, color: Color3, seconds: number, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.6
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	if shape then
		part.Shape = shape
	end
	part.Parent = overlayFolder
	Debris:AddItem(part, seconds)
end

local function onDebugDraw(kind: string, data: { [string]: any })
	if not overlayOn or type(data) ~= "table" then
		return
	end

	if kind == "Hitbox" then
		drawPart(data.cframe, data.size, HITBOX_COLOR, HITBOX_SECONDS)
	elseif kind == "Path" then
		for _, position in data.positions do
			drawPart(CFrame.new(position), Vector3.one * 0.6, PATH_COLOR, PATH_SECONDS, Enum.PartType.Ball)
		end
	end
end

local function labelBot(bot: Instance)
	if not bot:IsA("Model") or bot:FindFirstChild(STATE_LABEL_NAME, true) then
		return
	end
	local head = bot:FindFirstChild("Head") or bot.PrimaryPart
	if not head or not head:IsA("BasePart") then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = STATE_LABEL_NAME
	gui.Size = UDim2.new(4, 0, 1, 0)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.Parent = overlayFolder

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Theme.Font
	label.TextColor3 = PATH_COLOR
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	local function refresh()
		label.Text = tostring(bot:GetAttribute("BotState") or "")
		gui.Enabled = bot.Parent ~= nil
	end
	refresh()
	table.insert(botConnections, bot:GetAttributeChangedSignal("BotState"):Connect(refresh))
	table.insert(botConnections, bot.AncestryChanged:Connect(refresh))
end

local function setOverlay(on: boolean)
	overlayOn = on
	statsPanel.Visible = on

	for _, connection in botConnections do
		connection:Disconnect()
	end
	botConnections = {}
	overlayFolder:ClearAllChildren()

	if not on then
		return
	end

	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, bot in bots:GetChildren() do
			labelBot(bot)
		end
		table.insert(botConnections, bots.ChildAdded:Connect(labelBot))
	end
end

local function onOverlayStats(counts: { [string]: number }?)
	if counts == nil then
		setOverlay(false)
		return
	end
	if not overlayOn then
		setOverlay(true)
	end

	Widgets.clear(statsList)
	local keys = {}
	for key in counts do
		table.insert(keys, key)
	end
	table.sort(keys)

	if #keys == 0 then
		Widgets.label("No rejected calls yet", { TextColor3 = Theme.Colors.TextDim }).Parent = statsList
	end
	for index, key in keys do
		local line = Widgets.label(`{key}: {counts[key]}`, {
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = index,
		})
		line.Parent = statsList
	end
end

local function buildPanel()
	panel = Widgets.panel({
		Visible = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 200, 0.7, 0),
	})
	panel.Parent = screen

	local title = Widgets.label("Showcase", { Font = Theme.Font, Size = UDim2.new(1, 0, 0, 28) })
	title.Parent = panel

	local list = Widgets.scrollList({ Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 1, -34) })
	list.Parent = panel

	for index, entry in BUTTONS do
		local label, command, args = entry[1], entry[2], entry[3]
		local button = Widgets.button(label, function()
			Remotes.Command:FireServer(command, args)
		end, { Size = UDim2.new(1, -8, 0, 38), LayoutOrder = index })
		button.Parent = list
	end

	statsPanel = Widgets.panel({
		Visible = false,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, 260, 0, 200),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.2,
	})
	statsPanel.Parent = screen

	local statsTitle = Widgets.label("Rejected remote calls", { Font = Theme.Font, Size = UDim2.new(1, 0, 0, 24) })
	statsTitle.Parent = statsPanel

	statsList = Widgets.scrollList({ Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 1, -28) })
	statsList.Parent = statsPanel
end

function ShowcaseController.init()
	screen = Widgets.screen("Showcase")
	overlayFolder = Instance.new("Folder")
	overlayFolder.Name = "DebugOverlay"
	overlayFolder.Parent = workspace
	buildPanel()
end

function ShowcaseController.start()
	Remotes.DebugDraw.OnClientEvent:Connect(onDebugDraw)
	Remotes.OverlayStats.OnClientEvent:Connect(onOverlayStats)

	local showcaseButton: TextButton? = nil
	local function refreshAdmin()
		local isAdmin = localPlayer:GetAttribute("IsAdmin") == true
		if isAdmin and not showcaseButton then
			showcaseButton = HudController.addButton("Showcase", 10, function()
				if panel.Visible then
					panel.Visible = false
				else
					Pop.show(panel)
				end
			end)
		elseif not isAdmin and showcaseButton then
			showcaseButton:Destroy()
			showcaseButton = nil
			panel.Visible = false
		end
	end
	refreshAdmin()
	localPlayer:GetAttributeChangedSignal("IsAdmin"):Connect(refreshAdmin)
end

return ShowcaseController
