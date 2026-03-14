--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Iris = require(ReplicatedStorage.Packages.iris)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type ClientPayload = Types.ClientPayload

local logger = Logger.create("DevMenu")
local player: Player = Players.LocalPlayer

local stateChanged: RemoteEvent = Remotes.get("StateChanged")
local submitHintRemote: RemoteEvent = Remotes.get("SubmitHint")
local castVoteRemote: RemoteEvent = Remotes.get("CastVote")
local toggleAfkRemote: RemoteEvent = Remotes.get("ToggleAfk")
local guessWordRemote: RemoteEvent = Remotes.get("GuessWord")

-- only show in studio
local IS_STUDIO: boolean = RunService:IsStudio()

-- current payload cache
local currentPayload: ClientPayload? = nil

-- dev menu states
local testHint = Iris.State("clue")
local testGuess = Iris.State("word")

-- fps tracking
local lastDt: number = 0

local function renderDevMenu()
	if not IS_STUDIO then
		return
	end

	-- toggle button (always visible in studio)
	Iris.Window({ "Dev Tools", [Iris.Args.Window.NoCollapse] = true } :: any)

	-- game state info
	Iris.SeparatorText({ "State Info" })
	if currentPayload then
		local p: ClientPayload = currentPayload :: ClientPayload
		Iris.Text({ `State: {p.state}` })
		Iris.Text({ `Round: {p.round}` })
		Iris.Text({ `Theme: {p.theme or "none"}` })
		Iris.Text({ `Word: {p.word or "(hidden/none)"}` })
		Iris.Text({ `Time Left: {string.format("%.1f", p.timeLeft)}s` })
		Iris.Text({ `Players: {#p.players}` })
		Iris.Text({ `Imposter: {p.imposterName or "(unknown)"}` })
	else
		Iris.Text({ "No payload received yet" })
	end

	-- quick actions
	Iris.SeparatorText({ "Quick Actions" })

	if Iris.Button({ "Toggle AFK" }).clicked() then
		toggleAfkRemote:FireServer()
		logger.log("info", "devAction", { action = "toggleAfk" })
	end

	Iris.Separator()

	-- hint testing
	Iris.SeparatorText({ "Hint Testing" })
	Iris.InputText({ "Hint text" }, { text = testHint })
	if Iris.Button({ "Submit Test Hint" }).clicked() then
		submitHintRemote:FireServer(testHint:get())
		logger.log("info", "devAction", { action = "submitHint", hint = testHint:get() })
	end

	-- guess testing
	Iris.SeparatorText({ "Guess Testing" })
	Iris.InputText({ "Guess text" }, { text = testGuess })
	if Iris.Button({ "Submit Test Guess" }).clicked() then
		guessWordRemote:FireServer(testGuess:get())
		logger.log("info", "devAction", { action = "guessWord", guess = testGuess:get() })
	end

	-- vote testing
	Iris.SeparatorText({ "Vote Testing" })
	if currentPayload then
		for _, p in (currentPayload :: ClientPayload).players do
			if p.name == player.Name then
				continue
			end

			if Iris.Button({ `Vote for {p.name}` }).clicked() then
				local target: Player? = Players:FindFirstChild(p.name) :: Player?
				if target then
					castVoteRemote:FireServer(target)
					logger.log("info", "devAction", { action = "vote", target = p.name })
				end
			end
		end
	end

	if Iris.Button({ "Skip Vote" }).clicked() then
		castVoteRemote:FireServer("skip")
		logger.log("info", "devAction", { action = "skipVote" })
	end

	-- player info
	Iris.SeparatorText({ "Local Player" })
	local character: Model? = player.Character
	if character then
		local root: BasePart? = (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local pos: Vector3 = (root :: BasePart).Position
			Iris.Text({ string.format("Pos: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z) })
		end

		local humanoid: Humanoid? = (character :: Model):FindFirstChildOfClass("Humanoid")
		if humanoid then
			Iris.Text({ `Health: {(humanoid :: Humanoid).Health}/{(humanoid :: Humanoid).MaxHealth}` })
		end
	end

	-- FPS counter
	Iris.SeparatorText({ "Performance" })
	Iris.Text({ string.format("FPS: %.0f", if lastDt > 0 then 1 / lastDt else 0) })

	Iris.End()
end

-- module interface
return {
	context = "once",

	setup = function()
		if not IS_STUDIO then
			logger.log("info", "setup", { status = "skipped (not studio)" })
			return
		end

		stateChanged.OnClientEvent:Connect(function(payload: ClientPayload)
			currentPayload = payload
		end)

		-- track delta time for FPS display
		RunService.Heartbeat:Connect(function(dt: number)
			lastDt = dt
		end)

		-- Iris is already initialized in init.client, just connect
		Iris:Connect(renderDevMenu)

		logger.log("success", "setup", { status = "ready" })
	end,

	loop = function() end,
}
