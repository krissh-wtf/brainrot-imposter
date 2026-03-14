local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)

local logger = Logger.new("LeaderboardAPI")

local maxEntries = 100
local cacheDuration = 30

local orderedStores = {
  Coins = DataStoreService:GetOrderedDataStore("BRI_LB_Coins_v2"),
  Wins = DataStoreService:GetOrderedDataStore("BRI_LB_Wins_v2"),
  TimePlayed = DataStoreService:GetOrderedDataStore("BRI_LB_TimePlayed_v2"),
}

local cache: { [string]: { data: {}, timestamp: number } } = {}

local function fetchLeaderboard(statName: string)
  local cached = cache[statName]
  if cached and os.clock() - cached.timestamp < cacheDuration then
    return cached.data
  end

  local store = orderedStores[statName]
  if not store then
    return {}
  end

  local ok, pages = pcall(function()
    return store:GetSortedAsync(false, maxEntries)
  end)

  if not ok or not pages then
    logger:log("error", "fetchLeaderboard", { stat = statName, error = tostring(pages) })
    return cached and cached.data or {}
  end

  local entries = {}

  for rank, entry in pages:GetCurrentPage() do
    local userId = tonumber(entry.key)
    local playerName = "[???]"
    -- dcp on prend le nom du joueur si il est en ligne sinon on prend avk GetNameFromUserIdAsync, pr pas avoir les ??? chelou
    if userId then
      local onlinePlayer = Players:GetPlayerByUserId(userId)
      if onlinePlayer then
        playerName = onlinePlayer.DisplayName
      else
        local nameOk, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
        if nameOk then
          playerName = name
        end
      end
    end

    table.insert(entries, {
      rank = rank,
      name = playerName,
      value = entry.value,
      userId = userId,
    })
  end

  cache[statName] = { data = entries, timestamp = os.clock() }
  return entries
end

local roche = {
  context = "once",

  setup = function()
    local remote = Instance.new("RemoteFunction")
    remote.Name = "GetLeaderboardData"
    remote.Parent = ReplicatedStorage

    remote.OnServerInvoke = function()
      local result = {}
      for statName in orderedStores do
        result[statName] = fetchLeaderboard(statName)
      end
      return result
    end

    logger:log("success", "setup", { status = "ok" })
  end,

  loop = function() end,
}

return roche
