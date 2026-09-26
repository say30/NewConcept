--[[
	Logger
	Messages lisibles dans l'Output de Studio + relais vers l'interface
	(barre de statut). Aucun module ne fait de print() directement.
]]

local Config = require(script.Parent.Config)

local Logger = {}

local PREFIX = "[" .. Config.PLUGIN_DISPLAY_NAME .. "] "
local sinks = {}

Logger.Level = {
	Info = "Info",
	Success = "Success",
	Warning = "Warning",
	Error = "Error",
}

local function dispatch(level, message)
	for _, sink in ipairs(sinks) do
		local ok, err = pcall(sink, level, message)
		if not ok then
			warn(PREFIX .. "Logger sink error: " .. tostring(err))
		end
	end
end

function Logger.addSink(callback)
	table.insert(sinks, callback)
	return function()
		local index = table.find(sinks, callback)
		if index then
			table.remove(sinks, index)
		end
	end
end

function Logger.info(message)
	print(PREFIX .. message)
	dispatch(Logger.Level.Info, message)
end

function Logger.success(message)
	print(PREFIX .. message)
	dispatch(Logger.Level.Success, message)
end

function Logger.warn(message)
	warn(PREFIX .. message)
	dispatch(Logger.Level.Warning, message)
end

function Logger.error(message)
	warn(PREFIX .. "ERROR: " .. message)
	dispatch(Logger.Level.Error, message)
end

-- Message uniquement dans l'Output (détails techniques).
function Logger.verbose(message)
	print(PREFIX .. message)
end

return Logger
