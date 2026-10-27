--[[
	Components/PlayerList.lua
	Live player list with quick actions.

	Rows are pooled and only rebuilt when the player set changes. The list
	refreshes once per second through the scheduler (and immediately on join /
	leave), so health stays current without per-frame polling.

	Teleporting needs server authority, so it is opt-in:
		list:SetAction("teleport", function(player) ... end)
]]

local Players = game:GetService("Players")

local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)
local Icons = require(script.Parent.Parent.Utils.Icons)
local Pool = require(script.Parent.Parent.Utils.Pool)
local Util = require(script.Parent.Parent.Utils.Util)

local PlayerList = {}
PlayerList.__index = PlayerList

local ROW_HEIGHT = 36

function PlayerList.new(library, parent, config)
	config = config or {}

	local self = setmetatable({}, PlayerList)

	self.Library = library
	self.Height = config.Height or 280
	self.Filter = ""
	self.Destroyed = false
	self.Rows = {}
	self._connections = {}
	self.Actions = {
		teleport = config.OnTeleport,
		-- Spectate and copy work out of the box; teleport needs server authority.
		spectate = config.OnSpectate or function(player)
			self:_spectate(player)
		end,
		copy = config.OnCopy or function(player)
			self:_copy(player)
		end,
	}

	local palette = library.Palette

	self.Frame = Create.new("Frame", {
		Name = "PlayerList",
		Size = UDim2.new(1, 0, 0, self.Height),
		BackgroundTransparency = 0.08,
		Parent = parent,
	})
	library:Styled(self.Frame, "Surface", "BackgroundColor3")
	Create.corner(self.Frame, 10)
	library:Styled(Create.stroke(self.Frame, palette.Outline, 1, 0.4), "Outline", "Color")

	self.Title = Create.label({
		Name = "Title",
		Text = "Players",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(56, 16),
		Parent = self.Frame,
	})
	library:Styled(self.Title, "Text", "TextColor3")

	self.CountLabel = Create.label({
		Name = "Count",
		Text = "(0)",
		TextSize = 10,
		Position = UDim2.fromOffset(70, 9),
		Size = UDim2.fromOffset(40, 16),
		Parent = self.Frame,
	})
	library:Styled(self.CountLabel, "Placeholder", "TextColor3")

	self.SearchFrame = Create.new("Frame", {
		Name = "SearchFrame",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -42, 0, 8),
		Size = UDim2.fromOffset(140, 22),
		BackgroundTransparency = 0.2,
		Parent = self.Frame,
	})
	Create.corner(self.SearchFrame, 6)
	library:Styled(self.SearchFrame, "Background", "BackgroundColor3")
	library:Styled(Create.stroke(self.SearchFrame, palette.Outline, 1, 0.5), "Outline", "Color")

	self.SearchBox = Create.new("TextBox", {
		Name = "Search",
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -12, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Filter players",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = self.SearchFrame,
	})
	library:Styled(self.SearchBox, "Text", "TextColor3")
	library:Styled(self.SearchBox, "Placeholder", "PlaceholderColor3")

	self.RefreshButton = Create.textButton({
		Name = "Refresh",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(24, 22),
		Parent = self.Frame,
	})
	Create.corner(self.RefreshButton, 5)

	self.RefreshIcon = Icons.new("refresh", self.RefreshButton, 13, palette.SubText, 2)
	self.RefreshIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	self.RefreshIcon.Position = UDim2.fromScale(0.5, 0.5)
	Icons.bindTheme(self.RefreshIcon, library, "SubText")

	self.RefreshButton.MouseEnter:Connect(function()
		Icons.setColor(self.RefreshIcon, self.Library.Palette.Primary)
		Tween.play(self.RefreshButton, {
			BackgroundTransparency = 0.75,
			BackgroundColor3 = self.Library.Palette.SurfaceHigh,
		}, Tween.Info.Fast)
	end)

	self.RefreshButton.MouseLeave:Connect(function()
		Icons.setColor(self.RefreshIcon, self.Library.Palette.SubText)
		Tween.play(self.RefreshButton, { BackgroundTransparency = 1 }, Tween.Info.Fast)
	end)

	self.List = Create.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(10, 38),
		Size = UDim2.new(1, -20, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.35,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Parent = self.Frame,
	})
	Create.padding(self.List, 0, 4, 0, 0)
	Create.list(self.List, 3)
	library:Styled(self.List, "Outline", "ScrollBarImageColor3")

	self.Pool = Pool.new(function()
		return self:_createRow()
	end, function(row)
		row:SetAttribute("PlayerName", nil)
		row.Visible = true
	end, 8)

	table.insert(self._connections, self.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self.Filter = self.SearchBox.Text or ""
		self:Refresh()
	end))

	table.insert(self._connections, self.RefreshButton.Activated:Connect(function()
		self:Refresh()
	end))

	table.insert(self._connections, Players.PlayerAdded:Connect(function()
		self:Refresh()
	end))

	table.insert(self._connections, Players.PlayerRemoving:Connect(function()
		self:Refresh()
	end))

	table.insert(self._connections, library.ThemeManager.Changed:Connect(function()
		self:Refresh()
	end))

	self._task = library.Scheduler:Every(1, function()
		if not self.Frame or not self.Frame.Visible then
			return
		end

		local content = self.Frame.Parent and self.Frame.Parent.Parent
		if not content or not content.Visible then
			return
		end

		local main = content.Parent
		local root = main and main.Parent and main.Parent.Parent
		if root and root.Visible == false then
			return
		end

		self:Refresh()
	end)

	self:Refresh()

	return self
