--[[
	Components/ESPPreview.lua
	A live, interactive ESP preview.

	A styled 2D avatar sits in a dark stage with a highlight, box + corner
	brackets, a tracer and a name tag with a health bar. The chips above the
	stage toggle each visual, and the whole scene is animated at a capped 30 Hz
	through the library scheduler (never per-frame).

		preview:SetTarget({ Name = "Player", Health = 72, Distance = 60 })
		preview:OnChanged(function(settings) ... end)
]]

local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)
local Signal = require(script.Parent.Parent.Utils.Signal)
local Util = require(script.Parent.Parent.Utils.Util)

local ESPPreview = {}
ESPPreview.__index = ESPPreview

local CHIP_DEFS = {
	{ Key = "Highlight", Label = "Glow" },
	{ Key = "Box", Label = "Box" },
	{ Key = "Tracer", Label = "Tracer" },
	{ Key = "Name", Label = "Name" },
}

function ESPPreview.new(library, parent, config)
	config = config or {}

	local self = setmetatable({}, ESPPreview)

	self.Library = library
	self.Name = config.Name or "ESP Preview"
	self.Height = config.Height or 320
	self.Color = typeof(config.Color) == "Color3" and config.Color or library.Palette.Primary
	self.Enabled = { Highlight = true, Box = true, Tracer = true, Name = true }
	self.Target = {
		Name = config.TargetName or "Cherry",
		Health = 100,
		MaxHealth = 100,
		Distance = 42,
	}
	self.Changed = Signal.new()
	self.Destroyed = false

	self._connections = {}
	self._partStrokes = {}
	self._brackets = {}
	self._sway = 0
	self._bob = 0
	self._lean = 0

	local palette = library.Palette

	self.Frame = Create.new("Frame", {
		Name = "ESPPreview",
		Size = UDim2.new(1, 0, 0, self.Height),
		BackgroundTransparency = 0.08,
		Parent = parent,
	})
	library:Styled(self.Frame, "Surface", "BackgroundColor3")
	Create.corner(self.Frame, 10)
	library:Styled(Create.stroke(self.Frame, palette.Outline, 1, 0.4), "Outline", "Color")

	-- Header.
	self.LivePill = Create.new("Frame", {
		Name = "Live",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(40, 18),
		BackgroundColor3 = self.Color,
		BackgroundTransparency = 0.85,
		Parent = self.Frame,
	})
	Create.corner(self.LivePill, 9)

	self.LiveDot = Create.new("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(7, 9),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = self.Color,
		Parent = self.LivePill,
	})
	Create.corner(self.LiveDot, UDim.new(1, 0))

	self.LiveLabel = Create.label({
		Name = "LiveLabel",
		Text = "LIVE",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = self.Color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(13, 0),
		Size = UDim2.new(1, -13, 1, 0),
		Parent = self.LivePill,
	})

	self.Title = Create.label({
		Name = "Title",
		Text = self.Name,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = palette.Text,
		Position = UDim2.fromOffset(58, 10),
		Size = UDim2.new(1, -140, 0, 18),
		Parent = self.Frame,
	})
	library:Styled(self.Title, "Text", "TextColor3")

	self.DistanceLabel = Create.label({
		Name = "Distance",
		Text = "42 m",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(70, 18),
		Parent = self.Frame,
	})
	library:Styled(self.DistanceLabel, "SubText", "TextColor3")

	-- Toggle chips.
	local chipRow = Create.new("Frame", {
		Name = "Chips",
		Position = UDim2.fromOffset(10, 38),
		Size = UDim2.new(1, -20, 0, 20),
		BackgroundTransparency = 1,
		Parent = self.Frame,
	})
	Create.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = chipRow,
	})

	self.Chips = {}

	for index, definition in ipairs(CHIP_DEFS) do
		local chip = Create.textButton({
			Name = definition.Key,
			Size = UDim2.fromOffset(68, 20),
			Parent = chipRow,
		})
		chip.LayoutOrder = index
		Create.corner(chip, 5)

		local dot = Create.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(8, 10),
			Size = UDim2.fromOffset(4, 4),
			BackgroundColor3 = self.Color,
			Parent = chip,
		})
		Create.corner(dot, UDim.new(1, 0))

		local label = Create.label({
			Text = definition.Label,
			TextSize = 10,
			Position = UDim2.fromOffset(17, 0),
			Size = UDim2.new(1, -19, 1, 0),
			Parent = chip,
		})

		chip.Activated:Connect(function()
			self:Toggle(definition.Key)
		end)

		self.Chips[definition.Key] = { Button = chip, Dot = dot, Label = label }
	end

	-- Stage.
	self.Stage = Create.new("Frame", {
		Name = "Stage",
		Position = UDim2.fromOffset(10, 68),
		Size = UDim2.new(1, -20, 1, -78),
		BackgroundColor3 = palette.Background,
		BackgroundTransparency = 0.3,
		ClipsDescendants = true,
		Parent = self.Frame,
	})
	library:Styled(self.Stage, "Background", "BackgroundColor3")
	Create.corner(self.Stage, 8)
	library:Styled(Create.stroke(self.Stage, palette.Outline, 1, 0.5), "Outline", "Color")

	for index = 1, 3 do
		local offset = index * 0.25
		Create.new("Frame", {
			Name = "GridV",
			Position = UDim2.fromScale(offset, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = palette.Outline,
			BackgroundTransparency = 0.65,
			ZIndex = 1,
			Parent = self.Stage,
		})
		Create.new("Frame", {
			Name = "GridH",
			Position = UDim2.fromScale(0, offset),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = palette.Outline,
			BackgroundTransparency = 0.65,
			ZIndex = 1,
			Parent = self.Stage,
		})
	end

	-- Tracer.
	self.Tracer = Create.new("Frame", {
		Name = "Tracer",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(100, 1.5),
		BackgroundColor3 = self.Color,
		BackgroundTransparency = 0.25,
		ZIndex = 2,
		Parent = self.Stage,
	})
	Create.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 0.9),
		}),
		Parent = self.Tracer,
	})

	-- Avatar.
	self.Character = Create.new("Frame", {
		Name = "Character",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 140),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = self.Stage,
	})
	self.CharacterScale = Create.new("UIScale", { Scale = 1, Parent = self.Character })

	self.HighlightGlow = Create.new("Frame", {
		Name = "HighlightGlow",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(76, 138),
		BackgroundColor3 = self.Color,
		BackgroundTransparency = 0.9,
		ZIndex = 1,
		Parent = self.Character,
	})
	Create.corner(self.HighlightGlow, 18)

	self.Highlight = Create.new("Frame", {
		Name = "Highlight",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(52, 128),
		BackgroundColor3 = self.Color,
		BackgroundTransparency = 0.55,
		ZIndex = 2,
		Parent = self.Character,
	})
	Create.corner(self.Highlight, 14)

	local function makePart(name, position, size, corner, rotation)
		local part = Create.new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = position,
			Size = size,
			Rotation = rotation or 0,
			BackgroundTransparency = 0.05,
			ZIndex = 3,
			Parent = self.Character,
		})
		library:Styled(part, "SurfaceHigh", "BackgroundColor3")
		Create.corner(part, corner)
		table.insert(self._partStrokes, Create.stroke(part, self.Color, 1, 0.75))
		return part
	end

	makePart("Head", UDim2.new(0.5, 0, 0, 4), UDim2.fromOffset(24, 24), 12)
	makePart("Torso", UDim2.new(0.5, 0, 0, 30), UDim2.fromOffset(32, 50), 7)
	makePart("LeftArm", UDim2.new(0.5, -22, 0, 32), UDim2.fromOffset(10, 44), 5, 5)
	makePart("RightArm", UDim2.new(0.5, 22, 0, 32), UDim2.fromOffset(10, 44), 5, -5)
	makePart("LeftLeg", UDim2.new(0.5, -9, 0, 82), UDim2.fromOffset(12, 46), 6, 2)
	makePart("RightLeg", UDim2.new(0.5, 9, 0, 82), UDim2.fromOffset(12, 46), 6, -2)

	-- Face (kept subtle so the silhouette still reads as a player model).
	local face = Create.new("Frame", {
		Name = "Face",
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(16, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = self.Character,
	})
	for _, eyeX in ipairs({ 2, 10 }) do
		local eye = Create.new("Frame", {
			Name = "Eye",
			Position = UDim2.fromOffset(eyeX, 1),
			Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = Color3.fromRGB(30, 30, 34),
			ZIndex = 8,
			Parent = face,
		})
		Create.corner(eye, UDim.new(1, 0))
	end
	local smile = Create.new("Frame", {
		Name = "Smile",
		Position = UDim2.fromOffset(4, 7),
		Size = UDim2.fromOffset(8, 2),
		BackgroundColor3 = Color3.fromRGB(30, 30, 34),
		ZIndex = 8,
		Parent = face,
	})
	Create.corner(smile, 1)

	-- Bounding box + brackets.
	self.Box = Create.new("Frame", {
		Name = "BoundingBox",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(62, 140),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = self.Character,
	})
	self.BoxStroke = Create.stroke(self.Box, self.Color, 1.5, 0.15)

	local function bracket(anchorPoint, position, width, height)
		local frame = Create.new("Frame", {
			Name = "Bracket",
			AnchorPoint = anchorPoint,
			Position = position,
			Size = UDim2.fromOffset(width, height),
			BackgroundColor3 = self.Color,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = self.Box,
		})
		table.insert(self._brackets, frame)
	end

	bracket(Vector2.new(0, 0), UDim2.fromOffset(0, 0), 12, 2)
	bracket(Vector2.new(0, 0), UDim2.fromOffset(0, 0), 2, 12)
	bracket(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), 12, 2)
	bracket(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), 2, 12)
	bracket(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), 12, 2)
	bracket(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), 2, 12)
	bracket(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), 12, 2)
	bracket(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), 2, 12)

	-- Name tag.
	self.NameTag = Create.new("Frame", {
		Name = "NameTag",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -12),
		Size = UDim2.fromOffset(104, 30),
		BackgroundColor3 = palette.Background,
		BackgroundTransparency = 0.1,
		ZIndex = 7,
		Parent = self.Character,
	})
	Create.corner(self.NameTag, 5)
	library:Styled(self.NameTag, "Background", "BackgroundColor3")
	self.NameTagStroke = Create.stroke(self.NameTag, self.Color, 1, 0.45)

	self.NameLabel = Create.label({
		Name = "PlayerName",
		Text = self.Target.Name,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(2, 4),
		Size = UDim2.new(1, -4, 0, 13),
		ZIndex = 8,
		Parent = self.NameTag,
	})
	library:Styled(self.NameLabel, "Text", "TextColor3")

	local healthTrack = Create.new("Frame", {
		Name = "HealthTrack",
		Position = UDim2.fromOffset(5, 20),
		Size = UDim2.new(1, -10, 0, 3),
		BackgroundColor3 = palette.Outline,
		ZIndex = 8,
		Parent = self.NameTag,
	})
	Create.corner(healthTrack, 1)

	self.HealthFill = Create.new("Frame", {
		Name = "HealthFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Success,
		ZIndex = 9,
		Parent = healthTrack,
	})
	Create.corner(self.HealthFill, 1)

	-- Connections.
	table.insert(self._connections, self.Stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_updateScale()
	end))

	table.insert(self._connections, library.ThemeManager.Changed:Connect(function()
		self:_applyColor()
		self:_renderTarget()
	end))

	-- Capped 30 Hz animation through the shared scheduler.
	self._task = library.Scheduler:Every(1 / 30, function()
		self:_update()
	end)

	self:_updateScale()
	self:_applyColor()
	self:_renderTarget()
	self:_updateVisibility()

	return self
