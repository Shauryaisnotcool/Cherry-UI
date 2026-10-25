--[[
	Components/Toggle.lua
	Animated switch. Clicking anywhere on the row toggles it.

	The knob and track are tweened rather than snapped, and the control re-reads
	its colors whenever the theme changes so state colors always match the
	active palette.
]]

local Base = require(script.Parent.Parent.Utils.Base)
local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)

local Toggle = setmetatable({}, { __index = Base })
Toggle.__index = Toggle

local TRACK_WIDTH = 38
local KNOB_SIZE = 14
local KNOB_PADDING = 3

function Toggle.new(library, section, config)
	config = config or {}
	config.Height = config.Height or 34
	config.Default = config.Default == true

	local self = Base.new(library, section, "Toggle", config)
	setmetatable(self, Toggle)

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
		Size = UDim2.new(1, -76, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Text = self.Name,
		TextSize = 13,
		ZIndex = 3,
		Parent = self.Hit,
	})
	library:Styled(self.Label, "Text", "TextColor3")

	self.Track = Create.new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(TRACK_WIDTH, 20),
		ZIndex = 3,
		Parent = self.Hit,
	})
	Create.corner(self.Track, 10)

	self.TrackStroke = Create.stroke(self.Track, library.Palette.Outline, 1, 0.35)

	self.Knob = Create.new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB_PADDING, 0.5, 0),
		Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE),
		ZIndex = 4,
		Parent = self.Track,
	})
	Create.corner(self.Knob, UDim.new(1, 0))

	self:_render(false)

	self:_track(self.Hit.Activated:Connect(function()
		if self.Destroyed then
			return
		end
		self:SetValue(not self.Value)
	end))

	self:OnThemeChanged(function()
		self:_render(false)
	end)

	return self
end

function Toggle:_render(animate)
	local palette = self.Library.Palette
	local info = animate and Tween.Info.Fast or Tween.Info.Instant
	local enabled = self.Value == true

	self.Track.BackgroundColor3 = enabled and palette.Primary or palette.SurfaceHigh
	self.TrackStroke.Color = enabled and palette.Primary or palette.Outline
	self.TrackStroke.Transparency = enabled and 0.7 or 0.35
	self.Knob.BackgroundColor3 = enabled and Color3.new(1, 1, 1) or palette.SubText

	Tween.play(self.Knob, {
		Position = enabled
			and UDim2.new(0, TRACK_WIDTH - KNOB_SIZE - KNOB_PADDING, 0.5, 0)
			or UDim2.new(0, KNOB_PADDING, 0.5, 0),
	}, info)
end

function Toggle:SetValue(value, silent)
	if self.Destroyed then
		return
	end

	value = value == true
	local changed = self.Value ~= value

	self.Value = value
	self:_render(changed)

	if changed then
		self:_commit(value, silent)
	end
end

function Toggle:GetValue()
	return self.Value == true
end

function Toggle:Destroy()
	Base.Destroy(self)
end

return Toggle
