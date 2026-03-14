--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type ClientPayload = Types.ClientPayload
type GameState = Types.GameState

local logger = Logger.create("GameController")

local stateChanged: RemoteEvent = Remotes.get("StateChanged")
local submitHintRemote: RemoteEvent = Remotes.get("SubmitHint")
local castVoteRemote: RemoteEvent = Remotes.get("CastVote")
local toggleAfkRemote: RemoteEvent = Remotes.get("ToggleAfk")
local guessWordRemote: RemoteEvent = Remotes.get("GuessWord")
local playerInputRemote: RemoteEvent = Remotes.get("PlayerInput")

-- current state cache
local currentPayload: ClientPayload? = nil

-- throttle input remote
local lastInputTime: number = 0

local function onStateChanged(payload: ClientPayload)
  currentPayload = payload
  logger.log("info", "onStateChanged", { state = payload.state })
end

-- public API for UI scripts
local GameController = {}

function GameController.submitHint(hint: string)
  submitHintRemote:FireServer(hint)
end

function GameController.castVote(target: Player)
  castVoteRemote:FireServer(target)
end

function GameController.skipVote()
  castVoteRemote:FireServer("skip")
end

function GameController.toggleAfk()
  toggleAfkRemote:FireServer()
end

function GameController.guessWord(guess: string)
  guessWordRemote:FireServer(guess)
end

function GameController.getPayload(): ClientPayload?
  return currentPayload
end

-- module interface
return {
  context = "once",

  setup = function()
    stateChanged.OnClientEvent:Connect(onStateChanged)

    -- track input activity for server-side AFK detection (throttled)
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
      if processed then
        return
      end

      local now: number = os.clock()
      if now - lastInputTime < Config.INPUT_THROTTLE then
        return
      end
      lastInputTime = now
      playerInputRemote:FireServer()
    end)

    -- expose controller globally for UI scripts
    -- _G.GameController = GameController

    logger.log("success", "setup", { status = "ready" })
  end,

  loop = function() end,
}
