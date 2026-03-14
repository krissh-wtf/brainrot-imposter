--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Types = require(Shared.Types)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Logger)

type GameData = Types.GameData
type PlayerData = Types.PlayerData
type Role = Types.Role
type GameState = Types.GameState

local logger = Logger.new("PlayerService")

local PlayerService = {}

-- shared game data reference, set by GameService
local gameData: GameData = nil :: any

-- track last input time per player for auto-afk
local lastInputTimes: { [Player]: number } = {}

function PlayerService.init(data: GameData)
  gameData = data
end

function PlayerService.createPlayerData(player: Player): PlayerData
  return {
    player = player,
    role = nil :: Role?,
    isAfk = false,
    vote = nil :: Player?,
    hint = nil :: string?,
    isAlive = true,
    score = 0,
  }
end

function PlayerService.add(player: Player)
  if gameData.players[player] then
    return
  end

  gameData.players[player] = PlayerService.createPlayerData(player)
  lastInputTimes[player] = workspace:GetServerTimeNow()
  logger:log("info", "add", { player = player.Name })
end

function PlayerService.remove(player: Player): GameState?
  local data = gameData.players[player]
  if not data then
    return nil
  end

  gameData.players[player] = nil
  lastInputTimes[player] = nil

  local inProgress: boolean = gameData.state == "guessing"
    or gameData.state == "discussion"
    or gameData.state == "voting"
    or gameData.state == "overtime"

  -- imposter left mid-game
  if player == gameData.imposter and inProgress then
    logger:log("warn", "remove", { reason = "imposter disconnected" })
    return "investigatorWin"
  end

  -- not enough players to continue
  local active = PlayerService.getAlivePlayers()
  if inProgress and #active < Config.MIN_PLAYERS then
    logger:log("warn", "remove", { reason = "not enough players" })
    return "nothing"
  end

  return nil
end

function PlayerService.getAlivePlayers(): { PlayerData }
  local alive: { PlayerData } = {}
  for _, data in gameData.players do
    if data.isAlive and not data.isAfk then
      table.insert(alive, data)
    end
  end
  return alive
end

function PlayerService.toggleAfk(player: Player): boolean
  local data = gameData.players[player]
  if not data then
    return false
  end

  data.isAfk = not data.isAfk
  logger:log("info", "toggleAfk", { player = player.Name, afk = tostring(data.isAfk) })
  return data.isAfk
end

function PlayerService.registerInput(player: Player)
  lastInputTimes[player] = workspace:GetServerTimeNow()
end

function PlayerService.checkAfkTimeouts()
  local now: number = workspace:GetServerTimeNow()
  for player, lastInput in lastInputTimes do
    if now - lastInput <= Config.AFK_TIMEOUT then
      continue
    end

    local data = gameData.players[player]
    if not data or data.isAfk then
      continue
    end

    data.isAfk = true
    logger:log("info", "checkAfkTimeouts", { player = player.Name })
    -- TODO: notify client of auto-afk
  end
end

function PlayerService.resetRoundData()
  for _, data in gameData.players do
    data.vote = nil
    data.hint = nil
  end
end

function PlayerService.resetAll()
  for _, data in gameData.players do
    data.role = nil
    data.vote = nil
    data.hint = nil
    data.isAlive = true
  end
end

function PlayerService.pickRandom<T>(list: { T }): T
  return list[math.random(1, #list)]
end

return PlayerService
