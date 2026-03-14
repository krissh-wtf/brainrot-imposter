--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Iris = require(ReplicatedStorage.Packages.iris)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type ClientPayload = Types.ClientPayload
type ClientPlayerInfo = Types.ClientPlayerInfo
type GameState = Types.GameState

local logger = Logger.create("HudController")
local player: Player = Players.LocalPlayer

local stateChanged: RemoteEvent = Remotes.get("StateChanged")
local submitHintRemote: RemoteEvent = Remotes.get("SubmitHint")
local castVoteRemote: RemoteEvent = Remotes.get("CastVote")
local guessWordRemote: RemoteEvent = Remotes.get("GuessWord")

-- current payload from server
local currentPayload: ClientPayload? = nil

-- iris states (persistent across frames)
local hintInput = Iris.State("")
local guessInput = Iris.State("")

-- format time as M:SS
local function formatTime(seconds: number): string
	local m: number = math.floor(seconds / 60)
	local s: number = math.floor(seconds % 60)
	return string.format("%d:%02d", m, s)
end

-- render the player list table
local function renderPlayerList(players: { ClientPlayerInfo })
	Iris.SeparatorText({ "Players" })
	for _, p: ClientPlayerInfo in players do
		local status: string = if not p.isAlive then " [DEAD]" elseif p.hasVoted then " [VOTED]" else ""
		local hintText: string = if p.hint then ` - "{p.hint}"` else ""
		Iris.Text({ `{p.name} ({p.score} pts){status}{hintText}` })
	end
end

-- state-specific UI renderers
local function renderNothing()
	Iris.Text({ "Waiting for game to start..." })
end

local function renderWaiting(payload: ClientPayload)
	Iris.Text({ `Lobby open - {#payload.players} player(s) connected` })
	Iris.Text({ "Waiting for enough players to join." })
end

local function renderSelection(payload: ClientPayload)
	Iris.SeparatorText({ "Round " .. tostring(payload.round) })
	Iris.Text({ `Theme: {payload.theme or "???"}` })

	if payload.word then
		Iris.Text({ `Secret word: {payload.word}` })
	else
		Iris.PushConfig({ TextColor = Color3.fromRGB(255, 80, 80) })
		Iris.Text({ "You are the IMPOSTER! You don't know the word." })
		Iris.PopConfig()
	end

	Iris.Text({ `Time: {formatTime(payload.timeLeft)}` })
	renderPlayerList(payload.players)
end

local function renderGuessing(payload: ClientPayload)
	Iris.SeparatorText({ `Round {payload.round} - Guessing` })
	Iris.Text({ `Theme: {payload.theme or "???"}` })
	Iris.Text({ `Time: {formatTime(payload.timeLeft)}` })

	Iris.Separator()

	if payload.word then
		Iris.Text({ `Word: {payload.word}` })
	else
		Iris.PushConfig({ TextColor = Color3.fromRGB(255, 80, 80) })
		Iris.Text({ "You are the IMPOSTER - blend in!" })
		Iris.PopConfig()
	end

	Iris.InputText({ "Your hint (one word)" }, { text = hintInput })
	if Iris.Button({ "Submit Hint" }).clicked() then
		local hint: string = hintInput:get()
		if #hint > 0 then
			submitHintRemote:FireServer(hint)
			hintInput:set("")
		end
	end

	-- imposter guess option
	if not payload.word then
		Iris.Separator()
		Iris.InputText({ "Guess the word" }, { text = guessInput })
		if Iris.Button({ "Guess Word" }).clicked() then
			local guess: string = guessInput:get()
			if #guess > 0 then
				guessWordRemote:FireServer(guess)
				guessInput:set("")
			end
		end
	end

	renderPlayerList(payload.players)
end

local function renderDiscussion(payload: ClientPayload)
	Iris.SeparatorText({ "Discussion" })
	Iris.Text({ `Time: {formatTime(payload.timeLeft)}` })
	Iris.Text({ "Discuss the hints and find the imposter!" })
	renderPlayerList(payload.players)
end

local function renderVoting(payload: ClientPayload, isOvertime: boolean)
	if isOvertime then
		Iris.PushConfig({ TextColor = Color3.fromRGB(255, 200, 50) })
		Iris.SeparatorText({ "OVERTIME - Revote!" })
		Iris.PopConfig()
	else
		Iris.SeparatorText({ "Voting" })
	end

	Iris.Text({ `Time: {formatTime(payload.timeLeft)}` })

	Iris.Separator()
	for _, p: ClientPlayerInfo in payload.players do
		if not p.isAlive or p.name == player.Name then
			continue
		end

		local label: string = if p.hasVoted then `{p.name} [VOTED]` else p.name
		if Iris.Button({ `Vote: {label}` }).clicked() then
			local target: Player? = Players:FindFirstChild(p.name) :: Player?
			if target then
				castVoteRemote:FireServer(target)
			end
		end
	end

	Iris.Separator()
	if Iris.Button({ "Skip Vote" }).clicked() then
		castVoteRemote:FireServer("skip")
	end
end

local function renderOutcome(payload: ClientPayload)
	local state: GameState = payload.state

	if state == "investigatorWin" then
		Iris.PushConfig({ TextColor = Color3.fromRGB(80, 255, 80) })
		Iris.SeparatorText({ "Investigators Win!" })
		Iris.PopConfig()
	elseif state == "imposterWin" then
		Iris.PushConfig({ TextColor = Color3.fromRGB(255, 80, 80) })
		Iris.SeparatorText({ "Imposter Wins!" })
		Iris.PopConfig()
	elseif state == "investigatorLose" then
		Iris.SeparatorText({ "Investigators Lose..." })
	elseif state == "imposterLose" then
		Iris.SeparatorText({ "Imposter Caught!" })
	end

	if payload.imposterName then
		Iris.Text({ `Imposter was: {payload.imposterName}` })
	end

	if payload.eliminatedName then
		Iris.Text({ `Eliminated: {payload.eliminatedName}` })
	end

	if payload.word then
		Iris.Text({ `The word was: {payload.word}` })
	end

	renderPlayerList(payload.players)
end

-- main render function called every Iris frame
local function renderHud()
	Iris.Window({ "Brainrot Imposter", [Iris.Args.Window.NoClose] = true } :: any)

	local payload: ClientPayload? = currentPayload
	if not payload then
		Iris.Text({ "Connecting..." })
		Iris.End()
		return
	end

	local p: ClientPayload = payload :: ClientPayload
	local state: GameState = p.state

	if state == "nothing" then
		renderNothing()
	elseif state == "waiting" then
		renderWaiting(p)
	elseif state == "selection" then
		renderSelection(p)
	elseif state == "guessing" then
		renderGuessing(p)
	elseif state == "discussion" then
		renderDiscussion(p)
	elseif state == "voting" then
		renderVoting(p, false)
	elseif state == "overtime" then
		renderVoting(p, true)
	else
		renderOutcome(p)
	end

	Iris.End()
end

-- module interface
return {
	context = "once",

	setup = function()
		stateChanged.OnClientEvent:Connect(function(payload: ClientPayload)
			currentPayload = payload
		end)

		Iris:Connect(renderHud)

		logger.log("success", "setup", { status = "ready" })
	end,

	loop = function() end,
}
