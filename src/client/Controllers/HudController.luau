--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Types = require(ReplicatedStorage.Shared.Types)

type ClientPayload = Types.ClientPayload
type GameState = Types.GameState

local logger = Logger.create("HudController")
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- state renderers map each game state to a UI update function
local stateRenderers: { [GameState]: (payload: ClientPayload) -> () } = {
  nothing = function(_payload: ClientPayload)
    -- TODO: show lobby idle screen with game logo
  end,

  waiting = function(_payload: ClientPayload)
    -- TODO: show "waiting for players" with current/required count
  end,

  selection = function(_payload: ClientPayload)
    -- TODO: reveal theme and word (nil for imposter) with role animation
    -- TODO: play sound effect for role reveal
  end,

  guessing = function(_payload: ClientPayload)
    -- TODO: show hint input field (single word, max 24 chars)
    -- TODO: display submitted hints as they arrive
    -- TODO: show countdown timer from payload.timeLeft
  end,

  discussion = function(_payload: ClientPayload)
    -- TODO: show all submitted hints side by side
    -- TODO: enable chat panel for live discussion
    -- TODO: show countdown timer
  end,

  voting = function(_payload: ClientPayload)
    -- TODO: show player cards with vote buttons
    -- TODO: add skip vote button
    -- TODO: show countdown timer
    -- TODO: highlight who has already voted via payload.players[].hasVoted
  end,

  overtime = function(_payload: ClientPayload)
    -- TODO: show overtime warning banner with urgency styling
    -- TODO: show revote UI (same as voting but with warning)
  end,

  investigatorWin = function(_payload: ClientPayload)
    -- TODO: show victory screen with imposter reveal
    -- TODO: display scoreboard with vote bonus indicators
  end,

  investigatorLose = function(_payload: ClientPayload)
    -- TODO: show defeat screen with imposter reveal
  end,

  imposterWin = function(_payload: ClientPayload)
    -- TODO: show imposter victory screen with word reveal
    -- TODO: display scoreboard
  end,

  imposterLose = function(_payload: ClientPayload)
    -- TODO: show imposter caught screen with score breakdown
  end,
}

local function render(payload: ClientPayload)
  local renderer: ((payload: ClientPayload) -> ())? = stateRenderers[payload.state]
  if renderer then
    (renderer :: (payload: ClientPayload) -> ())(payload)
  end
end

-- module interface
return {
  context = "once",

  setup = function()
    local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
    local stateChanged: RemoteEvent = Remotes.get("StateChanged")

    stateChanged.OnClientEvent:Connect(function(payload: ClientPayload)
      render(payload)
    end)

    logger.log("success", "setup", { status = "ready" })
  end,

  loop = function() end,
}
