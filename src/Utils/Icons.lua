--[[
	Utils/Icons.lua
	Crisp, themeable icons drawn entirely from GuiObjects.

	Why not text glyphs? Roblox's default fonts have no coverage for the
	"dingbat" range (⌕ ✕ ▾ ✓ ◉ …), so those characters render as tofu boxes.
	Uploaded images are not an option either: a drop-in library cannot ship
	asset IDs. Every icon here is composed from a few rounded Frames instead,
	which means it is font-independent, stays sharp at any size, recolors with
	the theme, and animates (rotation, transparency) like any other instance.

	Icons are designed once on a 20x20 grid and scaled to the requested size, so
	the same drawing drives a 12px dropdown check and the 24px cursor arrow.

		Icons.new("target", parent, 16, palette.Primary)
		Icons.setColor(icon, palette.SubText)
		Icons.setTransparency(icon, 0.5)   -- used by tab dimming
]]

local Create = require(script.Parent.Create)
local Tween = require(script.Parent.Tween)

local Icons = {}

-- The design grid every builder draws on.
Icons.Grid = 20

-- frame -> { Parts = { { Instance, Color, Transparency } }, Size = n } (weak keys)
local Registry = setmetatable({}, { __mode = "k" })

--[[
	A single recolorable part. `color` and `transparency` are the property names
	to write, so one record serves Frames (BackgroundColor3/BackgroundTransparency)
	and strokes (Color/Transparency) alike.
]]
local function part(parts, instance, colorProperty, transparencyProperty, color)
	if colorProperty then
		instance[colorProperty] = color
	end

	table.insert(parts, {
		Instance = instance,
		Color = colorProperty,
		Transparency = transparencyProperty,
	})

	return instance
end

--------------------------------------------------------------------------
-- Primitives (each registers what it draws)
--------------------------------------------------------------------------

--[[
	A rounded stroke between two points on the design grid.
	One rotated bar beats stacking axis-aligned ones, which leave notches at the
	joints. Used for every diagonal: checks, chevrons, the cursor arrow.
]]
function Icons.line(parts, parent, x1, y1, x2, y2, thickness, color, zIndex)
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)

	local bar = Create.new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(x1, y1),
		Size = UDim2.fromOffset(length, thickness),
		Rotation = math.deg(math.atan2(dy, dx)),
		ZIndex = zIndex or 3,
		Parent = parent,
	})
	Create.corner(bar, UDim.new(0.5, 0))

	return part(parts, bar, "BackgroundColor3", "BackgroundTransparency", color)
end

-- A stroke-only circle/ellipse (UICorner 1 makes any size an ellipse).
function Icons.ring(parts, parent, x, y, width, height, thickness, color, zIndex)
	local ring = Create.new("Frame", {
		Name = "Ring",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		ZIndex = zIndex or 2,
		Parent = parent,
	})
	Create.corner(ring, UDim.new(1, 0))

	local stroke = Create.new("UIStroke", {
		Thickness = thickness,
		Parent = ring,
	})

	return part(parts, stroke, "Color", "Transparency", color)
end

function Icons.dot(parts, parent, x, y, size, color, zIndex)
	local dot = Create.new("Frame", {
		Name = "Dot",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		ZIndex = zIndex or 4,
		Parent = parent,
	})
	Create.corner(dot, UDim.new(1, 0))

	return part(parts, dot, "BackgroundColor3", "BackgroundTransparency", color)
end

-- A rotated square: the cheapest solid diamond.
function Icons.diamond(parts, parent, x, y, size, radius, color, zIndex)
	local shape = Create.new("Frame", {
		Name = "Diamond",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		Rotation = 45,
		ZIndex = zIndex or 2,
		Parent = parent,
	})
	Create.corner(shape, radius or UDim.new(0, 2))

	return part(parts, shape, "BackgroundColor3", "BackgroundTransparency", color)
end

