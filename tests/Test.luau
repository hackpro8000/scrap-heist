--!strict
--[[
	Test

	A tiny test library for specs run under Lune (see tests/run.luau). It has
	only what our specs need, so anyone reading a spec can see exactly what
	each line does without learning a framework.

	Spec files call describe() and it() when they load, which registers
	tests. The runner then takes the registered tests with collect() and
	runs each one. A test passes if its body finishes without an error.

	Public API:
		Test.describe(name, body)                 -- group tests; groups can nest
		Test.it(name, body)                       -- register one test
		Test.expect(actual).toBe(expected)        -- equal with ==
		Test.expect(actual).toEqual(expected)     -- equal by contents, for tables
		Test.expect(callback).toThrow(fragment?)  -- callback errors, message contains fragment
		Test.collect(): { Case }                  -- runner only: take registered tests
]]

local Test = {}

export type Case = {
	name: string,
	body: () -> (),
}

export type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toThrow: (fragment: string?) -> (),
}

-- Tables nested deeper than this print as {...} in failure messages.
local MAX_SHOW_DEPTH = 3

local cases: { Case } = {}
local groupPath: { string } = {}

local function show(value: any, depth: number): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	if type(value) ~= "table" then
		return tostring(value)
	end
	if depth >= MAX_SHOW_DEPTH then
		return "{...}"
	end

	local parts = {}
	for key, item in value do
		table.insert(parts, `[{show(key, depth + 1)}] = {show(item, depth + 1)}`)
	end
	-- Sort so the same table always prints the same way.
	table.sort(parts)

	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end

	return true
end

function Test.describe(name: string, body: () -> ())
	table.insert(groupPath, name)
	body()
	table.remove(groupPath)
end

function Test.it(name: string, body: () -> ())
	local path = table.clone(groupPath)
	table.insert(path, name)
	table.insert(cases, { name = table.concat(path, " > "), body = body })
end

-- Errors use level 2 so the reported line is the spec's expect() call,
-- not a line inside this file.
function Test.expect(actual: any): Expectation
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				error(`expected {show(expected, 0)}, got {show(actual, 0)}`, 2)
			end
		end,

		toEqual = function(expected: any)
			if not deepEqual(actual, expected) then
				error(`expected {show(expected, 0)}, got {show(actual, 0)}`, 2)
			end
		end,

		toThrow = function(fragment: string?)
			local ok, message = pcall(actual)
			if ok then
				error("expected an error, but none was thrown", 2)
			end
			if fragment and not string.find(tostring(message), fragment, 1, true) then
				error(`expected an error containing {show(fragment, 0)}, got {show(tostring(message), 0)}`, 2)
			end
		end,
	}
end

function Test.collect(): { Case }
	local collected = cases
	cases = {}
	-- A spec that errored mid-describe leaves its group open; drop it.
	table.clear(groupPath)

	return collected
end

return Test
