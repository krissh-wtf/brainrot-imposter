--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared: Folder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local ModuleLoader = require(Shared:WaitForChild("ModuleLoader"))

-- create remotes before services boot
require(Shared:WaitForChild("Remotes"))

local services: { Instance } = script.Services:GetChildren()
ModuleLoader.launch(services)
