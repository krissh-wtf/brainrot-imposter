--!strict

-- Loads and wires ModuleScript modules with a setup/loop lifecycle pattern

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Logger = require(script.Parent.Logger)

local logger = Logger.create("ModuleLoader")

type ModuleDefinition = {
	setup: () -> (),
	loop: (...any) -> (),
	context: string,
}

local contexts: { [string]: string | RBXScriptSignal } = {
	once = "once",
	heartbeat = RunService.Heartbeat,
	stepped = RunService.Stepped,
	renderStepped = RunService.RenderStepped,
	playerJoined = Players.PlayerAdded,
	playerLeaving = Players.PlayerRemoving,
}

local initialized: { [ModuleScript]: boolean } = {}

local function try(name: string, label: string, fn: (...any) -> ...any, ...: any): boolean
	local success: boolean, result: string = pcall(fn, ...)
	if not success then
		logger.log("error", name, { error = `{label} failed - {result}` })
	end
	return success
end

local function parseModule(moduleScript: ModuleScript)
	if initialized[moduleScript] then
		return
	end

	local name: string = moduleScript:GetFullName()

	local loaded: boolean, moduleResult: any = pcall(require, moduleScript)
	if not loaded then
		logger.log("error", name, { error = `failed to load - {moduleResult}` })
		return
	end

	local definition: ModuleDefinition = moduleResult :: ModuleDefinition

	if
		type(definition) ~= "table"
		or type(definition.setup) ~= "function"
		or type(definition.loop) ~= "function"
		or type(definition.context) ~= "string"
	then
		-- silently skip utility modules that don't follow the lifecycle pattern
		return
	end

	local context: (string | RBXScriptSignal)? = contexts[definition.context]
	if not context then
		logger.log("warn", name, { error = `unknown context '{definition.context}'` })
		return
	end

	initialized[moduleScript] = true

	if not try(name, "setup", definition.setup) then
		return
	end

	if definition.context == "once" then
		try(name, "loop", definition.loop)
		return
	end

	(context :: RBXScriptSignal):Connect(function(...: any)
		try(name, "loop", definition.loop, ...)
	end)
end

local function walk(item: Instance)
	if item:IsA("ModuleScript") then
		parseModule(item)
		return
	end

	for _, child: Instance in item:GetChildren() do
		walk(child)
	end
end

local function launch(items: { Instance } | Folder)
	for _, item: Instance in items :: { Instance } do
		walk(item)
	end
end

local function reset()
	table.clear(initialized)
end

return table.freeze({
	launch = launch,
	reset = reset,
})
