--!strict
--[[
	Source

	Loads modules from src/ the way Roblox would, so game code keeps normal
	Roblox requires (require(script.Parent.Foo), ReplicatedStorage.Shared.Foo)
	and still runs under Lune.

	Every file and folder in src/ is stood in for by a small fake Instance.
	Indexing a fake by name finds the child file or folder, Parent goes up a
	folder, and require() on a fake runs that file with `script` set to it.
	Which src/ folder appears where in the game (ReplicatedStorage.Shared,
	ServerScriptService.Server) is mapped in tests/Roblox.luau, matching
	default.project.json.

	Public API:
		Source.require(path)    -- run a module by repo path, without .luau
		Source.instance(path)   -- the fake Instance for a file or folder
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Source = {}

type FakeInfo = {
	path: string,
	name: string,
	-- The file require() runs: the .luau file, or a folder's init.luau.
	file: string?,
}

-- src/ is read once up front: Lune's file functions can yield, and a
-- yield isn't allowed inside the __index lookups that resolve requires.
local SOURCE_ROOT = "src"
local fileContents: { [string]: string } = {}
local directories: { [string]: boolean } = {}

local function scan(directory: string)
	directories[directory] = true
	for _, name in fs.readDir(directory) do
		local path = `{directory}/{name}`
		if fs.isDir(path) then
			scan(path)
		elseif string.sub(name, -5) == ".luau" then
			fileContents[path] = fs.readFile(path)
		end
	end
end

scan(SOURCE_ROOT)

-- One fake per path, so the same file always gives the same Instance.
local fakesByPath: { [string]: any } = {}
local infoByFake: { [any]: FakeInfo } = {}
local loaded: { [string]: any } = {}
local loading: { [string]: boolean } = {}

local sourceRequire: (target: any) -> any

local function parentPath(path: string): string?
	return string.match(path, "^(.*)/[^/]+$")
end

local function fakeFor(path: string): any
	local existing = fakesByPath[path]
	if existing then
		return existing
	end

	local file: string? = nil
	local candidates = {
		path .. ".luau",
		path .. "/init.luau",
		path .. "/init.server.luau",
		path .. "/init.client.luau",
	}
	for _, candidate in candidates do
		if fileContents[candidate] then
			file = candidate
			break
		end
	end
	if not file and not directories[path] then
		return nil
	end

	local info: FakeInfo = {
		path = path,
		name = string.match(path, "[^/]+$") or path,
		file = file,
	}

	local function child(name: string): any
		return fakeFor(`{path}/{name}`)
	end

	local fake = setmetatable({}, {
		__index = function(_self, key: string): any
			if key == "Name" then
				return info.name
			elseif key == "Parent" then
				local parent = parentPath(path)
				return if parent then fakeFor(parent) else nil
			elseif key == "FindFirstChild" then
				return function(_fake: any, name: string)
					return child(name)
				end
			elseif key == "WaitForChild" then
				return function(_fake: any, name: string)
					return child(name) or error(`Source: {name} is not a child of {path}`, 2)
				end
			end

			return child(key) or error(`Source: {key} is not a valid member of {path}`, 2)
		end,
		__tostring = function()
			return info.name
		end,
	})

	fakesByPath[path] = fake
	infoByFake[fake] = info

	return fake
end

sourceRequire = function(target: any): any
	local info = infoByFake[target]
	if not info then
		error("Source: game code must require an Instance (script.Parent.X), got " .. typeof(target), 2)
	end

	local file = info.file
	if not file then
		error(`Source: {info.path} is a folder, not a module`, 2)
	end

	if loaded[file] ~= nil then
		return loaded[file]
	end
	if loading[file] then
		error(`Source: circular require of {file}`, 2)
	end

	loading[file] = true
	local chunk = luau.load(fileContents[file], {
		debugName = file,
		-- Lune adds the runner's globals (task, game, Vector3, print) on top
		-- of this, so the module sees the fakes from tests/Roblox.luau.
		environment = {
			script = target,
			require = sourceRequire,
		},
	})
	local ok, result = pcall(chunk)
	loading[file] = nil
	if not ok then
		error(result, 0)
	end
	loaded[file] = if result == nil then true else result

	return loaded[file]
end

function Source.instance(path: string): any
	return fakeFor(path) or error(`Source: nothing at {path}`, 2)
end

function Source.require(path: string): any
	return sourceRequire(Source.instance(path))
end

return Source
