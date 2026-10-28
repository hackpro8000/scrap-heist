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
	if fs.isFile(path .. ".luau") then
		file = path .. ".luau"
	elseif fs.isFile(path .. "/init.luau") then
		file = path .. "/init.luau"
	elseif fs.isFile(path .. "/init.server.luau") then
		file = path .. "/init.server.luau"
	elseif fs.isFile(path .. "/init.client.luau") then
		file = path .. "/init.client.luau"
	elseif not fs.isDir(path) then
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
	local chunk = luau.load(fs.readFile(file), {
		debugName = file,
		-- Lune adds the runner's globals (task, game, Vector3, print) on top
		-- of this, so the module sees the fakes from tests/Roblox.luau.
		environment = {
			script = target,
			require = sourceRequire,
		},
	})
	local result = chunk()
	loading[file] = nil
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
