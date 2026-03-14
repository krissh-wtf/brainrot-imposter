--!strict

-- Functional state machine for managing timed game states with enter/exit transitions

export type StateDefinition = {
	name: string,
	duration: number,
	enter: ((previous: string?) -> boolean)?,
	completed: (() -> string?)?,
}

export type StateMachineInstance = {
	define: (states: { StateDefinition }) -> (),
	transition: (stateName: string) -> (),
	update: () -> (),
	getCurrent: () -> string?,
	getElapsed: () -> number,
}

local function create(): StateMachineInstance
	local states: { [string]: StateDefinition } = {}
	local currentState: string? = nil
	local startTime: number = 0
	local duration: number = 0

	local instance: StateMachineInstance = {} :: StateMachineInstance

	function instance.define(stateList: { StateDefinition })
		for _, state: StateDefinition in stateList do
			states[state.name] = state
		end

		if stateList[1] then
			instance.transition(stateList[1].name)
		end
	end

	function instance.transition(stateName: string)
		local nextState: StateDefinition? = states[stateName]
		if not nextState then
			return
		end

		local state: StateDefinition = nextState :: StateDefinition
		local previous: string? = currentState

		if state.enter and not (state.enter :: (previous: string?) -> boolean)(previous) then
			return
		end

		currentState = stateName
		duration = state.duration
		startTime = workspace:GetServerTimeNow()
	end

	function instance.update()
		if not currentState then
			return
		end

		local now: number = workspace:GetServerTimeNow()
		local elapsed: number = now - startTime
		if elapsed < duration then
			return
		end

		local state: StateDefinition? = states[currentState :: string]
		if not state then
			return
		end

		local def: StateDefinition = state :: StateDefinition
		if def.completed then
			local nextState: string? = (def.completed :: () -> string?)()
			if nextState then
				instance.transition(nextState)
			end
		end
	end

	function instance.getCurrent(): string?
		return currentState
	end

	function instance.getElapsed(): number
		return workspace:GetServerTimeNow() - startTime
	end

	return instance
end

return table.freeze({ create = create })
