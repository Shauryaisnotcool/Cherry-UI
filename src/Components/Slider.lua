--[[
	Components/Slider.lua
	Smooth slider with a live value display that doubles as a numeric input.

	Dragging updates the value directly (no tweens) so it tracks the cursor
	exactly; clicking the value label lets the user type a precise number. All
	updates are clamped, step-rounded (optional) and formatted via `config.Format`.
]]

local UserInputService = game:GetService("UserInputService")

local Base = require(script.Parent.Parent.Utils.Base)
local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)
local Util = require(script.Parent.Parent.Utils.Util)

local Slider = setmetatable({}, { __index = Base })
Slider.__index = Slider

function Slider.new(library, section, config)
	config = config or {}
	config.Height = config.Height or 48

	local minimum = tonumber(config.Min) or 0
	local maximum = tonumber(config.Max) or 100
	if maximum <= minimum then
		maximum = minimum + 1
	end

	config.Min = minimum
	config.Max = maximum
	if config.Default == nil then
		config.Default = minimum
	end

	local self = Base.new(library, section, "Slider", config)
	setmetatable(self, Slider)

	self.Min = minimum
	self.Max = maximum
	self.Step = tonumber(config.Step) or 0
	self.Decimals = tonumber(config.Decimals) or 0
	self.Suffix = config.Suffix or ""
	self.Dragging = false

	if type(config.Format) == "function" then
		self.Format = config.Format
	else
		local decimals = self.Decimals
		local suffix = self.Suffix
		self.Format = function(value)
			return Util.trimNumber(value, decimals) .. suffix
		end
	end

	self.Value = Util.clamp(tonumber(config.Default) or minimum, minimum, maximum)

	self.Hit = Create.textButton({
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = self.Holder,
	})
	self:AddHover(self.Hit)

	self.Label = Create.label({
		Name = "Label",
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(1, -100, 0, 18),
		Text = self.Name,
		TextSize = 13,
		ZIndex = 3,
		Parent = self.Hit,
	})
	library:Styled(self.Label, "Text", "TextColor3")

	self.ValueBox = Create.new("TextBox", {
		Name = "ValueBox",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 5),
		Size = UDim2.fromOffset(76, 18),
		BackgroundTransparency = 1,
		Text = "",
		TextSize = 12,
		Font = Enum.Font.Code,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = false,
		ZIndex = 4,
		Parent = self.Hit,
	})
	library:Styled(self.ValueBox, "Primary", "TextColor3")

	self.Track = Create.textButton({
		Name = "Track",
		Position = UDim2.fromOffset(12, 29),
		Size = UDim2.new(1, -24, 0, 14),
		ZIndex = 3,
		Parent = self.Hit,
	})

	self.Rail = Create.new("Frame", {
		Name = "Rail",
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.new(1, 0, 0, 4),
		ZIndex = 3,
		Parent = self.Track,
	})
	Create.corner(self.Rail, 2)
	library:Styled(self.Rail, "SurfaceHigh", "BackgroundColor3")

	self.Fill = Create.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = self.Rail,
	})
	Create.corner(self.Fill, 2)
	library.ThemeManager:BindGradient(
		Create.new("UIGradient", { Rotation = 0, Parent = self.Fill }),
		{ "Primary", "Accent" }
	)

	self.Knob = Create.new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = self.Track,
	})
	Create.corner(self.Knob, UDim.new(1, 0))
	library:Styled(Create.stroke(self.Knob, library.Palette.Primary, 2, 0), "Primary", "Color")

	self.KnobScale = Create.new("UIScale", { Scale = 1, Parent = self.Knob })

	self:_render()

	self:_wireEvents()

	return self
end

function Slider:_alpha()
	return (self.Value - self.Min) / math.max(self.Max - self.Min, 1e-6)
end

function Slider:_render()
	local alpha = Util.clamp(self:_alpha(), 0, 1)

	self.Fill.Size = UDim2.new(alpha, 0, 1, 0)
	self.Knob.Position = UDim2.new(alpha, 0, 0.5, 0)

	if not self.ValueBox:IsFocused() then
		self.ValueBox.Text = self.Format(self.Value)
	end
end

function Slider:_clean(value)
	value = tonumber(value) or self.Min
	value = Util.clamp(value, self.Min, self.Max)

	if self.Step > 0 then
		value = math.floor(value / self.Step + 0.5) * self.Step
	end

	return Util.clamp(Util.round(value, self.Decimals), self.Min, self.Max)
end

function Slider:_valueFromPosition(x)
	local width = self.Track.AbsoluteSize.X
	if width <= 0 then
		return nil
	end

	local relative = Util.clamp((x - self.Track.AbsolutePosition.X) / width, 0, 1)
	return self:_clean(self.Min + (self.Max - self.Min) * relative)
end

function Slider:_wireEvents()
	self:_track(self.Track.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		self.Dragging = true
		local value = self:_valueFromPosition(input.Position.X)
		if value then
			self:SetValue(value)
		end
	end))

	self:_track(UserInputService.InputChanged:Connect(function(input)
		if not self.Dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local value = self:_valueFromPosition(input.Position.X)
		if value then
			self:SetValue(value)
		end
	end))

	self:_track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.Dragging = false
		end
	end))

	self:_track(self.Track.MouseEnter:Connect(function()
		Tween.play(self.KnobScale, { Scale = 1.2 }, Tween.Info.Fast)
	end))

	self:_track(self.Track.MouseLeave:Connect(function()
		Tween.play(self.KnobScale, { Scale = 1 }, Tween.Info.Fast)
	end))

	self:_track(self.ValueBox.FocusLost:Connect(function()
		local text = self.ValueBox.Text
		local number = tonumber(string.match(text, "%-?%d+%.?%d*") or "")

		if number then
			self:SetValue(number)
		else
			self:_render()
		end
	end))

	self:OnThemeChanged(function()
		self:_render()
	end)
end

function Slider:SetValue(value, silent)
	if self.Destroyed then
		return
	end

	local cleaned = self:_clean(value)
	local changed = self.Value ~= cleaned

	self.Value = cleaned
	self:_render()

	if changed then
		self:_commit(cleaned, silent)
	end
end

function Slider:GetValue()
	return self.Value
end

function Slider:Destroy()
	Base.Destroy(self)
end

return Slider