end

function ESPPreview:_updateScale()
	if not self.Stage then
		return
	end

	local height = self.Stage.AbsoluteSize.Y
	if height <= 0 then
		return
	end

	self.CharacterScale.Scale = math.clamp(height / 260, 0.7, 1.05)
end

function ESPPreview:_renderChip(key, animate)
	local chip = self.Chips[key]
	if not chip then
		return
	end

	local palette = self.Library.Palette
	local enabled = self.Enabled[key] == true
	local info = animate and Tween.Info.Fast or Tween.Info.Instant

	Tween.play(chip.Button, {
		BackgroundColor3 = enabled and self.Color or palette.SurfaceHigh,
		BackgroundTransparency = enabled and 0.82 or 0.2,
	}, info)

	chip.Dot.BackgroundColor3 = enabled and self.Color or palette.Placeholder
	chip.Label.TextColor3 = enabled and self.Color or palette.SubText
end

function ESPPreview:_applyColor()
	local color = self.Color

	if self.LivePill then
		self.LivePill.BackgroundColor3 = color
		self.LiveDot.BackgroundColor3 = color
		self.LiveLabel.TextColor3 = color
	end

	self.Highlight.BackgroundColor3 = color
	self.HighlightGlow.BackgroundColor3 = color
	self.BoxStroke.Color = color
	self.Tracer.BackgroundColor3 = color
	self.NameTagStroke.Color = color

	for _, bracket in ipairs(self._brackets) do
		bracket.BackgroundColor3 = color
	end
	for _, stroke in ipairs(self._partStrokes) do
		stroke.Color = color
	end

	for _, definition in ipairs(CHIP_DEFS) do
		self:_renderChip(definition.Key, false)
	end