-- A stroke-only rounded rectangle (used by "layers" and "copy").
function Icons.outline(parts, parent, x, y, width, height, radius, thickness, color, zIndex)
	local shape = Create.new("Frame", {
		Name = "Outline",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		ZIndex = zIndex or 2,
		Parent = parent,
	})
	Create.corner(shape, radius)

	local stroke = Create.new("UIStroke", {
		Thickness = thickness,
		Parent = shape,
	})

	return part(parts, stroke, "Color", "Transparency", color)
end

--------------------------------------------------------------------------
-- Builders: one per icon kind, each draws at `color` on the canvas
--------------------------------------------------------------------------

local BUILDERS = {}

BUILDERS.target = function(parts, color, canvas)
	Icons.ring(parts, canvas, 5, 5, 10, 10, 1.8, color)
	Icons.line(parts, canvas, 10, 1, 10, 4, 1.8, color)
	Icons.line(parts, canvas, 10, 16, 10, 19, 1.8, color)
	Icons.line(parts, canvas, 1, 10, 4, 10, 1.8, color)
	Icons.line(parts, canvas, 16, 10, 19, 10, 1.8, color)
	Icons.dot(parts, canvas, 8.6, 8.6, 2.8, color)
end

BUILDERS.eye = function(parts, color, canvas)
	Icons.ring(parts, canvas, 2, 6, 16, 8, 1.8, color)
	Icons.dot(parts, canvas, 8, 8, 4, color)
end

BUILDERS.layers = function(parts, color, canvas)
	Icons.outline(parts, canvas, 5, 2, 10, 10, UDim.new(0, 2), 1.8, color, 2)
	Icons.outline(parts, canvas, 5, 8.5, 10, 10, UDim.new(0, 2), 1.8, color, 3)
end

BUILDERS.players = function(parts, color, canvas)
	Icons.ring(parts, canvas, 7, 1.5, 6, 6, 1.8, color)
	Icons.outline(parts, canvas, 3, 11, 14, 7, UDim.new(0.5, 0), 1.8, color, 2)
end

BUILDERS.settings = function(parts, color, canvas)
	for _, row in ipairs({
		{ Y = 6, Knob = 12 },
		{ Y = 10, Knob = 6 },
		{ Y = 14, Knob = 14 },
	}) do
		Icons.line(parts, canvas, 3, row.Y, 17, row.Y, 1.6, color)
		Icons.dot(parts, canvas, row.Knob - 2.1, row.Y - 2.1, 4.2, color)
	end
end

BUILDERS.search = function(parts, color, canvas)
	Icons.ring(parts, canvas, 2.5, 2.5, 11, 11, 1.8, color)
	Icons.line(parts, canvas, 12, 12, 17.5, 17.5, 1.8, color)
end

BUILDERS.close = function(parts, color, canvas)
	Icons.line(parts, canvas, 4.5, 4.5, 15.5, 15.5, 1.8, color)
	Icons.line(parts, canvas, 15.5, 4.5, 4.5, 15.5, 1.8, color)
end

BUILDERS.check = function(parts, color, canvas)
	Icons.line(parts, canvas, 3.5, 10.5, 8, 15, 1.9, color)
	Icons.line(parts, canvas, 8, 15, 16.5, 4.5, 1.9, color)
end

-- Points down at rotation 0; the dropdown rotates it 180 degrees when open.
BUILDERS.chevron = function(parts, color, canvas)
	Icons.line(parts, canvas, 4.5, 7.5, 10, 13, 1.9, color)
	Icons.line(parts, canvas, 10, 13, 15.5, 7.5, 1.9, color)
end

BUILDERS.refresh = function(parts, color, canvas)
	Icons.ring(parts, canvas, 3.5, 3.5, 13, 13, 1.8, color)
	Icons.line(parts, canvas, 12.5, 1.8, 17.2, 1.8, 1.8, color)
	Icons.line(parts, canvas, 17.2, 1.8, 17.2, 6.5, 1.8, color)
