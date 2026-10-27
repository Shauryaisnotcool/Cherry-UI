--[[
	Core/Cursor.lua
	The Cherry pointer: a stroke-drawn arrow with a cherry badge.

	Roblox cannot set an operating-system cursor from a LocalScript and there is
	no way to ship an uploaded image with a library, so the supported route is to
	hide the default pointer (`UserInputService.MouseIconEnabled = false`) and
	draw our own. Everything here is GuiObjects, so it needs no asset id, recolors
	with the active theme, and stays crisp at any resolution.

	The arrow tip sits exactly at the frame's origin, which makes the hotspot
	(0, 0): the pointer lands where the user is actually aiming.

	Modes (see `CherryUI:SetCursorMode`):
	  * "always" - replaces the Roblox pointer as soon as the library loads (default)
	  * "menu"   - only while a Cherry UI window is open
	  * "off"    - never; the Roblox cursor is left alone

	The cursor also survives mouse-lock changes: `Refresh` re-runs whenever
	MouseBehavior flips, so unlocking the mouse brings the pointer back without
	waiting for the menu to be opened or closed.

	Cost: one RenderStepped connection that exists only while the cursor is
	actually visible.
]]

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Parent.Utils.Create)
local Icons = require(script.Parent.Parent.Utils.Icons)
local Tween = require(script.Parent.Parent.Utils.Tween)

local Cursor = {}
Cursor.__index = Cursor

local FRAME = 32
local ARROW = 24
-- Design-grid point the arrow tip lives at inside Core/Icons' "cursor" kind.
local ARROW_TIP = Vector2.new(4.5, 1.5)

local MODES = { menu = true, always = true, off = true }
local LEAF_DARK = Color3.fromHex("22C55E")
local LEAF_LIGHT = Color3.fromHex("A7F3D0")
local STEM_COLOR = Color3.fromHex("4ADE80")
local BACKING = Color3.fromHex("0B0B0D")

local function topbarInset()
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)

	if ok and typeof(inset) == "Vector2" then
		return inset.Y
	end

	return 36
end

function Cursor.new(library)
	local self = setmetatable({}, Cursor)

	self.Library = library
	self.Mode = "always"
	self.Visible = false
	self.Destroyed = false
	self.Inset = topbarInset()
	self._ownsMouseIcon = false
	self._connection = nil
	self._behaviorConnection = nil

	self.Frame = Create.new("Frame", {
		Name = "CherryCursor",
		AnchorPoint = Vector2.new(0, 0),
		Size = UDim2.fromOffset(FRAME, FRAME),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5000,
		Parent = library.ScreenGui,
	})

	-- Soft shadow so the pointer reads on light and dark backgrounds alike.
	local shadow = Create.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(3, 4),
		Size = UDim2.fromOffset(22, 21),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		ZIndex = 1,
		Parent = self.Frame,
	})
	Create.corner(shadow, UDim.new(1, 0))

	-- The arrow: a translucent dark copy sits behind the white one so the
	-- outline stays readable over dark panels without a second asset.
	local scale = ARROW / Icons.Grid
	local tipOffset = UDim2.fromOffset(-ARROW_TIP.X * scale, -ARROW_TIP.Y * scale)

	local backing = Icons.new("cursor", self.Frame, ARROW + 3, BACKING, 2)
	backing.Position = tipOffset
	Icons.setTransparency(backing, 0.45)

	local arrow = Icons.new("cursor", self.Frame, ARROW, Color3.fromHex("FFFFFF"), 3)
	arrow.Position = tipOffset

	-- Cherry badge tucked under the arrow head, so the pointer is unmistakably
	-- Cherry UI while still reading as an arrow.
	local badge = Create.new("Frame", {
		Name = "Badge",
		Position = UDim2.fromOffset(13, 15),
		Size = UDim2.fromOffset(18, 17),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = self.Frame,
	})

	local function cherry(position, size, zIndex)
		local berry = Create.new("Frame", {
			Name = "Cherry",
			Position = position,
			Size = UDim2.fromOffset(size, size),
			ZIndex = zIndex,
			Parent = badge,
		})
		Create.corner(berry, UDim.new(1, 0))
		library.ThemeManager:BindGradient(
			Create.new("UIGradient", { Rotation = 45, Parent = berry }),
			{ "Accent", "Primary" }
		)

		-- A thin light stroke keeps the silhouette readable over the dark panel.
		library:Styled(Create.stroke(berry, Color3.new(1, 1, 1), 1, 0.55), "Text", "Color")

		local shine = Create.new("Frame", {
			Name = "Shine",
			Position = UDim2.fromScale(0.2, 0.16),
			Size = UDim2.fromScale(0.32, 0.26),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.45,
			Rotation = -20,
			ZIndex = zIndex + 1,
			Parent = berry,
		})
		Create.corner(shine, UDim.new(1, 0))

		return berry
	end

	local stem = Create.new("Frame", {
		Name = "Stem",
		Position = UDim2.fromOffset(9, 1),
		Size = UDim2.new(0, 1.6, 0, 6),
		BackgroundColor3 = STEM_COLOR,
		Rotation = 28,
		ZIndex = 4,
		Parent = badge,
	})
	Create.corner(stem, UDim.new(0.5, 0))

	local leaf = Create.new("Frame", {
		Name = "Leaf",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(12, 3),
		Size = UDim2.fromOffset(8, 4.5),
		Rotation = -24,
		ZIndex = 4,
		Parent = badge,
	})
	Create.corner(leaf, UDim.new(1, 0))
	Create.new("UIGradient", {
		Rotation = 40,
		Color = ColorSequence.new(LEAF_DARK, LEAF_LIGHT),
		Parent = leaf,
	})

	cherry(UDim2.fromOffset(2, 7), 11, 5)
	cherry(UDim2.fromOffset(11, 10), 9, 6)

	-- Shift-lock / first person hides the pointer; leaving it must restore it
	-- even when no window was opened in between.
	self._behaviorConnection = UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
		self:Refresh()
	end)

	self:Refresh()

	return self
