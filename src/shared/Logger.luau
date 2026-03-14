--!strict

-- Debug logger that only prints in Studio, with timestamped and categorized output

local RunService = game:GetService("RunService")

local IS_STUDIO: boolean = RunService:IsStudio()

export type LogType = "success" | "info" | "warn" | "error"

local LOG_ICONS: { [LogType]: string } = {
	success = "🟢",
	info = "🔵",
	warn = "🟠",
	error = "🔴",
}

export type Logger = {
	log: (logType: LogType, module: string, data: { [string]: any }?) -> (),
}

local function get_timestamp(): string
	local date: { hour: number, min: number, sec: number } = os.date("!*t") :: any
	return string.format("%02i:%02i:%02i", date.hour, date.min, date.sec)
end

local function format_table(tbl: { [string]: any }): string
	local parts: { string } = {}
	for key: string, value: any in tbl do
		table.insert(parts, string.format('%s="%s"', tostring(key), tostring(value)))
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function create(source: string): Logger
	local function log(logType: LogType, module: string, data: { [string]: any }?)
		if not IS_STUDIO then
			return
		end

		local icon: string = LOG_ICONS[logType]
		local base: string = string.format("[%s] (%s) [%s.%s]", icon, get_timestamp(), source, module)

		if data then
			base ..= " " .. format_table(data)
		end

		print(base)
	end

	return { log = log }
end

return table.freeze({ create = create })
