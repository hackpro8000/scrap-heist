--!strict
--[[
	Combat remotes

	Client to server (intent only; the server decides what happens):
		Attack()                    -- "I want to swing"
		SetBlocking(isBlocking)     -- "I'm holding / released block"
		EquipWeapon(weaponName)     -- "switch to this weapon"

	Server to client:
		PlaySwing(model, weaponName, stepIndex)   -- all clients: animate a swing
		HitEffect(model, outcome, damage, attacker)   -- all clients: show a hit
		Knockback(velocity)                       -- the hit player's client only
]]

local Net = require(script.Parent.Parent.Net.Net)

local SYSTEM = "Combat"

return {
	Attack = Net.event(SYSTEM, "Attack"),
	SetBlocking = Net.event(SYSTEM, "SetBlocking"),
	EquipWeapon = Net.event(SYSTEM, "EquipWeapon"),
	PlaySwing = Net.event(SYSTEM, "PlaySwing"),
	HitEffect = Net.event(SYSTEM, "HitEffect"),
	Knockback = Net.event(SYSTEM, "Knockback"),
}
