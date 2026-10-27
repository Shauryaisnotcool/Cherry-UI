--[[
	Components/Window.lua
	The main Cherry UI window.

	Reference layout:
	  header  - logo, title, search box, close button (drag handle)
	  tab bar - horizontal tabs with an accent underline + theme dots on the right
	  content - lazily built tab pages

	Performance notes:
	  * `Main` clips its descendants, so nothing draws outside the rounded panel
	  * one global InputChanged/InputEnded connection handles drag and resize
	  * a UIScale keeps the window usable on smaller viewports
]]

local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)
local Fade = require(script.Parent.Parent.Utils.Fade)
local Icons = require(script.Parent.Parent.Utils.Icons)
local Logo = require(script.Parent.Parent.Core.Logo)
local Tab = require(script.Parent.Tab)

local Window = {}
Window.__index = Window

local HEADER_HEIGHT = 44
local TAB_BAR_HEIGHT = 34
local TAB_WIDTH = 86

function Window.new(library, config)
	config = config or {}

	local self = setmetatable({}, Window)

	self.Library = library
	self.Config = config
	self.Title = tostring(config.Title or "Cherry UI")
	self.Subtitle = tostring(config.Subtitle or ("v" .. tostring(library.Version)))
	self.MinWidth = tonumber(config.MinWidth) or 480
	self.MinHeight = tonumber(config.MinHeight) or 300
	self.Resizable = config.Resizable ~= false
	self._resizeAxes = { X = true, Y = true }

	-- Accept both explicit Width/Height and the documented `Size = UDim2` form.
	local width = tonumber(config.Width)
	local height = tonumber(config.Height)
	local size = config.Size

	if typeof(size) == "UDim2" then
		local viewport = self:_viewportSize()

		if size.X.Scale > 0 then
			width = math.floor(viewport.X * size.X.Scale)
		end
		if size.Y.Scale > 0 then
			height = math.floor(viewport.Y * size.Y.Scale)
		end
		if size.X.Offset > 0 then
			width = size.X.Offset
		end
		if size.Y.Offset > 0 then
			height = size.Y.Offset
		end
	end

	self.Width = math.max(width or 640, self.MinWidth)
	self.Height = math.max(height or 460, self.MinHeight)
	self.Tabs = {}
	self.ActiveTab = nil
	self.Visible = false
	self.Destroyed = false
	self.SearchEntries = {}

	self._connections = {}
	self._baseScale = 1
	self._animScale = 1
	self._dragging = false
	self._resizing = false

	self:_build()
	self:_bindEvents()
	self:_updateScale()

	-- The ScreenGui reports a 0x0 AbsoluteSize until its first render, so scale
	-- once more after the frame is on screen (otherwise a small viewport can keep
	-- the window at 100% and push it off the edges).
	task.defer(function()
		if not self.Destroyed then
			self:_updateScale()
		end
	end)

	--[[
		An empty window is undiagnosable from the outside, so after a moment of
		grace it explains itself: this is what happens when the calling script hit
		an error before its first AddTab (or is running a stale bundle).
	]]
	task.delay(1.5, function()
		if self.Destroyed or #self.Tabs > 0 then
			return
		end

		warn(string.format(
			"[CherryUI] Window '%s' has no tabs yet. Add one with window:AddTab(name, icon, builder).",
			self.Title
		))

		self:ShowNotice({
			Type = "info",
			Icon = "layers",
			Title = "This window has no tabs yet",
			Content = table.concat({
				"If your script already calls AddTab, it hit an error before reaching it —",
				"check the Output/console for the first message. Otherwise:",
				'',
				'window:AddTab("Combat", "target", function(tab)',
				'\ttab:AddSection("Aimbot"):AddToggle({ Name = "Enable Aimbot" })',
				'end)',
			}, "\n"),
		})
	end)

	library.Windows[self] = true

	if config.StartOpen ~= false then
		self:Open()
	end

	return self
end

function Window:_track(connection)
	table.insert(self._connections, connection)
	return connection
end

-- Viewport size with fallbacks for the first frames, when the ScreenGui has not
-- been laid out yet and `AbsoluteSize` is still (0, 0).
function Window:_viewportSize()
	local screenGui = self.Library.ScreenGui
	local size = screenGui and screenGui.AbsoluteSize

	if size and size.X > 0 and size.Y > 0 then
		return size
	end

	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize and camera.ViewportSize.X > 0 then
		return camera.ViewportSize
	end

	return Vector2.new(1280, 800)
end

