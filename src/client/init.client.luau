local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModuleLoader = require(ReplicatedStorage.Shared.ModuleLoader)

require(ReplicatedStorage.Shared.Remotes)

local controllers = script.Controllers:GetChildren()
ModuleLoader.launch(controllers)