end

function ESPPreview:_renderTarget()
	local palette = self.Library.Palette
	local target = self.Target
	local fraction = Util.clamp(target.Health / math.max(target.MaxHealth, 1), 0, 1)

	self.NameLabel.Text = target.Name
	self.HealthFill.Size = UDim2.fromScale(fraction, 1)
	self.HealthFill.BackgroundColor3 = fraction > 0.6 and palette.Success
		or fraction > 0.3 and palette.Warning
		or palette.Danger
	self.DistanceLabel.Text = tostring(math.floor(target.Distance)) .. " m"
end

function ESPPreview:_updateVisibility()
	self.Highlight.Visible = self.Enabled.Highlight == true
	self.HighlightGlow.Visible = self.Highlight.Visible
	self.Box.Visible = self.Enabled.Box == true
	self.Tracer.Visible = self.Enabled.Tracer == true
	self.NameTag.Visible = self.Enabled.Name == true
end

function ESPPreview:_update()
	if self.Destroyed then
		return
	end

	-- Pause the animation while the tab or the window is hidden.
	local content = self.Frame and self.Frame.Parent and self.Frame.Parent.Parent
	if content and not content.Visible then
		return
	end
	local main = content and content.Parent
	local root = main and main.Parent and main.Parent.Parent
	if root and root.Visible == false then
		return
	end

	local clock = os.clock()
	self._sway = math.sin(clock * 0.9) * 9
	self._bob = math.sin(clock * 1.8) * 2
	self._lean = math.sin(clock * 0.9 + 0.7) * 1.5

	self.Character.Position = UDim2.new(0.5, self._sway, 0.5, self._bob)
	self.Character.Rotation = self._lean

	if self.Enabled.Highlight then
		self.Highlight.BackgroundTransparency = 0.56 + math.sin(clock * 2.2) * 0.05
		self.HighlightGlow.BackgroundTransparency = 0.9 + math.sin(clock * 1.4) * 0.02
	end

	local stage = self.Stage
	local size = stage.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end

	local stagePosition = stage.AbsolutePosition
	local characterPosition = self.Character.AbsolutePosition - stagePosition
	local characterSize = self.Character.AbsoluteSize

	local bottom = Vector2.new(size.X * 0.5, size.Y)
	local target = Vector2.new(
		characterPosition.X + characterSize.X * 0.5,
		characterPosition.Y + characterSize.Y * 0.74
	)
	local delta = target - bottom

	self.Tracer.Size = UDim2.fromOffset(math.max(delta.Magnitude, 1), 1.5)
	self.Tracer.Position = UDim2.fromOffset(bottom.X, bottom.Y)
	self.Tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