-- Keeps the window inside the viewport, including after a resolution change.
function Window:_fitToViewport()
	if not self.Root then
		return
	end

	local viewport = self:_viewportSize()
	local factor = math.max(self._baseScale, 0.4)
	local maxWidth = math.max(240, viewport.X / factor - 24)
	local maxHeight = math.max(180, viewport.Y / factor - 24)

	local width = math.clamp(self.Width, math.min(self.MinWidth, maxWidth), maxWidth)
	local height = math.clamp(self.Height, math.min(self.MinHeight, maxHeight), maxHeight)

	if math.floor(width) ~= self.Width or math.floor(height) ~= self.Height then
		self.Width = math.floor(width)
		self.Height = math.floor(height)
		self.Root.Size = UDim2.fromOffset(self.Width, self.Height)
	end
end

function Window:_build()
	local library = self.Library
	local palette = library.Palette

	self.Root = Create.new("Frame", {
		Name = "CherryWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self.Width, self.Height),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = library.ScreenGui,
	})

	self.Scale = Create.new("UIScale", { Scale = 1, Parent = self.Root })

	for index = 1, 3 do
		local spread = index * 5
		local shadow = Create.new("Frame", {
			Name = "Shadow" .. tostring(index),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.82 + index * 0.04,
			Position = UDim2.fromOffset(-spread, -spread + 3),
			Size = UDim2.new(1, spread * 2, 1, spread * 2),
			ZIndex = 1,
			Parent = self.Root,
		})
		Create.corner(shadow, 9 + spread)
	end

	self.Frame = Create.new("Frame", {
		Name = "Main",
		BackgroundTransparency = 0.03,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = self.Root,
	})
	library:Styled(self.Frame, "Background", "BackgroundColor3")
	Create.corner(self.Frame, 8)
	library:Styled(Create.stroke(self.Frame, palette.Outline, 1, 0.15), "Outline", "Color")

	-- Top sheen + a single accent glow, kept subtle.
	local sheen = Create.new("Frame", {
		Name = "Sheen",
		Size = UDim2.new(1, 0, 0.3, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = self.Frame,
	})
	Create.corner(sheen, 8)
	Create.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.955),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = sheen,
	})

	local glow = Create.new("Frame", {
		Name = "Glow",
		Position = UDim2.fromOffset(-110, -120),
		Size = UDim2.fromOffset(340, 260),
		BackgroundTransparency = 0.92,
		ZIndex = 2,
		Parent = self.Frame,
	})
	Create.corner(glow, UDim.new(1, 0))
	library:Styled(glow, "Primary", "BackgroundColor3")
	Create.new("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = glow,
	})

	-- Header.
	self.Header = Create.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = self.Frame,
	})

	self.TitleBar = Create.textButton({
		Name = "TitleBar",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = self.Header,
	})

	self.Logo = Logo.new(library, {
		Parent = self.TitleBar,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 6,
	})

	self.TitleLabel = Create.label({
		Name = "Title",
		Text = self.Title,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.fromOffset(46, 3),
		Size = UDim2.new(0.5, -46, 0, 20),
		ZIndex = 6,
		Parent = self.TitleBar,
	})
	library:Styled(self.TitleLabel, "Text", "TextColor3")

	self.SubtitleLabel = Create.label({
		Name = "Subtitle",
		Text = self.Subtitle,
		TextSize = 10,
		Position = UDim2.fromOffset(46, 21),
		Size = UDim2.new(0.5, -46, 0, 14),
		ZIndex = 6,
		Parent = self.TitleBar,
	})
	library:Styled(self.SubtitleLabel, "SubText", "TextColor3")

	self.SearchFrame = Create.new("Frame", {
		Name = "SearchFrame",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -48, 0, 10),
		Size = UDim2.fromOffset(176, 24),
		BackgroundTransparency = 0.25,
		ZIndex = 7,
		Parent = self.Header,
	})
	Create.corner(self.SearchFrame, 6)
	library:Styled(self.SearchFrame, "Surface", "BackgroundColor3")
	self.SearchStroke = Create.stroke(self.SearchFrame, palette.Outline, 1, 0.35)
	library:Styled(self.SearchStroke, "Outline", "Color")

	self.SearchIcon = Icons.new("search", self.SearchFrame, 13, palette.Placeholder, 7)
	self.SearchIcon.Position = UDim2.fromOffset(7, 5.5)
	Icons.bindTheme(self.SearchIcon, library, "Placeholder")

	self.SearchBox = Create.new("TextBox", {
		Name = "Search",
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -32, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Search settings",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 7,
		Parent = self.SearchFrame,
	})
	library:Styled(self.SearchBox, "Text", "TextColor3")
	library:Styled(self.SearchBox, "Placeholder", "PlaceholderColor3")

	self.CloseButton = Create.textButton({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, HEADER_HEIGHT / 2),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = palette.SurfaceHigh,
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 7,
		Parent = self.Header,
	})
	Create.corner(self.CloseButton, 12)

	self.CloseIcon = Icons.new("close", self.CloseButton, 12, palette.SubText, 8)
	self.CloseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	self.CloseIcon.Position = UDim2.fromScale(0.5, 0.5)

	-- Tab bar.
	self.TabBar = Create.new("Frame", {
		Name = "TabBar",
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 0, TAB_BAR_HEIGHT),
		BackgroundColor3 = palette.Surface,
		BackgroundTransparency = 0.55,
		ZIndex = 5,
		Parent = self.Frame,
	})
	library:Styled(self.TabBar, "Surface", "BackgroundColor3")

	local tabBarDivider = Create.new("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 0.4,
		ZIndex = 5,
		Parent = self.TabBar,
	})
	library:Styled(tabBarDivider, "Outline", "BackgroundColor3")

	self.TabList = Create.new("Frame", {
		Name = "TabList",
		Size = UDim2.new(1, -110, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = self.TabBar,
	})
	Create.padding(self.TabList, 0, 0, 0, 8)
	Create.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = self.TabList,
	})

	-- Theme dots on the right side of the tab bar.
	self.ThemeRow = Create.new("Frame", {
		Name = "Themes",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(96, 18),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = self.TabBar,
	})
	Create.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = self.ThemeRow,
	})

	self._themeDots = {}

	for index, name in ipairs(library:GetThemeNames()) do
		local theme = library.Themes[name]
		if theme then
			local dot = Create.textButton({
				Name = tostring(name) .. "Theme",
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = theme.Primary,
				BackgroundTransparency = 0.35,
				Text = "",
				ZIndex = 6,
				Parent = self.ThemeRow,
			})
			dot.LayoutOrder = index
			Create.corner(dot, UDim.new(1, 0))

			local stroke = Create.stroke(dot, Color3.new(1, 1, 1), 1, 1)

			self:_track(dot.Activated:Connect(function()
				library:SetTheme(name)
			end))

			self:_track(dot.MouseEnter:Connect(function()
				Tween.play(dot, { BackgroundTransparency = 0 }, Tween.Info.Fast)
			end))

			self:_track(dot.MouseLeave:Connect(function()
				self:_updateThemeDots()
			end))

			self._themeDots[name] = { Button = dot, Stroke = stroke }
		end
	end

	-- Content.
	self.Content = Create.new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, HEADER_HEIGHT + TAB_BAR_HEIGHT),
		Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + TAB_BAR_HEIGHT)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = self.Frame,
	})

	self.NoResults = Create.label({
		Name = "NoResults",
		Text = "No settings match your search.",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		ZIndex = 8,
		Parent = self.Content,
	})
	library:Styled(self.NoResults, "SubText", "TextColor3")

	--[[
		Notice banner: an in-window card for things the console would hide.
		An empty menu is the most confusing state a library can put a script
author in, so "no tabs yet" and failed tab builders are reported here.
	]]
	self.NoticeHolder = Create.new("Frame", {
		Name = "Notice",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(1, -32, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = self.Content,
	})

	-- Resize affordances: a corner grip (22x22 hit area) plus thin right/bottom
	-- edges, so the window can be grabbed from any of the three expected spots.
	self.ResizeGrip = Create.textButton({
		Name = "Resize",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		Size = UDim2.fromOffset(22, 22),
		ZIndex = 9,
		Parent = self.Frame,
	})

	for index = 1, 3 do
		local bar = Create.new("Frame", {
			Name = "GripBar",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromOffset(-3 - (index - 1) * 5, -3 - (index - 1) * 5),
			Size = UDim2.fromOffset(3 + (index - 1) * 5, 2),
			Rotation = -45,
			BackgroundTransparency = 0.3 + (index - 1) * 0.18,
			ZIndex = 9,
			Parent = self.ResizeGrip,
		})
		library:Styled(bar, "SubText", "BackgroundColor3")
		Create.corner(bar, 1)
	end

	self.RightGrip = Create.textButton({
		Name = "ResizeRight",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		Size = UDim2.new(0, 6, 1, -(HEADER_HEIGHT + 26)),
		ZIndex = 9,
		Parent = self.Frame,
	})

	self.BottomGrip = Create.textButton({
		Name = "ResizeBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 26, 1, 0),
		Size = UDim2.new(1, -52, 0, 6),
		ZIndex = 9,
		Parent = self.Frame,
	})

	if not self.Resizable then
		self.ResizeGrip.Visible = false
		self.RightGrip.Visible = false
		self.BottomGrip.Visible = false
	end

	self:_updateThemeDots()
end

function Window:_bindEvents()
	self:_track(self.TitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self:_startDrag(input)
		end
	end))

	local grips = {
		{ Button = self.ResizeGrip, Axes = { X = true, Y = true } },
		{ Button = self.RightGrip, Axes = { X = true, Y = false } },
		{ Button = self.BottomGrip, Axes = { X = false, Y = true } },
	}

	for _, grip in ipairs(grips) do
		self:_track(grip.Button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				self:_startResize(input, grip.Axes)
			end
		end))
	end

	self:_track(UserInputService.InputChanged:Connect(function(input)
		self:_onInputChanged(input)
	end))

	self:_track(UserInputService.InputEnded:Connect(function(input)
		self:_onInputEnded(input)
	end))

	self:_track(self.CloseButton.Activated:Connect(function()
		self:Close()
	end))

	-- The close button reacts in the danger colour so it never looks like a
	-- plain square: background tint, icon recolour, and a small scale pop.
	self:_track(self.CloseButton.MouseEnter:Connect(function()
		local palette = self.Library.Palette
		Tween.play(self.CloseButton, { BackgroundTransparency = 0.8 }, Tween.Info.Fast)
		Icons.setColor(self.CloseIcon, palette.Danger)
		Icons.setSize(self.CloseIcon, 14, Tween.Info.Fast)
	end))

	self:_track(self.CloseButton.MouseLeave:Connect(function()
		Tween.play(self.CloseButton, { BackgroundTransparency = 1 }, Tween.Info.Fast)
		Icons.setColor(self.CloseIcon, self.Library.Palette.SubText)
		Icons.setSize(self.CloseIcon, 12, Tween.Info.Fast)
	end))

	self:_track(self.CloseButton.MouseEnter:Connect(function()
		Tween.play(self.CloseButton, {
			BackgroundTransparency = 0.15,
			BackgroundColor3 = self.Library.Palette.Danger,
			TextColor3 = Color3.new(1, 1, 1),
		}, Tween.Info.Fast)
	end))

	self:_track(self.CloseButton.MouseLeave:Connect(function()
		Tween.play(self.CloseButton, {
			BackgroundTransparency = 1,
			BackgroundColor3 = self.Library.Palette.SurfaceHigh,
			TextColor3 = self.Library.Palette.SubText,
		}, Tween.Info.Fast)
	end))

	self:_track(self.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self:Filter(self.SearchBox.Text)
	end))

	self:_track(self.SearchBox.Focused:Connect(function()
		Tween.play(self.SearchStroke, {
			Color = self.Library.Palette.Primary,
			Transparency = 0.1,
		}, Tween.Info.Fast)
	end))

	self:_track(self.SearchBox.FocusLost:Connect(function()
		Tween.play(self.SearchStroke, {
			Color = self.Library.Palette.Outline,
			Transparency = 0.35,
		}, Tween.Info.Fast)
	end))

	local screenGui = self.Library.ScreenGui
	if screenGui then
		self:_track(screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_updateScale()
		end))
	end

	self:_track(self.Library.ThemeManager.Changed:Connect(function()
		self:_updateThemeDots()
		for _, tab in ipairs(self.Tabs) do
			self:_setTabActive(tab, tab == self.ActiveTab)
		end
	end))
