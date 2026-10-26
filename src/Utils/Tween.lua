--[[
	Utils/Tween.lua
	Central place for Cherry UI's motion language.

	Everything animated in the library goes through TweenService with a small,
	consistent set of easing curves (Quad for micro-interactions, Quart for
	larger movements, Back only for the window intro).
]]

local TweenService = game:GetService("TweenService")

local Tween = {}

Tween.Info = {
	Instant = TweenInfo.new(0.06, Enum.EasingStyle.Linear),
	Snap = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Fast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Smooth = TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Glide = TweenInfo.new(0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Spring = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

function Tween.linear(duration)
	return TweenInfo.new(duration or 1, Enum.EasingStyle.Linear)
end

--[[
	TweenService:Create raises "no property named 'X' for object 'Y'" for a
	property the instance does not have (GroupTransparency on a Frame is the
	classic case). A cosmetic animation must never take the whole interface down,
	so creation is guarded and failures are reported once per offending property.
]]
local reported = {}

local function createTween(instance, properties, info)
	local ok, result = pcall(TweenService.Create, TweenService, instance, info or Tween.Info.Smooth, properties)

	if ok then
		return result
	end

	local message = tostring(result)
	if not reported[message] then
		reported[message] = true
		warn("[CherryUI] tween skipped: " .. message)
	end

	return nil
end

function Tween.create(instance, properties, info)
	return createTween(instance, properties, info)
end

function Tween.play(instance, properties, info)
	local tween = createTween(instance, properties, info)

	if tween then
		tween:Play()
	end

	return tween
end

--[[
	Animates a number and calls `callback` with every intermediate value.
	Internally it tweens a NumberValue so it can reuse TweenService's easing.
]]
function Tween.number(from, to, duration, callback, style, direction)
	assert(type(callback) == "function", "Tween.number expects a callback")

	local holder = Instance.new("NumberValue")
	holder.Value = from

	local tween = createTween(
		holder,
		{ Value = to },
		TweenInfo.new(
			duration or 0.3,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		)
	)

	local connection = holder:GetPropertyChangedSignal("Value"):Connect(function()
		callback(holder.Value)
	end)

	if not tween then
		holder.Value = to
		connection:Disconnect()
		holder:Destroy()
		callback(to)
		return nil
	end

	tween.Completed:Once(function()
		connection:Disconnect()
		holder:Destroy()
	end)

	tween:Play()
	callback(from)
	return tween
end

return Tween
