local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roches = require(Shared:WaitForChild("Roches"))

require(Shared:WaitForChild("Remotes"))

local Controllers = script.Controllers:GetChildren()
Roches.launch(Controllers)
