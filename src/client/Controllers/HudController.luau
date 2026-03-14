--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Logger = require(Shared.Logger)

type ClientPayload = Types.ClientPayload
type GameState = Types.GameState

local logger = Logger.new("HudController")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── UI state renderers ──

local stateRenderers: { [GameState]: (payload: ClientPayload) -> () } = {
  nothing = function(_payload: ClientPayload)
    -- TODO: show lobby idle screen
  end,

  waiting = function(payload: ClientPayload)
    -- TODO: show "waiting for players" with count
  end,

  selection = function(payload: ClientPayload)
    -- TODO: reveal theme (and word if investigator)
    -- TODO: show role assignment animation
  end,

  guessing = function(payload: ClientPayload)
    -- TODO: show hint input field
    -- TODO: display submitted hints as they come in
    -- TODO: show countdown timer from payload.timeLeft
  end,

  discussion = function(payload: ClientPayload)
    -- TODO: show all hints side by side
    -- TODO: enable chat panel
    -- TODO: show countdown timer
  end,

  voting = function(payload: ClientPayload)
    -- TODO: show player cards with vote buttons
    -- TODO: show countdown timer
  end,

  overtime = function(payload: ClientPayload)
    -- TODO: show overtime warning banner
    -- TODO: show revote UI
  end,

  investigatorWin = function(payload: ClientPayload)
    -- TODO: show victory screen with imposter reveal
    -- TODO: display scoreboard
  end,

  investigatorLose = function(payload: ClientPayload)
    -- TODO: show defeat screen with imposter reveal
  end,

  imposterWin = function(payload: ClientPayload)
    -- TODO: show imposter victory screen
    -- TODO: display scoreboard
  end,

  imposterLose = function(payload: ClientPayload)
    -- TODO: show imposter caught screen
  end,
}

local function render(payload: ClientPayload)
  local renderer = stateRenderers[payload.state]
  if renderer then
    renderer(payload)
  end
end

-- ── Roches interface ──

return {
  context = "once",

  setup = function()
    -- listen for state changes via GameController
    local Remotes = require(Shared:WaitForChild("Remotes"))
    local stateChanged = Remotes.get("StateChanged")

    stateChanged.OnClientEvent:Connect(function(payload: ClientPayload)
      render(payload)
    end)

    logger:log("success", "setup", { status = "ready" })
  end,

  loop = function() end,
}
