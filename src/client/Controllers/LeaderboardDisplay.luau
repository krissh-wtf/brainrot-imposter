local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)

local logger = Logger.new("LeaderboardDisplay")

local refreshInterval = 65
local leaderboardRemote: RemoteFunction = nil

local boards = {
  { stat = "Coins", modelName = "TopCoinsLdb" },
  { stat = "Wins", modelName = "TopWinsLdb" },
  { stat = "TimePlayed", modelName = "TopHoursLdb" },
}

local function formatValue(stat: string, value: number): string -- c juste pour formater les heures et les gros nombres
  if stat == "TimePlayed" then
    local hours = math.floor(value / 3600)
    local mins = math.floor((value % 3600) / 60)
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
  local ldb = workspace:FindFirstChild(modelName)
  if not ldb then
    return nil
  end

  local model = ldb:FindFirstChild("Model")
  if not model then
    return nil
  end

  local screen = model:FindFirstChild("Screen")
  if not screen then
    return nil
  end

  local gui = screen:FindFirstChild("SurfaceGui")
  if not gui then
    return nil
  end

  local holder = gui:FindFirstChild("Holder")
  if not holder then
    return nil
  end

  return holder:FindFirstChild("PlayerList")
end

local function clearEntries(playerList: Frame)
  for _, child in playerList:GetChildren() do
    if not child:IsA("Frame") then
      continue
    end

    local isTemplate = child.Name == "PlayerTemplate"
      or child.Name == "Top1Template"
      or child.Name == "Top2Template"
      or child.Name == "Top3Template"

    if isTemplate then
      child.Visible = false
    else
      child:Destroy()
    end
  end
end

local function getTemplate(playerList: Frame, rank: number): Frame? -- eh jsai pas mon gars
  if rank == 1 then
    return playerList:FindFirstChild("Top1Template")
  end
  if rank == 2 then
    return playerList:FindFirstChild("Top2Template")
  end
  if rank == 3 then
    return playerList:FindFirstChild("Top3Template")
  end
  return playerList:FindFirstChild("PlayerTemplate")
end

local function setText(label: TextLabel, text: string)
  label.Text = text
  local depth = label:FindFirstChild("Depth")
  if depth and depth:IsA("TextLabel") then
    depth.Text = text
  end
end

local function populateBoard(boardInfo, data) -- liste de { rank, name, value, userId } pr le board
  local playerList = getPlayerList(boardInfo.modelName)
  if not playerList then
    logger:log("warn", "populateBoard", { error = `PlayerList introuvable dans {boardInfo.modelName}` })
    return
  end

  clearEntries(playerList)

  for i, entry in data do
    local template = getTemplate(playerList, i)
    if not template then
      continue
    end

    local clone = template:Clone()
    clone.Name = `Entry_{i}`
    clone.Visible = true
    clone.LayoutOrder = i

    -- rang (#1, #2, etc)
    local place = clone:FindFirstChild("Place", true)
    if place and place:IsA("TextLabel") then
      setText(place, `#{i}`)
    end

    -- nom du joueur
    local playerName = clone:FindFirstChild("PlayerName", true)
    if playerName and playerName:IsA("TextLabel") then
      setText(playerName, entry.name)
    end

    -- valeur (coins, wins, temps)
    local count = clone:FindFirstChild("Count", true)
    if count and count:IsA("TextLabel") then
      setText(count, formatValue(boardInfo.stat, entry.value))
    end

    -- avatar
    local headshot = clone:FindFirstChild("Headshot", true)
    if headshot and headshot:IsA("ImageLabel") and entry.userId then
      local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(entry.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
      end)
      if ok then
        headshot.Image = content
      end
    end

    clone.Parent = playerList
  end
end

local function refreshAll()
  if not leaderboardRemote then
    return
  end

  local ok, result = pcall(function()
    return leaderboardRemote:InvokeServer()
  end)

  if not ok or not result then
    logger:log("error", "refreshAll", { error = tostring(result) })
    return
  end

  for _, boardInfo in boards do
    local data = result[boardInfo.stat]
    if data then
      populateBoard(boardInfo, data)
    end
  end
end

-- ton roche c de la frappe
local roche = {
  context = "once",

  setup = function()
    leaderboardRemote = ReplicatedStorage:WaitForChild("GetLeaderboardData", 30)
    if not leaderboardRemote then
      logger:log("error", "setup", { error = "remote introuvable" })
      return
    end

    task.spawn(function()
      while true do
        refreshAll()
        task.wait(refreshInterval)
      end
    end)

    logger:log("success", "setup", { status = "ok" })
  end,

  loop = function() end,
}

return roche
