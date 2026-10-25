--[[
	Cherry UI — a high-performance, cherry-picked UI library for Roblox FPS games.

	Usage (from a LocalScript):

		local CherryUI = require(ReplicatedStorage.CherryUI)
		local window = CherryUI:CreateWindow({ Title = "Cherry" })
		local tab = window:AddTab("Combat", "◎")
		tab:AddSection("Aimbot"):AddToggle({ Name = "Enable Aimbot" })

	The module deliberately owns a single ScreenGui (created on first use), one
	Heartbeat scheduler and one theme manager, no matter how many windows the
	user creates.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Utils.Create)
local Signal = require(script.Utils.Signal)
local Scheduler = require(script.Utils.Scheduler)
local Util = require(script.Utils.Util)
local ConfigManager = require(script.Utils.Config)
local ThemeManager = require(script.Core.ThemeManager)
local Notification = require(script.Components.Notification)
local Window = require(script.Components.Window)

local Themes = {
	Crimson = require(script.Themes.Crimson),
	Pink = require(script.Themes.Pink),
	Purple = require(script.Themes.Purple),
	Green = require(script.Themes.Green),
	Blue = require(script.Themes.Blue),
}

local THEME_ORDER = { "Crimson", "Pink", "Purple", "Green", "Blue" }
local DEFAULT_THEME = "Crimson"

local Library = {}
Library.__index = Library

function Library.new()
	local self = setmetatable({}, Library)

	self.Version = "1.0.0"
	self.Themes = Themes
	self.ThemeOrder = THEME_ORDER
	self.Windows = {}
	self.ToggleKey = Enum.KeyCode.RightShift
	self.ToggleKeyChanged = Signal.new()
	self.Capturing = false
	self.ActivePopup = nil
	self.ScreenGui = nil
	self.Overlay = nil
	self.Notifier = nil
	self.PrimaryWindow = nil
	self.Destroyed = false

	self.ThemeManager = ThemeManager.new(Themes, DEFAULT_THEME)
	self.Palette = self.ThemeManager.Palette
	self.Scheduler = Scheduler.new(30)
	self.Config = ConfigManager.new(self)

	self:_bindInput()

	return self
end

-- Applies a palette token now and keeps the instance in sync on theme changes.
function Library:Styled(instance, token, property)
	return self.ThemeManager:Bind(instance, property, token)
end

function Library:_bindInput()
	self._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or self.Capturing then
			return
		end

		if UserInputService:GetFocusedTextBox() then
			return
		end

		if Util.matchesInput(input, self.ToggleKey) then
			self:ToggleUI()
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape and self.ActivePopup then
			self.ActivePopup:Close()
		end
	end)
end

function Library:_ensureScreen()
	if self.ScreenGui and self.ScreenGui.Parent then
		return self.ScreenGui
	end

	if not RunService:IsClient() then
		warn("[CherryUI] Cherry UI builds its interface on the client; require it from a LocalScript.")
		return nil
	end

	local player = Players.LocalPlayer
	if not player then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		player = Players.LocalPlayer
	end

	if not player then
		warn("[CherryUI] Cherry UI must be created on the client (no LocalPlayer found).")
		return nil
	end

	local screenGui = Create.new("ScreenGui", {
		Name = "CherryUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Respect device safe areas / the topbar on modern clients.
	pcall(function()
		screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)

	self.ScreenGui = screenGui

	self.Overlay = Create.new("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 500,
		Parent = screenGui,
	})

	self.Notifier = Notification.new(self)

	return screenGui
end

function Library:CreateWindow(config)
	if self.Destroyed then
		return nil
	end

	config = config or {}

	if typeof(config.ToggleKey) == "EnumItem" then
		self:SetToggleKey(config.ToggleKey)
	end

	self:_ensureScreen()
	if not self.ScreenGui then
		return nil
	end

	local window = Window.new(self, config)
	self.Windows[window] = true

	if not self.PrimaryWindow then
		self.PrimaryWindow = window
	end

	return window
end

function Library:GetPrimaryWindow()
	return self.PrimaryWindow
end

function Library:Notify(config)
	if self.Destroyed then
		return nil
	end

	self:_ensureScreen()
	if not self.Notifier then
		return nil
	end

	return self.Notifier:Show(config)
end

function Library:GetThemeNames()
	local names = {}
	for _, name in ipairs(self.ThemeOrder) do
		if self.Themes[name] then
			table.insert(names, name)
		end
	end
	return names
end

function Library:SetTheme(name, animate)
	if self.Destroyed then
		return false
	end

	if self.ThemeManager:SetTheme(name, animate ~= false) then
		self.Palette = self.ThemeManager.Palette
		self.Config:MarkDirty()
		return true
	end

	return false
end

function Library:SetToggleKey(key)
	if typeof(key) ~= "EnumItem" or self.ToggleKey == key then
		return
	end

	self.ToggleKey = key
	self.Config:MarkDirty()
	self.ToggleKeyChanged:Fire(key)
end

function Library:OnToggleKeyChanged(callback)
	return self.ToggleKeyChanged:Connect(callback)
end

function Library:ToggleUI()
	local window = self.PrimaryWindow
	if window and not window.Destroyed then
		window:Toggle()
	end
end

function Library:SetActivePopup(popup)
	local previous = self.ActivePopup

	if previous and previous ~= popup then
		self.ActivePopup = nil
		previous:Close()
	end

	self.ActivePopup = popup
end

function Library:GetActivePopup()
	return self.ActivePopup
end

function Library:RefreshVisibility()
	for _, component in ipairs(self.Config.Components) do
		if not component.Destroyed then
			component:UpdateVisibility()
		end
	end

	for window in self.Windows do
		if not window.Destroyed then
			window:Filter(window.SearchBox.Text)
		end
	end
end

function Library:_buildAllTabs()
	for window in self.Windows do
		if not window.Destroyed then
			for _, tab in ipairs(window.Tabs) do
				tab:EnsureBuilt()
			end
		end
	end
end

function Library:SaveConfig()
	-- Register lazy tabs first so their values are included in the snapshot.
	self:_buildAllTabs()
	return self.Config:Save()
end

function Library:LoadConfig()
	self:_buildAllTabs()
	return self.Config:Load()
end

function Library:ResetConfig()
	self:_buildAllTabs()
	return self.Config:Reset()
end

function Library:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	local windows = {}
	for window in self.Windows do
		table.insert(windows, window)
	end
	for index = 1, #windows do
		windows[index]:Destroy()
	end
	table.clear(self.Windows)

	if self.Notifier then
		self.Notifier:Destroy()
		self.Notifier = nil
	end

	if self._inputConnection then
		self._inputConnection:Disconnect()
		self._inputConnection = nil
	end

	self.Scheduler:Destroy()
	self.ThemeManager:Destroy()
	self.Config:Destroy()
	self.ToggleKeyChanged:Destroy()

	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end

	self.Overlay = nil
	self.PrimaryWindow = nil
end

return Library.new()
