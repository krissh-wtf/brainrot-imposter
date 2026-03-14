-- écrit les stats dans des OrderedDataStore pour le classement global
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)

local logger = Logger.new("LeaderboardUpdater")

local updateInterval = 60

-- noms frais pour éviter les anciennes données
local orderedStores = {
  Coins = DataStoreService:GetOrderedDataStore("BRI_LB_Coins_v2"),
  Wins = DataStoreService:GetOrderedDataStore("BRI_LB_Wins_v2"),
  TimePlayed = DataStoreService:GetOrderedDataStore("BRI_LB_TimePlayed_v2"),
}

local function getStatValue(player: Player, statName: string): number?
  -- Coins et Wins sont dans leaderstats, TimePlayed dans PlayerStats
  local folder = if statName == "TimePlayed"
    then player:FindFirstChild("PlayerStats")
    else player:FindFirstChild("leaderstats")

  if not folder then
    return nil
  end

  local stat = folder:FindFirstChild(statName)
  if not stat then
    return nil
  end

  return stat.Value
end

local function updateAll()
  for _, player in Players:GetPlayers() do
    local key = tostring(player.UserId)

    for statName, store in orderedStores do
      local value = getStatValue(player, statName)
      if not value or value <= 0 then
        continue
      end

      local ok, err = pcall(function()
        store:SetAsync(key, value)
      end)

      if not ok then
        logger:log("error", "updateAll", {
          player = player.Name,
          stat = statName,
          error = tostring(err),
        })
      end
    end
  end
end

local roche = {
  context = "once",

  setup = function()
    task.spawn(function()
      while true do
        task.wait(updateInterval)
        updateAll()
        logger:log("info", "cycle", { status = "done" })
      end
    end)

    logger:log("success", "setup", { status = "ok" })
  end,

  loop = function() end,
}

return roche
