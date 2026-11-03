--!strict
--[[
	Test runner

	Runs every *.spec.luau file under tests/ with Lune, outside Roblox
	Studio. Game logic that doesn't need the engine (timing, currency,
	trades, rounds, loot) is checked here. Anything that does need it
	(physics, replication, pathfinding, saves) stays on the Studio
	checklists in docs/testing/.

	Usage, from the repo root:
		lune run tests/run            -- every spec
		lune run tests/run Signal     -- only specs whose path contains "Signal"

	Exits with code 1 if any test fails or a spec can't load.

	Spec layout mirrors src: tests/shared/Util/Signal.spec.luau tests
	src/shared/Util/Signal.luau. Specs load game code with Source.luau and
	use Test.luau and Roblox.luau from this folder.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Roblox = require("./Roblox")
local Test = require("./Test")

local TESTS_DIR = "tests"
local SPEC_SUFFIX = ".spec.luau"

local function findSpecs(directory: string, found: { string }): { string }
	for _, name in fs.readDir(directory) do
		local path = `{directory}/{name}`
		if fs.isDir(path) then
			findSpecs(path, found)
		elseif string.sub(name, -#SPEC_SUFFIX) == SPEC_SUFFIX then
			table.insert(found, path)
		end
	end

	return found
end

local function colored(color: string, text: string): string
	return stdio.color(color :: any) .. text .. stdio.color("reset")
end

if not fs.isDir(TESTS_DIR) then
	print("Run from the repo root: lune run tests/run")
	process.exit(1)
end

Roblox.install()

local filter = process.args[1]
local specs = findSpecs(TESTS_DIR, {})
table.sort(specs)

local passed = 0
local failed = 0

for _, specPath in specs do
	if filter and not string.find(specPath, filter, 1, true) then
		continue
	end

	print(specPath)

	-- require() resolves relative to this file, which sits in tests/.
	local modulePath = "./" .. string.sub(specPath, #TESTS_DIR + 2, -#".luau" - 1)
	local loaded, loadError = pcall(require, modulePath)
	local cases = Test.collect()

	if not loaded then
		failed += 1
		print(`  {colored("red", "FAIL")} could not load spec`)
		print(`       {loadError}`)
		continue
	end

	for _, case in cases do
		local ok, message = pcall(case.body)
		if ok then
			passed += 1
			print(`  {colored("green", "ok")}   {case.name}`)
		else
			failed += 1
			print(`  {colored("red", "FAIL")} {case.name}`)
			print(`       {message}`)
		end
	end
end

local summary = `{passed} passed, {failed} failed`
print(if failed > 0 then colored("red", summary) else colored("green", summary))

process.exit(if failed > 0 then 1 else 0)
