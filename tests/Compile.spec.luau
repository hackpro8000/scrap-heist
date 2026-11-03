--!strict
-- Compiles every file in src/, including services and controllers that
-- can't run outside Roblox, so a syntax error anywhere fails the suite
-- before it reaches Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Test = require("./Test")

local describe, it = Test.describe, Test.it

local function luauFiles(directory: string, found: { string }): { string }
	for _, name in fs.readDir(directory) do
		local path = `{directory}/{name}`
		if fs.isDir(path) then
			luauFiles(path, found)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(found, path)
		end
	end

	return found
end

local files = luauFiles("src", {})
table.sort(files)
local sources = {}
for _, path in files do
	sources[path] = fs.readFile(path)
end

describe("Compile", function()
	for _, path in files do
		it(path, function()
			luau.compile(sources[path])
		end)
	end
end)
