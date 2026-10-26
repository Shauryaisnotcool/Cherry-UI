--[[
	Components/Notification.lua
	Top-right notification stack with pooled cards.

	Cards slide in from the right, show a shrinking progress bar, pause while
	hovered, and are returned to the pool after their exit animation. A single
	10 Hz scheduler task drives every active card's lifetime.
]]

local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)
local Fade = require(script.Parent.Parent.Utils.Fade)
local Pool = require(script.Parent.Parent.Utils.Pool)

local Notification = {}
Notification.__index = Notification

local HOLDER_WIDTH = 304
local CARD_HEIGHT = 76
local MAX_VISIBLE = 4

function Notification.new(library)
	local self = setmetatable({}, Notification)

	self.Library = library
	self.Entries = {}
	self._byId = {}
	self._widgets = {}
	self._nextId = 0
	self.MaxVisible = MAX_VISIBLE
	self.Destroyed = false

	self.Holder = Create.new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(HOLDER_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 600,
		Parent = library.ScreenGui,
	})

	Create.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = self.Holder,
	})

	self.Pool = Pool.new(function()
		return self:_createCard()
	end, function(wrapper)
		self:_resetCard(wrapper)
	end)

	self._task = library.Scheduler:Every(0.1, function()
		self:_tick()
	end)

	return self
end

