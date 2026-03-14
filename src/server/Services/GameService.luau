--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Config = require(Shared.Config)
local Logger = require(Shared.Logger)
local Minerais = require(Shared.Minerais)
local PlayerService = require(script.Parent.PlayerService)
local Remotes = require(Shared.Remotes)
local Themes = require(Shared.Themes)
local Types = require(Shared.Types)

type GameData = Types.GameData
type GameState = Types.GameState
type PlayerData = Types.PlayerData
type ClientPayload = Types.ClientPayload
type Minerai = Minerais.Minerai

local logger = Logger.new("GameService")

-- remotes
local stateChanged = Remotes.get("StateChanged")
local submitHintRemote = Remotes.get("SubmitHint")
local castVoteRemote = Remotes.get("CastVote")
local toggleAfkRemote = Remotes.get("ToggleAfk")
local guessWordRemote = Remotes.get("GuessWord")
local playerInputRemote = Remotes.get("PlayerInput")

-- game data
local gameData: GameData = {
  state = "nothing" :: GameState,
  players = {},
  theme = nil :: string?,
  word = nil :: string?,
  imposter = nil :: Player?,
  round = 0,
  roundStartTime = 0,
}

-- state machine
local stateMachine: Minerais.Minerais = Minerais.new()

-- build client-safe payload (imposter does not receive the word)
local function buildPayload(player: Player): ClientPayload
  local playerData = gameData.players[player]
  local isImposter: boolean = playerData ~= nil and playerData.role == "imposter"

  local playerList: { { name: string, isAlive: boolean, score: number, hint: string? } } = {}
  for _, data in gameData.players do
    table.insert(playerList, {
      name = data.player.Name,
      isAlive = data.isAlive,
      score = data.score,
      hint = data.hint,
    })
  end

  local elapsed: number = workspace:GetServerTimeNow() - gameData.roundStartTime
  local durations: { [GameState]: number } = {
    selection = Config.SELECTION_DURATION,
    guessing = Config.GUESSING_DURATION,
    discussion = Config.DISCUSSION_DURATION,
    voting = Config.VOTING_DURATION,
    overtime = Config.OVERTIME_DURATION,
  }

  local duration: number = durations[gameData.state] or 0
  local timeLeft: number = math.max(0, duration - elapsed)

  return {
    state = gameData.state,
    theme = gameData.theme,
    word = if isImposter then nil else gameData.word,
    players = playerList,
    round = gameData.round,
    timeLeft = timeLeft,
  }
end

-- broadcast state to all connected players
local function broadcastState()
  for player in gameData.players do
    local payload: ClientPayload = buildPayload(player)
    stateChanged:FireClient(player, payload)
  end
end

-- force transition the state machine
local function forceTransition(state: GameState)
  gameData.state = state
  stateMachine:transition(state)
end

-- ── vote tallying (shared between voting and overtime) ──

local function tallyVotes(): (Player?, boolean)
  local tally: { [Player]: number } = {}
  local active = PlayerService.getAlivePlayers()

  for _, data in active do
    if data.vote then
      tally[data.vote] = (tally[data.vote] or 0) + 1
    end
  end

  local maxVotes: number = 0
  local eliminated: Player? = nil
  local isTie: boolean = false

  for player, count in tally do
    if count > maxVotes then
      maxVotes = count
      eliminated = player
      isTie = false
    elseif count == maxVotes then
      isTie = true
    end
  end

  return eliminated, isTie
end

local function resolveElimination(eliminated: Player): GameState
  local eliminatedData = gameData.players[eliminated]
  if eliminatedData then
    eliminatedData.isAlive = false
    logger:log("info", "resolveElimination", { player = eliminated.Name })
  end

  if eliminated == gameData.imposter then
    return "investigatorWin"
  end

  local remaining = PlayerService.getAlivePlayers()
  if #remaining <= 2 then
    return "imposterWin"
  end

  if gameData.round < Config.MAX_ROUNDS then
    return "guessing"
  end

  return "imposterWin"
end

-- ── scoring ──

local function scoreInvestigatorWin()
  for _, data in gameData.players do
    if data.role ~= "investigator" or not data.isAlive then
      continue
    end

    data.score += Config.INVESTIGATOR_WIN_SCORE

    if data.vote == gameData.imposter then
      data.score += Config.VOTE_BONUS_SCORE
    end
  end
