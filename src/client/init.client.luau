local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roches = require(ReplicatedStorage.Shared.Roches)

local Controllers = script.Controllers:GetChildren()
Roches.launch(Controllers)
