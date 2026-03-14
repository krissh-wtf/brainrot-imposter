local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roches = require(Shared:WaitForChild("Roches"))

-- create remotes before services boot
require(Shared:WaitForChild("Remotes"))

local Services = script.Services:GetChildren()
Roches.launch(Services)
