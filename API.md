# Cherry UI — Function Reference

Complete API for **Cherry UI v1.0.0**. Every function, config key and signal the library exposes, with runnable snippets.

> Looking for install steps instead? See [setup.md](setup.md) for Roblox Studio, [EXECUTORS.md](EXECUTORS.md) for `loadstring`/executor use, and [README.md](README.md) for the overview.

---

## Contents

1. [Loading the library](#1-loading-the-library)
2. [CherryUI object](#2-cherryui-object)
3. [Window](#3-window)
4. [Tab](#4-tab)
5. [Section](#5-section)
6. [Controls (shared behavior)](#6-controls-shared-behavior)
   - [Toggle](#toggle) · [Button](#button) · [Slider](#slider) · [Dropdown](#dropdown) · [TextBox](#textbox) · [Keybind](#keybind) · [ColorPicker](#colorpicker) · [Label](#label)
7. [ESP Preview](#7-esp-preview)
8. [Player List](#8-player-list)
9. [Notifications](#9-notifications)
10. [Themes](#10-themes)
11. [Config saving & loading](#11-config-saving--loading)
12. [Cherry cursor](#12-cherry-cursor)
13. [Icons](#13-icons)
14. [Utility modules](#14-utility-modules)
15. [Search & dependency boxes](#15-search--dependency-boxes)
16. [Full example](#16-full-example)
17. [Quick troubleshooting](#17-quick-troubleshooting)

---

## 1. Loading the library

**LocalScript (Rojo / model in `ReplicatedStorage`):**

```lua
local CherryUI = require(game:GetService("ReplicatedStorage"):WaitForChild("CherryUI"))
```

**Executor:** paste `dist/CherryUI.lua` first, then use the global it publishes:

```lua
local CherryUI = getgenv().CherryUI     -- set by dist/CherryUI.lua
```

`CherryUI` is a **singleton**: requiring it twice returns the same instance, and every window shares one `ScreenGui`, one scheduler, one theme manager and one notification stack.

---

## 2. CherryUI object

| Member | Signature | Notes |
| --- | --- | --- |
| `CreateWindow` | `(config) -> Window` | First window becomes the *primary* window (the one the keybind toggles). |
| `GetPrimaryWindow` | `() -> Window?` | |
| `Notify` | `(config) -> { Id, Dismiss() }` | See [Notifications](#9-notifications). |
| `ToggleUI` | `()` | Toggle the primary window. Call this from your own keybind if you need one. |
| `SetToggleKey` | `(key: EnumItem)` | Accepts a `KeyCode` or a `UserInputType` (e.g. `Enum.UserInputType.MouseButton2`). |
| `ToggleKey` | `EnumItem` | Default `Enum.KeyCode.RightShift`. |
| `OnToggleKeyChanged` | `(callback) -> Connection` | Fires with the new key. |
| `SetTheme` | `(name: string, animate: boolean?) -> boolean` | See [Themes](#10-themes). |
| `GetThemeNames` | `() -> { string }` | |
| `Themes` | `{ [name]: Palette }` | Raw palette tables. |
| `Palette` | `Palette` | Active palette (`Background`, `Surface`, `Primary`, `Text`, …). |
| `SetCursorMode` | `(mode: "always" \| "menu" \| "off") -> boolean` | See [Cherry cursor](#12-cherry-cursor). |
| `GetCursorMode` | `() -> string` | |
| `ResetCursor` | `() -> boolean` | Shorthand for `SetCursorMode("off")`. |
| `Config` | `ConfigManager` | See [Config saving](#11-config-saving--loading). |
| `SaveConfig` | `() -> boolean` | Builds lazy tabs first, then saves. |
| `LoadConfig` | `() -> boolean` | |
| `ResetConfig` | `() -> boolean` | Restores every control's `Default`. |
| `RefreshVisibility` | `()` | Re-evaluates dependency boxes and search filtering. |
| `Styled` | `(instance, token, property)` | Binds one instance property to a palette token. |
| `SetCapturing` | `(capturing: boolean)` | Advanced: marks keybind capture active (the menu keybind pauses while `true`). |
| `Version` | `"1.0.0"` | |
| `Destroy` | `()` | Tears down every window, notification, connection and the `ScreenGui`. |

```lua
CherryUI:SetTheme("Purple")
CherryUI:SetToggleKey(Enum.KeyCode.Insert)
CherryUI:SetCursorMode("menu")
```

### Menu keybind behavior

* Default: **RightShift**.
* The toggle key is handled **before** the `gameProcessed` filter and is **not** blocked by focused TextBoxes (the settings search box included) — a menu key must always work.
* While a [Keybind](#keybind) control is capturing a key, the menu toggle pauses. If a capture is abandoned (window closed, focus stolen) it times out after 5 seconds.

---

## 3. Window

```lua
local window = CherryUI:CreateWindow({
	Title      = "Cherry",
	Subtitle   = "FPS Suite · v1.0.0",
	Size       = UDim2.fromOffset(640, 460),   -- or Width / Height numbers
	Width      = 640,
	Height     = 460,
	MinWidth   = 480,
	MinHeight  = 300,
	Resizable  = true,                          -- false hides all three grips
	StartOpen  = true,                          -- false = hidden until toggled
	ToggleKey  = Enum.KeyCode.RightShift,       -- overrides CherryUI.ToggleKey
	Cursor     = "always",                      -- "always" | "menu" | "off"
})
```

| Method | Signature | Notes |
| --- | --- | --- |
| `AddTab` | `(name, icon?, builder?) -> Tab` | `icon` accepts a friendly name (`"target"`, `"layers"`, `"players"`, `"settings"`) or any glyph/emoji. `builder` is called **once**, the first time the tab is opened (lazy loading). `window:AddTab("Combat", function(tab) end)` also works. |
| `SelectTab` | `(tab, instant?)` | |
| `Open` / `Close` | `(animate?)` | `false` skips the fade. |
| `Toggle` | `()` | |
| `Filter` | `(query: string)` | Powers the search box; call it yourself to drive filtering programmatically. |
| `RegisterSearchEntry` / `UnregisterSearchEntry` | `(component)` | Controls call these automatically. |
| `Destroy` | `()` | |

**Properties:** `Title`, `Subtitle`, `Width`, `Height`, `MinWidth`, `MinHeight`, `Resizable`, `Visible`, `Tabs`, `ActiveTab`, `Root`, `Frame`, `Content`, `SearchBox`, `Destroyed`.

**Interaction:** drag the header bar; resize with the bottom-right grip, the right edge or the bottom edge (all three), or double-click-free. Windows are clamped into the viewport and scale down automatically on small screens (`UIScale` + `CoreUISafeInsets`).

---

## 4. Tab

```lua
local tab = window:AddTab("Combat", "target", function(page)
	local section = page:AddSection("Aimbot")
	section:AddToggle({ Name = "Enable Aimbot" })
end)
```

| Method | Signature | Notes |
| --- | --- | --- |
| `AddSection` | `(name, config?) -> Section` | Builds immediately (use the `AddTab` builder for lazy behaviour). |
| `AddESPPreview` | `(config?) -> ESPPreview` | |
| `AddPlayerList` | `(config?) -> PlayerList` | |
| `Select` | `()` | Activates the tab. |
| `EnsureBuilt` | `() -> Tab` | Runs the builder if it has not run yet. |
| `Destroy` | `()` | Destroys sections, embeds and the tab button. |

**Properties:** `Name`, `Icon`, `Built`, `Sections`, `Embeds`, `Content`, `Scroller`, `Button`, `HasContent`.

> A tab with no `builder` never spends time building anything, so `window:AddTab("Players", "players")` plus `tab:AddPlayerList()` costs nothing until the tab is opened.

---

## 5. Section

A titled card inside a tab that groups controls and collapses itself when every child is hidden (search or dependency boxes).

| Method | Config keys | Returns |
| --- | --- | --- |
| `AddToggle(config)` | `Name`, `Default`, `Height`, `Callback`, `Keywords`, `Id` | [Toggle](#toggle) |
| `AddButton(config)` | `Text`, `Variant`, `Callback`, `Height`, `Keywords` | [Button](#button) |
| `AddSlider(config)` | `Name`, `Min`, `Max`, `Default`, `Step`, `Decimals`, `Suffix`, `Format`, `Callback` | [Slider](#slider) |
| `AddDropdown(config)` | `Name`, `Options`, `Multi`, `Default`, `Placeholder`, `Callback` | [Dropdown](#dropdown) |
| `AddTextBox(config)` | `Name`, `Default`, `Numeric`, `Min`, `Max`, `Placeholder`, `ClearTextOnFocus`, `Width`, `Callback` | [TextBox](#textbox) |
| `AddKeybind(config)` | `Name`, `Default`, `Callback` | [Keybind](#keybind) |
| `AddColorPicker(config)` | `Name`, `Default`, `Callback` | [ColorPicker](#colorpicker) |
| `AddLabel(text, config)` | `TextSize` | `TextLabel` |

```lua
local section = tab:AddSection("Visuals")
section:AddSlider({ Name = "Field of View", Min = 10, Max = 180, Default = 90, Suffix = "°" })
section:AddLabel("Press RightShift to hide the menu.", { TextSize = 11 })
```

---

## 6. Controls (shared behavior)

Every control accepts this config:

| Key | Type | Meaning |
| --- | --- | --- |
| `Name` | `string` | Row label (also used for the search index). |
| `Default` | any | Value applied at construction. |
| `Callback` / `OnChanged` | `(value) -> ()` | Runs on user changes (never on config restore). |
| `Height` | `number` | Row height in pixels (default `34`). |
| `Keywords` | `string \| { string }` | Extra search terms. |
| `Id` | `string` | Explicit config id; otherwise `Kind_Name`. |

Every control exposes:

```lua
control:SetValue(value, silent?)   -- silent = true skips Callback and Changed
control:GetValue()                 -- -> value
control:OnChanged(function(value) end) -> Connection
control:AddDependency(sourceControl, expected?)   -- dependency box
control:SetVisible(boolean)        -- manual hide/show
control:UpdateVisibility()         -- re-evaluate visibility
control:Destroy()                  -- disconnects everything, nils references
```

### Toggle

```lua
local toggle = section:AddToggle({ Name = "Enable Aimbot", Default = false })
toggle:SetValue(true)
print(toggle:GetValue())   --> true
```

Animated switch; `GetValue()` returns a boolean.

### Button

```lua
section:AddButton({ Text = "Apply", Variant = "primary" })            -- "primary" | "secondary" | "danger"
local reset = section:AddButton({ Text = "Reset", Variant = "danger", Callback = function() end })
reset:SetText("Reset all")
reset:SetEnabled(false)    -- dimmed + non-interactive
```

### Slider

```lua
local fov = section:AddSlider({
	Name     = "Field of View",
	Min      = 10,
	Max      = 180,
	Default  = 90,
	Step     = 1,          -- snapping (0 = smooth)
	Decimals = 0,          -- display precision
	Suffix   = "°",
	Format   = nil,        -- function(value) -> string overrides the display entirely
})
fov:SetValue(120)
```

Draggable track with a value readout; precise input via drag and click.

### Dropdown

```lua
local single = section:AddDropdown({
	Name = "Hit Part",
	Options = { "Head", "Torso", "Nearest" },
	Default = "Head",
})
single:SetValue("Torso")
print(single:GetValue())      --> "Torso"

local multi = section:AddDropdown({
	Name = "Flags",
	Options = { "Wall check", "Visible only", "Team check" },
	Multi = true,                 -- GetValue() returns a string array
	Placeholder = "Select flags",
})
multi:SetValue({ "Wall check" })
```

Scrollable option list in a popup, animated checkmarks, `single:Open()` / `single:Close()`.

### TextBox

```lua
local speed = section:AddTextBox({
	Name = "Speed",
	Numeric = true,        -- rejects non-numbers, clamps to Min/Max on commit
	Min = 16, Max = 500,
	Default = 16,
	Placeholder = "16",
	ClearTextOnFocus = false,
	Width = 100,           -- box width in pixels
})
speed:SetValue(90)
```

Committed on focus lost / Enter. `Numeric = false` keeps free text.

### Keybind

```lua
local bind = section:AddKeybind({
	Name = "Menu Keybind",
	Default = Enum.KeyCode.RightShift,
	Callback = function(key) CherryUI:SetToggleKey(key) end,
})
bind:BeginCapture()    -- start listening programmatically
bind:EndCapture()      -- cancel
print(bind:GetValue()) --> Enum.KeyCode.RightShift
```

Click to rebind; Escape cancels. Supports keyboard keys and the three mouse buttons.

### ColorPicker

```lua
local color = section:AddColorPicker({ Name = "ESP Color", Default = Color3.fromRGB(255, 77, 109) })
color:SetValue(Color3.fromRGB(0, 200, 255))
print(color:GetValue())   --> Color3
color:Open() / color:Close()
```

Hue strip + saturation/value square + hex readout. Use it for ESP, aimbot or tracer colors.

### Label

```lua
section:AddLabel("Only works while the master toggle is on.", { TextSize = 11 })
```

Non-interactive wrapped text; destroyed with the section.

---

## 7. ESP Preview

A live preview: a sample character silhouette with highlight, box, tracer and name tag, plus per-feature chips and 30 Hz throttled updates.

```lua
local preview = tab:AddESPPreview({
	Name = "ESP Preview",
	Height = 300,
	Color = Color3.fromRGB(255, 77, 109),
	TargetName = "Player",
})

preview:OnChanged(function(settings)
	-- settings = { Highlight, Box, Tracer, Name, Color, Target }
	applyESP(settings)
end)
```

| Method | Signature | Notes |
| --- | --- | --- |
| `GetSettings` | `() -> { Highlight, Box, Tracer, Name, Color, Target }` | |
| `SetEnabled` | `(key, value, silent?)` | `key` is `"Highlight" \| "Box" \| "Tracer" \| "Name"`. |
| `Toggle` | `(key)` | |
| `SetColor` | `(color: Color3)` | |
| `SetTarget` | `({ Name, Health, MaxHealth, Distance })` | Feed it your current target each frame — the preview throttles internally. |
| `OnChanged` | `(callback) -> Connection` | |
| `Destroy` | `()` | |

The preview is a **preview**: it never renders your real ESP. Read `GetSettings()` inside `OnChanged` and drive your own drawing code.

---

## 8. Player List

```lua
local list = tab:AddPlayerList({
	Height = 340,
	OnTeleport = function(player) print("teleport", player.Name) end,
	OnSpectate = function(player) print("spectate", player.Name) end,   -- optional override
	OnCopy = function(player) print("copy", player.Name) end,           -- optional override
})

list:SetAction("teleport", function(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = hrp.CFrame end
end)
list:Refresh()
```

| Method | Signature |
| --- | --- |
| `SetAction` | `(name: "teleport" \| "spectate" \| "copy", callback)` |
| `Refresh` | `()` — rebuilds rows (also runs on join/leave and once a second) |

Built-in actions: **TP** (needs a handler — teleporting requires server authority), **spectate** (sets `CameraSubject`), **copy** (uses `setclipboard` in executors, shows the name in a notification otherwise). Rows are pooled, show live health, and include a player filter box.

---

## 9. Notifications

```lua
local handle = CherryUI:Notify({
	Title = "Injected",
	Content = "Cherry UI loaded successfully.",
	Type = "success",              -- "info" | "success" | "warning" | "error"
	Duration = 4,                   -- seconds; pause-on-hover
	Icon = "layers",                -- icon name / glyph / emoji / "rbxassetid://…"
	Color = Color3.fromRGB(255, 77, 109),  -- overrides the type accent
})

handle.Dismiss()                    -- dismiss early
print(handle.Id)                    --> 1
```

| Key | Default | Notes |
| --- | --- | --- |
| `Title` | `"Notification"` | |
| `Content` | `""` | Wrapped, 2 lines. |
| `Type` | `"info"` | Drives the accent colour **and** the default icon (info / check circle / warning / error circle). |
| `Duration` | `5` | Minimum `0.1`. The progress bar shrinks in real time. |
| `Icon` | type icon | A drawn [icon](#13-icons) name, a glyph/emoji, or an `rbxassetid://…` image. |
| `Color` | type accent | Overrides the accent. |

Cards slide in from the top right, pause while hovered, close on their `×`, and are **instance-pooled** (a reused card is never re-created). At most 4 are visible at once.

---

## 10. Themes

Built-in: `Crimson` (default), `Pink`, `Purple`, `Green`, `Blue`. Switch at runtime from the dots in the tab bar or in code:

```lua
CherryUI:SetTheme("Purple")
for _, name in ipairs(CherryUI:GetThemeNames()) do print(name) end
```

**Full palette tokens:** `Background`, `Surface`, `SurfaceHigh`, `Primary`, `Accent`, `Text`, `SubText`, `Placeholder`, `Outline`, `Danger`, `Success`, `Warning`.

**Custom theme** — add it to the table before creating windows:

```lua
CherryUI.Themes.Midnight = {
	Name = "Midnight",
	Background = Color3.fromHex("05060A"),
	Surface = Color3.fromHex("0D1018"),
	SurfaceHigh = Color3.fromHex("151A26"),
	Primary = Color3.fromHex("5B8CFF"),
	Accent = Color3.fromHex("8AB0FF"),
	Text = Color3.fromHex("F2F5FF"),
	SubText = Color3.fromHex("9AA3BA"),
	Placeholder = Color3.fromHex("5C6478"),
	Outline = Color3.fromHex("232A3A"),
	Danger = Color3.fromHex("FF5A5A"),
	Success = Color3.fromHex("4FE08C"),
	Warning = Color3.fromHex("FFC46B"),
}
table.insert(CherryUI.ThemeOrder, "Midnight")
CherryUI:SetTheme("Midnight")
```

**ThemeManager** (`CherryUI.ThemeManager`):

| Method | Signature | Notes |
| --- | --- | --- |
| `SetTheme` | `(name, animate?) -> boolean` | |
| `GetColor` | `(token) -> Color3` | |
| `Bind` | `(instance, property, token) -> instance` | Live-updates the property on theme change. |
| `BindGradient` | `(gradient, { tokenA, tokenB })` | Two-token gradient. |
| `BindCustom` | `(callback) -> handle` | |
| `Unbind` | `(handle)` | |
| `Changed` | `Signal` | Fires `(name, palette)`. |

---

## 11. Config saving & loading

Every control registers itself, so saving needs no bookkeeping. The snapshot contains `values` (keyed by config id, e.g. `Toggle_Enable_Aimbot`), `theme`, and `toggleKey`.

```lua
CherryUI.Config:SetMode("file", { Path = "CherryUI/config.json" })   -- executors
CherryUI.Config:EnableAutoSave(30)                                    -- seconds

CherryUI:SaveConfig()
CherryUI:LoadConfig()
CherryUI:ResetConfig()      -- back to every control's Default
```

| Mode | Backend | Options |
| --- | --- | --- |
| `"memory"` | Current session only (default) | — |
| `"file"` | `writefile`/`readfile`/`isfile` | `{ Path = "CherryUI/config.json" }` |
| `"datastore"` | `DataStore:GetAsync/SetAsync` | `{ Store = store, Key = "CherryUI_Config" }` |
| `"custom"` | Your own functions | `{ save = fn, load = fn }` |

```lua
CherryUI.Config:SetMode("custom", {
	save = function(data) myRemote:FireServer(data) end,
	load = function() return myRemote:InvokeServer() end,
})
```

Other members: `Register(component)`, `Unregister(component)`, `MarkDirty()`, `Serialize() -> table`, `Apply(data) -> boolean`, `Memory`, `Mode`, `FilePath`, `DataKey`.

---

## 12. Cherry cursor

The cherry pointer replaces the Roblox cursor the moment the library loads (`"always"` is the default) and needs **no uploaded asset** — it is drawn from `GuiObjects`, so it recolors with the theme and stays sharp at any resolution. It is an arrow (hotspot at the arrow tip) with a cherry badge tucked under the head.

```lua
CherryUI:SetCursorMode("always")   -- default
CherryUI:SetCursorMode("menu")     -- only while a window is open
CherryUI:SetCursorMode("off")      -- leave Roblox's cursor alone
print(CherryUI:GetCursorMode())
```

It hides itself during mouse-lock / first person and returns on unlock. `CherryUI.Cursor` exposes `SetMode`, `GetMode`, `Refresh`, `Destroy`.

---

## 13. Icons

Roblox's fonts have no coverage for the usual "cool symbols" (⌕ ✕ ▾ ✓ ◉ …) — they render as tofu boxes. Cherry UI therefore draws its icons from rounded frames, and you can use the same set.

```lua
local Icons = CherryUI.Icons

local icon = Icons.new("target", someFrame, 20, palette.Primary)
icon.Position = UDim2.fromOffset(8, 8)
Icons.setColor(icon, palette.SubText)
Icons.setTransparency(icon, 0.4)
Icons.setSize(icon, 26, Tween.Info.Fast)   -- animated resize
Icons.bindTheme(icon, CherryUI, "Primary") -- follows theme changes
```

**Kinds:** `target`, `eye`, `layers`, `players`, `settings`, `search`, `close`, `check`, `chevron`, `refresh`, `copy`, `diamond`, `info`, `warning`, `success`, `error`, `cursor`.

**Aliases** (all resolve to the same drawing): `crosshair`/`aim`/`aimbot`/`combat`/`◎`/`🎯` → `target`, `visuals`/`esp`/`render`/`◈` → `layers`, `list`/`people`/`☰`/`👥` → `players`, `config`/`gear`/`⚙` → `settings`, `spectate`/`◉`/`👁` → `eye`, `reload`/`rescan`/`⟳` → `refresh`, `clipboard`/`⧉` → `copy`, `notification`/`◆` → `diamond`, `danger`/`✗` → `error`, plus `search`, `check`, `chevron`, `close`, `cursor`/`arrow`/`pointer`.

`Icons.resolve(name) -> kind?` maps a string to a kind (returns `nil` for emoji/letters, which are rendered as text instead). Low-level builders: `Icons.line`, `Icons.ring`, `Icons.dot`, `Icons.diamond`, `Icons.outline` — all on a 20×20 grid (`Icons.Grid`).

---

## 14. Utility modules

All are reachable from the library table (`CherryUI.Tween`, `CherryUI.Signal`, …) and from `Utils` in the source tree.

| Module | Highlights |
| --- | --- |
| `Tween` | `Tween.Info` presets (`Instant`, `Snap`, `Fast`, `Smooth`, `Glide`, `Spring`), `Tween.play(instance, props, info)`, `Tween.create`, `Tween.number(from, to, duration, callback, style, direction)`, `Tween.linear(duration)`. Failures warn once instead of erroring. |
| `Signal` | `Signal.new()`, `:Connect(fn) -> Connection`, `:Fire(...)`, `:DisconnectAll()`, `:Destroy()`. |
| `Pool` | `Pool.new(create, reset, prewarm)`, `:Get(parent)`, `:Release(instance)`, `:ReleaseAll()`, `:Destroy()`. Used by notifications, dropdown options, player rows and the ESP chips. |
| `Scheduler` | One `Heartbeat` loop for the whole library. `Scheduler:Every(interval, fn) -> task`, `:Remove(task)`, `:Clear()`, `:Destroy()`. 30 Hz by default. |
| `Popup` | `Popup.new(library, { Name, Width, Height, OnClose })`, `:SetSize(w, h)`, `:Open()`, `:Close()`, `:Destroy()`. Used by dropdowns and the color picker. |
| `Fade` | Whole-subtree fades without `CanvasGroup`: `Fade.set(root, alpha)`, `Fade.play(root, from, to, duration, style, direction, onComplete)`, `Fade.playing(root)`, `Fade.invalidate(root)`. |
| `Util` | `clamp`, `round`, `trimNumber`, `keyName(enumItem)`, `matchesInput(input, binding)`, `hex(color)`, `fromHex(text)`, `copy(text)`. |
| `Create` | `new(class, props, children)`, `corner`, `stroke`, `padding`, `list`, `label`, `textButton`, `shadow`. |
| `Icons` | See [Icons](#13-icons). |

---

## 15. Search & dependency boxes

**Search** — the header search box filters every control by name and `Keywords`, hides sections that end up empty, dims tab buttons with no matches, and shows “No settings match …”. Drive it in code with `window:Filter("esp")`; clear it with `window:Filter("")`.

**Dependency boxes** — hide a control until another control has a given value:

```lua
local master = section:AddToggle({ Name = "Enable ESP", Default = false })

section:AddSlider({ Name = "FOV", Min = 10, Max = 180, Default = 90 })
	:AddDependency(master)                     -- visible only while master is true

local mode = section:AddDropdown({ Name = "Mode", Options = { "Box", "Tracer" } })
local thickness = section:AddSlider({ Name = "Thickness", Min = 1, Max = 6 })
thickness:AddDependency(mode, "Tracer")        -- literal value
thickness:AddDependency(master, { "Box", "Tracer" })  -- array = any of these
thickness:AddDependency(other, function(value) return value > 50 end)  -- predicate
```

Hidden rows collapse their height with a tween (no layout pops) and re-expand instantly when the condition becomes true.

---

## 16. Full example

```lua
local CherryUI = require(game:GetService("ReplicatedStorage"):WaitForChild("CherryUI"))

local window = CherryUI:CreateWindow({
	Title = "Cherry",
	Subtitle = "FPS Suite · v" .. CherryUI.Version,
	Size = UDim2.fromOffset(660, 470),
})

local combat = window:AddTab("Combat", "target", function(tab)
	local aim = tab:AddSection("Aimbot")
	local master = aim:AddToggle({ Name = "Enable Aimbot", Default = false })

	aim:AddSlider({ Name = "Field of View", Min = 10, Max = 180, Default = 90, Suffix = "°" })
		:AddDependency(master)
	aim:AddDropdown({ Name = "Hit Part", Options = { "Head", "Torso", "Nearest" }, Default = "Head" })
		:AddDependency(master)
	aim:AddKeybind({
		Name = "Aim Key",
		Default = Enum.KeyCode.E,
		Callback = function(key) print("aim key:", key.Name) end,
	})
end)	local visuals = window:AddTab("Visuals", "layers", function(tab)
	tab:AddSection("Features"):AddToggle({ Name = "Enable ESP", Default = true })

	tab:AddESPPreview({
		Name = "ESP Preview",
		Height = 300,
		Color = Color3.fromRGB(255, 77, 109),
	}):OnChanged(function(settings) print("esp:", settings.Box, settings.Color) end)
end)

local players = window:AddTab("Players", "players")
players:AddPlayerList({ Height = 340 })

local settings = window:AddTab("Settings", "settings", function(tab)
	local section = tab:AddSection("Appearance")
	local theme = section:AddDropdown({
		Name = "Theme",
		Options = CherryUI:GetThemeNames(),
		Default = "Crimson",
	})
	theme:OnChanged(function(name) CherryUI:SetTheme(name) end)

	section:AddButton({ Text = "Save config", Variant = "primary", Callback = function() CherryUI:SaveConfig() end })
	section:AddButton({ Text = "Reset", Variant = "danger", Callback = function() CherryUI:ResetConfig() end })
end)

CherryUI:Notify({
	Title = "Cherry UI " .. CherryUI.Version,
	Content = "Press RightShift to toggle the menu.",
	Type = "success",
	Duration = 6,
})
```

---

## 17. Quick troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| RightShift does nothing | You are running in Studio's **Run** (F8) mode or from a `Script` on the server — Cherry UI is client-only. Use **Play** (F5), a LocalScript in `StarterPlayerScripts`, or an executor. `CherryUI:ToggleUI()` also works from your own keybind. |
| Nothing renders at all | The module builds its `ScreenGui` on the client. Check the output for the `[CherryUI]` warning explaining which case you hit. |
| Icons show as empty squares | That only happens with the old glyph icons. Rebuild the bundle (`python3 tools/bundle.py`) so `dist/CherryUI.lua` matches `src/`. |
| The cursor looks like two cursors | Another script also owns the pointer, or you hid it manually. `CherryUI:ResetCursor()` puts Roblox's back; `SetCursorMode("menu")` avoids conflicts. |
| A control never appears | It has a dependency box that is not satisfied. `control:SetVisible(true)` overrides it, `control:UpdateVisibility()` re-evaluates. |
| Config does not persist | `"memory"` is the default. Use `Config:SetMode("file", { Path = … })` (executor) or `"datastore"`/`"custom"`. |
| Tabs are slow to open | They are lazily built on first open by design. Move heavy work out of the tab builder if you see a hitch. |

---

MIT © Cherry UI contributors — see [LICENSE](LICENSE).
