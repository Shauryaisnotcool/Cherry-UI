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
local Cursor = require(script.Core.Cursor)
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
	self.Cursor = nil
	self.PrimaryWindow = nil
	self.Destroyed = false

	-- The cherry pointer ships on by default: loading the library replaces the
	-- Roblox cursor immediately, even before the first window is created.
	self._cursorMode = "always"

	self.ThemeManager = ThemeManager.new(Themes, DEFAULT_THEME)
	self.Palette = self.ThemeManager.Palette
	self.Scheduler = Scheduler.new(30)
	self.Config = ConfigManager.new(self)

	self:_bindInput()

	-- Build the ScreenGui (and with it the cherry cursor) as soon as the module
	-- runs. Deferred so `require` never yields, and client-only so requiring the
	-- library from server code or Studio's edit mode stays silent.
	task.defer(function()
		if not self.Destroyed and RunService:IsClient() then
			self:_ensureScreen()
		end
	end)

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

--[[
	Picks where the ScreenGui should live.

	Executors expose `gethui()`, which returns a container that draws above the
	game's own interfaces; plain Roblox clients only have PlayerGui. Both are
	client-side, so a LocalScript and an injected script take the same path.
]]
local function resolveGuiParent(player)
	local getHiddenUi = gethui

	if type(getHiddenUi) == "function" then
		local ok, parent = pcall(getHiddenUi)
		if ok and parent then
			return parent
		end
	end

	return player:WaitForChild("PlayerGui")
end

function Library:_ensureScreen()
	if self.ScreenGui and self.ScreenGui.Parent then
		return self.ScreenGui
	end

	if not RunService:IsClient() then
		warn("[CherryUI] Cherry UI builds its interface on the client; require it from a LocalScript (or run it in Studio with Play, not Run).")
		return nil
	end

	-- Never block forever: in Studio's "Run" mode (F8) there is no LocalPlayer and
	-- an unbounded wait would silently swallow the whole script.
	local player = Players.LocalPlayer
	local attempts = 0
	while not player and attempts < 50 do
		task.wait(0.1)
		player = Players.LocalPlayer
		attempts += 1
	end

	if not player then
		warn("[CherryUI] No LocalPlayer: open the place with Play (F5), not Run (F8), or move the script into StarterPlayerScripts.")
		return nil
	end

	local guiProps = {
		Name = "CherryUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	}

	-- Executors sometimes expose a `gethui()` that refuses the parent; falling
	-- back to PlayerGui keeps the library usable instead of erroring there.
	local function buildGui(target)
		local props = table.clone(guiProps)
		props.Parent = target
		return Create.new("ScreenGui", props)
	end

	local ok, screenGui = pcall(buildGui, resolveGuiParent(player))
	if not ok or not screenGui or not screenGui.Parent then
		screenGui = buildGui(player:WaitForChild("PlayerGui"))
	end

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

	self.Cursor = Cursor.new(self)
	self.Notifier = Notification.new(self)

	if self._cursorMode then
		self.Cursor:SetMode(self._cursorMode)
	end

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

	if config.Cursor ~= nil then
		self:SetCursorMode(config.Cursor)
	else
		self:SetCursorMode(self._cursorMode or "always")
	end

	local window = Window.new(self, config)
	self.Windows[window] = true

	if not self.PrimaryWindow then
		self.PrimaryWindow = window

		-- The window opens inside its constructor, before it is the primary one,
		-- so the "menu" cursor needs one more nudge to appear.
		if self.Cursor then
			self.Cursor:Refresh()
		end
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

--[[
	Cursor control: "always" (default) replaces the Roblox pointer as soon as the
	library loads, "menu" draws the cherry only while a Cherry UI window is open,
	and "off" leaves the Roblox cursor untouched.
]]
function Library:SetCursorMode(mode)
	if self.Cursor then
		return self.Cursor:SetMode(mode)
	end

	if not (mode == "always" or mode == "menu" or mode == "off") then
		warn("[CherryUI] Unknown cursor mode: " .. tostring(mode))
		return false
	end

	self._cursorMode = mode
	return true
end

function Library:GetCursorMode()
	if self.Cursor then
		return self.Cursor:GetMode()
	end

	return self._cursorMode or "always"
end

-- Puts Roblox's own pointer back without tearing the interface down. Handy when
-- another script (or a hard script stop) needs the system cursor again.
function Library:ResetCursor()
	return self:SetCursorMode("off")
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

	if self.Cursor then
		self.Cursor:Destroy()
		self.Cursor = nil
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
