local Minerais = {}

export type Minerai = {
  name: string,
  duration: number,
  enter: () -> (),
  start: () -> (),
  complete: () -> (),
}

-- state machine wip

return Minerais
