--!strict

-- Serves leaderboard data to clients via a RemoteFunction, with caching

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)

local logger = Logger.create("LeaderboardAPI")

local MAX_ENTRIES: number = 100
local CACHE_DURATION: number = 30

type LeaderboardEntry = {
  rank: number,
  name: string,
  value: number,
  userId: number?,
}

type CacheEntry = {
  data: { LeaderboardEntry },
  timestamp: number,
}

local orderedStores: { [string]: OrderedDataStore } = {
  Coins = DataStoreService:GetOrderedDataStore("BRI_LB_Coins_v2"),
  Wins = DataStoreService:GetOrderedDataStore("BRI_LB_Wins_v2"),
  TimePlayed = DataStoreService:GetOrderedDataStore("BRI_LB_TimePlayed_v2"),
}

local cache: { [string]: CacheEntry } = {}

local function fetchLeaderboard(statName: string): { LeaderboardEntry }
  local cached: CacheEntry? = cache[statName]
  if cached and os.clock() - (cached :: CacheEntry).timestamp < CACHE_DURATION then
    return (cached :: CacheEntry).data
  end

  local store: OrderedDataStore? = orderedStores[statName]
  if not store then
    return {}
  end

  local ok: boolean, pages: any = pcall(function()
    return (store :: OrderedDataStore):GetSortedAsync(false, MAX_ENTRIES)
  end)

  if not ok or not pages then
    logger.log("error", "fetchLeaderboard", { stat = statName, error = tostring(pages) })
    return if cached then (cached :: CacheEntry).data else {}
  end

  local entries: { LeaderboardEntry } = {}

  for rank: number, entry in pages:GetCurrentPage() do
    local userId: number? = tonumber(entry.key)
    local playerName: string = "[???]"

    -- resolve name from online player first, then from API
    if userId then
      local onlinePlayer: Player? = Players:GetPlayerByUserId(userId :: number)
      if onlinePlayer then
        playerName = (onlinePlayer :: Player).DisplayName
      else
        local nameOk: boolean, name: string = pcall(Players.GetNameFromUserIdAsync, Players, userId :: number)
        if nameOk then
          playerName = name
        end
      end
    end

    table.insert(
      entries,
      {
        rank = rank,
        name = playerName,
        value = entry.value,
        userId = userId,
      } :: LeaderboardEntry
    )
  end

  cache[statName] = { data = entries, timestamp = os.clock() }
  return entries
end

-- module interface
return {
  context = "once",

  setup = function()
    local remote: RemoteFunction = Instance.new("RemoteFunction")
    remote.Name = "GetLeaderboardData"
    remote.Parent = ReplicatedStorage

    -- rate limit per player to prevent spam
    local lastRequest: { [Player]: number } = {}

    remote.OnServerInvoke = function(player: Player): { [string]: { LeaderboardEntry } }
      local now: number = os.clock()
      if lastRequest[player] and now - lastRequest[player] < 5 then
        -- return cached data if spamming
        local result: { [string]: { LeaderboardEntry } } = {}
        for statName: string in orderedStores do
          local cached: CacheEntry? = cache[statName]
          result[statName] = if cached then (cached :: CacheEntry).data else {}
        end
        return result
      end
      lastRequest[player] = now

      local result: { [string]: { LeaderboardEntry } } = {}
      for statName: string in orderedStores do
        result[statName] = fetchLeaderboard(statName)
      end
      return result
    end

    -- clean up on player leave
    Players.PlayerRemoving:Connect(function(player: Player)
      lastRequest[player] = nil
    end)

    logger.log("success", "setup", { status = "ok" })
  end,

  loop = function() end,
}
