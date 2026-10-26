--[[
	Components/ColorPicker.lua
	Compact HSV color picker for ESP/aimbot colors.

	The field shows a live swatch and hex code; the popup (built lazily) has a
	saturation/value square, a hue strip and a hex input. Dragging updates the
	value continuously so a connected ESP can preview the change instantly.
]]

local UserInputService = game:GetService("UserInputService")

local Base = require(script.Parent.Parent.Utils.Base)
local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)
local Util = require(script.Parent.Parent.Utils.Util)
local Popup = require(script.Parent.Parent.Utils.Popup)

local ColorPicker = setmetatable({}, { __index = Base })
ColorPicker.__index = ColorPicker

local POPUP_WIDTH = 216
local POPUP_HEIGHT = 186

function ColorPicker.new(library, section, config)
	config = config or {}
	config.Height = config.Height or 34

	local default = config.Default
	if typeof(default) ~= "Color3" then
		default = library.Palette.Primary
	end
	config.Default = default

	local self = Base.new(library, section, "ColorPicker", config)
	setmetatable(self, ColorPicker)

	self.Value = default
	self.DragMode = nil

	local hue, saturation, brightness = default:ToHSV()
	self.HueValue = hue
	self.Saturation = saturation
	self.Brightness = brightness

	self.Hit = Create.textButton({
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = self.Holder,
	})
	self:AddHover(self.Hit)

	self.Label = Create.label({
		Name = "Label",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -150, 1, 0),
		Text = self.Name,
		TextSize = 13,
		ZIndex = 3,
		Parent = self.Hit,
	})
	library:Styled(self.Label, "Text", "TextColor3")

	self.Field = Create.textButton({
		Name = "ColorField",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(112, 24),
		BackgroundTransparency = 0.15,
		ZIndex = 3,
		Parent = self.Hit,
	})
	Create.corner(self.Field, 6)
	library:Styled(self.Field, "SurfaceHigh", "BackgroundColor3")
	library:Styled(Create.stroke(self.Field, library.Palette.Outline, 1, 0.4), "Outline", "Color")

	self.Swatch = Create.new("Frame", {
		Name = "Swatch",
		Position = UDim2.fromOffset(5, 4),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = self.Value,
		ZIndex = 4,
		Parent = self.Field,
	})
	Create.corner(self.Swatch, UDim.new(1, 0))
	Create.stroke(self.Swatch, Color3.new(0, 0, 0), 1, 0.75)

	self.ValueLabel = Create.label({
		Name = "Hex",
		Position = UDim2.fromOffset(27, 0),
		Size = UDim2.new(1, -32, 1, 0),
		Text = Util.hex(self.Value),
		TextSize = 11,
		Font = Enum.Font.Code,
		ZIndex = 4,
		Parent = self.Field,
	})
	library:Styled(self.ValueLabel, "SubText", "TextColor3")

	self:_track(self.Field.Activated:Connect(function()
		if self.Destroyed then
			return
		end
		self:Open()
	end))

	self:OnThemeChanged(function()
		self:_render()
	end)

	self:_render()

	return self
end

-- Drag listeners are created on mouse-down and removed on release.
function ColorPicker:_beginDrag()
	if self._dragConnection then
		return
	end

	self._dragConnection = UserInputService.InputChanged:Connect(function(input)
		if not self.DragMode then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		if self.DragMode == "sv" then
			self:_updateSV(input.Position)
		elseif self.DragMode == "hue" then
			self:_updateHue(input.Position)
		end
	end)

	self._endConnection = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			then
			self:_endDrag()
		end
	end)
end

function ColorPicker:_endDrag()
	self.DragMode = nil

	if self._dragConnection then
		self._dragConnection:Disconnect()
		self._dragConnection = nil
	end

	if self._endConnection then
		self._endConnection:Disconnect()
		self._endConnection = nil
	end
end

