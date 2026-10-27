--[[
	Core/Cursor.lua
	The Cherry cursor: Roblox's own arrow, plus a cherry that trails it.

	Earlier versions hid the system pointer and drew a replacement arrow from
	GuiObjects. That is the wrong trade: a drawn arrow is always heavier and
	blurrier than the client's own cursor, its hotspot math is approximate, and
	if anything goes wrong the user is left with no pointer at all.

	So this keeps the native cursor untouched and draws the branding as a small
	badge that follows the pointer with a little lag. The result reads as a
	deliberate accent instead of a worse arrow, never blocks a click (the badge
	sits below-right of the hotspot and is not `Active`), and cannot leave the
	client without a cursor.

	Modes (see `CherryUI:SetCursorMode`):
	  * "always" - the badge is always there (default)
	  * "menu"   - only while a Cherry UI window is open
	  * "off"    - nothing but the Roblox cursor

	Cost: one RenderStepped connection, alive only while the badge is visible.
]]

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)

local Cursor = {}
Cursor.__index = Cursor

local BADGE = 20
-- Where the badge sits relative to the pointer hotspot: clear of the arrow
-- itself, so the two never overlap.
local OFFSET = Vector2.new(9, 11)
-- Follow speed (per second). High enough to feel attached, low enough to trail.
local FOLLOW = 16
-- A jump this large is a teleport/respawn, not movement: snap instead of glide.
local SNAP_DISTANCE = 220

local MODES = { menu = true, always = true, off = true }
local LEAF_DARK = Color3.fromHex("22C55E")
local LEAF_LIGHT = Color3.fromHex("A7F3D0")
local STEM_COLOR = Color3.fromHex("4ADE80")

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
	self._position = nil
	self._connection = nil
	self._behaviorConnection = nil
	self._inputConnection = nil

	self.Frame = Create.new("Frame", {
		Name = "CherryCursor",
		AnchorPoint = Vector2.new(0, 0),
		Size = UDim2.fromOffset(BADGE, BADGE),
		BackgroundTransparency = 1,
		Active = false,
		Visible = false,
		ZIndex = 5000,
		Parent = library.ScreenGui,
	})

	self.Scale = Create.new("UIScale", { Scale = 1, Parent = self.Frame })

	-- Soft accent halo so the badge reads on light and dark backgrounds alike.
	local glow = Create.new("Frame", {
		Name = "Glow",
		Position = UDim2.fromScale(-0.2, -0.2),
		Size = UDim2.fromScale(1.4, 1.4),
		BackgroundTransparency = 0.9,
		ZIndex = 1,
		Parent = self.Frame,
	})
	Create.corner(glow, UDim.new(1, 0))
	library:Styled(glow, "Primary", "BackgroundColor3")

	local function cherry(position, size, zIndex)
		local berry = Create.new("Frame", {
			Name = "Cherry",
			Position = position,
			Size = UDim2.fromOffset(size, size),
			ZIndex = zIndex,
			Parent = self.Frame,
		})
		Create.corner(berry, UDim.new(1, 0))
		library.ThemeManager:BindGradient(
			Create.new("UIGradient", { Rotation = 45, Parent = berry }),
			{ "Accent", "Primary" }
		)

		-- A thin light stroke keeps the silhouette readable over dark panels.
		library:Styled(Create.stroke(berry, Color3.new(1, 1, 1), 1, 0.5), "Text", "Color")

		local shine = Create.new("Frame", {
			Name = "Shine",
			Position = UDim2.fromScale(0.2, 0.16),
			Size = UDim2.fromScale(0.32, 0.26),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.4,
			Rotation = -20,
			ZIndex = zIndex + 1,
			Parent = berry,
		})
		Create.corner(shine, UDim.new(1, 0))

		return berry
	end

	-- Stem + leaf first, so the berries overlap them.
	local stem = Create.new("Frame", {
		Name = "Stem",
		Position = UDim2.fromOffset(9, 1),
		Size = UDim2.new(0, 1.6, 0, 6),
		BackgroundColor3 = STEM_COLOR,
		Rotation = 26,
		ZIndex = 2,
		Parent = self.Frame,
	})
	Create.corner(stem, UDim.new(0.5, 0))

	local leaf = Create.new("Frame", {
		Name = "Leaf",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(12, 3),
		Size = UDim2.fromOffset(9, 5),
		Rotation = -26,
		ZIndex = 2,
		Parent = self.Frame,
	})
	Create.corner(leaf, UDim.new(1, 0))
	Create.new("UIGradient", {
		Rotation = 40,
		Color = ColorSequence.new(LEAF_DARK, LEAF_LIGHT),
		Parent = leaf,
	})

	cherry(UDim2.fromOffset(2, 8), 12, 3)
	cherry(UDim2.fromOffset(11, 11), 10, 4)

	-- Shift-lock / first person hides the pointer; leaving it must restore the
	-- badge even when no window was opened in between.
	self._behaviorConnection = UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
		self:Refresh()
	end)

	-- Click feedback: the badge dips when the user presses either mouse button.
	self._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or self.Destroyed or not self.Visible then
			return
		end

		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2 then
			self:_pop()
		end
	end)

	self:Refresh()

	return self
end

-- A quick dip-and-settle, driven by the window's own tween presets.
function Cursor:_pop()
	if not self.Scale then
		return
	end

	self.Scale.Scale = 0.78
	Tween.play(self.Scale, { Scale = 1 }, Tween.Info.Spring)
end

-- GUI-space pointer position (the ScreenGui ignores the topbar inset).
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

function Cursor:_follow(delta)
	local target = self:_mousePosition() + OFFSET
	local current = self._position

	if not current then
		self._position = target
	else
		local gap = target - current

		if gap.Magnitude > SNAP_DISTANCE then
			self._position = target
		else
			self._position = current + gap * math.min(1, FOLLOW * (delta or 1 / 60))
		end
	end

	local position = self._position
	self.Frame.Position = UDim2.fromOffset(position.X, position.Y)
end

function Cursor:_setVisible(visible)
	if self.Visible == visible then
		return
	end

	self.Visible = visible
	self.Frame.Visible = visible

	if visible then
		self._position = nil
		self:_follow()

		if not self._connection then
			self._connection = RunService.RenderStepped:Connect(function(delta)
				if self:_shouldShow() then
					self:_follow(delta)
				else
					self:_setVisible(false)
				end
			end)
		end
	elseif self._connection then
		self._connection:Disconnect()
		self._connection = nil
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

	if self._inputConnection then
		self._inputConnection:Disconnect()
		self._inputConnection = nil
	end

	if self.Frame then
		self.Frame:Destroy()
		self.Frame = nil
	end
end

return Cursor
