--!strict
--[[
	HeldWeaponService

	Puts the weapon a fighter is holding in its right hand, so everyone sees
	what it's swinging. Weapon models come from ServerStorage.WeaponModels,
	named after the weapon (WeaponModels.Bat, WeaponModels.Spanner), each
	with a "Grip" attachment where the hand closes and the weapon running
	along the attachment's Y axis. tools/studio/PlaceModels.luau puts them
	there from the uploaded art.

	Weapons with no model, and fighters with no right hand (bots carry
	their weapons built in), simply show nothing. Putting a weapon away
	(CombatService.weaponChanged with nil) takes the model out of the hand.

	Public API: none.
]]

local ServerStorage = game:GetService("ServerStorage")

local CombatService = require(script.Parent.CombatService)

local MODELS_FOLDER = "WeaponModels"
local HELD_NAME = "HeldWeapon"
local HANDS = { "RightHand", "Right Arm" }
-- From the hand's grip to the weapon's: the weapon points forward out of
-- the fist instead of down along the arm.
local POINT_FORWARD = CFrame.Angles(-math.pi / 2, 0, 0)
-- How long a new character's hand gets to arrive: CombatService registers
-- a character once its root is in, which can be before its limbs are.
local HAND_WAIT = 5

local HeldWeaponService = {}

local function handOf(model: Model): BasePart?
	for _, name in HANDS do
		local hand = model:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			return hand
		end
	end
	return nil
end

local function templateFor(weaponName: string?): Model?
	local folder = ServerStorage:FindFirstChild(MODELS_FOLDER)
	local template = folder and weaponName and folder:FindFirstChild(weaponName)
	return if template and template:IsA("Model") then template else nil
end

local function showWeapon(model: Model, weaponName: string?)
	local held = model:FindFirstChild(HELD_NAME)
	if held then
		held:Destroy()
	end

	local hand = handOf(model)
	local template = templateFor(weaponName)
	local grip = template and template.PrimaryPart and template.PrimaryPart:FindFirstChild("Grip")
	if not (hand and template and grip and grip:IsA("Attachment")) then
		return
	end

	local weapon = template:Clone()
	weapon.Name = HELD_NAME
	local handle = weapon.PrimaryPart :: BasePart
	local handGrip = hand:FindFirstChild("RightGripAttachment")
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = handle
	-- Only the grip's position: R15's RightGripAttachment comes turned,
	-- and the turn here is the one that counts.
	local fist = if handGrip and handGrip:IsA("Attachment") then handGrip.Position else Vector3.zero
	weld.C0 = CFrame.new(fist) * POINT_FORWARD
	weld.C1 = grip.CFrame
	weld.Parent = handle
	weapon.Parent = model
end

function HeldWeaponService.init() end

local function onWeaponChanged(model: Model, weaponName: string?)
	if handOf(model) or not weaponName then
		showWeapon(model, weaponName)
		return
	end
	task.spawn(function()
		model:WaitForChild(HANDS[1], HAND_WAIT)
		-- Only if nothing changed while waiting.
		if model:GetAttribute("Weapon") == weaponName then
			showWeapon(model, weaponName)
		end
	end)
end

function HeldWeaponService.start()
	CombatService.weaponChanged:connect(onWeaponChanged)
end

return HeldWeaponService