end

BUILDERS.copy = function(parts, color, canvas)
	Icons.outline(parts, canvas, 3, 2, 9, 11, UDim.new(0, 2), 1.6, color, 2)
	Icons.outline(parts, canvas, 8, 7, 9, 11, UDim.new(0, 2), 1.6, color, 3)
end

BUILDERS.diamond = function(parts, color, canvas)
	Icons.diamond(parts, canvas, 5, 5, 10, UDim.new(0, 2), color)
end

BUILDERS.info = function(parts, color, canvas)
	Icons.ring(parts, canvas, 2, 2, 16, 16, 1.8, color)
	Icons.dot(parts, canvas, 8.9, 5.5, 2.4, color)
	Icons.line(parts, canvas, 10, 9.5, 10, 14.5, 1.8, color)
end

BUILDERS.warning = function(parts, color, canvas)
	Icons.ring(parts, canvas, 2, 2, 16, 16, 1.8, color)
	Icons.line(parts, canvas, 10, 6, 10, 11.5, 1.8, color)
	Icons.dot(parts, canvas, 8.9, 13.2, 2.4, color)
end

BUILDERS.success = function(parts, color, canvas)
	Icons.ring(parts, canvas, 2, 2, 16, 16, 1.8, color)
	Icons.line(parts, canvas, 6, 10.5, 9, 13.5, 1.8, color)
	Icons.line(parts, canvas, 9, 13.5, 14.5, 6.5, 1.8, color)
end

BUILDERS.error = function(parts, color, canvas)
	Icons.ring(parts, canvas, 2, 2, 16, 16, 1.8, color)
	Icons.line(parts, canvas, 7, 7, 13, 13, 1.8, color)
	Icons.line(parts, canvas, 13, 7, 7, 13, 1.8, color)
end

-- The pointer arrow used by Core/Cursor.lua: a stroke-drawn arrowhead plus a
-- tail. Drawn rather than textured so it never depends on an asset id.
BUILDERS.cursor = function(parts, color, canvas)
	Icons.line(parts, canvas, 4.5, 1.5, 4.5, 14.5, 1.9, color)
	Icons.line(parts, canvas, 4.5, 1.5, 11, 12, 1.9, color)
	Icons.line(parts, canvas, 4.5, 14.5, 11, 12, 1.9, color)
	Icons.line(parts, canvas, 11, 12, 13.5, 18.5, 2.4, color)
end

--------------------------------------------------------------------------
-- Aliases: friendly names, the old glyphs (existing scripts keep working) and
-- the emoji people tend to type.
--------------------------------------------------------------------------

local ALIASES = {
	target = "target",
	crosshair = "target",
	aim = "target",
	aimbot = "target",
	combat = "target",
	["◎"] = "target",
	["🎯"] = "target",

	layers = "layers",
	visuals = "layers",
	esp = "layers",
	render = "layers",
	["◈"] = "layers",
	["🧊"] = "layers",

	players = "players",
	player = "players",
	list = "players",
	people = "players",
	["☰"] = "players",
	["👥"] = "players",

	settings = "settings",
	config = "settings",
	gear = "settings",
	options = "settings",
	["⚙"] = "settings",
	["⚙️"] = "settings",

	eye = "eye",
	spectate = "eye",
	info = "info",
	["◉"] = "eye",
	["👁"] = "eye",

	search = "search",
	["⌕"] = "search",
	["🔍"] = "search",

	close = "close",
	["✕"] = "close",
	["×"] = "close",
	["✗"] = "close",

	check = "check",
	["✓"] = "check",
	["✔"] = "check",

	chevron = "chevron",
	["▾"] = "chevron",
	["▿"] = "chevron",

	refresh = "refresh",
	reload = "refresh",
	rescan = "refresh",
	["⟳"] = "refresh",
	["↻"] = "refresh",

	copy = "copy",
	clipboard = "copy",
	["⧉"] = "copy",

	diamond = "diamond",
	notification = "diamond",
	["◆"] = "diamond",

	warning = "warning",
	["⚠"] = "warning",
	danger = "error",
	error = "error",
	success = "success",

	cursor = "cursor",
	arrow = "cursor",
	pointer = "cursor",
}

