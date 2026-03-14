--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Types = require(ReplicatedStorage.Shared.Types)

type GameData = Types.GameData
type PlayerData = Types.PlayerData
type Role = Types.Role
type GameState = Types.GameState

local logger = Logger.create("PlayerService")

local PlayerService = {}

-- shared game data reference, set by GameService
local gameData: GameData = nil :: any

-- track last input time per player for auto-afk
local lastInputTimes: { [Player]: number } = {}

function PlayerService.init(data: GameData)
  gameData = data
end

local function createPlayerData(player: Player): PlayerData
  return {
    player = player,
    role = nil :: Role?,
    isAfk = false,
    vote = nil :: Player?,
    hint = nil :: string?,
    isAlive = true,
    score = 0,
    hasSkippedVote = false,
    hasGuessedThisRound = false,
  }
end

function PlayerService.add(player: Player)
  if gameData.players[player] then
    return
  end

  gameData.players[player] = createPlayerData(player)
  lastInputTimes[player] = workspace:GetServerTimeNow()
  logger.log("info", "add", { player = player.Name })
end

function PlayerService.remove(player: Player): GameState?
  local data: PlayerData? = gameData.players[player]
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
    logger.log("warn", "remove", { reason = "imposter disconnected" })
    return "investigatorWin"
  end

  -- not enough players to continue
  local active: { PlayerData } = PlayerService.getAlivePlayers()
  if inProgress and #active < Config.MIN_PLAYERS then
    logger.log("warn", "remove", { reason = "not enough players" })
    return "nothing"
  end

  return nil
end

function PlayerService.getAlivePlayers(): { PlayerData }
  local alive: { PlayerData } = {}
  for _, data: PlayerData in gameData.players do
    if data.isAlive and not data.isAfk then
      table.insert(alive, data)
    end
  end
  return alive
end

function PlayerService.toggleAfk(player: Player): boolean
  local data: PlayerData? = gameData.players[player]
  if not data then
    return false
  end

  local pd: PlayerData = data :: PlayerData
  pd.isAfk = not pd.isAfk
  logger.log("info", "toggleAfk", { player = player.Name, afk = tostring(pd.isAfk) })
  return pd.isAfk
end

function PlayerService.registerInput(player: Player)
  lastInputTimes[player] = workspace:GetServerTimeNow()
end

-- optional remote for notifying clients of auto-afk (set by GameService)
PlayerService.onAutoAfk = nil :: ((player: Player) -> ())?

function PlayerService.checkAfkTimeouts()
  local now: number = workspace:GetServerTimeNow()
  for player: Player, lastInput: number in lastInputTimes do
    if now - lastInput <= Config.AFK_TIMEOUT then
      continue
    end

    local data: PlayerData? = gameData.players[player]
    if not data or (data :: PlayerData).isAfk then
      continue
    end

    (data :: PlayerData).isAfk = true
    logger.log("info", "checkAfkTimeouts", { player = player.Name })

    if PlayerService.onAutoAfk then
      (PlayerService.onAutoAfk :: (player: Player) -> ())(player)
    end
  end
end

function PlayerService.resetRoundData()
  for _, data: PlayerData in gameData.players do
    data.vote = nil
    data.hint = nil
    data.hasSkippedVote = false
    data.hasGuessedThisRound = false
  end
end

function PlayerService.resetAll()
  for _, data: PlayerData in gameData.players do
    data.role = nil
    data.vote = nil
    data.hint = nil
    data.isAlive = true
    data.hasSkippedVote = false
    data.hasGuessedThisRound = false
  end
end

function PlayerService.pickRandom<T>(list: { T }): T
  return list[math.random(1, #list)]
end

return PlayerService
