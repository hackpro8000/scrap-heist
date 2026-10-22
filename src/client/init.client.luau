--!strict
--[[
	Client entry point

	The only client LocalScript. Requires every controller in boot order and
	hands them to Boot, which calls all init()s and then all start()s.

	To add a controller: require it below and add it to CONTROLLERS in the
	spot where its dependencies have already booted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boot = require(ReplicatedStorage.Shared.Util.Boot)

local CONTROLLERS: { Boot.Entry } = {}

Boot.run("Client", CONTROLLERS)