-- Maps a glyph / friendly name / kind to a drawable kind, or nil when the
-- string should be rendered as text (a plain letter or an emoji we don't draw).
function Icons.resolve(icon)
	if type(icon) ~= "string" then
		return nil
	end

	local kind = ALIASES[icon]
	if kind and BUILDERS[kind] then
		return kind
	end

	return nil
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

--[[
	Builds an icon.
	    kind   - a key from ALIASES / BUILDERS ("target", "close", "cursor", …)
	    parent - parent instance
	    size   - rendered size in pixels (default 16)
	    color  - single colour for every part
]]
function Icons.new(kind, parent, size, color, zIndex)
	size = size or 16
	color = color or Color3.new(1, 1, 1)
	zIndex = zIndex or 5

	local root = Create.new("Frame", {
		Name = "Icon_" .. tostring(kind),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		Parent = parent,
	})

	--[[
		The design canvas is 20x20 and a UIScale maps it to the requested size.
		The UIScale sits on the *canvas*, not on the root: UIScale scales the
		GuiObject it is a child of, so hanging it on the root would shrink the
		root's own box and throw off any AnchorPoint-based centering.
	]]
	local canvas = Create.new("Frame", {
		Name = "Canvas",
		Size = UDim2.fromOffset(Icons.Grid, Icons.Grid),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		Parent = root,
	})

	local scale = Create.new("UIScale", { Scale = size / Icons.Grid, Parent = canvas })

	local parts = {}
	local builder = BUILDERS[kind]

	if builder then
		builder(parts, color, canvas)
	else
		warn("[CherryUI] Unknown icon kind: " .. tostring(kind))
	end

	Registry[root] = {
		Parts = parts,
		Canvas = canvas,
		Scale = scale,
		Size = size,
	}

	return root
end

--[[
	Resizes a drawn icon. The drawing lives on a fixed 20x20 design grid that a
	UIScale maps onto the requested size, so both have to move together; passing
	tween info animates the change (used for the close button hover pop).
]]
function Icons.setSize(icon, size, info)
	local entry = Registry[icon]
	if not entry then
		return icon
	end

	entry.Size = size

	local rootSize = UDim2.fromOffset(size, size)
	local target = { Scale = size / Icons.Grid }

	if info then
		Tween.play(entry.Scale, target, info)
		Tween.play(icon, { Size = rootSize }, info)
	else
		entry.Scale.Scale = target.Scale
		icon.Size = rootSize
	end

	return icon
end

-- Recolors every part of a drawn icon.
function Icons.setColor(icon, color)
	local entry = Registry[icon]
	if not entry then
		return icon
	end

	for _, item in ipairs(entry.Parts) do
		if item.Color then
			item.Instance[item.Color] = color
		end
	end

	return icon
end

-- Fades a drawn icon (0 = solid, 1 = invisible) and hides it entirely at 1.
function Icons.setTransparency(icon, transparency)
	local entry = Registry[icon]
	if not entry then
		return icon
	end

	for _, item in ipairs(entry.Parts) do
		if item.Transparency then
			item.Instance[item.Transparency] = transparency
		end
	end

	return icon
end

-- Keeps every part of an icon in sync with a theme token ("Primary", "SubText").
function Icons.bindTheme(icon, library, token)
	local entry = Registry[icon]
	if not entry then
		return icon
	end

	for _, item in ipairs(entry.Parts) do
		if item.Color then
			library.ThemeManager:Bind(item.Instance, item.Color, token)
		end
	end

	return icon
end

function Icons.isIcon(instance)
	return Registry[instance] ~= nil
end

return Icons
