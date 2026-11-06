--!strict
--[[
	Format

	Numbers as players read them.

	Public API:
		Format.short(number): string   -- 950, 1.2K, 34.5M, 2B, 1.5T
]]

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa" }

function Format.short(value: number): string
	local sign = if value < 0 then "-" else ""
	local amount = math.abs(value)
	if amount < 1000 then
		-- Small rates keep one decimal (1.4/s); whole numbers show none.
		local rounded = math.floor(amount * 10 + 0.5) / 10
		return sign .. (if rounded % 1 == 0 then string.format("%d", rounded) else string.format("%.1f", rounded))
	end

	local index = math.min(#SUFFIXES, math.floor(math.log10(amount) / 3))
	local scaled = amount / 1000 ^ index
	-- Cut, don't round up: 999,999 reads 999.9K, never 1000K.
	local cut = math.floor(scaled * 10) / 10
	local text = if cut % 1 == 0 or cut >= 100 then string.format("%d", math.floor(cut)) else string.format("%.1f", cut)

	return sign .. text .. SUFFIXES[index]
end

return Format