end

function Window:_updateScale()
	if not self.Library.ScreenGui then
		return
	end

	local size = self:_viewportSize()
	if size.X <= 0 or size.Y <= 0 then
		return
	end

	local scale = math.min(size.X / 1280, size.Y / 800)
	self._baseScale = math.clamp(scale, 0.7, 1.1)
	self:_applyScale()
	self:_fitToViewport()
end

function Window:_applyScale()
	if self.Scale then
		self.Scale.Scale = self._baseScale * self._animScale
	end
end

function Window:_startDrag(input)
	if not self.Visible or self.Destroyed then
		return
	end

	if UserInputService:GetFocusedTextBox() then
		return
	end

	self._dragging = true
	self._dragOrigin = self.Library.Overlay.AbsolutePosition

	local absolute = self.Root.AbsolutePosition - self._dragOrigin
	local size = self.Root.AbsoluteSize

	self._dragStartPosition = Vector2.new(absolute.X + size.X * 0.5, absolute.Y + size.Y * 0.5)
	self._dragStartMouse = Vector2.new(input.Position.X, input.Position.Y)
end

function Window:_startResize(input, axes)
	if not self.Resizable or not self.Visible or self.Destroyed then
		return
	end

	self._resizing = true
	self._resizeAxes = axes or { X = true, Y = true }
	self._resizeStartMouse = Vector2.new(input.Position.X, input.Position.Y)
	self._resizeStartSize = Vector2.new(self.Root.AbsoluteSize.X, self.Root.AbsoluteSize.Y)
	self._resizeStartTopLeft = self.Root.AbsolutePosition - self.Library.Overlay.AbsolutePosition