end

local function scoreImposterWin()
  local imposterData = if gameData.imposter then gameData.players[gameData.imposter] else nil
  if imposterData then
    imposterData.score += Config.IMPOSTER_WIN_SCORE
  end
end

-- ── Minerais state definitions ──

local states: { Minerai } = {
  {
    name = "nothing",
    duration = 0,
    enter = function(_previous: string?): boolean
      gameData.theme = nil
      gameData.word = nil
      gameData.imposter = nil
      gameData.round = 0
      PlayerService.resetAll()
      broadcastState()
      logger:log("info", "nothing", { status = "idle" })
      return true
    end,
    completed = function(): string?
      return nil
    end,
  },

  {
    name = "waiting",
    duration = 1,
    enter = function(_previous: string?): boolean
      broadcastState()
      logger:log("info", "waiting", { status = "lobby open" })
      return true
    end,
    completed = function(): string?
      local active = PlayerService.getAlivePlayers()
      if #active >= Config.MIN_PLAYERS then
        return "selection"
      end
      -- loop back to waiting
      return "waiting"
    end,
  },

  {
    name = "selection",
    duration = Config.SELECTION_DURATION,
    enter = function(_previous: string?): boolean
      gameData.round += 1
      gameData.roundStartTime = workspace:GetServerTimeNow()

      -- pick theme and word
      local themeNames: { string } = {}
      for name in Themes do
        table.insert(themeNames, name)
      end

      gameData.theme = PlayerService.pickRandom(themeNames)
      gameData.word = PlayerService.pickRandom(Themes[gameData.theme :: string])

      -- need enough players
      local active = PlayerService.getAlivePlayers()
      if #active < Config.MIN_PLAYERS then
        return false
      end

      -- assign roles
      local imposterData: PlayerData = PlayerService.pickRandom(active)
      gameData.imposter = imposterData.player

      for _, data in active do
        data.role = if data.player == gameData.imposter then "imposter" else "investigator"
      end

      broadcastState()
      logger:log("success", "selection", {
        theme = gameData.theme :: string,
        imposter = (gameData.imposter :: Player).Name,
      })
      return true
    end,
    completed = function(): string?
      return "guessing"
    end,
  },

  {
    name = "guessing",
    duration = Config.GUESSING_DURATION,
    enter = function(_previous: string?): boolean
      gameData.roundStartTime = workspace:GetServerTimeNow()
      PlayerService.resetRoundData()
      broadcastState()
      logger:log("info", "guessing", { round = tostring(gameData.round) })
      return true
    end,
    completed = function(): string?
      return "discussion"
    end,
  },

  {
    name = "discussion",
    duration = Config.DISCUSSION_DURATION,
    enter = function(_previous: string?): boolean
      gameData.roundStartTime = workspace:GetServerTimeNow()
      broadcastState()
      logger:log("info", "discussion", {})
      return true
    end,
    completed = function(): string?
      return "voting"
    end,
  },

  {
    name = "voting",
    duration = Config.VOTING_DURATION,
    enter = function(_previous: string?): boolean
      gameData.roundStartTime = workspace:GetServerTimeNow()
      for _, data in gameData.players do
        data.vote = nil
      end
      broadcastState()
      logger:log("info", "voting", {})
      return true
    end,
    completed = function(): string?
      local eliminated, isTie = tallyVotes()

      if isTie or not eliminated then
        return "overtime"
      end

      return resolveElimination(eliminated :: Player)
    end,
  },

  {
    name = "overtime",
    duration = Config.OVERTIME_DURATION,
    enter = function(_previous: string?): boolean
      gameData.roundStartTime = workspace:GetServerTimeNow()
      for _, data in gameData.players do
        data.vote = nil
      end
      broadcastState()
      logger:log("warn", "overtime", { reason = "tie vote" })
      return true
    end,
    completed = function(): string?
      local eliminated, isTie = tallyVotes()

      -- second tie = imposter wins
      if isTie or not eliminated then
        return "imposterWin"
      end

      return resolveElimination(eliminated :: Player)
    end,
  },

  {
    name = "investigatorWin",
    duration = Config.OUTCOME_DURATION,
    enter = function(_previous: string?): boolean
      scoreInvestigatorWin()
      broadcastState()
      logger:log("success", "investigatorWin", {})
      return true
    end,
    completed = function(): string?
      return "waiting"
    end,
  },

  {
    name = "investigatorLose",
    duration = Config.OUTCOME_DURATION,
    enter = function(_previous: string?): boolean
      broadcastState()
      logger:log("info", "investigatorLose", {})
      return true
    end,
    completed = function(): string?
      return "waiting"
    end,
  },

  {
    name = "imposterWin",
    duration = Config.OUTCOME_DURATION,
    enter = function(_previous: string?): boolean
      scoreImposterWin()
      broadcastState()
      logger:log("success", "imposterWin", {})
      return true
    end,
    completed = function(): string?
      return "waiting"
    end,
  },

  {
    name = "imposterLose",
    duration = Config.OUTCOME_DURATION,
    enter = function(_previous: string?): boolean
      broadcastState()
      logger:log("info", "imposterLose", {})
      return true
    end,
    completed = function(): string?
      return "waiting"
    end,
  },
}

