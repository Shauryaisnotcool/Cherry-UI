--[[
	Components/Button.lua
	Primary / Secondary / Danger action button.

	Primary buttons use the theme's Primary -> Accent gradient, Secondary is a
	surface button with an outline, Danger uses the danger color. Clicking
	animates a small press and invokes `config.Callback`.
]]

local Base = require(script.Parent.Parent.Utils.Base)
local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)

local Button = setmetatable({}, { __index = Base })
Button.__index = Button

function Button.new(library, section, config)
	config = config or {}
	config.Height = config.Height or 36

	local self = Base.new(library, section, "Button", config)
	setmetatable(self, Button)

	self.Variant = config.Variant or "Primary"
	self.Value = nil

	self.Button = Create.textButton({
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = self.Holder,
	})
	Create.corner(self.Button, 8)

	self.Label = Create.label({
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Text = config.Text or self.Name,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = self.Button,
	})

	self.Overlay = Create.new("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = self.Button,
	})
	Create.corner(self.Overlay, 8)

	self.Scale = Create.new("UIScale", { Scale = 1, Parent = self.Button })

	self:_applyVariant()
	self:_wireEvents()

	return self
end

function Button:_applyVariant()
	local palette = self.Library.Palette
	local variant = self.Variant
	local background, textColor, strokeColor, strokeTransparency

	if variant == "Danger" then
		background = palette.Danger
		textColor = Color3.new(1, 1, 1)
		strokeColor = palette.Danger
		strokeTransparency = 0.45
	elseif variant == "Secondary" then
		background = palette.SurfaceHigh
		textColor = palette.Text
		strokeColor = palette.Outline
		strokeTransparency = 0.2
	else
		background = palette.Primary
		textColor = Color3.new(1, 1, 1)
		strokeColor = palette.Accent
		strokeTransparency = 0.55
	end

	self.Button.BackgroundColor3 = background
	self.Label.TextColor3 = textColor

	if self.Stroke then
		self.Stroke.Color = strokeColor
		self.Stroke.Transparency = strokeTransparency
	else
		self.Stroke = Create.stroke(self.Button, strokeColor, 1, strokeTransparency)
	end

	if variant == "Primary" then
		if not self.Gradient then
			self.Gradient = Create.new("UIGradient", { Rotation = 25, Parent = self.Button })
			self.Library.ThemeManager:BindGradient(self.Gradient, { "Primary", "Accent" })
		end
	elseif self.Gradient then
		self.Gradient:Destroy()
		self.Gradient = nil
	end
end

function Button:_wireEvents()
	self:_track(self.Button.MouseEnter:Connect(function()
		Tween.play(self.Overlay, {
			BackgroundTransparency = self.Variant == "Secondary" and 0.94 or 0.86,
		}, Tween.Info.Fast)
	end))

	self:_track(self.Button.MouseLeave:Connect(function()
		Tween.play(self.Overlay, { BackgroundTransparency = 1 }, Tween.Info.Fast)
		Tween.play(self.Scale, { Scale = 1 }, Tween.Info.Fast)
	end))

	self:_track(self.Button.MouseButton1Down:Connect(function()
		if self.Disabled then
			return
		end
		Tween.play(self.Scale, { Scale = 0.97 }, Tween.Info.Snap)
	end))

	self:_track(self.Button.MouseButton1Up:Connect(function()
		Tween.play(self.Scale, { Scale = 1 }, Tween.Info.Fast)
	end))

	self:_track(self.Button.Activated:Connect(function()
		if self.Destroyed or self.Disabled then
			return
		end

		local callback = self.Config.Callback or self.Config.OnClick
		if type(callback) == "function" then
			local ok, err = pcall(callback)
			if not ok then
				warn("[CherryUI] Button callback error: " .. tostring(err))
			end
		end
	end))

	self:OnThemeChanged(function()
		self:_applyVariant()
	end)
end

function Button:SetText(text)
	self.Label.Text = tostring(text)
end

function Button:SetEnabled(enabled)
	self.Disabled = not enabled
	self.Button.Active = self.Disabled ~= true
	self.Label.TextTransparency = self.Disabled and 0.5 or 0
	self.Button.BackgroundTransparency = self.Disabled and 0.35 or 0
	return self
end

function Button:Destroy()
	Base.Destroy(self)
end

return Button
