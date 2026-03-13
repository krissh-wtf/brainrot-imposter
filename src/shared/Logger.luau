local RunService = game:GetService("RunService")
local Logger = {}

local dev = RunService:IsStudio()

export type LogTypes = "success" | "info" | "warn" | "error"

local logTypes: { [LogTypes]: string } = {
  success = "🟢",
  info = "🔵",
  warn = "🟠",
  error = "🔴",
}

export type Logger = {
  source: string,
  log: (self: Logger, logType: LogTypes, module: string, additionalData: { [string]: any }?) -> (),
}

local function getTimestamp(): string
  local date = os.date("!*t")
  return string.format("%02i:%02i:%02i", date.hour, date.min, date.sec)
end

local function formatTable(tbl: { [string]: any }): string
  local parts = {}

  for key, value in pairs(tbl) do
    table.insert(parts, string.format("%s=\"%s\"", tostring(key), tostring(value)))
  end

  return "{ " .. table.concat(parts, ", ") .. " }"
end

function Logger.new(source: string): Logger
  local self = {
    source = source,
  } :: any

  function self:log(logType: LogTypes, module: string, additionalData: { [string]: any }?)
    if not dev then
      return
    end

    local icon = logTypes[logType]
    local base = string.format("[%s] (%s) [%s.%s]", icon, getTimestamp(), self.source, module)

    if additionalData then
      base ..= " " .. formatTable(additionalData)
    end

    print(base)
  end

  return self
end

return Logger
