--!strict

-- Renders in-world leaderboard surfaces with data from the server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)

local logger = Logger.create("LeaderboardDisplay")

local REFRESH_INTERVAL: number = 65
local leaderboardRemote: RemoteFunction? = nil

type BoardInfo = {
	stat: string,
	modelName: string,
}

local boards: { BoardInfo } = {
	{ stat = "Coins", modelName = "TopCoinsLdb" },
	{ stat = "Wins", modelName = "TopWinsLdb" },
	{ stat = "TimePlayed", modelName = "TopHoursLdb" },
}

local function formatValue(stat: string, value: number): string
	if stat == "TimePlayed" then
		local hours: number = math.floor(value / 3600)
		local mins: number = math.floor((value % 3600) / 60)
		return `{hours}h {mins}m`
	end

	if value >= 1_000_000 then
		return string.format("%.1fM", value / 1_000_000)
	elseif value >= 1_000 then
		return string.format("%.1fK", value / 1_000)
	end

	return tostring(value)
end

local function getPlayerList(modelName: string): Frame?
	local ldb: Instance? = workspace:FindFirstChild(modelName)
	if not ldb then
		return nil
	end

	local model: Instance? = (ldb :: Instance):FindFirstChild("Model")
	if not model then
		return nil
	end

	local screen: Instance? = (model :: Instance):FindFirstChild("Screen")
	if not screen then
		return nil
	end

	local gui: Instance? = (screen :: Instance):FindFirstChild("SurfaceGui")
	if not gui then
		return nil
	end

	local holder: Instance? = (gui :: Instance):FindFirstChild("Holder")
	if not holder then
		return nil
	end

	return (holder :: Instance):FindFirstChild("PlayerList") :: Frame?
end

local function clearEntries(playerList: Frame)
	for _, child: Instance in playerList:GetChildren() do
		if not child:IsA("Frame") then
			continue
		end

		local isTemplate: boolean = child.Name == "PlayerTemplate"
			or child.Name == "Top1Template"
			or child.Name == "Top2Template"
			or child.Name == "Top3Template"

		if isTemplate then
			(child :: Frame).Visible = false
		else
			child:Destroy()
		end
	end
end

local function getTemplate(playerList: Frame, rank: number): Frame?
	if rank == 1 then
		return playerList:FindFirstChild("Top1Template") :: Frame?
	end
	if rank == 2 then
		return playerList:FindFirstChild("Top2Template") :: Frame?
	end
	if rank == 3 then
		return playerList:FindFirstChild("Top3Template") :: Frame?
	end
	return playerList:FindFirstChild("PlayerTemplate") :: Frame?
end

local function setText(label: TextLabel, text: string)
	label.Text = text
	local depth: Instance? = label:FindFirstChild("Depth")
	if depth and (depth :: Instance):IsA("TextLabel") then
		(depth :: TextLabel).Text = text
	end
end

type LeaderboardEntry = {
	rank: number,
	name: string,
	value: number,
	userId: number?,
}

local function populateBoard(boardInfo: BoardInfo, data: { LeaderboardEntry })
	local playerList: Frame? = getPlayerList(boardInfo.modelName)
	if not playerList then
		logger.log("warn", "populateBoard", { error = `PlayerList not found in {boardInfo.modelName}` })
		return
	end

	clearEntries(playerList :: Frame)

	for i: number, entry: LeaderboardEntry in data do
		local template: Frame? = getTemplate(playerList :: Frame, i)
		if not template then
			continue
		end

		local clone: Frame = (template :: Frame):Clone()
		clone.Name = `Entry_{i}`
		clone.Visible = true
		clone.LayoutOrder = i

		-- rank display (#1, #2, etc.)
		local place: Instance? = clone:FindFirstChild("Place", true)
		if place and (place :: Instance):IsA("TextLabel") then
			setText(place :: TextLabel, `#{i}`)
		end

		-- player name
		local playerName: Instance? = clone:FindFirstChild("PlayerName", true)
		if playerName and (playerName :: Instance):IsA("TextLabel") then
			setText(playerName :: TextLabel, entry.name)
		end

		-- stat value (coins, wins, time)
		local count: Instance? = clone:FindFirstChild("Count", true)
		if count and (count :: Instance):IsA("TextLabel") then
			setText(count :: TextLabel, formatValue(boardInfo.stat, entry.value))
		end

		-- player avatar
		local headshot: Instance? = clone:FindFirstChild("Headshot", true)
		if headshot and (headshot :: Instance):IsA("ImageLabel") and entry.userId then
			local ok: boolean, content: string = pcall(function()
				return Players:GetUserThumbnailAsync(
					entry.userId :: number,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)
			end)
			if ok then
				(headshot :: ImageLabel).Image = content
			end
		end

		clone.Parent = playerList
	end
end

local function refreshAll()
	if not leaderboardRemote then
		return
	end

	local ok: boolean, result: any = pcall(function()
		return (leaderboardRemote :: RemoteFunction):InvokeServer()
	end)

	if not ok or not result then
		logger.log("error", "refreshAll", { error = tostring(result) })
		return
	end

	for _, boardInfo: BoardInfo in boards do
		local data: { LeaderboardEntry }? = result[boardInfo.stat]
		if data then
			populateBoard(boardInfo, data :: { LeaderboardEntry })
		end
	end
end

-- module interface
return {
	context = "once",

	setup = function()
		leaderboardRemote = ReplicatedStorage:WaitForChild("GetLeaderboardData", 30) :: RemoteFunction?
		if not leaderboardRemote then
			logger.log("error", "setup", { error = "GetLeaderboardData remote not found" })
			return
		end

		task.spawn(function()
			while true do
				refreshAll()
				task.wait(REFRESH_INTERVAL)
			end
		end)

		logger.log("success", "setup", { status = "ok" })
	end,

	loop = function() end,
}
