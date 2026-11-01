--!strict
--[[
	Currency

	The rules for changing a scrap balance. DataService.addScrap and
	DataService.trySpend are the only callers, and they are the only code
	that writes a player's scrap.

	Scrap is a whole number. Amounts must be positive whole numbers: zero,
	negatives, fractions, NaN and infinity are all refused. Refusing
	negatives matters most: "add -500" is how a sloppy API lets a player
	spend money they don't have, and "spend -500" is how it gives money away.

	Public API:
		Currency.MAX_BALANCE
		Currency.isValidAmount(amount): boolean
		Currency.add(balance, amount): (ok, newBalance)
		Currency.spend(balance, amount): (ok, newBalance)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validate = require(ReplicatedStorage.Shared.Util.Validate)

local Currency = {}

-- Far beyond anything the economy reaches, and well inside the range where
-- numbers are still exact whole numbers.
Currency.MAX_BALANCE = 1e15

function Currency.isValidAmount(amount: any): boolean
	return Validate.isPositiveInteger(amount) and amount <= Currency.MAX_BALANCE
end

function Currency.add(balance: number, amount: number): (boolean, number)
	if not Currency.isValidAmount(amount) then
		return false, balance
	end

	return true, math.min(Currency.MAX_BALANCE, balance + amount)
end

function Currency.spend(balance: number, amount: number): (boolean, number)
	-- DUPE-SAFE: the balance check and the deduction happen together, with
	-- no yield between, so two purchases can't both pass the check.
	if not Currency.isValidAmount(amount) or amount > balance then
		return false, balance
	end

	return true, balance - amount
end

return Currency
