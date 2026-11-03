--!strict
--[[
	Validate

	Small type checks for values that arrive from clients. A remote's
	arguments can be anything an exploiter likes (NaN, huge numbers, tables
	where we expect a string), so every handler checks its inputs with these
	before using them.

	NaN is the classic trap: NaN ~= NaN, and every comparison with it is
	false, so a check like `amount > 0` alone can be slipped past.

	Public API:
		Validate.isFiniteNumber(value): boolean
		Validate.isPositiveInteger(value): boolean
		Validate.isNonNegativeInteger(value): boolean
		Validate.isShortString(value, maxLength): boolean
		Validate.isOneOf(value, allowed): boolean   -- value is a key in allowed
]]

local Validate = {}

function Validate.isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.isNonNegativeInteger(value: any): boolean
	return Validate.isFiniteNumber(value) and value >= 0 and value % 1 == 0
end

function Validate.isPositiveInteger(value: any): boolean
	return Validate.isNonNegativeInteger(value) and value > 0
end

function Validate.isShortString(value: any, maxLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maxLength
end

function Validate.isOneOf(value: any, allowed: { [any]: any }): boolean
	return value ~= nil and allowed[value] ~= nil
end

return Validate
