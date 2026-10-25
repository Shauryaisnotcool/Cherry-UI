--[[
	Utils/Pool.lua
	A minimal object pool.

	Used by the notification stack and by dropdown option rows so opening and
	closing UI never spikes the instance count. Pooled objects are unparented on
	release so they cost nothing to render.
]]

local Pool = {}
Pool.__index = Pool

function Pool.new(create, reset, prefill)
	local self = setmetatable({}, Pool)

	self.Create = create or function()
		return Instance.new("Frame")
	end
	self.Reset = reset
	self.Free = {}
	self.Active = {}
	self.Destroyed = false

	for _ = 1, prefill or 0 do
		local object = self.Create()
		object.Parent = nil
		table.insert(self.Free, object)
	end

	return self
end

function Pool:Get(parent)
	local object = table.remove(self.Free)

	if object == nil then
		object = self.Create()
	end

	self.Active[object] = true

	if parent then
		object.Parent = parent
	end

	return object
end

function Pool:Release(object)
	if object == nil or self.Active[object] == nil then
		return
	end

	self.Active[object] = nil

	if self.Reset then
		self.Reset(object)
	end

	object.Parent = nil

	if self.Destroyed then
		object:Destroy()
	else
		table.insert(self.Free, object)
	end
end

function Pool:ReleaseAll()
	local active = {}

	for object in self.Active do
		table.insert(active, object)
	end

	for index = 1, #active do
		self:Release(active[index])
	end
end

function Pool:Destroy()
	self.Destroyed = true

	local owned = {}

	for object in self.Active do
		table.insert(owned, object)
	end
	for index = 1, #self.Free do
		table.insert(owned, self.Free[index])
	end

	self.Active = {}
	self.Free = {}

	for index = 1, #owned do
		owned[index]:Destroy()
	end
end

return Pool