function ESPPreview:GetSettings()
	return {
		Highlight = self.Enabled.Highlight == true,
		Box = self.Enabled.Box == true,
		Tracer = self.Enabled.Tracer == true,
		Name = self.Enabled.Name == true,
		Color = self.Color,
		Target = self.Target,
	}
end

function ESPPreview:_commit()
	self.Changed:Fire(self:GetSettings())
end

function ESPPreview:SetEnabled(key, value, silent)
	if self.Enabled[key] == nil or self.Destroyed then
		return
	end

	self.Enabled[key] = value == true
	self:_renderChip(key, true)
	self:_updateVisibility()

	if not silent then
		self:_commit()
	end
end

function ESPPreview:Toggle(key)
	if self.Enabled[key] == nil then
		return
	end
	self:SetEnabled(key, not self.Enabled[key])
end

function ESPPreview:SetColor(color)
	if typeof(color) ~= "Color3" or self.Destroyed then
		return
	end

	self.Color = color
	self:_applyColor()
	self:_commit()
end

function ESPPreview:SetTarget(data)
	if type(data) ~= "table" or self.Destroyed then
		return
	end

	if data.Name ~= nil then
		self.Target.Name = tostring(data.Name)
	end
	if tonumber(data.Health) ~= nil then
		self.Target.Health = tonumber(data.Health)
	end
	if tonumber(data.MaxHealth) ~= nil then
		self.Target.MaxHealth = tonumber(data.MaxHealth)
	end
	if tonumber(data.Distance) ~= nil then
		self.Target.Distance = tonumber(data.Distance)
	end

	self:_renderTarget()
end

function ESPPreview:OnChanged(callback)
	return self.Changed:Connect(callback)
end

function ESPPreview:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	if self._task then
		self.Library.Scheduler:Remove(self._task)
		self._task = nil
	end

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)

	self.Changed:Destroy()
	self.Frame:Destroy()
end

return ESPPreview
