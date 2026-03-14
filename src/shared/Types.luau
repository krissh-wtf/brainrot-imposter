--!strict

export type Role = "investigator" | "imposter"

export type GameState =
  "nothing"
  | "waiting"
  | "selection"
  | "guessing"
  | "discussion"
  | "voting"
  | "overtime"
  | "investigatorWin"
  | "investigatorLose"
  | "imposterWin"
  | "imposterLose"

export type PlayerData = {
  player: Player,
  role: Role?,
  isAfk: boolean,
  vote: Player?,
  hint: string?,
  isAlive: boolean,
  score: number,
}

export type GameData = {
  state: GameState,
  players: { [Player]: PlayerData },
  theme: string?,
  word: string?,
  imposter: Player?,
  round: number,
  roundStartTime: number,
}

-- payload sent to each client on state change
export type ClientPayload = {
  state: GameState,
  theme: string?,
  word: string?,
  players: { { name: string, isAlive: boolean, score: number, hint: string? } },
  round: number,
  timeLeft: number,
}

return nil
