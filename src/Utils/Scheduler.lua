--[[
	Utils/Scheduler.lua
	One Heartbeat connection drives every repeating Cherry UI task.

	Instead of each live component connecting its own RenderStepped/Heartbeat
	event (and running at 60+ Hz), they register with the scheduler, which ticks
	at a capped frequency (30 Hz by default) and then runs due tasks. The ESP
	preview, player list refresh and notification timers all use it.
]]

local RunService = game:GetService("RunService")

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new(frequency)
	local self = setmetatable({}, Scheduler)

	self.Frequency = frequency or 30
	self.Interval = 1 / self.Frequency
	self.Tasks = {}
	self.Accumulator = 0
	self.Destroyed = false

	self.Connection = RunService.Heartbeat:Connect(function(deltaTime)
		self:_step(deltaTime)
	end)

	return self
end

function Scheduler:_step(deltaTime)
	if self.Destroyed then
		return
	end

	self.Accumulator += deltaTime

	if self.Accumulator < self.Interval then
		return
	end

	local elapsed = self.Accumulator
	self.Accumulator = self.Accumulator % self.Interval

	local tasks = self.Tasks
	local index = 1

	while index <= #tasks do
		local taskEntry = tasks[index]

		if taskEntry.Cancelled then
			table.remove(tasks, index)
		else
			taskEntry.Elapsed += elapsed

			while taskEntry.Elapsed >= taskEntry.Interval do
				taskEntry.Elapsed -= taskEntry.Interval

				if taskEntry.Callback then
					local ok, err = pcall(taskEntry.Callback)
					if not ok then
						warn("[CherryUI] Scheduler task error: " .. tostring(err))
					end
				end

				if taskEntry.Cancelled then
					break
				end
			end

			index += 1
		end
	end
end

function Scheduler:Every(interval, callback, runImmediately)
	local taskEntry = {
		Interval = math.max(tonumber(interval) or self.Interval, 0.01),
		Elapsed = 0,
		Callback = callback,
		Cancelled = false,
	}

	table.insert(self.Tasks, taskEntry)

	if runImmediately and callback then
		task.spawn(callback)
	end

	return taskEntry
end

function Scheduler:Remove(taskEntry)
	if taskEntry then
		taskEntry.Cancelled = true
	end
end

function Scheduler:Clear()
	for index = 1, #self.Tasks do
		self.Tasks[index].Cancelled = true
	end
	table.clear(self.Tasks)
end

function Scheduler:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	self:Clear()
end

return Scheduler
