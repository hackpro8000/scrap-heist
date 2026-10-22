--!strict
--[[
	Server entry point

	The only server Script. Requires every service in boot order and hands
	them to Boot, which calls all init()s and then all start()s.

	To add a service: require it below and add it to SERVICES in the spot
	where its dependencies have already booted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boot = require(ReplicatedStorage.Shared.Util.Boot)

local SERVICES: { Boot.Entry } = {}

Boot.run("Server", SERVICES)
