--[[
	Components/Keybind.lua
	Click-to-rebind key capture.

	Supports keyboard keys as well as the three mouse buttons, cancels with
	Escape, and sets `Library.Capturing` while listening so the menu toggle and
	popups don't fire while the user is picking a new key.
]]

local UserInputService = game:GetService("UserInputService")

local Base = require(script.Parent.Parent.Utils.Base)
local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)
local Util = require(script.Parent.Parent.Utils.Util)

local Keybind = setmetatable({}, { __index = Base })
Keybind.__index = Keybind

function Keybind.new(library, section, config)
	config = config or {}
	config.Height = config.Height or 34
	config.Default = config.Default or Enum.KeyCode.RightShift

	local self = Base.new(library, section, "Keybind", config)
	setmetatable(self, Keybind)

	self.Value = config.Default
	self.Capturing = false
	self.CaptureConnection = nil

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
		Size = UDim2.new(1, -130, 1, 0),
		Text = self.Name,
		TextSize = 13,
		ZIndex = 3,
		Parent = self.Hit,
	})
	library:Styled(self.Label, "Text", "TextColor3")

	self.KeyButton = Create.textButton({
		Name = "Key",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(100, 24),
		Text = "",
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.15,
		ZIndex = 3,
		Parent = self.Hit,
	})
	Create.corner(self.KeyButton, 6)
	library:Styled(self.KeyButton, "SurfaceHigh", "BackgroundColor3")

	self.KeyStroke = Create.stroke(self.KeyButton, library.Palette.Outline, 1, 0.4)
	library:Styled(self.KeyStroke, "Outline", "Color")

	self:_render()

	self:_track(self.KeyButton.Activated:Connect(function()
		if self.Destroyed then
			return
		end
		if self.Capturing then
			self:EndCapture()
		else
			self:BeginCapture()
		end
	end))

	self:OnThemeChanged(function()
		if not self.Capturing then
			self:_render()
		end
	end)

	return self
end

function Keybind:_render()
	local palette = self.Library.Palette
	self.KeyButton.Text = Util.keyName(self.Value)
	self.KeyButton.TextColor3 = palette.Text
	self.KeyStroke.Color = palette.Outline
	self.KeyStroke.Transparency = 0.4
end

function Keybind:BeginCapture()
	if self.Capturing or self.Destroyed then
		return
	end

	self.Capturing = true
	-- SetCapturing also stamps the start time, so an abandoned capture times out
	-- instead of blocking the menu toggle forever.
	self.Library:SetCapturing(true)

	self.KeyButton.Text = "Press a key"
	self.KeyButton.TextColor3 = self.Library.Palette.Primary
	self.KeyStroke.Color = self.Library.Palette.Primary
	self.KeyStroke.Transparency = 0.2

	self.CaptureConnection = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			self:EndCapture()
			return
		end

		-- Non-keyboard input reports KeyCode.None; mouse buttons are captured below.
		if input.KeyCode ~= Enum.KeyCode.None then
			self:SetValue(input.KeyCode)
			self:EndCapture()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3
		then
			self:SetValue(input.UserInputType)
			self:EndCapture()
		end
	end)
end

function Keybind:EndCapture()
	if not self.Capturing then
		return
	end

	self.Capturing = false
	self.Library:SetCapturing(false)

	if self.CaptureConnection then
		self.CaptureConnection:Disconnect()
		self.CaptureConnection = nil
	end

	if not self.Destroyed then
		self:_render()
	end
end

function Keybind:SetValue(value, silent)
	if self.Destroyed or typeof(value) ~= "EnumItem" then
		return
	end

	local changed = self.Value ~= value
	self.Value = value

	if not self.Capturing then
		self:_render()
	end

	if changed then
		self:_commit(value, silent)
	end
end

function Keybind:GetValue()
	return self.Value
end

function Keybind:Destroy()
	self:EndCapture()
	Base.Destroy(self)
end

return Keybind