end

function PlayerList:_createRow()
	local library = self.Library
	local palette = library.Palette

	local row = Create.new("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = palette.SurfaceHigh,
		BackgroundTransparency = 0.7,
		Parent = nil,
	})
	Create.corner(row, 6)
	library:Styled(row, "SurfaceHigh", "BackgroundColor3")

	local avatar = Create.new("ImageLabel", {
		Name = "Avatar",
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = palette.Surface,
		BackgroundTransparency = 0.2,
		Image = "rbxthumb://type=AvatarHeadShot&id=1&w=48&h=48",
		ScaleType = Enum.ScaleType.Crop,
		Parent = row,
	})
	Create.corner(avatar, UDim.new(1, 0))
	library:Styled(avatar, "Surface", "BackgroundColor3")

	local name = Create.label({
		Name = "PlayerName",
		Text = "",
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(38, 4),
		Size = UDim2.new(1, -150, 0, 14),
		Parent = row,
	})
	library:Styled(name, "Text", "TextColor3")

	local status = Create.label({
		Name = "Status",
		Text = "",
		TextSize = 10,
		Position = UDim2.fromOffset(38, 19),
		Size = UDim2.new(1, -150, 0, 12),
		Parent = row,
	})
	library:Styled(status, "SubText", "TextColor3")

	local actions = {
		{ Name = "teleport", Label = "TP", Offset = 10, Color = "Primary" },
		{ Name = "spectate", Icon = "eye", Offset = 38 },
		{ Name = "copy", Icon = "copy", Offset = 66 },
	}

	local buttons = {}

	for _, action in ipairs(actions) do
		local button = Create.textButton({
			Name = action.Name,
			Text = action.Label or "",
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -action.Offset, 0.5, 0),
			Size = UDim2.fromOffset(24, 22),
			Parent = row,
		})
		Create.corner(button, 4)
		library:Styled(button, "SubText", "TextColor3")

		local icon = action.Icon and Icons.new(action.Icon, button, 13, palette.SubText, 2)
		if icon then
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.5)
		end

		button.Activated:Connect(function()
			local playerName = row:GetAttribute("PlayerName")
			local player = playerName and Players:FindFirstChild(playerName)
			if player then
				self:_runAction(action.Name, player)
			end
		end)

		button.MouseEnter:Connect(function()
			button.TextColor3 = self.Library.Palette.Primary
			button.BackgroundTransparency = 0.75
			button.BackgroundColor3 = self.Library.Palette.Surface
			if icon then
				Icons.setColor(icon, self.Library.Palette.Primary)
			end
		end)

		button.MouseLeave:Connect(function()
			button.TextColor3 = self.Library.Palette.SubText
			button.BackgroundTransparency = 1
			if icon then
				Icons.setColor(icon, self.Library.Palette.SubText)
			end
		end)

		buttons[action.Name] = button
	end

	row.MouseEnter:Connect(function()
		Tween.play(row, { BackgroundTransparency = 0.5 }, Tween.Info.Fast)
	end)

	row.MouseLeave:Connect(function()
		Tween.play(row, { BackgroundTransparency = 0.7 }, Tween.Info.Fast)
	end)

	return row
