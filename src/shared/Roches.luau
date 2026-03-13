local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Logger = require(script.Parent.Logger)

local Roches = {}

local logger = Logger.new("Roches")

type Roche = {
  setup: () -> (),
  loop: (...any) -> (),
  context: string,
}

local contexts = {
  once = "once",
  heartbeat = RunService.Heartbeat,
  stepped = RunService.Stepped,
  renderStepped = RunService.RenderStepped,
  playerJoined = Players.PlayerAdded,
  playerLeaving = Players.PlayerRemoving,
}

local initialized: { [ModuleScript]: boolean } = {}

local function try(name: string, label: string, fn: (...any) -> ...any, ...)
  local success, result = pcall(fn, ...)
  if not success then
    logger:log("error", name, {
      error = `{label} failed - {result}`,
    })
  end
  return success
end

local function parseRoche(moduleScript: ModuleScript)
  if initialized[moduleScript] then
    return
  end

  local name = moduleScript:GetFullName()

  local loaded, moduleResult = pcall(require, moduleScript)
  if not loaded then
    logger:log("error", name, {
      error = `failed to load - {moduleResult}`,
    })
    return
  end

  local roche = moduleResult :: Roche

  if
    type(roche) ~= "table"
    or type(roche.setup) ~= "function"
    or type(roche.loop) ~= "function"
    or type(roche.context) ~= "string"
  then
    logger:log("warn", name, {
      error = "must define setup(), loop(), and context",
    })
    return
  end

  local context = contexts[roche.context]
  if not context then
    logger:log("warn", name, {
      error = `unknown context '{roche.context}'`,
    })
    return
  end

  initialized[moduleScript] = true

  if not try(name, "setup", roche.setup) then
    return
  end

  if roche.context == "once" then
    try(name, "loop", roche.loop)
    return
  end

  context:Connect(function(...)
    try(name, "loop", roche.loop, ...)
  end)
end

local function walk(item: Instance)
  if item:IsA("ModuleScript") then
    parseRoche(item)
    return
  end

  for _, child in item:GetChildren() do
    walk(child)
  end
end

function Roches.launch(items: { Instance } | Folder)
  for _, item in items do
    walk(item)
  end
end

function Roches.reset()
  table.clear(initialized)
end

export type self = typeof(Roches)
return Roches
