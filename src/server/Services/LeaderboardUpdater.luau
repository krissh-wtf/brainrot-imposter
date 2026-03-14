--!strict

-- Periodically writes player stats to OrderedDataStores for global leaderboards

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)

local logger = Logger.create("LeaderboardUpdater")

local UPDATE_INTERVAL: number = 60

local orderedStores: { [string]: OrderedDataStore } = {
	Coins = DataStoreService:GetOrderedDataStore("BRI_LB_Coins_v2"),
	Wins = DataStoreService:GetOrderedDataStore("BRI_LB_Wins_v2"),
	TimePlayed = DataStoreService:GetOrderedDataStore("BRI_LB_TimePlayed_v2"),
}

local function getStatValue(player: Player, statName: string): number?
	local folder: Instance? = if statName == "TimePlayed"
		then player:FindFirstChild("PlayerStats")
		else player:FindFirstChild("leaderstats")

	if not folder then
		return nil
	end

	local stat: Instance? = (folder :: Instance):FindFirstChild(statName)
	if not stat then
		return nil
	end

	return (stat :: IntValue).Value
end

local function updateAll()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end

	for _, player: Player in players do
		local key: string = tostring(player.UserId)

		for statName: string, store: OrderedDataStore in orderedStores do
			local value: number? = getStatValue(player, statName)
			if not value or (value :: number) <= 0 then
				continue
			end

			local ok: boolean, err: string = pcall(function()
				store:SetAsync(key, value :: number)
			end)

			if not ok then
				logger.log("error", "updateAll", {
					player = player.Name,
					stat = statName,
					error = tostring(err),
				})
			end

			-- small yield between writes to stay within DataStore rate limits
			task.wait()
		end
	end
end

-- module interface
return {
	context = "once",

	setup = function()
		task.spawn(function()
			while true do
				task.wait(UPDATE_INTERVAL)
				updateAll()
				logger.log("info", "cycle", { status = "done" })
			end
		end)

		logger.log("success", "setup", { status = "ok" })
	end,

	loop = function() end,
}
