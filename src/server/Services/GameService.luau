--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)
local PlayerService = require(script.Parent.PlayerService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StateMachine = require(ReplicatedStorage.Shared.StateMachine)
local Themes = require(ReplicatedStorage.Shared.Themes)
local Types = require(ReplicatedStorage.Shared.Types)

type GameData = Types.GameData
type GameState = Types.GameState
type PlayerData = Types.PlayerData
type ClientPayload = Types.ClientPayload
type ClientPlayerInfo = Types.ClientPlayerInfo
type StateDefinition = StateMachine.StateDefinition

local logger = Logger.create("GameService")

-- remotes
local stateChanged: RemoteEvent = Remotes.get("StateChanged")
local submitHintRemote: RemoteEvent = Remotes.get("SubmitHint")
local castVoteRemote: RemoteEvent = Remotes.get("CastVote")
local toggleAfkRemote: RemoteEvent = Remotes.get("ToggleAfk")
local guessWordRemote: RemoteEvent = Remotes.get("GuessWord")
local playerInputRemote: RemoteEvent = Remotes.get("PlayerInput")

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

-- tracks the last eliminated player name for client display
local lastEliminatedName: string? = nil

-- state machine
local stateMachine: StateMachine.StateMachineInstance = StateMachine.create()

-- build client-safe payload (imposter does not receive the word)
local function buildPayload(player: Player): ClientPayload
  local playerData: PlayerData? = gameData.players[player]
  local isImposter: boolean = playerData ~= nil and (playerData :: PlayerData).role == "imposter"

  local playerList: { ClientPlayerInfo } = {}
  for _, data: PlayerData in gameData.players do
    table.insert(playerList, {
      name = data.player.Name,
      isAlive = data.isAlive,
      score = data.score,
      hint = data.hint,
      hasVoted = data.vote ~= nil,
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

  -- reveal imposter identity on outcome screens
  local isOutcome: boolean = gameData.state == "investigatorWin"
    or gameData.state == "investigatorLose"
    or gameData.state == "imposterWin"
    or gameData.state == "imposterLose"

  local imposterName: string? = nil
  if isOutcome and gameData.imposter then
    imposterName = (gameData.imposter :: Player).Name
  end

  return {
    state = gameData.state,
    theme = gameData.theme,
    word = if isImposter and not isOutcome then nil else gameData.word,
    players = playerList,
    round = gameData.round,
    timeLeft = timeLeft,
    imposterName = imposterName,
    eliminatedName = if isOutcome then lastEliminatedName else nil,
  }
end

-- broadcast state to all connected players
local function broadcastState()
  for player: Player in gameData.players do
    local payload: ClientPayload = buildPayload(player)
    stateChanged:FireClient(player, payload)
  end
end

-- force transition the state machine
local function forceTransition(state: GameState)
  gameData.state = state
  stateMachine.transition(state)
end

-- vote tallying (shared between voting and overtime)
local function tallyVotes(): (Player?, boolean)
  local tally: { [Player]: number } = {}
  local active: { PlayerData } = PlayerService.getAlivePlayers()
  local skipCount: number = 0
  local voterCount: number = 0

  for _, data: PlayerData in active do
    voterCount += 1
    if data.hasSkippedVote then
      skipCount += 1
    elseif data.vote then
      tally[data.vote] = (tally[data.vote] or 0) + 1
    end
  end

  -- majority skipped → nobody eliminated
  if skipCount > voterCount / 2 then
    logger.log("info", "tallyVotes", { result = "majority skip" })
    return nil, false
  end

  local maxVotes: number = 0
  local eliminated: Player? = nil
  local isTie: boolean = false

  for player: Player, count: number in tally do
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
  local eliminatedData: PlayerData? = gameData.players[eliminated]
  if eliminatedData then
    (eliminatedData :: PlayerData).isAlive = false
    logger.log("info", "resolveElimination", { player = eliminated.Name })
  end

  lastEliminatedName = eliminated.Name

  if eliminated == gameData.imposter then
    return "investigatorWin"
  end

  local remaining: { PlayerData } = PlayerService.getAlivePlayers()
  if #remaining <= 2 then
    return "imposterWin"
  end

  if gameData.round < Config.MAX_ROUNDS then
    return "guessing"
  end

  return "imposterWin"
end

-- sync score delta to leaderstats
local function awardCoinsAndWin(player: Player, coins: number)
  local leaderstats: Instance? = player:FindFirstChild("leaderstats")
  if not leaderstats then
    return
  end

  local coinsVal: IntValue? = (leaderstats :: Folder):FindFirstChild("Coins") :: IntValue?
  if coinsVal then
    (coinsVal :: IntValue).Value += coins
  end

  local winsVal: IntValue? = (leaderstats :: Folder):FindFirstChild("Wins") :: IntValue?
  if winsVal then
    (winsVal :: IntValue).Value += 1
  end
end

-- scoring
local function scoreInvestigatorWin()
  for _, data: PlayerData in gameData.players do
    if data.role ~= "investigator" or not data.isAlive then
      continue
    end

    data.score += Config.INVESTIGATOR_WIN_SCORE

    if data.vote == gameData.imposter then
      data.score += Config.VOTE_BONUS_SCORE
    end

    awardCoinsAndWin(data.player, Config.COINS_PER_WIN)
  end
end

local function scoreImposterWin()
  local imposterData: PlayerData? = if gameData.imposter then gameData.players[gameData.imposter] else nil
  if imposterData then
    (imposterData :: PlayerData).score += Config.IMPOSTER_WIN_SCORE
    awardCoinsAndWin((imposterData :: PlayerData).player, Config.COINS_PER_WIN)
  end
end

-- state definitions
local states: { StateDefinition } = {
  {
    name = "nothing",
    duration = 0,
    enter = function(_previous: string?): boolean
      gameData.theme = nil
      gameData.word = nil
      gameData.imposter = nil
      gameData.round = 0
      lastEliminatedName = nil
      PlayerService.resetAll()
      broadcastState()
      logger.log("info", "nothing", { status = "idle" })
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
      logger.log("info", "waiting", { status = "lobby open" })
      return true
    end,
    completed = function(): string?
      local active: { PlayerData } = PlayerService.getAlivePlayers()
      if #active >= Config.MIN_PLAYERS then
        return "selection"
      end
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
      for name: string in Themes do
        table.insert(themeNames, name)
      end

      gameData.theme = PlayerService.pickRandom(themeNames)
      gameData.word = PlayerService.pickRandom(Themes[gameData.theme :: string])

      local active: { PlayerData } = PlayerService.getAlivePlayers()
      if #active < Config.MIN_PLAYERS then
        return false
      end

      -- assign roles
      local imposterData: PlayerData = PlayerService.pickRandom(active)
      gameData.imposter = imposterData.player

      for _, data: PlayerData in active do
        data.role = if data.player == gameData.imposter then "imposter" else "investigator"
      end

      broadcastState()
      logger.log("success", "selection", {
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
      logger.log("info", "guessing", { round = tostring(gameData.round) })
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
      logger.log("info", "discussion", {})
      -- TODO: enable in-game chat for this phase only
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
      for _, data: PlayerData in gameData.players do
        data.vote = nil
        data.hasSkippedVote = false
      end
      broadcastState()
      logger.log("info", "voting", {})
      return true
    end,
    completed = function(): string?
      local eliminated: Player?, isTie: boolean = tallyVotes()

      if isTie or not eliminated then
        return "overtime"
      end

      lastEliminatedName = (eliminated :: Player).Name
      return resolveElimination(eliminated :: Player)
    end,
  },

  {
    name = "overtime",
    duration = Config.OVERTIME_DURATION,
    enter = function(_previous: string?): boolean
      gameData.roundStartTime = workspace:GetServerTimeNow()
      for _, data: PlayerData in gameData.players do
        data.vote = nil
        data.hasSkippedVote = false
      end
      broadcastState()
      logger.log("warn", "overtime", { reason = "tie vote" })
      return true
    end,
    completed = function(): string?
      local eliminated: Player?, isTie: boolean = tallyVotes()

      -- second tie = imposter wins
      if isTie or not eliminated then
        return "imposterWin"
      end

      lastEliminatedName = (eliminated :: Player).Name
      return resolveElimination(eliminated :: Player)
    end,
  },

  {
    name = "investigatorWin",
    duration = Config.OUTCOME_DURATION,
    enter = function(_previous: string?): boolean
      scoreInvestigatorWin()
      broadcastState()
      logger.log("success", "investigatorWin", {})
      -- TODO: play victory sound/animation
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
      logger.log("info", "investigatorLose", {})
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
      logger.log("success", "imposterWin", {})
      -- TODO: play imposter reveal animation
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
      logger.log("info", "imposterLose", {})
      return true
    end,
    completed = function(): string?
      return "waiting"
    end,
  },
}

-- hint submission
local function onSubmitHint(player: Player, hint: unknown)
  if gameData.state ~= "guessing" then
    return
  end

  if type(hint) ~= "string" then
    return
  end

  local hintStr: string = hint :: string

  -- enforce single-word hint within length limit
  if #hintStr == 0 or #hintStr > Config.MAX_HINT_LENGTH then
    return
  end

  if string.find(hintStr, "%s") then
    return
  end

  local data: PlayerData? = gameData.players[player]
  if not data or not (data :: PlayerData).isAlive or (data :: PlayerData).isAfk then
    return
  end

  -- prevent revealing the word
  if gameData.word and string.lower(hintStr) == string.lower(gameData.word :: string) then
    return
  end

  -- prevent hints that contain the word as a substring
  if gameData.word and string.find(string.lower(hintStr), string.lower(gameData.word :: string), 1, true) then
    return
  end

  -- prevent duplicate hints
  for _, other: PlayerData in gameData.players do
    if other.hint and string.lower(other.hint :: string) == string.lower(hintStr) then
      return
    end
  end

  (data :: PlayerData).hint = hintStr
  broadcastState()
  logger.log("info", "onSubmitHint", { player = player.Name })

  -- auto-advance if everyone submitted
  local allSubmitted: boolean = true
  for _, d: PlayerData in gameData.players do
    if d.isAlive and not d.isAfk and not d.hint then
      allSubmitted = false
      break
    end
  end

  if allSubmitted then
    forceTransition("discussion")
  end
end

-- resolve vote results and transition to the correct next state
local function resolveVoteResults()
  local eliminated: Player?, isTie: boolean = tallyVotes()

  if gameData.state == "overtime" then
    -- second tie = imposter wins
    if isTie or not eliminated then
      forceTransition("imposterWin")
    else
      forceTransition(resolveElimination(eliminated :: Player))
    end
  else
    if isTie or not eliminated then
      forceTransition("overtime")
    else
      forceTransition(resolveElimination(eliminated :: Player))
    end
  end
end

-- vote casting
local function onCastVote(player: Player, target: unknown)
  if gameData.state ~= "voting" and gameData.state ~= "overtime" then
    return
  end

  local voterData: PlayerData? = gameData.players[player]
  if not voterData then
    return
  end

  local voter: PlayerData = voterData :: PlayerData
  if not voter.isAlive or voter.isAfk then
    return
  end

  -- handle skip vote
  if target == "skip" then
    voter.hasSkippedVote = true
    broadcastState()
  else
    if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Player") then
      return
    end

    local targetPlayer: Player = target :: Player
    local targetData: PlayerData? = gameData.players[targetPlayer]

    if not targetData or not (targetData :: PlayerData).isAlive then
      return
    end

    if player == targetPlayer then
      return
    end

    voter.vote = targetPlayer
    broadcastState()
  end

  -- auto-advance if everyone voted or skipped
  local allVoted: boolean = true
  for _, d: PlayerData in gameData.players do
    if d.isAlive and not d.isAfk and not d.vote and not d.hasSkippedVote then
      allVoted = false
      break
    end
  end

  if allVoted then
    resolveVoteResults()
  end
end

-- afk toggle
local function onToggleAfk(player: Player)
  PlayerService.toggleAfk(player)
  broadcastState()
end

-- imposter word guess (one attempt per round)
local function onGuessWord(player: Player, guess: unknown)
  if type(guess) ~= "string" then
    return
  end

  local data: PlayerData? = gameData.players[player]
  if not data or (data :: PlayerData).role ~= "imposter" then
    return
  end

  if (data :: PlayerData).hasGuessedThisRound then
    return
  end

  if not gameData.word then
    return
  end

  (data :: PlayerData).hasGuessedThisRound = true

  if string.lower(guess :: string) == string.lower(gameData.word :: string) then
    forceTransition("imposterWin")
  else
    forceTransition("investigatorWin")
  end
end

-- input activity tracking
local function onPlayerInput(player: Player)
  PlayerService.registerInput(player)
end

-- module interface
return {
  context = "heartbeat",

  setup = function()
    PlayerService.init(gameData)

    -- notify client when auto-afk kicks in
    PlayerService.onAutoAfk = function(player: Player)
      broadcastState()
    end

    -- wire remotes
    submitHintRemote.OnServerEvent:Connect(onSubmitHint)
    castVoteRemote.OnServerEvent:Connect(onCastVote)
    toggleAfkRemote.OnServerEvent:Connect(onToggleAfk)
    guessWordRemote.OnServerEvent:Connect(onGuessWord)
    playerInputRemote.OnServerEvent:Connect(onPlayerInput)

    -- player join
    Players.PlayerAdded:Connect(function(player: Player)
      PlayerService.add(player)

      if gameData.state == "nothing" then
        forceTransition("waiting")
      end

      local payload: ClientPayload = buildPayload(player)
      stateChanged:FireClient(player, payload)
    end)

    -- player leave
    Players.PlayerRemoving:Connect(function(player: Player)
      local override: GameState? = PlayerService.remove(player)
      if override then
        forceTransition(override)
      end
    end)

    -- boot state machine
    stateMachine.define(states)
    logger.log("success", "setup", { status = "ready" })
  end,

  loop = function(_dt: number)
    stateMachine.update()
    PlayerService.checkAfkTimeouts()
  end,
}
