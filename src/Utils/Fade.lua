--[[
	Utils/Fade.lua
	Whole-subtree fading for plain GuiObjects.

	Roblox only exposes `GroupTransparency` on CanvasGroup, and a CanvasGroup
	re-rasterises its entire subtree whenever any descendant changes — the wrong
	trade for a library that animates an ESP preview at 30 Hz. Instead, `Fade`
	snapshots the transparency of every descendant once, then drives them together
	through a single number tween.

	Transparency is interpolated as `base + (1 - base) * alpha`, so:
	  * alpha 0 restores each element's own transparency exactly (nothing drifts)
	  * alpha 1 hides the subtree no matter what its per-element values were
	  * elements that are already invisible (base = 1) stay invisible

	The snapshot is dropped when a fade completes at alpha 0 (a clean state), and
	kept when it completes at alpha 1 (the values are polluted, but the bases are
	still the clean ones), so close -> open cycles never lose their baseline.
]]

local Tween = require(script.Parent.Tween)

local Fade = {}

-- Only numeric transparency properties. Reading a property the instance does not
-- have returns nil, which the numeric check below filters out.
local PROPERTIES = {
	"BackgroundTransparency",
	"TextTransparency",
	"TextStrokeTransparency",
	"ImageTransparency",
	"ScrollBarImageTransparency",
	"Transparency",
}

-- root -> { Entries = { { Instance, Property, Base } }, Alpha, Token }
local Cache = setmetatable({}, { __mode = "k" })

local function addEntries(entries, instance)
	for index = 1, #PROPERTIES do
		local property = PROPERTIES[index]
		local value = instance[property]

		if type(value) == "number" then
			table.insert(entries, { Instance = instance, Property = property, Base = value })
		end
	end
end

local function capture(root)
	local entries = {}

	addEntries(entries, root)
	for _, descendant in ipairs(root:GetDescendants()) do
		addEntries(entries, descendant)
	end

	return { Entries = entries, Alpha = 0, Token = 0 }
end

local function apply(state, alpha)
	local entries = state.Entries

	for index = 1, #entries do
		local entry = entries[index]
		local base = entry.Base
		entry.Instance[entry.Property] = base + (1 - base) * alpha
	end

	state.Alpha = alpha
end

local function stateFor(root)
	local state = Cache[root]

	if not state then
		state = capture(root)
		Cache[root] = state
	end

	return state
end

-- Instantly sets a subtree's fade level (0 = normal, 1 = invisible).
function Fade.set(root, alpha)
	if not root then
		return
	end

	local state = stateFor(root)
	apply(state, alpha)

	if alpha <= 0 then
		Cache[root] = nil
	end
end

--[[
	Animates a subtree from `from` to `to`.
	`onComplete` runs exactly once, for the newest fade on that root only, so a
	rapid open/close cannot leave a half-faded window.
]]
function Fade.play(root, from, to, duration, style, direction, onComplete)
	if not root then
		return nil
	end

	local state = stateFor(root)
	state.Token += 1
	local token = state.Token

	apply(state, from)

	local tween = Tween.number(from, to, duration or 0.24, function(value)
		if state.Token ~= token then
			return
		end
		apply(state, value)
	end, style, direction)

	task.delay(duration or 0.24, function()
		if state.Token ~= token then
			return
		end

		apply(state, to)

		if to <= 0 then
			Cache[root] = nil
		end

		if onComplete then
			onComplete()
		end
	end)

	return tween
end

function Fade.playing(root)
	local state = Cache[root]
	return state ~= nil and state.Alpha > 0
end

-- Drops a cached snapshot (for callers that rebuild a subtree in place).
function Fade.invalidate(root)
	if root then
		Cache[root] = nil
	end
end

return Fade
