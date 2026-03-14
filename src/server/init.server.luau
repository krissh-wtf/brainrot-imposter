--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModuleLoader = require(ReplicatedStorage.Shared.ModuleLoader)

require(ReplicatedStorage.Shared.Remotes)

local services = script.Services:GetChildren()
ModuleLoader.launch(services)