end

function Window:_onInputChanged(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end

	if self._dragging then
		local delta = Vector2.new(input.Position.X, input.Position.Y) - self._dragStartMouse
		local center = self._dragStartPosition + delta
		local viewport = self.Library.Overlay.AbsoluteSize
		local size = self.Root.AbsoluteSize

		local minX = size.X * 0.5 - 24
		local maxX = viewport.X - size.X * 0.5 + 24
		local minY = size.Y * 0.5 - 24
		local maxY = viewport.Y - size.Y * 0.5 + 24

		self.Root.Position = UDim2.fromOffset(
			math.clamp(center.X, minX, math.max(minX, maxX)),
			math.clamp(center.Y, minY, math.max(minY, maxY))
		)
	elseif self._resizing then
		local delta = Vector2.new(input.Position.X, input.Position.Y) - self._resizeStartMouse
		local viewport = self:_viewportSize()
		local factor = self.Scale.Scale

		if factor <= 0 then
			factor = 1
		end

		local axes = self._resizeAxes or { X = true, Y = true }
		local topLeft = self._resizeStartTopLeft or Vector2.new(0, 0)

		-- Grow only along the axis the grip belongs to (edges resize one axis).
		local targetWidth = self._resizeStartSize.X / factor
		local targetHeight = self._resizeStartSize.Y / factor
		if axes.X then
			targetWidth += delta.X / factor
		end
		if axes.Y then
			targetHeight += delta.Y / factor
		end

		local maxWidth = math.max(200, (viewport.X - topLeft.X - 12) / factor)
		local maxHeight = math.max(160, (viewport.Y - topLeft.Y - 12) / factor)
		local width = math.floor(math.clamp(targetWidth, math.min(self.MinWidth, maxWidth), maxWidth))
		local height = math.floor(math.clamp(targetHeight, math.min(self.MinHeight, maxHeight), maxHeight))

		self.Width = width
		self.Height = height
		self.Root.Size = UDim2.fromOffset(width, height)

		-- AnchorPoint is centered, so compensate to keep the top-left pinned while resizing.
		self.Root.Position = UDim2.fromOffset(
			topLeft.X + width * factor * 0.5,
			topLeft.Y + height * factor * 0.5
		)
	end
end

function Window:_onInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		self._dragging = false
		self._resizing = false
	end
end

--------------------------------------------------------------------------
-- Notices
--------------------------------------------------------------------------

local NOTICE_STYLE = {
	info = { Token = "Primary", Kind = "info" },
	success = { Token = "Success", Kind = "success" },
	warning = { Token = "Warning", Kind = "warning" },
	error = { Token = "Danger", Kind = "error" },
}

--[[
	Shows a card across the top of the content area. The console is easy to miss
	(and invisible in a screenshot), so warnings that matter — a tab that failed
	to build, a window with no tabs — are reported in the interface itself.

		window:ShowNotice({
			Type = "error",        -- info | success | warning | error
			Title = "Tab failed to build",
			Content = "...",
			Duration = 8,          -- seconds; omit to keep it on screen
		})

	Returns a handle with `:Dismiss()`. Only one notice shows at a time.
]]
function Window:ShowNotice(config)
	config = config or {}

	if self.Destroyed or not self.NoticeHolder then
		return nil
	end

	local library = self.Library
	local style = NOTICE_STYLE[config.Type or "info"] or NOTICE_STYLE.info
	local token = style.Token
	local accent = library.Palette[token] or library.Palette.Primary

	self:ClearNotice()

	local card = Create.new("Frame", {
		Name = "NoticeCard",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		ZIndex = 41,
		Parent = self.NoticeHolder,
	})
	library:Styled(card, "Surface", "BackgroundColor3")
	Create.corner(card, 10)
	library:Styled(Create.stroke(card, accent, 1, 0.45), token, "Color")
	Create.padding(card, 12, 34, 12, 12)

	local accentBar = Create.new("Frame", {
		Name = "Accent",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0, 8),
		Size = UDim2.fromOffset(3, 16),
		ZIndex = 42,
		Parent = card,
	})
	Create.corner(accentBar, 2)
	library:Styled(accentBar, token, "BackgroundColor3")

	local icon = Icons.new(Icons.resolve(config.Icon) or style.Kind, card, 16, accent, 42)
	icon.Position = UDim2.fromOffset(2, 0)

	local title = Create.label({
		Name = "Title",
		Text = tostring(config.Title or "Notice"),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 0, 17),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 42,
		Parent = card,
	})
	library:Styled(title, "Text", "TextColor3")

	local content = Create.label({
		Name = "Content",
		Text = tostring(config.Content or ""),
		TextSize = 11,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 42,
		Parent = card,
	})
	library:Styled(content, "SubText", "TextColor3")

	local close = Create.textButton({
		Name = "Dismiss",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.fromOffset(18, 18),
		Text = "",
		ZIndex = 42,
		Parent = card,
	})
	Create.corner(close, 9)

	local closeIcon = Icons.new("close", close, 10, library.Palette.SubText, 43)
	closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	closeIcon.Position = UDim2.fromScale(0.5, 0.5)

	local notice
	notice = {
		Frame = card,
		Dismiss = function()
			if self._notice == notice then
				self:ClearNotice()
			end
		end,
	}

	self._notice = notice
	self.NoticeHolder.Visible = true

	self:_track(close.Activated:Connect(function()
		notice.Dismiss()
	end))

	-- Slide + fade in, so it never just pops into an empty panel.
	card.Position = UDim2.fromOffset(0, -8)
	Fade.play(card, 1, 0, 0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	Tween.play(card, { Position = UDim2.fromOffset(0, 0) }, Tween.Info.Smooth)

	local duration = tonumber(config.Duration)
	if duration and duration > 0 then
		task.delay(duration, function()
			notice.Dismiss()
		end)
	end

	return notice
end

function Window:ClearNotice()
	local notice = self._notice
	if not notice then
		return
	end

	self._notice = nil

	if self.NoticeHolder and not self.NoticeHolder.Destroyed then
		self.NoticeHolder.Visible = false
	end

	if notice.Frame then
		notice.Frame:Destroy()
	end
end

--[[
	Adds a tab. Failures are reported in the window instead of silently
	leaving a blank menu (and instead of taking the caller's script down):
	`AddTab` returns nil and the reason appears in a notice card.
]]
function Window:AddTab(name, icon, builder)
	if self.Destroyed then
		return nil
	end

	-- window:AddTab("Combat", function(tab) ... end) works too.
	if type(icon) == "function" and builder == nil then
		builder = icon
		icon = nil
	end

	local ok, tab = pcall(self._createTab, self, name, icon, builder)

	if not ok then
		warn("[CherryUI] Could not create tab '" .. tostring(name) .. "': " .. tostring(tab))
		self:ShowNotice({
			Type = "error",
			Title = 'Could not create tab "' .. tostring(name) .. '"',
			Content = tostring(tab),
		})
		return nil
	end

	-- The first tab clears the "no tabs yet" hint.
	self:ClearNotice()
	return tab
end

function Window:_createTab(name, icon, builder)
	-- (`Window:CreateTab` is an alias for this, provided at the end of the file.)

	local tab = Tab.new(self.Library, self, {
		Name = name,
		Icon = icon,
		Builder = builder,
	})
	table.insert(self.Tabs, tab)

	local palette = self.Library.Palette
	local button = Create.textButton({
		Name = tostring(name) .. "Tab",
		Size = UDim2.fromOffset(TAB_WIDTH, 26),
		BackgroundColor3 = palette.SurfaceHigh,
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = self.TabList,
	})
	button.LayoutOrder = #self.Tabs
	Create.corner(button, 5)

	-- Tab icons accept a friendly name / glyph ("combat", "◎", "🎯") that maps
	-- to a drawn icon; anything else is rendered as text so plain labels and
	-- emoji still work.
	local kind = Icons.resolve(icon)
	local hasIcon = kind ~= nil or (type(icon) == "string" and icon ~= "")
	local offset = hasIcon and 26 or 8

	if kind then
		tab.ButtonIcon = Icons.new(kind, button, 15, palette.SubText, 7)
		tab.ButtonIcon.Position = UDim2.fromOffset(7, 5.5)
	elseif hasIcon then
		tab.ButtonIcon = Create.label({
			Name = "Icon",
			Text = icon,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = palette.SubText,
			Position = UDim2.fromOffset(7, 0),
			Size = UDim2.fromOffset(16, 26),
			ZIndex = 7,
			Parent = button,
		})
	end

	local nameLabel = Create.label({
		Name = "Name",
		Text = tostring(name),
		TextSize = 11,
		TextColor3 = palette.SubText,
		Position = UDim2.fromOffset(offset, 0),
		Size = UDim2.new(1, -offset - 4, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
		Parent = button,
	})

	local indicator = Create.new("Frame", {
		Name = "Indicator",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(18, 2),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = button,
	})
	Create.corner(indicator, 1)
	self.Library.ThemeManager:Bind(indicator, "BackgroundColor3", "Primary")

	tab.Button = button
	tab.ButtonLabel = nameLabel
	tab.Indicator = indicator

	self:_track(button.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then
			Tween.play(button, { BackgroundTransparency = 0.7 }, Tween.Info.Fast)
		end
	end))

	self:_track(button.MouseLeave:Connect(function()
		if self.ActiveTab ~= tab then
			Tween.play(button, { BackgroundTransparency = 1 }, Tween.Info.Fast)
		end
	end))

	self:_track(button.Activated:Connect(function()
		self:SelectTab(tab)
	end))

	if #self.Tabs == 1 then
		self:SelectTab(tab, true)
	end

	return tab
end

function Window:_setTabActive(tab, active)
	if tab.Destroyed or not tab.Button or not tab.ButtonLabel or not tab.Indicator then
		return
	end

	local palette = self.Library.Palette
	local info = Tween.Info.Fast

	Tween.play(tab.Button, {
		BackgroundTransparency = active and 0.75 or 1,
		BackgroundColor3 = palette.SurfaceHigh,
	}, info)

	Tween.play(tab.ButtonLabel, {
		TextColor3 = active and palette.Primary or palette.SubText,
	}, info)

	if tab.ButtonIcon then
		local color = active and palette.Primary or palette.SubText

		if Icons.isIcon(tab.ButtonIcon) then
			Icons.setColor(tab.ButtonIcon, color)
		else
			Tween.play(tab.ButtonIcon, { TextColor3 = color }, info)
		end
	end

	Tween.play(tab.Indicator, {
		BackgroundTransparency = active and 0 or 1,
		Size = UDim2.fromOffset(active and 22 or 10, 2),
	}, info)
end

function Window:SelectTab(tab, instant)
	if self.Destroyed or not tab or tab.Destroyed then
		return
	end

	if self.ActiveTab == tab then
		tab:EnsureBuilt()
		return
	end

	local popup = self.Library:GetActivePopup()
	if popup then
		popup:Close()
	end

	local previous = self.ActiveTab
	self.ActiveTab = tab
	tab:EnsureBuilt()

	if previous and previous ~= tab then
		previous.Content.Visible = false
	end

	local content = tab.Content
	content.Visible = true

	-- A plain Frame cannot group-fade, so `Fade` drives the subtree's
	-- transparency. Skip it while the window itself is fading in, otherwise the
	-- two snapshots would capture each other's in-between values.
	if instant or Fade.playing(self.Root) then
		Fade.set(content, 0)
		content.Position = UDim2.fromOffset(0, 0)
	else
		Fade.play(content, 1, 0, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		content.Position = UDim2.fromOffset(0, 8)
		Tween.play(content, { Position = UDim2.fromOffset(0, 0) }, Tween.Info.Smooth)
	end

	for _, other in ipairs(self.Tabs) do
		self:_setTabActive(other, other == tab)
	end

	self:Filter(self.SearchBox.Text)
end

function Window:RegisterSearchEntry(component)
	local keywords = component.Config.Keywords
	if type(keywords) == "string" then
		keywords = { keywords }
	end

	local entry = {
		Component = component,
		Label = component.Name,
		Keywords = keywords,
		Tab = component.Section.Tab,
	}

	table.insert(self.SearchEntries, entry)
	return entry
end

function Window:UnregisterSearchEntry(component)
	for index = #self.SearchEntries, 1, -1 do
		if self.SearchEntries[index].Component == component then
			table.remove(self.SearchEntries, index)
		end
	end
end

function Window:Filter(query)
	if self.Destroyed then
		return
	end

	local rawQuery = tostring(query or "")
	query = string.lower(rawQuery)
	local filtering = #query > 0

	if filtering then
		for _, tab in ipairs(self.Tabs) do
			tab:EnsureBuilt()
		end
	end

	for _, entry in ipairs(self.SearchEntries) do
		local match = true

		if filtering then
			match = string.find(string.lower(entry.Label), query, 1, true) ~= nil

			if not match and entry.Keywords then
				for _, keyword in ipairs(entry.Keywords) do
					if string.find(string.lower(tostring(keyword)), query, 1, true) then
						match = true
						break
					end
				end
			end
		end

		if entry.Component.SearchMatch ~= match then
			entry.Component.SearchMatch = match
			entry.Component:UpdateVisibility()
		end
	end

	for _, tab in ipairs(self.Tabs) do
		tab:UpdateVisibility(filtering, query)
	end

	local active = self.ActiveTab
	if filtering and active and not active.HasContent then
		self.NoResults.Text = 'No settings match "' .. rawQuery .. '"'
		self.NoResults.Visible = true
	else
		self.NoResults.Visible = false
	end
end

function Window:Open(animate)
	if self.Destroyed or self.Visible then
		return
	end

	self.Visible = true
	self:_updateScale()
	self.Root.Visible = true

	if self.Library.Cursor then
		self.Library.Cursor:Refresh()
	end

	if animate == false then
		Fade.set(self.Root, 0)
		self._animScale = 1
		self:_applyScale()
		return
	end

	self._animToken = (self._animToken or 0) + 1
	local token = self._animToken

	Fade.play(self.Root, 1, 0, 0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	self._animScale = 0.96
	self:_applyScale()

	Tween.number(0.96, 1, 0.32, function(value)
		if self.Destroyed or self._animToken ~= token then
			return
		end
		self._animScale = value
		self:_applyScale()
	end, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	self:_playLogoIntro()
	self:_playPetalBurst()
end

function Window:Close(animate)
	if self.Destroyed or not self.Visible then
		return
	end

	self.Visible = false

	if self.Library.Cursor then
		self.Library.Cursor:Refresh()
	end

	-- A hidden, still-focused search box would swallow the toggle keybind.
	if self.SearchBox and self.SearchBox:IsFocused() then
		self.SearchBox:ReleaseFocus()
	end

	local popup = self.Library:GetActivePopup()
	if popup then
		popup:Close()
	end

	self._animToken = (self._animToken or 0) + 1
	local token = self._animToken

	if animate == false then
		self.Root.Visible = false
		Fade.set(self.Root, 0)
		self._animScale = 1
		self:_applyScale()
		return
	end

	Fade.play(self.Root, 0, 1, 0.16)
	Tween.number(1, 0.96, 0.18, function(value)
		if self.Destroyed or self._animToken ~= token then
			return
		end
		self._animScale = value
		self:_applyScale()
	end)

	task.delay(0.24, function()
		if self.Destroyed or self.Visible or self._animToken ~= token then
			return
		end
		self.Root.Visible = false
		Fade.set(self.Root, 0)
		self._animScale = 1
		self:_applyScale()
	end)
end

function Window:Toggle()
	if self.Visible then
		self:Close()
	else
		self:Open()
	end
end

function Window:_playLogoIntro()
	if not self.Logo then
		return
	end

	-- The window's own fade already brings the logo's pixels in; adding a second
	-- nested fade would snapshot the logo mid-transition. Only motion here.
	self.Logo.Rotation = -32
	Tween.play(self.Logo, { Rotation = 0 }, Tween.Info.Glide)
end

function Window:_playPetalBurst()
	local palette = self.Library.Palette
	local colors = { palette.Primary, palette.Accent, palette.Primary }

	for index = 1, 10 do
		local color = colors[(index % #colors) + 1]
		local petal = Logo.Petal(color, 6 + math.random() * 4)
		petal.Parent = self.Root
		petal.Position = UDim2.fromOffset(26, 22)
		petal.Rotation = math.random(0, 360)

		local angle = (index / 10) * math.pi * 2 + math.random() * 0.35
		local distance = 40 + math.random() * 55
		local targetX = 26 + math.cos(angle) * distance
		local targetY = 22 + math.sin(angle) * distance

		Tween.play(petal, {
			Position = UDim2.fromOffset(targetX, targetY),
			Rotation = petal.Rotation + math.random(-160, 160),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 3),
		}, Tween.Info.Glide)

		task.delay(0.5, function()
			if petal and petal.Parent then
				petal:Destroy()
			end
		end)
	end
end

function Window:_updateThemeDots()
	if not self._themeDots then
		return
	end

	local active = self.Library.ThemeManager.Name

	for name, dot in pairs(self._themeDots) do
		local isActive = name == active
		Tween.play(dot.Button, {
			Size = UDim2.fromOffset(isActive and 13 or 10, isActive and 13 or 10),
			BackgroundTransparency = isActive and 0 or 0.35,
		}, Tween.Info.Fast)
		dot.Stroke.Transparency = isActive and 0.15 or 1
	end
end

function Window:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Visible = false

	local popup = self.Library:GetActivePopup()
	if popup then
		popup:Close()
	end

	self.Library.Windows[self] = nil
	if self.Library.PrimaryWindow == self then
		self.Library.PrimaryWindow = nil
	end

	if self.SearchBox and self.SearchBox:IsFocused() then
		self.SearchBox:ReleaseFocus()
	end

	-- Snapshot: each tab removes itself from self.Tabs.
	local tabs = table.clone(self.Tabs)
	for _, tab in ipairs(tabs) do
		tab:Destroy()
	end
	table.clear(self.Tabs)
	table.clear(self.SearchEntries)

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)

	self.Root:Destroy()
end

--[[
	Naming alias: plenty of UI libraries call this `CreateTab`, and a missing
	method means the caller's whole script dies on the next line — leaving an
	empty window with no explanation. Both spellings do the same thing.
]]
Window.CreateTab = Window.AddTab

return Window
