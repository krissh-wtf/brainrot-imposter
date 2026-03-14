--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local remoteNames: { string } = {
  "StateChanged",
  "SubmitHint",
  "CastVote",
  "ToggleAfk",
  "GuessWord",
  "PlayerInput",
}

-- server creates, client fetches
if RunService:IsServer() then
  local folder = Instance.new("Folder")
  folder.Name = "ImposterRemotes"
  folder.Parent = ReplicatedStorage

  for _, name in remoteNames do
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = folder
  end
end

function Remotes.get(name: string): RemoteEvent
  local folder = ReplicatedStorage:WaitForChild("ImposterRemotes")
  return folder:WaitForChild(name) :: RemoteEvent
end

return table.freeze(Remotes)