function ColorPicker:_ensurePopup()
	if self.Popup then
		return
	end

	self.Popup = Popup.new(self.Library, {
		Name = "ColorPickerPopup",
		Width = POPUP_WIDTH,
		Height = POPUP_HEIGHT,
		OnClose = function()
			self:_endDrag()
			if self.HexBox and self.HexBox:IsFocused() then
				self.HexBox:ReleaseFocus()
			end
		end,
	})

	local frame = self.Popup.Frame

	-- Saturation / value square.
	self.SV = Create.new("Frame", {
		Name = "SaturationValue",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(POPUP_WIDTH - 20, 104),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Active = true,
		Parent = frame,
	})
	Create.corner(self.SV, 6)

	self.SVGradient = Create.new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(self.HueValue, 1, 1)),
		Parent = self.SV,
	})

	local shade = Create.new("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = self.SV,
	})
	Create.corner(shade, 6)
	Create.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = shade,
	})

	self.SVPicker = Create.new("Frame", {
		Name = "SVPicker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Parent = self.SV,
	})
	Create.corner(self.SVPicker, UDim.new(1, 0))
	Create.stroke(self.SVPicker, Color3.new(1, 1, 1), 2, 0.1)

	-- Hue strip.
	self.HueStrip = Create.new("Frame", {
		Name = "Hue",
		Position = UDim2.fromOffset(10, 122),
		Size = UDim2.fromOffset(POPUP_WIDTH - 20, 12),
		Active = true,
		Parent = frame,
	})
	Create.corner(self.HueStrip, 6)

	local hueKeypoints = {}
	for index = 0, 6 do
		table.insert(
			hueKeypoints,
			ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1))
		)
	end
	Create.new("UIGradient", {
		Color = ColorSequence.new(hueKeypoints),
		Parent = self.HueStrip,
	})

	self.HuePicker = Create.new("Frame", {
		Name = "HuePicker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(6, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = self.HueStrip,
	})
	Create.corner(self.HuePicker, 3)
	Create.stroke(self.HuePicker, Color3.new(0, 0, 0), 1, 0.5)

	-- Hex input + preview.
	self.HexBox = Create.new("TextBox", {
		Name = "HexInput",
		Position = UDim2.fromOffset(10, 146),
		Size = UDim2.fromOffset(120, 28),
		Text = Util.hex(self.Value),
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 2,
		Parent = frame,
	})
	Create.corner(self.HexBox, 6)
	self.Library:Styled(self.HexBox, "SurfaceHigh", "BackgroundColor3")
	self.Library:Styled(self.HexBox, "Text", "TextColor3")
	Create.padding(self.HexBox, 8, 6, 8, 6)
	self.Library:Styled(
		Create.stroke(self.HexBox, self.Library.Palette.Outline, 1, 0.4),
		"Outline",
		"Color"
	)

	self.Preview = Create.new("Frame", {
		Name = "Preview",
		Position = UDim2.fromOffset(POPUP_WIDTH - 48, 146),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = self.Value,
		ZIndex = 2,
		Parent = frame,
	})
	Create.corner(self.Preview, 6)
	Create.stroke(self.Preview, Color3.new(0, 0, 0), 1, 0.75)

	self.SV.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.DragMode = "sv"
			self:_beginDrag()
			self:_updateSV(input.Position)
		end
	end)

	self.HueStrip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.DragMode = "hue"
			self:_beginDrag()
			self:_updateHue(input.Position)
		end
	end)

	self.HexBox.FocusLost:Connect(function()
		local color = Util.fromHex(self.HexBox.Text)
		if color then
			self:SetValue(color)
		else
			self.HexBox.Text = Util.hex(self.Value)
		end
	end)

	self:_render()
end

function ColorPicker:_updateSV(position)
	local size = self.SV.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end

	local relativeX = Util.clamp((position.X - self.SV.AbsolutePosition.X) / size.X, 0, 1)
	local relativeY = Util.clamp((position.Y - self.SV.AbsolutePosition.Y) / size.Y, 0, 1)

	self.Saturation = relativeX
	self.Brightness = 1 - relativeY

	self:_commitColor()
end

function ColorPicker:_updateHue(position)
	local size = self.HueStrip.AbsoluteSize
	if size.X <= 0 then
		return
	end

	self.HueValue = Util.clamp((position.X - self.HueStrip.AbsolutePosition.X) / size.X, 0, 0.999)

	self:_commitColor()
end

function ColorPicker:_commitColor()
	local color = Color3.fromHSV(self.HueValue, self.Saturation, self.Brightness)
	local changed = self.Value ~= color

	self.Value = color
	self:_render()

	if changed then
		self:_commit(color, false)
	end
end

function ColorPicker:_render()
	local palette = self.Library.Palette
	local color = self.Value or palette.Primary

	self.Swatch.BackgroundColor3 = color
	self.ValueLabel.Text = Util.hex(color)

	if self.SV then
		self.SVGradient.Color = ColorSequence.new(
			Color3.new(1, 1, 1),
			Color3.fromHSV(self.HueValue, 1, 1)
		)
		self.SVPicker.Position = UDim2.fromScale(self.Saturation, 1 - self.Brightness)
		self.HuePicker.Position = UDim2.fromScale(self.HueValue, 0.5)
		self.Preview.BackgroundColor3 = color

		if not self.HexBox:IsFocused() then
			self.HexBox.Text = Util.hex(color)
		end
	end
end

function ColorPicker:Open()
	if self.Destroyed then
		return
	end

	self:_ensurePopup()
	self.Popup:Open(self.Field)
end

function ColorPicker:Close()
	if self.Popup then
		self.Popup:Close()
	end
end

function ColorPicker:SetValue(value, silent)
	if self.Destroyed or typeof(value) ~= "Color3" then
		return
	end

	local changed = self.Value ~= value
	self.Value = value

	local hue, saturation, brightness = value:ToHSV()
	self.HueValue = hue
	self.Saturation = saturation
	self.Brightness = brightness

	self:_render()

	if changed then
		self:_commit(value, silent)
	end
end

function ColorPicker:GetValue()
	return self.Value
end

function ColorPicker:Destroy()
	if self.Destroyed then
		return
	end

	self:_endDrag()

	if self.Popup then
		self.Popup:Destroy()
		self.Popup = nil
	end

	Base.Destroy(self)
end

return ColorPicker
