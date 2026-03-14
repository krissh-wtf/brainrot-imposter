local Minerais = {}
Minerais.__index = Minerais

export type Minerai = {
  name: string,
  duration: number,
  enter: ((previous: string?) -> boolean)?,
  completed: (() -> string?)?,
}

export type Minerais = typeof(setmetatable(
  {} :: {
    minerais: { [string]: Minerai },
    currentMinerai: string?,
    _startTime: number,
    _duration: number,
  },

  Minerais
))

function Minerais.new(): Minerais
  local self = setmetatable({
    minerais = {},
    currentMinerai = nil :: string?,
    _startTime = 0,
    _duration = 0,
  }, Minerais)

  return self
end

function Minerais:defineMinerais(minerais: { Minerai })
  for _, minerai in ipairs(minerais) do
    self.minerais[minerai.name] = minerai
  end

  if minerais[1] then
    self:transition(minerais[1].name)
  end
end

function Minerais:transition(mineraiName: string)
  local nextMinerai = self.minerais[mineraiName]
  if not nextMinerai then
    return
  end

  local minerai = nextMinerai :: Minerai
  local previous = self.currentMinerai
  if minerai.enter and not minerai.enter(previous) then
    return
  end

  self.currentMinerai = mineraiName
  self._duration = minerai.duration
  self._startTime = workspace:GetServerTimeNow()
end

function Minerais:update()
  local stateName = self.currentMinerai
  if not stateName then
    return
  end

  local now = workspace:GetServerTimeNow()
  local elapsed = now - self._startTime
  if elapsed < self._duration then
    return
  end

  local state = self.minerais[stateName]
  if not state then
    return
  end

  local minerai = state :: Minerai
  if minerai.completed then
    local nextState = minerai.completed()
    if nextState then
      self:transition(nextState)
    end
  end
end

return Minerais