function Notification:_createCard()
	local library = self.Library
	local palette = library.Palette

	local wrapper = Create.new("Frame", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
	})

	local card = Create.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 60, 0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.05,
		Parent = wrapper,
	})
	library:Styled(card, "Surface", "BackgroundColor3")
	Create.corner(card, 9)
	library:Styled(Create.stroke(card, palette.Outline, 1, 0.3), "Outline", "Color")
	library.ThemeManager:BindGradient(
		Create.new("UIGradient", { Rotation = 90, Parent = card }),
		{ "SurfaceHigh", "Surface" }
	)

	local accent = Create.new("Frame", {
		Name = "Accent",
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(0, 3, 1, -20),
		BackgroundColor3 = palette.Primary,
		Parent = card,
	})
	Create.corner(accent, 2)

	local iconHolder = Create.new("Frame", {
		Name = "IconHolder",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = palette.Primary,
		BackgroundTransparency = 0.85,
		Parent = card,
	})
	Create.corner(iconHolder, 8)

	local iconLabel = Create.label({
		Name = "Icon",
		Text = "◆",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = iconHolder,
	})

	local iconImage = Create.new("ImageLabel", {
		Name = "IconImage",
		Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.fromOffset(5, 5),
		BackgroundTransparency = 1,
		Image = "",
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		Parent = iconHolder,
	})

	local title = Create.label({
		Name = "Title",
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Position = UDim2.fromOffset(52, 10),
		Size = UDim2.new(1, -100, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	library:Styled(title, "Text", "TextColor3")

	local content = Create.label({
		Name = "Content",
		Text = "",
		TextSize = 12,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(52, 27),
		Size = UDim2.new(1, -66, 0, 34),
		Parent = card,
	})
	library:Styled(content, "SubText", "TextColor3")

	local close = Create.textButton({
		Name = "Close",
		Text = "✕",
		TextSize = 11,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(18, 18),
		Parent = card,
	})
	library:Styled(close, "SubText", "TextColor3")

	local progressTrack = Create.new("Frame", {
		Name = "ProgressTrack",
		Position = UDim2.fromOffset(10, CARD_HEIGHT - 8),
		Size = UDim2.new(1, -20, 0, 2),
		BackgroundColor3 = palette.Primary,
		BackgroundTransparency = 0.8,
		Parent = card,
	})
	Create.corner(progressTrack, 1)

	local progressFill = Create.new("Frame", {
		Name = "ProgressFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Primary,
		Parent = progressTrack,
	})
	Create.corner(progressFill, 1)

	self._widgets[wrapper] = {
		Card = card,
		Accent = accent,
		IconHolder = iconHolder,
		IconLabel = iconLabel,
		IconImage = iconImage,
		Title = title,
		Content = content,
		Close = close,
		ProgressTrack = progressTrack,
		ProgressFill = progressFill,
	}

	local function findEntry()
		local id = wrapper:GetAttribute("CherryNotification")
		return id and self._byId[id] or nil
	end

	card.MouseEnter:Connect(function()
		local entry = findEntry()
		if entry and not entry.Dismissed then
			entry.Hovered = true
			if entry.ProgressTween then
				entry.ProgressTween:Pause()
			end
		end
	end)

	card.MouseLeave:Connect(function()
		local entry = findEntry()
		if entry then
			entry.Hovered = false
			if entry.ProgressTween and not entry.Dismissed then
				entry.ProgressTween:Play()
			end
		end
	end)

	close.Activated:Connect(function()
		local entry = findEntry()
		if entry then
			self:_dismiss(entry)
		end
	end)

	close.MouseEnter:Connect(function()
		close.TextColor3 = self.Library.Palette.Text
	end)

	close.MouseLeave:Connect(function()
		close.TextColor3 = self.Library.Palette.SubText
	end)

	return wrapper
end

function Notification:_resetCard(wrapper)
	local widgets = self._widgets[wrapper]
	if not widgets then
		return
	end

	wrapper.Visible = false
	wrapper:SetAttribute("CherryNotification", nil)

	widgets.Card.Position = UDim2.new(1, 60, 0, 0)
	Fade.set(widgets.Card, 0)
	widgets.ProgressFill.Size = UDim2.fromScale(1, 1)
	widgets.Title.Text = ""
	widgets.Content.Text = ""
	widgets.IconImage.Visible = false
	widgets.IconImage.Image = ""
	widgets.IconLabel.Visible = true
end

function Notification:Show(config)
	if self.Destroyed then
		return nil
	end

	config = config or {}

	local duration = math.max(tonumber(config.Duration) or 5, 0.1)
	local wrapper = self.Pool:Get(self.Holder)
	local widgets = self._widgets[wrapper]

	self._nextId += 1
	local id = self._nextId

	wrapper:SetAttribute("CherryNotification", id)
	wrapper.Visible = true
	widgets.Card.Visible = true
	-- Newest cards stack on top; the UIListLayout sorts ascending.
	wrapper.LayoutOrder = -id

	local palette = self.Library.Palette
	local accent = config.Color
	if typeof(accent) ~= "Color3" then
		local kind = config.Type or "info"
		if kind == "success" then
			accent = palette.Success
		elseif kind == "warning" then
			accent = palette.Warning
		elseif kind == "error" or kind == "danger" then
			accent = palette.Danger
		else
			accent = palette.Primary
		end
	end

	widgets.Accent.BackgroundColor3 = accent
	widgets.IconHolder.BackgroundColor3 = accent
	widgets.IconLabel.TextColor3 = accent
	widgets.ProgressTrack.BackgroundColor3 = accent
	widgets.ProgressFill.BackgroundColor3 = accent
	widgets.Close.TextColor3 = palette.SubText
	widgets.Title.Text = tostring(config.Title or "Notification")
	widgets.Content.Text = tostring(config.Content or "")

	local icon = config.Icon
	if type(icon) == "string" and string.sub(icon, 1, 10) == "rbxassetid" then
		widgets.IconImage.Image = icon
		widgets.IconImage.Visible = true
		widgets.IconLabel.Visible = false
	else
		widgets.IconImage.Visible = false
		widgets.IconImage.Image = ""
		widgets.IconLabel.Visible = true
		widgets.IconLabel.Text = (type(icon) == "string" and icon ~= "") and icon or "◆"
	end

	local entry = {
		Id = id,
		Wrapper = wrapper,
		Card = widgets.Card,
		Config = config,
		Duration = duration,
		Remaining = duration,
		Hovered = false,
		Dismissed = false,
	}
	entry.Dismiss = function()
		self:_dismiss(entry)
	end

	self._byId[id] = entry
	table.insert(self.Entries, entry)

	widgets.Card.Position = UDim2.new(1, 60, 0, 0)
	Fade.play(widgets.Card, 1, 0, 0.36, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	Tween.play(widgets.Card, {
		Position = UDim2.new(1, 0, 0, 0),
	}, Tween.Info.Glide)

	widgets.ProgressFill.Size = UDim2.fromScale(1, 1)
	entry.ProgressTween = Tween.create(widgets.ProgressFill, {
		Size = UDim2.fromScale(0, 1),
	}, Tween.linear(duration))
	entry.ProgressTween:Play()

	-- Dismissed cards linger for their exit animation, so pick the oldest card
	-- that is still visible instead of blindly trimming the head of the list.
	local guard = 0
	while #self.Entries > self.MaxVisible and guard < 10 do
		guard += 1

		local target = nil
		for index = 1, #self.Entries do
			local candidate = self.Entries[index]
			if candidate ~= entry and not candidate.Dismissed then
				target = candidate
				break
			end
		end

		if not target then
			break
		end

		self:_dismiss(target)
	end

	return entry
end

function Notification:_dismiss(entry)
	if not entry or entry.Dismissed then
		return
	end

	entry.Dismissed = true

	if entry.ProgressTween then
		entry.ProgressTween:Cancel()
	end

	local widgets = self._widgets[entry.Wrapper]
	if widgets then
		Tween.play(widgets.Card, {
			Position = UDim2.new(1, 60, 0, 0),
		}, Tween.Info.Fast)
		Fade.play(widgets.Card, 0, 1, 0.14)
	end

	local wrapper = entry.Wrapper

	task.delay(0.18, function()
		if self.Destroyed then
			return
		end

		self._byId[entry.Id] = nil

		local index = table.find(self.Entries, entry)
		if index then
			table.remove(self.Entries, index)
		end

		if wrapper and wrapper.Parent then
			self.Pool:Release(wrapper)
		end
	end)
end

function Notification:_tick()
	for index = #self.Entries, 1, -1 do
		local entry = self.Entries[index]
		if not entry.Dismissed and not entry.Hovered then
			entry.Remaining -= 0.1
			if entry.Remaining <= 0 then
				self:_dismiss(entry)
			end
		end
	end
end

function Notification:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	if self._task then
		self.Library.Scheduler:Remove(self._task)
		self._task = nil
	end

	table.clear(self.Entries)
	table.clear(self._byId)

	if self.Pool then
		self.Pool:Destroy()
		self.Pool = nil
	end

	table.clear(self._widgets)

	if self.Holder then
		self.Holder:Destroy()
		self.Holder = nil
	end
end

return Notification
