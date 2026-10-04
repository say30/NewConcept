--!strict
-- Minimal synchronous signal. Listeners run in connection order.

export type Connection = { Disconnect: (self: Connection) -> () }

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _listeners = {} :: { [number]: any } }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local listener = { fn = fn, connected = true }
	table.insert(self._listeners, listener)

	local signal = self
	return {
		Disconnect = function()
			if not listener.connected then
				return
			end
			listener.connected = false
			local index = table.find(signal._listeners, listener)
			if index then
				table.remove(signal._listeners, index)
			end
		end,
	}
end

function Signal:Fire(...: any)
	-- Copy so listeners can disconnect while we iterate.
	for _, listener in table.clone(self._listeners) do
		if listener.connected then
			listener.fn(...)
		end
	end
end

function Signal:DisconnectAll()
	for _, listener in self._listeners do
		listener.connected = false
	end
	table.clear(self._listeners)
end

return Signal
