local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roches = require(ReplicatedStorage.Shared.Roches)

local Services = script.Services:GetChildren()
Roches.launch(Services)
