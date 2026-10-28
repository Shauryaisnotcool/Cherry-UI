--[[
	Cherry UI — a high-performance, cherry-picked UI library for Roblox FPS games.

	Usage (from a LocalScript):

		local CherryUI = require(ReplicatedStorage.CherryUI)
		local window = CherryUI:CreateWindow({ Title = "Cherry" })
	local tab = window:AddTab("Combat", "target")
	tab:AddSection("Aimbot"):AddToggle({ Name = "Enable Aimbot" })

	The module deliberately owns a single ScreenGui (created on first use), one
	Heartbeat scheduler and one theme manager, no matter how many windows the
	user creates.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Create = require(script.Utils.Create)
local Signal = require(script.Utils.Signal)
local Scheduler = require(script.Utils.Scheduler)
local Util = require(script.Utils.Util)
local Tween = require(script.Utils.Tween)
local Fade = require(script.Utils.Fade)
local Icons = require(script.Utils.Icons)
local Pool = require(script.Utils.Pool)
local Popup = require(script.Utils.Popup)
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

-- Priority 3000 sits above the 2000 a game's own BindAction uses by default, so
-- the menu key wins the key even in a game that binds RightShift itself.
local TOGGLE_ACTION = "CherryUIToggleUI"
local TOGGLE_PRIORITY = 3000

local Library = {}
Library.__index = Library

function Library.new()
	local self = setmetatable({}, Library)

	-- Bumped so a stale bundle is obvious: `print(CherryUI.Version)` should match
	-- the release you loaded.
	self.Version = "1.2.0"

	--[[
		Exposed so scripts built on Cherry UI can reuse the same motion, pooling
		and icon language instead of writing their own:
			CherryUI.Icons.new("target", frame, 18, CherryUI.Palette.Primary)
			CherryUI.Pool.new(create, reset)
			CherryUI.Tween.play(frame, { BackgroundTransparency = 0 }, CherryUI.Tween.Info.Fast)
	]]
	self.Create = Create
	self.Signal = Signal
	self.Tween = Tween
	self.Fade = Fade
	self.Icons = Icons
	self.Pool = Pool
	self.Popup = Popup
	self.Util = Util

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

--[[
	Marks that a Keybind control is waiting for a key. The timestamp lets the
	input handler release a capture that was abandoned (window closed mid-capture,
	focus stolen) instead of leaving the menu toggle dead forever.
]]
function Library:SetCapturing(capturing)
	self.Capturing = capturing and true or false
	self._captureStarted = os.clock()
end

-- How long an unfinished keybind capture may block the menu toggle.
local CAPTURE_TIMEOUT = 5

-- Two toggle paths (ContextActionService + UserInputService) must never fire
-- twice for one physical press, or the menu closes itself in the same frame.
local DOUBLE_PRESS_WINDOW = 0.03
local lastToggleAt = 0

--[[
	One physical key press reaches the library twice: once through
	ContextActionService and once through UserInputService. When both see the
	same `InputObject` the identity check is exact; some clients hand each path
	its own object though, so a 30 ms window catches that duplicate. A person
	cannot press twice inside 30 ms, so no deliberate double tap is lost.
]]
function Library:_togglePressed(input)
	if input ~= nil and self._toggleInput == input then
		return
	end

	local now = os.clock()
	if now - lastToggleAt < DOUBLE_PRESS_WINDOW then
		return
	end

	lastToggleAt = now
	self._toggleInput = input
	self:ToggleUI()
end

--[[
	Binds the toggle key through ContextActionService as well as
	UserInputService.

	UserInputService alone is not enough: when a game binds the same key (or a
	TextBox has focus) the press is either sunk before the library sees it or
	arrives with `gameProcessed` set. ContextActionService is the request to be
	told about the key *first*, at a priority above the usual 2000 a game's own
	`BindAction` uses, so the menu key keeps working in busy games.
]]
function Library:_bindToggleAction()
	if self._toggleAction then
		ContextActionService:UnbindAction(self._toggleAction)
		self._toggleAction = nil
	end

	local key = self.ToggleKey
	if not key then
		return
	end

	self._toggleAction = TOGGLE_ACTION

	local ok = pcall(function()
		ContextActionService:BindActionAtPriority(TOGGLE_ACTION, function(_, inputState, inputObject)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end

			-- A Keybind control is recording: the key belongs to it.
			if self.Capturing and os.clock() - (self._captureStarted or 0) < CAPTURE_TIMEOUT then
				return Enum.ContextActionResult.Pass
			end

			self:_togglePressed(inputObject)
			return Enum.ContextActionResult.Sink
		end, TOGGLE_PRIORITY, false, key)
	end)

	if not ok then
		-- Some executors ship a stripped ContextActionService; the
		-- UserInputService path below still works.
		self._toggleAction = nil
	end
end

function Library:_bindInput()
	self:_bindToggleAction()

	self._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if self.Capturing then
			-- Keybind capture owns the keyboard, but only for a moment: a capture
			-- that never received a key must not swallow the toggle key.
			if os.clock() - (self._captureStarted or 0) < CAPTURE_TIMEOUT then
				return
			end

			self:SetCapturing(false)
		end

		--[[
			The toggle key is checked *before* the gameProcessed bail-out.
			RightShift is a modifier: on some clients it arrives with gameProcessed
			set, and any focused TextBox (the settings search box is a TextBox) used
			to disable the toggle entirely. A menu key must always work, so nothing
			short of an active keybind capture gets to block it.
		]]
		if Util.matchesInput(input, self.ToggleKey) then
			self:_togglePressed(input)
			return
		end

		if gameProcessed then
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

	--[[
		Two live windows stack, and the newer one (usually the accidental one)
		sits on top — which looks exactly like "the menu is empty". Say so instead
		of letting the first window hide behind it.
	]]
	local existing = self.PrimaryWindow
	if existing and not existing.Destroyed then
		warn(string.format(
			"[CherryUI] A second window was created while '%s' is still open. Reuse that one, or call window:Destroy() first.",
			existing.Title
		))
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

-- Shows a notice card in the primary window (handy for reporting an error to a
-- user who never sees the console). See `Window:ShowNotice`.
function Library:ShowNotice(config)
	local window = self.PrimaryWindow

	if not window or window.Destroyed then
		return nil
	end

	return window:ShowNotice(config)
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

--[[
	Replaces the built-in drawn icons with uploaded images, per kind:

		CherryUI:SetIcons({
			target = "rbxassetid://1234567890",
			close  = "rbxassetid://1234567891",
		})

	Call it before creating windows (icons are built with the interface). Use
	white PNGs so ImageColor3 can tint them to the active theme, and
	`CherryUI.Icons.kinds()` for the list of overridable names.
]]
function Library:SetIcons(map)
	if self.Destroyed then
		return 0
	end

	local applied = Icons.setImages(map)

	if applied > 0 then
		self.Config:MarkDirty()
	end

	return applied
end

function Library:SetToggleKey(key)
	if typeof(key) ~= "EnumItem" or self.ToggleKey == key then
		return
	end

	self.ToggleKey = key
	self:_bindToggleAction()
	self.Config:MarkDirty()
	self.ToggleKeyChanged:Fire(key)
end

function Library:OnToggleKeyChanged(callback)
	return self.ToggleKeyChanged:Connect(callback)
end

--[[
	Scans every window for elements that are stuck invisible and restores them.

	A fade that is interrupted half-way, an executor reloading the script, or a
	script that hides a frame by hand and forgets to bring it back can all leave
	text and panels at full transparency. `Diagnose` is the one-liner that puts
them back, and it prints what it did:

		print(CherryUI:Diagnose())
]]
function Library:Diagnose(repair)
	local report = {
		Windows = 0,
		Repaired = 0,
		Details = {},
	}

	for window in self.Windows do
		if not window.Destroyed then
			report.Windows += 1

			local count, details = Fade.reset(window.Root)
			report.Repaired += count

			for index = 1, #details do
				table.insert(report.Details, details[index])
			end

			-- Keep the window's own state honest about what is on screen.
			if window.Visible and not window.Root.Visible then
				window.Visible = false
			end
		end
	end

	if repair == false then
		return report
	end

	if report.Repaired > 0 then
		warn(
			string.format(
				"[CherryUI] Diagnose restored %d invisible propert%s across %d window(s).",
				report.Repaired,
				report.Repaired == 1 and "y" or "ies",
				report.Windows
			)
		)
	else
		print(string.format("[CherryUI] Diagnose: %d window(s) checked, nothing stuck.", report.Windows))
	end

	return report
end

--[[
	Shows or hides the interface. Every live window is treated together: if any
	one of them is on screen the keybind hides them all, otherwise it shows the
	primary window. That is what makes the key feel reliable in scripts that
	create a second window by accident.
]]
function Library:ToggleUI()
	if self.Destroyed then
		return
	end

	local primary = self.PrimaryWindow
	if not primary or primary.Destroyed then
		primary = nil
		for candidate in self.Windows do
			if not candidate.Destroyed then
				primary = candidate
				self.PrimaryWindow = candidate
				break
			end
		end
	end

	local open = false
	for candidate in self.Windows do
		if not candidate.Destroyed and candidate:IsOpen() then
			open = true
			break
		end
	end

	if open then
		for candidate in self.Windows do
			if not candidate.Destroyed then
				candidate:Close()
			end
		end
		return
	end

	if primary and not primary.Destroyed then
		primary:Open()
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

	if self._toggleAction then
		pcall(function()
			ContextActionService:UnbindAction(self._toggleAction)
		end)
		self._toggleAction = nil
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