end

function PlayerList:_renderRow(row, player)
	local palette = self.Library.Palette
	local avatar = row:FindFirstChild("Avatar")
	local nameLabel = row:FindFirstChild("PlayerName")
	local statusLabel = row:FindFirstChild("Status")

	if avatar then
		local url = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", player.UserId)
		-- Avoid re-requesting the same thumbnail every refresh tick.
		if avatar.Image ~= url then
			avatar.Image = url
		end
	end

	local localPlayer = Players.LocalPlayer
	if nameLabel then
		nameLabel.Text = player.Name .. (player == localPlayer and "  (you)" or "")
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if statusLabel then
		if humanoid and humanoid.Health > 0 then
			statusLabel.Text = string.format("Alive · %d HP", math.floor(humanoid.Health))
			statusLabel.TextColor3 = palette.Success
		elseif character then
			statusLabel.Text = "Dead"
			statusLabel.TextColor3 = palette.Danger
		else
			statusLabel.Text = "Loading..."
			statusLabel.TextColor3 = palette.SubText
		end
	end
end

function PlayerList:_runAction(name, player)
	local handler = self.Actions[name]

	if type(handler) ~= "function" then
		self.Library:Notify({
			Title = "Action unavailable",
			Content = "Set a handler with PlayerList:SetAction('" .. name .. "', fn).",
			Type = "warning",
		})
		return
	end

	local ok, err = pcall(handler, player)
	if not ok then
		warn("[CherryUI] Player action '" .. name .. "' failed: " .. tostring(err))
	end
end

function PlayerList:SetAction(name, callback)
	self.Actions[name] = callback
	return self
end

function PlayerList:Refresh()
	if self.Destroyed then
		return
	end

	local players = Players:GetPlayers()
	local localPlayer = Players.LocalPlayer

	table.sort(players, function(a, b)
		if a == b then
			return false
		end
		if a == localPlayer then
			return true
		elseif b == localPlayer then
			return false
		end

		local aName, bName = string.lower(a.Name), string.lower(b.Name)
		if aName == bName then
			return a.UserId < b.UserId
		end
		return aName < bName
	end)

	local filter = string.lower(self.Filter)
	local seen = {}
	local shown = 0

	for _, player in ipairs(players) do
		local matches = filter == "" or string.find(string.lower(player.Name), filter, 1, true) ~= nil
		if matches then
			shown += 1

			local row = self.Rows[player]
			if not row then
				row = self.Pool:Get(self.List)
				self.Rows[player] = row
			end

			row:SetAttribute("PlayerName", player.Name)
			row.LayoutOrder = shown
			row.Visible = true
			self:_renderRow(row, player)

			seen[player] = true
		end
	end

	for player, row in pairs(self.Rows) do
		if not seen[player] then
			self.Rows[player] = nil
			self.Pool:Release(row)
		end
	end

	self.CountLabel.Text = "(" .. tostring(shown) .. ")"
end

function PlayerList:_spectate(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		self.Library:Notify({
			Title = "Can't spectate",
			Content = player.Name .. " has no character right now.",
			Type = "warning",
		})
		return
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end

	self.Library:Notify({
		Title = "Spectating",
		Content = player.Name,
		Type = "info",
	})
end

function PlayerList:_copy(player)
	local copied = Util.copy(player.Name)

	self.Library:Notify({
		Title = copied and "Copied username" or "Clipboard unavailable",
		Content = copied and player.Name or ("Copy manually: " .. player.Name),
		Type = copied and "success" or "warning",
	})
end

function PlayerList:Destroy()
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

	table.clear(self.Rows)

	if self.Pool then
		self.Pool:Destroy()
		self.Pool = nil
	end

	self.Frame:Destroy()
end

return PlayerList
