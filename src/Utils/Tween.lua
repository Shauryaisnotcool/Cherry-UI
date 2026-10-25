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

function Tween.create(instance, properties, info)
	return TweenService:Create(instance, info or Tween.Info.Smooth, properties)
end

function Tween.play(instance, properties, info)
	local tween = TweenService:Create(instance, info or Tween.Info.Smooth, properties)
	tween:Play()
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

	local tween = TweenService:Create(
		holder,
		TweenInfo.new(
			duration or 0.3,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		),
		{ Value = to }
	)

	local connection = holder:GetPropertyChangedSignal("Value"):Connect(function()
		callback(holder.Value)
	end)

	tween.Completed:Once(function()
		connection:Disconnect()
		holder:Destroy()
	end)

	tween:Play()
	callback(from)
	return tween
end

return Tween
