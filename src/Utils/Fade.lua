--[[
	Utils/Fade.lua
	Whole-subtree fading for plain GuiObjects.

	Roblox only exposes `GroupTransparency` on CanvasGroup, and a CanvasGroup
	re-rasterises its entire subtree whenever any descendant changes — the wrong
	trade for a library that animates an ESP preview at 30 Hz. Instead, `Fade`
	drives the transparency of every descendant together from one number tween.

	Transparency is interpolated as `base + (1 - base) * alpha`, so alpha 0
	restores each element's own transparency exactly and alpha 1 hides the
	subtree no matter what its per-element values were.

	Two rules make that safe when fades nest (the window fades while a tab
	content fades, a notice card fades inside the window):

	  * A value read from a live instance is only trusted while no other fade
	    owns it. Otherwise the owning fade's recorded base is used, because the
	    live value is an in-between animation frame that would otherwise be
	    baked in as the element's "original" transparency and never come back.
	  * A child fade's alpha composes with its parent's
	    (`1 - (1 - parent) * (1 - child)`), and the child re-applies its entries
	    whenever the parent moves, so the two never clobber each other.

	Clean bases are remembered per instance in a weak table for the lifetime of
	the process, which is what keeps close -> open cycles perfectly lossless.
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

-- root -> state
local Cache = setmetatable({}, { __mode = "k" })
-- instance -> { [property] = clean base }
local Bases = setmetatable({}, { __mode = "k" })
-- instance -> { [property] = the state that currently owns the value }
local Owner = setmetatable({}, { __mode = "k" })

local function recordBase(instance, property, value)
	local record = Bases[instance]
	if not record then
		record = {}
		Bases[instance] = record
	end
	record[property] = value
	return value
end

local function ownedBase(instance, property)
	local owners = Owner[instance]
	local owner = owners and owners[property]
	if not owner then
		return nil
	end

	local index = owner.Index[instance]
	local base = index and index[property]
	return base
end

local function captureEntries(state, root)
	local entries, index = state.Entries, state.Index

	local function add(instance)
		for i = 1, #PROPERTIES do
			local property = PROPERTIES[i]
			local live = instance[property]

			if type(live) == "number" then
				-- Prefer, in order: a base another fade already owns, a base we
				-- recorded earlier in this process, and only then the live value.
				local base = ownedBase(instance, property)
				if base == nil then
					local record = Bases[instance]
					base = record and record[property]
				end
				if base == nil then
					base = recordBase(instance, property, live)
				end

				local entry = { Instance = instance, Property = property, Base = base }
				table.insert(entries, entry)

				index[instance] = index[instance] or {}
				index[instance][property] = base

				local owners = Owner[instance]
				if not owners then
					owners = {}
					Owner[instance] = owners
				end
				owners[property] = state
			end
		end
	end

	add(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		add(descendant)
	end
end

local function findParentState(root)
	local node = root.Parent

	while node do
		local state = Cache[node]
		if state then
			return state
		end
		node = node.Parent
	end

	return nil
end

local function newState(root)
	local state = {
		Root = root,
		Entries = {},
		Index = {},
		Children = {},
		Alpha = 0,
		Effective = 0,
		Token = 0,
	}

	state.Parent = findParentState(root)
	captureEntries(state, root)

	if state.Parent then
		table.insert(state.Parent.Children, state)
	end

	Cache[root] = state
	return state
end

local function applyState(state)
	local effective = state.Alpha
	local parent = state.Parent

	if parent then
		effective = 1 - (1 - (parent.Effective or 0)) * (1 - state.Alpha)
	end

	state.Effective = effective

	local entries = state.Entries
	for i = 1, #entries do
		local entry = entries[i]
		local base = entry.Base
		entry.Instance[entry.Property] = base + (1 - base) * effective
	end

	-- Deeper fades own the same instances; they re-apply with the new combined
	-- alpha so a parent move can never clobber a child's contribution.
	local children = state.Children
	for i = 1, #children do
		applyState(children[i])
	end
end

local function repruneParent(state)
	local parent = state.Parent
	if not parent then
		return
	end

	local index = table.find(parent.Children, state)
	if index then
		table.remove(parent.Children, index)
	end
end

local function adoptChildren(state)
	local children = state.Children
	for i = 1, #children do
		local child = children[i]
		child.Parent = state.Parent

		if state.Parent then
			table.insert(state.Parent.Children, child)
		end
	end
	table.clear(children)
end

-- Drops a fully-visible state, releasing ownership so the next fade re-reads
-- the (now restored) values.
local function release(root, state)
	repruneParent(state)
	adoptChildren(state)

	local entries = state.Entries
	for i = 1, #entries do
		local entry = entries[i]
		local owners = Owner[entry.Instance]
		if owners and owners[entry.Property] == state then
			owners[entry.Property] = nil
		end
	end

	table.clear(state.Entries)
	table.clear(state.Index)
	state.Alpha = 0
	state.Effective = 0

	if Cache[root] == state then
		Cache[root] = nil
	end
end

--[[
	`releaseWhenClear` is only true for the *end* of an animation (or a direct
	`Fade.set`), never for an intermediate frame. Releasing while a tween is
	running would drop the entries the remaining frames write to, which silently

turned "fade out" into "do nothing".
]]
local function setAlpha(root, state, alpha, releaseWhenClear)
	state.Alpha = alpha
	applyState(state)

	if releaseWhenClear and alpha <= 0 then
		release(root, state)
	end
end

local function stateFor(root)
	local state = Cache[root]
	if not state then
		state = newState(root)
	end
	return state
end

-- Instantly sets a subtree's fade level (0 = normal, 1 = invisible).
function Fade.set(root, alpha)
	if not root then
		return
	end

	setAlpha(root, stateFor(root), alpha, true)
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

	setAlpha(root, state, from, false)

	local tween = Tween.number(from, to, duration or 0.24, function(value)
		if state.Token ~= token then
			return
		end
		setAlpha(root, state, value, false)
	end, style, direction)

	duration = duration or 0.24

	task.delay(duration, function()
		if state.Token ~= token then
			return
		end

		setAlpha(root, state, to, true)

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

-- Drops a cached state (for callers that rebuild a subtree in place).
function Fade.invalidate(root)
	local state = root and Cache[root]
	if state then
		setAlpha(root, state, 0)
	end
end

--[[
	Restores a subtree to its clean, fully-visible values and drops any cached
	fade state for it. Returns the number of properties repaired plus a list of
	"Instance.Class.Property" strings (capped, for diagnostics).

	Only elements whose *original* value was visible are touched: the hover
	overlays, popup catchers and other deliberately invisible frames recorded a
	base of 1 the first time they were seen, so they are left alone.
]]
local RESET_LIMIT = 40

--[[
	`textOnly` limits the repair to text properties. That is what the automatic
	self-heal uses: a background/indicator transparency of 1 is often a deliberate
	state (an inactive tab's underline), while invisible text never is.
]]
function Fade.reset(root, textOnly)
	if not root then
		return 0, {}
	end

	Fade.invalidate(root)

	local repaired = 0
	local details = {}

	local function restore(instance)
		local record = Bases[instance]
		if not record then
			return
		end

		for property, base in record do
			local wanted = not textOnly or string.sub(property, 1, 4) == "Text"
			local live = instance[property]
			if wanted and type(live) == "number" and live > 0.95 and base < 0.5 then
				instance[property] = base
				repaired += 1

				if #details < RESET_LIMIT then
					table.insert(details, instance:GetFullName() .. "." .. property)
				end
			end
		end
	end

	restore(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		restore(descendant)
	end

	return repaired, details
end

--[[
	Forgets the recorded base of an instance (or a whole subtree). Call this
	after changing an element's "resting" transparency by hand, otherwise the
	next fade would restore the old value.
]]
function Fade.forget(instance)
	if not instance then
		return
	end

	Bases[instance] = nil
	Owner[instance] = nil

	for _, descendant in ipairs(instance:GetDescendants()) do
		Bases[descendant] = nil
		Owner[descendant] = nil
	end
end

return Fade
