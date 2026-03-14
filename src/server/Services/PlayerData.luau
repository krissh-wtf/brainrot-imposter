local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Logger = require(ReplicatedStorage.Shared.Logger)
local ProfileStore = require(ServerScriptService.ServerPackages.profilestore)

local logger = Logger.new("PlayerData")

local profileTemplate = {
  Coins = 0,
  Wins = 0,
  TimePlayed = 0,
}

local playerStore = ProfileStore.New("PlayerData_v1", profileTemplate)
local profiles: { [Player]: typeof(playerStore:StartSessionAsync()) } = {}

local function setupPlayerStats(player: Player, profile)
  -- leaderstats tab
  local leaderstats = Instance.new("Folder")
  leaderstats.Name = "leaderstats"
  leaderstats.Parent = player

  local coins = Instance.new("IntValue")
  coins.Name = "Coins"
  coins.Value = profile.Data.Coins
  coins.Parent = leaderstats

  local wins = Instance.new("IntValue")
  wins.Name = "Wins"
  wins.Value = profile.Data.Wins
  wins.Parent = leaderstats

  -- PlayerStats
  local playerStats = Instance.new("Folder")
  playerStats.Name = "PlayerStats"
  playerStats.Parent = player

  local timePlayed = Instance.new("IntValue")
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
    logger:log("error", "onPlayerAdded", { error = `profile nil pour {player.Name}` })
    player:Kick("Erreur de chargement, reconnecte-toi.")
    return
  end

  profile:AddUserId(player.UserId)
  profile:Reconcile()

  profile.OnSessionEnd:Connect(function()
    profiles[player] = nil
    player:Kick("Session data terminée, reconnecte-toi.")
  end)

  if player.Parent ~= Players then
    profile:EndSession()
    return
  end

  profiles[player] = profile
  setupPlayerStats(player, profile)
  logger:log("success", "onPlayerAdded", { player = player.Name })
end

local function onPlayerRemoving(player: Player)
  local profile = profiles[player]
  if not profile then
    return
  end

  -- sync vers le profil avant de save
  local leaderstats = player:FindFirstChild("leaderstats")
  if leaderstats then
    profile.Data.Coins = leaderstats.Coins.Value
    profile.Data.Wins = leaderstats.Wins.Value
  end

  local playerStats = player:FindFirstChild("PlayerStats")
  if playerStats then
    profile.Data.TimePlayed = playerStats.TimePlayed.Value
  end

  profile:EndSession()
end

local roche = {
  context = "once",

  setup = function()
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    for _, player in Players:GetPlayers() do
      task.spawn(onPlayerAdded, player)
    end

    -- pr incrementer le temp jeu tous les secondes, on check si le profil est actif pr eviter les incrementations chelou
    task.spawn(function()
      while true do
        task.wait(1)
        for player, profile in profiles do
          if not profile:IsActive() then
            continue
          end
          profile.Data.TimePlayed += 1
          local playerStats = player:FindFirstChild("PlayerStats")
          if playerStats then
            playerStats.TimePlayed.Value = profile.Data.TimePlayed
          end
        end
      end
    end)

    logger:log("success", "setup", { status = "ok" })
  end,

  loop = function() end,
}

function roche.getProfile(player: Player)
  return profiles[player]
end

return roche
