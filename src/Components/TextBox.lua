--[[
	Components/TextBox.lua
	Text input with an optional numeric mode (clamping + parsing).

	Values are committed on focus loss / Enter. Numeric input accepts an
	optional minus, digits and a decimal point; invalid input restores the last
	valid value instead of calling the user's callback.
]]

local Base = require(script.Parent.Parent.Utils.Base)
local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)

local TextBox = setmetatable({}, { __index = Base })
TextBox.__index = TextBox

function TextBox.new(library, section, config)
	config = config or {}
	config.Height = config.Height or 34

	local self = Base.new(library, section, "TextBox", config)
	setmetatable(self, TextBox)

	self.Numeric = config.Numeric == true
	self.Min = tonumber(config.Min)
	self.Max = tonumber(config.Max)
	self.Value = config.Default

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
		Size = UDim2.new(1, -140, 1, 0),
		Text = self.Name,
		TextSize = 13,
		ZIndex = 3,
		Parent = self.Hit,
	})
	library:Styled(self.Label, "Text", "TextColor3")

	self.Box = Create.new("Frame", {
		Name = "Input",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(config.Width or 112, 24),
		BackgroundTransparency = 0.15,
		ZIndex = 3,
		Parent = self.Hit,
	})
	Create.corner(self.Box, 6)
	library:Styled(self.Box, "SurfaceHigh", "BackgroundColor3")

	self.BoxStroke = Create.stroke(self.Box, library.Palette.Outline, 1, 0.4)
	library:Styled(self.BoxStroke, "Outline", "Color")

	self.Input = Create.new("TextBox", {
		Name = "Input",
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = config.Placeholder or (self.Numeric and "0" or "Enter text"),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = config.ClearTextOnFocus == true,
		ZIndex = 4,
		Parent = self.Box,
	})
	library:Styled(self.Input, "Text", "TextColor3")
	library:Styled(self.Input, "Placeholder", "PlaceholderColor3")

	self:_render()

	self:_track(self.Input.Focused:Connect(function()
		Tween.play(self.BoxStroke, { Transparency = 0, Color = self.Library.Palette.Primary }, Tween.Info.Fast)
	end))

	self:_track(self.Input.FocusLost:Connect(function()
		Tween.play(self.BoxStroke, {
			Transparency = 0.4,
			Color = self.Library.Palette.Outline,
		}, Tween.Info.Fast)
		self:_commitInput()
	end))

	self:OnThemeChanged(function()
		self:_render()
	end)

	return self
end

function TextBox:_render()
	self._updating = true
	self.Input.Text = self.Value ~= nil and tostring(self.Value) or ""
	self._updating = false
end

function TextBox:_commitInput()
	if self.Destroyed then
		return
	end

	local text = self.Input.Text

	if self.Numeric then
		local number = tonumber(string.match(text, "%-?%d+%.?%d*") or "")
		if number == nil then
			self:_render()
			return
		end

		if self.Min then
			number = math.max(number, self.Min)
		end
		if self.Max then
			number = math.min(number, self.Max)
		end

		self:SetValue(number)
	else
		text = string.gsub(text, "^%s+", "")
		text = string.gsub(text, "%s+$", "")
		self:SetValue(text)
	end
end

function TextBox:SetValue(value, silent)
	if self.Destroyed then
		return
	end

	local changed = self.Value ~= value
	self.Value = value
	self:_render()

	if changed then
		self:_commit(value, silent)
	end
end

function TextBox:GetValue()
	return self.Value
end

function TextBox:Destroy()
	Base.Destroy(self)
end

return TextBox
