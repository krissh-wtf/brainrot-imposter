--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Logger = require(Shared.Logger)

type ClientPayload = Types.ClientPayload
type GameState = Types.GameState

local logger = Logger.new("GameController")

local stateChanged = Remotes.get("StateChanged")
local submitHintRemote = Remotes.get("SubmitHint")
local castVoteRemote = Remotes.get("CastVote")
local toggleAfkRemote = Remotes.get("ToggleAfk")
local guessWordRemote = Remotes.get("GuessWord")
local playerInputRemote = Remotes.get("PlayerInput")

-- current state cache
local currentPayload: ClientPayload? = nil

-- ── state change handler ──

local function onStateChanged(payload: ClientPayload)
  currentPayload = payload
  logger:log("info", "onStateChanged", { state = payload.state })

  -- TODO: update HUD based on payload.state
  -- TODO: show/hide guessing UI, voting UI, scoreboard, timer
  -- TODO: display payload.theme and payload.word (nil for imposter)
  -- TODO: render player list from payload.players
  -- TODO: start countdown from payload.timeLeft
end

-- ── public api for UI scripts ──

local GameController = {}

function GameController.submitHint(hint: string)
  submitHintRemote:FireServer(hint)
end

function GameController.castVote(target: Player)
  castVoteRemote:FireServer(target)
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

-- ── Roches interface ──

return {
  context = "once",

  setup = function()
    stateChanged.OnClientEvent:Connect(onStateChanged)

    -- track input activity for server-side AFK detection
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
      if processed then
        return
      end
      playerInputRemote:FireServer()
    end)

    -- expose controller globally for UI scripts
    _G.GameController = GameController

    logger:log("success", "setup", { status = "ready" })
  end,

  loop = function()
    -- one-shot, no loop needed
  end,
}
