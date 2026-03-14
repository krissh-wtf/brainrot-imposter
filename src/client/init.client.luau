local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModuleLoader = require(ReplicatedStorage.Shared.ModuleLoader)
local Iris = require(ReplicatedStorage.Packages.iris)

require(ReplicatedStorage.Shared.Remotes)

-- initialize Iris before controllers so any controller can connect to it
Iris.Init()

local controllers = script.Controllers:GetChildren()
ModuleLoader.launch(controllers)
