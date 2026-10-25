--[[
	Utils/Signal.lua
	A tiny signal implementation used for component callbacks and library events.

	Design notes:
	* handlers are stored in a dictionary so disconnecting is O(1)
	* firing iterates over a snapshot, so connecting/disconnecting inside a
	  handler is safe
	* handler errors are caught and reported instead of breaking the whole UI
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect expects a function")

	local signal = self
	local connection = {
		Connected = true,
		Callback = callback,
	}

	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		self.Callback = nil
		signal._handlers[self] = nil
	end

	function connection:IsConnected()
		return self.Connected
	end

	self._handlers[connection] = true
	return connection
end

function Signal:Fire(...)
	local snapshot = {}
	for connection in self._handlers do
		table.insert(snapshot, connection)
	end

	for index = 1, #snapshot do
		local connection = snapshot[index]
		if connection.Connected and connection.Callback then
			local ok, err = pcall(connection.Callback, ...)
			if not ok then
				warn("[CherryUI] Signal handler error: " .. tostring(err))
			end
		end
	end
end

function Signal:DisconnectAll()
	for connection in self._handlers do
		connection.Connected = false
		connection.Callback = nil
	end
	table.clear(self._handlers)
end

function Signal:Destroy()
	self:DisconnectAll()
end

return Signal
