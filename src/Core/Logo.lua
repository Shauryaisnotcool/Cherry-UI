--[[
	Core/Logo.lua
	The Cherry UI mark, drawn entirely with GuiObjects.

	Using frames instead of an image means the logo scales to any size without
	a sprite sheet, adapts to the active theme, and can be animated (the window
	intro rotates and fades it, and `Logo.Petal` powers the petal burst).
]]

local Create = require(script.Parent.Parent.Utils.Create)

local Logo = {}

local LEAF_DARK = Color3.fromHex("22C55E")
local LEAF_LIGHT = Color3.fromHex("A7F3D0")
local STEM_COLOR = Color3.fromHex("4ADE80")

--[[
	Builds the logo inside `properties.Parent`.
	Colors for the cherries come from the theme palette ("Accent" -> "Primary").
]]
function Logo.new(library, properties)
	properties = properties or {}

	local frame = Create.new("Frame", {
		Name = "CherryLogo",
		Size = properties.Size or UDim2.fromOffset(24, 24),
		Position = properties.Position or UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = properties.ZIndex or 5,
		Parent = properties.Parent,
	})

	-- Soft accent halo.
	local glow = Create.new("Frame", {
		Name = "Glow",
		Position = UDim2.fromScale(-0.22, -0.22),
		Size = UDim2.fromScale(1.44, 1.44),
		BackgroundTransparency = 0.9,
		Parent = frame,
	})
	Create.corner(glow, UDim.new(1, 0))
	library:Styled(glow, "Primary", "BackgroundColor3")
	Create.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = glow,
	})

	-- Stems.
	local stems = {
		{ X = 0.44, Y = 0.2, Height = 0.3, Rotation = -24 },
		{ X = 0.57, Y = 0.16, Height = 0.27, Rotation = 18 },
	}

	for _, stemData in stems do
		local stem = Create.new("Frame", {
			Name = "Stem",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(stemData.X, stemData.Y),
			Size = UDim2.fromScale(0.055, stemData.Height),
			BackgroundColor3 = STEM_COLOR,
			Rotation = stemData.Rotation,
			Parent = frame,
		})
		Create.corner(stem, UDim.new(0.5, 0))
	end

	-- Leaf.
	local leaf = Create.new("Frame", {
		Name = "Leaf",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.65, 0.18),
		Size = UDim2.fromScale(0.36, 0.18),
		Rotation = -28,
		Parent = frame,
	})
	Create.corner(leaf, UDim.new(1, 0))
	Create.new("UIGradient", {
		Rotation = 40,
		Color = ColorSequence.new(LEAF_DARK, LEAF_LIGHT),
		Parent = leaf,
	})

	-- Cherries.
	local function cherry(x, y, size)
		local berry = Create.new("Frame", {
			Name = "Cherry",
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(size, size),
			Parent = frame,
		})
		Create.corner(berry, UDim.new(1, 0))
		library.ThemeManager:BindGradient(
			Create.new("UIGradient", { Rotation = 45, Parent = berry }),
			{ "Accent", "Primary" }
		)

		local highlight = Create.new("Frame", {
			Name = "Highlight",
			Position = UDim2.fromScale(0.18, 0.14),
			Size = UDim2.fromScale(0.3, 0.24),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.5,
			Parent = berry,
		})
		Create.corner(highlight, UDim.new(1, 0))

		return berry
	end

	cherry(0.07, 0.48, 0.34)
	cherry(0.42, 0.58, 0.36)

	return frame
end

--[[
	A single falling petal, used by the window's intro burst.
	The caller owns the returned frame and is responsible for destroying it.
]]
function Logo.Petal(color, size)
	size = size or 8

	local petal = Create.new("Frame", {
		Name = "Petal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.62, size),
		BackgroundColor3 = color,
		ZIndex = 60,
	})

	Create.corner(petal, UDim.new(1, 0))
	Create.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.45)),
		Parent = petal,
	})

	return petal
end

return Logo
