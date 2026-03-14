--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Logger = require(ReplicatedStorage.Shared.Logger)
local ProfileStore = require(ServerScriptService.ServerPackages.profilestore)

local logger = Logger.create("PlayerData")

local profileTemplate = {
  Coins = 0,
  Wins = 0,
  TimePlayed = 0,
}

local playerStore = ProfileStore.New("PlayerData_v1", profileTemplate)
local profiles: { [Player]: typeof(playerStore:StartSessionAsync("nil", {})) } = {}

local function setupPlayerStats(player: Player, profile: typeof(playerStore:StartSessionAsync("nil", {})))
  local leaderstats: Folder = Instance.new("Folder")
  leaderstats.Name = "leaderstats"
  leaderstats.Parent = player

  local coins: IntValue = Instance.new("IntValue")
  coins.Name = "Coins"
  coins.Value = profile.Data.Coins
  coins.Parent = leaderstats

  local wins: IntValue = Instance.new("IntValue")
  wins.Name = "Wins"
  wins.Value = profile.Data.Wins
  wins.Parent = leaderstats

  local playerStats: Folder = Instance.new("Folder")
  playerStats.Name = "PlayerStats"
  playerStats.Parent = player

  local timePlayed: IntValue = Instance.new("IntValue")
  timePlayed.Name = "TimePlayed"
  timePlayed.Value = profile.Data.TimePlayed
  timePlayed.Parent = playerStats
end

local function onPlayerAdded(player: Player)
  local profile = playerStore:StartSessionAsync(`{player.UserId}`, {
    Cancel = function()
      return player.Parent ~= Players
    end,
  })

  if not profile then
    logger.log("error", "onPlayerAdded", { error = `profile nil for {player.Name}` })
    player:Kick("Failed to load data, please reconnect.")
    return
  end

  profile:AddUserId(player.UserId)
  profile:Reconcile()

  profile.OnSessionEnd:Connect(function()
    profiles[player] = nil
    player:Kick("Session ended, please reconnect.")
  end)

  if player.Parent ~= Players then
    profile:EndSession()
    return
  end

  profiles[player] = profile
  setupPlayerStats(player, profile)
  logger.log("success", "onPlayerAdded", { player = player.Name })
end

local function onPlayerRemoving(player: Player)
  local profile = profiles[player]
  if not profile then
    return
  end

  -- sync stats to profile before saving
  local leaderstats: Instance? = player:FindFirstChild("leaderstats")
  if leaderstats then
    profile.Data.Coins = (leaderstats :: Folder):FindFirstChild("Coins") and (leaderstats :: any).Coins.Value or 0
    profile.Data.Wins = (leaderstats :: Folder):FindFirstChild("Wins") and (leaderstats :: any).Wins.Value or 0
  end

  local playerStats: Instance? = player:FindFirstChild("PlayerStats")
  if playerStats then
    profile.Data.TimePlayed = (playerStats :: any).TimePlayed.Value
  end

  profile:EndSession()
end

-- module interface
local roche = {
  context = "once",

  setup = function()
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    for _, player: Player in Players:GetPlayers() do
      task.spawn(onPlayerAdded, player)
    end

    -- increment play time every second for active profiles
    task.spawn(function()
      while true do
        task.wait(1)
        for player: Player, profile in profiles do
          if not profile:IsActive() then
            continue
          end
          profile.Data.TimePlayed += 1
          local playerStats: Instance? = player:FindFirstChild("PlayerStats")
          if playerStats then
            (playerStats :: any).TimePlayed.Value = profile.Data.TimePlayed
          end
        end
      end
    end)

    logger.log("success", "setup", { status = "ok" })
  end,

  loop = function() end,
}

function roche.getProfile(player: Player)
  return profiles[player]
end

return roche