end

-- GUI-space mouse position (the ScreenGui ignores the topbar inset).
function Cursor:_mousePosition()
	local location = UserInputService:GetMouseLocation()
	return Vector2.new(location.X, location.Y - self.Inset)
end

function Cursor:_shouldShow()
	if self.Destroyed or self.Mode == "off" then
		return false
	end

	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return false
	end

	if self.Mode == "always" then
		return true
	end

	local window = self.Library.PrimaryWindow
	return window ~= nil and window.Visible == true and not window.Destroyed
end

-- The arrow tip is the frame origin, so no hotspot offset is needed.
function Cursor:_follow()
	local position = self:_mousePosition()
	self.Frame.Position = UDim2.fromOffset(position.X, position.Y)
end

function Cursor:_setVisible(visible)
	if self.Visible == visible then
		return
	end

	self.Visible = visible
	self.Frame.Visible = visible

	if visible then
		self:_follow()
		-- Hide the system pointer only after ours is on screen, so there is never
		-- a frame with no cursor at all.
		if UserInputService.MouseIconEnabled then
			UserInputService.MouseIconEnabled = false
			self._ownsMouseIcon = true
		end

		if not self._connection then
			self._connection = RunService.RenderStepped:Connect(function()
				if self:_shouldShow() then
					self:_follow()
				else
					self:_setVisible(false)
				end
			end)
		end
	else
		if self._connection then
			self._connection:Disconnect()
			self._connection = nil
		end

		if self._ownsMouseIcon then
			UserInputService.MouseIconEnabled = true
			self._ownsMouseIcon = false
		end
	end
end

-- Called when window visibility, mouse lock or the mode changes.
function Cursor:Refresh()
	if self.Destroyed then
		return
	end

	self:_setVisible(self:_shouldShow())
end

function Cursor:SetMode(mode)
	if not MODES[mode] then
		warn("[CherryUI] Unknown cursor mode: " .. tostring(mode))
		return false
	end

	self.Mode = mode
	self:Refresh()
	return true
end

function Cursor:GetMode()
	return self.Mode
end

function Cursor:Destroy()
	if self.Destroyed then
		return
	end

	self:_setVisible(false)
	self.Destroyed = true

	if self._behaviorConnection then
		self._behaviorConnection:Disconnect()
		self._behaviorConnection = nil
	end

	if self.Frame then
		self.Frame:Destroy()
		self.Frame = nil
	end
end

return Cursor
