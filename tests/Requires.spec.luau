--!strict
-- Resolves every require() in src/ to a file, the way Roblox would, and
-- checks the require graph has no cycles (Roblox refuses circular
-- requires). Catches typos and loops in services and controllers that
-- can't run outside Studio.
local fs = require("@lune/fs")

local Source = require("./Source")
local Test = require("./Test")

local describe, it = Test.describe, Test.it

-- Wally packages aren't in src/; these roots are skipped.
local EXTERNAL_ROOTS = { ServerStorage = true }

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

-- The fake Instance that `script` is for a file.
local function scriptInstance(file: string): any
	local folderScript = string.match(file, "^(.*)/init[%.%w]*%.luau$")
	return Source.instance(folderScript or string.sub(file, 1, -6))
end

local function split(chain: string): { string }
	local parts = {}
	for part in string.gmatch(chain, "[^%.]+") do
		table.insert(parts, part)
	end

	return parts
end

-- Returns the file a require chain points at, nil for external packages,
-- or errors with a readable message.
local function resolve(file: string, text: string, chain: string, depth: number?): string?
	local parts = split(chain)
	local root = parts[1]
	local node: any

	if root == "script" then
		node = scriptInstance(file)
	elseif root == "ReplicatedStorage" then
		node = Source.instance("src/shared")
		assert(parts[2] == "Shared", `{file}: only ReplicatedStorage.Shared is mapped, got {chain}`)
		table.remove(parts, 2)
	elseif EXTERNAL_ROOTS[root] then
		return nil
	else
		-- A local alias, like `local Services = script.Services`.
		local aliased = string.match(text, `local {root} = ([%w_%.]+)\n`)
		assert(aliased and (depth or 0) < 3, `{file}: can't resolve require({chain})`)
		local rest = table.concat(parts, ".", 2)
		local expanded = if rest == "" then aliased else `{aliased}.{rest}`
		return resolve(file, text, expanded, (depth or 0) + 1)
	end

	for index = 2, #parts do
		local ok, child = pcall(function()
			return node[parts[index]]
		end)
		assert(ok and child, `{file}: require({chain}) breaks at "{parts[index]}"`)
		node = child
	end

	local target = Source.fileOf(node)
	assert(target, `{file}: require({chain}) points at a folder, not a module`)
	return target
end

local files = luauFiles("src", {})
table.sort(files)
local texts: { [string]: string } = {}
for _, file in files do
	texts[file] = fs.readFile(file)
end

local edges: { [string]: { string } } = {}

describe("Requires", function()
	for _, file in files do
		it(`resolve in {file}`, function()
			edges[file] = {}
			for chain in string.gmatch(texts[file], "require%(([%w_%.]+)%)") do
				local target = resolve(file, texts[file], chain)
				if target then
					table.insert(edges[file], target)
				end
			end
		end)
	end

	it("form no cycles", function()
		local state: { [string]: string } = {}
		local stack: { string } = {}

		local function visit(file: string)
			if state[file] == "done" then
				return
			end
			if state[file] == "visiting" then
				local start = table.find(stack, file) or 1
				local loop = table.concat(stack, " -> ", start) .. " -> " .. file
				error(`circular require: {loop}`)
			end

			state[file] = "visiting"
			table.insert(stack, file)
			for _, target in edges[file] or {} do
				visit(target)
			end
			table.remove(stack)
			state[file] = "done"
		end

		for _, file in files do
			visit(file)
		end
	end)
end)
