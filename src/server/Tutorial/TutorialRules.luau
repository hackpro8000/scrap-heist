--!strict
--[[
	TutorialRules

	Which tutorial step a player is on, from the steps they've finished
	(saved in profile.tutorial). Steps go in order; a tip tied to a round
	phase waits, without blocking anything, until that phase comes round.

	Public API:
		TutorialRules.currentStep(done, phase): Step?
		TutorialRules.canDismiss(done, phase, stepName): boolean
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)

local TutorialRules = {}

function TutorialRules.currentStep(done: { [string]: boolean }, phase: string): Tutorial.Step?
	for _, step in Tutorial.STEPS do
		if not done[step.name] then
			if step.showDuring == nil or step.showDuring == phase then
				return step
			end
			-- A phase-tied tip that isn't due yet: skip it for now, so the
			-- player isn't stuck with no prompt while waiting for a storm.
		end
	end

	return nil
end

-- SECURITY: clients can only dismiss the tip they are being shown, never
-- skip an action step.
function TutorialRules.canDismiss(done: { [string]: boolean }, phase: string, stepName: any): boolean
	local step = TutorialRules.currentStep(done, phase)
	return step ~= nil and step.kind == "Tip" and step.name == stepName
end

return TutorialRules
