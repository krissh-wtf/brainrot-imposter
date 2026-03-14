--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared: Folder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local ModuleLoader = require(Shared:WaitForChild("ModuleLoader"))

require(Shared:WaitForChild("Remotes"))

local controllers: { Instance } = script.Controllers:GetChildren()
ModuleLoader.launch(controllers)