-- ── hint submission ──

local function onSubmitHint(player: Player, hint: unknown)
  if gameData.state ~= "guessing" then
    return
  end

  if type(hint) ~= "string" then
    return
  end

  local data = gameData.players[player]
  if not data or not data.isAlive or data.isAfk then
    return
  end

  -- prevent revealing the word
  if gameData.word and string.lower(hint) == string.lower(gameData.word) then
    return
  end

  -- prevent duplicate hints
  for _, other in gameData.players do
    if other.hint and string.lower(other.hint) == string.lower(hint) then
      return
    end
  end

  data.hint = hint
  broadcastState()
  logger:log("info", "onSubmitHint", { player = player.Name })

  -- auto-advance if everyone submitted
  local allSubmitted: boolean = true
  for _, d in gameData.players do
    if d.isAlive and not d.isAfk and not d.hint then
      allSubmitted = false
      break
    end
  end

  if allSubmitted then
    forceTransition("discussion")
  end
end

-- ── vote casting ──

local function onCastVote(player: Player, target: unknown)
  if gameData.state ~= "voting" and gameData.state ~= "overtime" then
    return
  end

  if typeof(target) ~= "Instance" or not target:IsA("Player") then
    return
  end

  local targetPlayer = target :: Player

  local voterData = gameData.players[player]
  local targetData = gameData.players[targetPlayer]
  if not voterData or not targetData then
    return
  end

  if not voterData.isAlive or voterData.isAfk or not targetData.isAlive then
    return
  end

  if player == targetPlayer then
    return
  end

  voterData.vote = targetPlayer
  broadcastState()
end

-- ── afk toggle ──

local function onToggleAfk(player: Player)
  PlayerService.toggleAfk(player)
  broadcastState()
end

-- ── imposter word guess ──

local function onGuessWord(player: Player, guess: unknown)
  if type(guess) ~= "string" then
    return
  end

  local data = gameData.players[player]
  if not data or data.role ~= "imposter" then
    return
  end

  if not gameData.word then
    return
  end

  if string.lower(guess) == string.lower(gameData.word) then
    forceTransition("imposterWin")
  else
    forceTransition("investigatorWin")
  end
end

-- ── input activity tracking ──

local function onPlayerInput(player: Player)
  PlayerService.registerInput(player)
end

-- ── Roches interface ──

local GameService = {
  context = "heartbeat",

  setup = function()
    PlayerService.init(gameData)

    -- wire remotes
    submitHintRemote.OnServerEvent:Connect(onSubmitHint)
    castVoteRemote.OnServerEvent:Connect(onCastVote)
    toggleAfkRemote.OnServerEvent:Connect(onToggleAfk)
    guessWordRemote.OnServerEvent:Connect(onGuessWord)
    playerInputRemote.OnServerEvent:Connect(onPlayerInput)

    -- player join/leave
    Players.PlayerAdded:Connect(function(player: Player)
      PlayerService.add(player)

      if gameData.state == "nothing" then
        forceTransition("waiting")
      end

      local payload: ClientPayload = buildPayload(player)
      stateChanged:FireClient(player, payload)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
      local override: GameState? = PlayerService.remove(player)
      if override then
        forceTransition(override)
      end
    end)

    -- boot state machine
    stateMachine:defineMinerais(states)
    logger:log("success", "setup", { status = "ready" })
  end,

  loop = function(_dt: number)
    stateMachine:update()
    PlayerService.checkAfkTimeouts()
  end,
}

return GameService
