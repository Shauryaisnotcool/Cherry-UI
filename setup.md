# Cherry UI — Setup Guide

This guide walks through installing Cherry UI, placing it correctly, and using
the window, controls, themes, notifications, config saving, the ESP preview and
the player list.

---

## 1. Prerequisites

- Roblox Studio with a place open.
- Basic familiarity with LocalScripts and `require`.
- Optional but recommended: [Rojo](https://rojo.space/) (or another `.rbxlx` /
  `.rbxm` sync tool) so `.lua` files become ModuleScripts automatically.

Cherry UI is a **client-side** library. All UI code must run in a LocalScript
(or a ModuleScript required by one) so `Players.LocalPlayer` exists.

---

## 2. Installation

### Option A — Rojo (recommended)

1. Clone or download this repository.
2. From the repository root run:

   ```bash
   rojo serve
   ```

3. In Studio, open the Rojo plugin, connect to `localhost:34872`, and sync.

The included [`default.project.json`](default.project.json) is a `DataModel`
place project (so it can be synced as a place, not just a model) and maps
`src/` to `ReplicatedStorage.CherryUI` as a single ModuleScript with `Core`,
`Components`, `Themes` and `Utils` children. Restart `rojo serve` after
updating the file, then reconnect or resync from the Studio plugin.

Installing the plugin, choosing the right project file and fixing common sync
errors is covered step by step in [RESUME.md](RESUME.md) §2–§3.

### Option B — Manual (no plugins)

1. In `ReplicatedStorage`, create a **ModuleScript** named `CherryUI`.
2. Paste the contents of [`src/init.lua`](src/init.lua).
3. Create four **Folders** inside it: `Core`, `Components`, `Themes`, `Utils`.
4. For every file in `src/Core`, `src/Components`, `src/Themes` and `src/Utils`,
   create a **ModuleScript** named after the file (without `.lua`) inside the
   matching folder, and paste its contents:

   - `Core/Logo.lua` → ModuleScript `Logo`
   - `Core/ThemeManager.lua` → ModuleScript `ThemeManager`
   - `Components/Window.lua` → ModuleScript `Window`
   - `Utils/Create.lua` → ModuleScript `Create`
   - …and so on.

   The requires are relative (`require(script.Utils.Create)`), so the folder
   names and module names must match exactly.

5. Also paste [`src/Example.lua`](src/Example.lua) into a separate LocalScript
   if you want the demo menu (see “Running the demo” below).

6. Verify the tree:

   ```
   ReplicatedStorage
   └── CherryUI (ModuleScript)
       ├── Core (Folder)
       │   ├── Logo (ModuleScript)
       │   ├── Cursor (ModuleScript)
       │   └── ThemeManager (ModuleScript)
       ├── Components (Folder)
       │   ├── Window, Tab, Section, Button, Toggle, Slider,
       │   │   Dropdown, TextBox, Keybind, ColorPicker,
       │   │   Notification, ESPPreview, PlayerList
       ├── Themes (Folder)
       │   └── Crimson, Pink, Purple, Green, Blue
       └── Utils (Folder)
           └── Base, Config, Create, Fade, Pool, Popup,
               Scheduler, Signal, Tween, Util
   ```

### Option C — Release model

Download `CherryUI.rbxm` from the GitHub releases page and drop it into
`ReplicatedStorage`. The model contains the same ModuleScript tree.

To build it yourself from source: `rojo build model.project.json -o CherryUI.rbxm`
(see [RESUME.md](RESUME.md) §5.6).

### Option D — Lua executors (single file)

Executors cannot `require` a ModuleScript tree, so use the pre-built bundle:
[`dist/CherryUI.lua`](dist/CherryUI.lua). It inlines every module, needs no
`script` object, and returns the library table.

1. Paste the whole of `dist/CherryUI.lua` into your executor, or load it:

   ```lua
   local CherryUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/Cherry-UI/main/dist/CherryUI.lua"))()
   ```

2. Build your menu below it (or in a second script — the bundle publishes
   itself on `getgenv().CherryUI`):

   ```lua
   local CherryUI = getgenv().CherryUI

   local Window = CherryUI:CreateWindow({ Title = "Cherry", Subtitle = "FPS Suite" })
   Window:AddTab("Combat", "target", function(tab)
       tab:AddSection("Aimbot"):AddToggle({ Name = "Enable Aimbot" })
   end)
   ```

3. Rebuild the bundle after editing `src/`:

   ```bash
   python3 tools/bundle.py
   ```

The bundle picks the best GUI parent automatically (`gethui()` when the executor
exposes it, otherwise `PlayerGui`). [`src/Example.lua`](src/Example.lua) detects
all three install styles, so it can be pasted below the bundle unchanged.

---

### Running the demo

[`src/Example.lua`](src/Example.lua) is a full FPS menu, but it syncs as a
ModuleScript and will not run by itself. Paste its contents into a
**LocalScript** under `StarterPlayer/StarterPlayerScripts`, then press Play.
It expects the library at `ReplicatedStorage.CherryUI` and looks for an
optional `TeleportRequest` RemoteEvent.

---

## 3. Basic usage

Create a **LocalScript** in `StarterPlayer/StarterPlayerScripts`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CherryUI = require(ReplicatedStorage:WaitForChild("CherryUI"))

local Window = CherryUI:CreateWindow({
    Title = "Cherry",
    Subtitle = "FPS Suite",
})

local Tab = Window:AddTab("Combat", "target")
local Section = Tab:AddSection("Aimbot")

Section:AddToggle({
    Name = "Enable Aimbot",
    Default = false,
    Callback = function(enabled)
        print("Aimbot:", enabled)
    end,
})

Section:AddSlider({
    Name = "Field of View",
    Min = 10,
    Max = 360,
    Default = 90,
    Suffix = "°",
})
```

The menu opens immediately (set `StartOpen = false` to keep it hidden) and is
toggled with **RightShift**.

### Cursor

Loading Cherry UI replaces Roblox's pointer with a code-drawn cherry as soon as
the library is required (or pasted). It needs no uploaded image, recolors with
the theme and is hidden automatically under shift-lock / first person.

```lua
CherryUI:SetCursorMode("always")   -- default: cherry everywhere outside shift-lock
CherryUI:SetCursorMode("menu")     -- only while a window is open
CherryUI:SetCursorMode("off")      -- restore the Roblox cursor
CherryUI:GetCursorMode()           -- "always" | "menu" | "off"
```

The mode can also be set per window:
`CherryUI:CreateWindow({ Cursor = "menu" })`. Roblox's own cursor is restored on
`CherryUI:Destroy()`.

### Resizing

The window is draggable from its header and resizable from the bottom-right
grip (both axes), the right edge (width) and the bottom edge (height). Sizes are
clamped to the viewport and to `MinWidth` / `MinHeight` (480 × 300 by default):

```lua
CherryUI:CreateWindow({
    Size = UDim2.fromOffset(640, 460),
    MinWidth = 520,
    MinHeight = 360,
    Resizable = true,          -- false hides all three grips
})
```

### Tabs

Tabs can be built eagerly:

```lua
local visuals = Window:AddTab("Visuals", "layers")
visuals:AddSection("Player ESP"):AddToggle({ Name = "Enabled" })
```

…or lazily, so the heavy content is only constructed the first time the tab is
opened:

```lua
Window:AddTab("Visuals", "layers", function(tab)
    -- runs on first open (and when a search forces the tab to build)
    local section = tab:AddSection("Player ESP")
    section:AddToggle({ Name = "Enabled" })
end)
```

### Closing / cleanup

```lua
Window:Close()          -- animate out
Window:Toggle()         -- toggle visibility
Window:Destroy()        -- destroy the window and all of its tabs
CherryUI:Destroy()      -- destroy every window, notification and connection
```

---

## 4. Components

All controls return an object with `:GetValue()`, `:SetValue(value, silent)`,
`:OnChanged(callback)` and `:Destroy()`.

### Button

```lua
Section:AddButton({
    Name = "Apply",
    Variant = "Primary",         -- "Primary" | "Secondary" | "Danger"
    Callback = function() print("clicked") end,
})
```

### Toggle + dependency box

```lua
local master = Section:AddToggle({ Name = "Enable ESP", Default = true })

Section:AddSlider({ Name = "Max Distance", Min = 50, Max = 2000 }):AddDependency(master)
Section:AddColorPicker({ Name = "Color" }):AddDependency(master)
```

`AddDependency` accepts a boolean, an array of accepted values, or a predicate:

```lua
slider:AddDependency(dropdown, { "Head", "Torso" })
slider:AddDependency(dropdown, function(value) return value ~= "Off" end)
```

Hidden controls animate their row height to zero and collapse their section
when everything inside is hidden.

### Slider

```lua
Section:AddSlider({
    Name = "Smoothing",
    Min = 0,
    Max = 1,
    Default = 0.18,
    Decimals = 2,
    Step = 0.01,           -- optional snapping
    Suffix = "x",          -- appended to the displayed value
    Callback = function(value) print(value) end,
})
```

The value label is editable: click it and type a precise number.

### Dropdown

```lua
Section:AddDropdown({
    Name = "Hitbox",
    Options = { "Head", "Torso", "Nearest" },
    Default = "Head",
})

Section:AddDropdown({
    Name = "Elements",
    Multi = true,
    Options = { "Box", "Name", "Health", "Tracer" },
    Default = { "Box", "Name" },
    Callback = function(selected)
        -- selected is an array when Multi = true
    end,
})
```

### TextBox (numeric)

```lua
Section:AddTextBox({
    Name = "Walk Speed",
    Numeric = true,
    Min = 8,
    Max = 100,
    Default = 16,
    Callback = function(value)
        print("speed", value)
    end,
})
```

Values commit on Enter or focus loss; invalid input restores the previous value.

### Keybind

```lua
Section:AddKeybind({
    Name = "Aim Key",
    Default = Enum.KeyCode.E,
    Callback = function(key) print("bound", key) end,
})
```

Click the pill and press a key or mouse button; Escape cancels.

### ColorPicker

```lua
Section:AddColorPicker({
    Name = "ESP Color",
    Default = Color3.fromHex("FF4D6D"),
    Callback = function(color) print(color) end,
})
```

The popup has a saturation/value square, hue strip and hex input.

---

## 5. Advanced usage

### Themes

```lua
CherryUI:SetTheme("Purple")         -- animated
CherryUI:SetTheme("Green", false)   -- instant
print(CherryUI:GetThemeNames())     -- { "Crimson", "Pink", "Purple", "Green", "Blue" }
print(CherryUI.Palette.Primary)     -- current accent color
```

Theme tokens: `Background`, `Surface`, `SurfaceHigh`, `Primary`, `Accent`,
`Text`, `SubText`, `Placeholder`, `Outline`, `Danger`, `Success`, `Warning`.

If you build custom UI, register it with the manager so it follows theme
changes:

```lua
CherryUI:Styled(myFrame, "Surface", "BackgroundColor3")
CherryUI.ThemeManager:BindGradient(myGradient, { "Primary", "Accent" })
```

### Notifications

```lua
CherryUI:Notify({
    Title = "Injected",
    Content = "Cherry UI loaded successfully.",
    Icon = "success",        -- drawn icon name, emoji, or an rbxassetid:// image
    Type = "success",        -- "info" | "success" | "warning" | "error"
    Duration = 5,            -- seconds (hover pauses the timer)
})
```

Notifications stack top-right, slide in/out, and reuse pooled cards.

### ESP preview hook

```lua
local preview = tab:AddESPPreview({ Height = 300 })

preview:SetTarget({ Name = "Player", Health = 72, Distance = 60 })
preview:SetColor(CherryUI.Palette.Primary)
preview:SetEnabled("Tracer", true)

preview:OnChanged(function(settings)
    -- settings = { Highlight, Box, Tracer, Name, Color, Target }
    applyMyEspSettings(settings)
end)
```

The preview runs its animation at 30 Hz through the shared scheduler and stops
as soon as you call `preview:Destroy()`.

### Player list

```lua
local list = tab:AddPlayerList({ Height = 320 })

list:SetAction("teleport", function(player)
    TeleportRemote:FireServer(player.UserId)
end)
```

Spectate works out of the box; teleport needs a server-side handler because
clients cannot move other characters. Copy uses the executor's `setclipboard`
when available; in vanilla Roblox it shows the name for manual copying.

### Config saving

```lua
-- Session memory (default)
CherryUI.Config:SetMode("memory")

-- Executor JSON file
CherryUI.Config:SetMode("file", { Path = "CherryUI/config.json" })

-- Your own backend (RemoteFunction, ProfileService, etc.)
CherryUI.Config:SetMode("custom", {
    save = function(data) MyRemote:InvokeServer("Save", data) end,
    load = function() return MyRemote:InvokeServer("Load") end,
})

-- DataStore (server-side only; pass a store and key)
CherryUI.Config:SetMode("datastore", { Store = myStore, Key = "user_123" })

CherryUI:SaveConfig()
CherryUI:LoadConfig()
CherryUI:ResetConfig()

-- Save 30 seconds after the last change
CherryUI.Config:EnableAutoSave(30)
```

Saved data includes every control's value, the active theme and the menu
keybind. Saving or loading first builds any lazy tabs, so deferred controls are
included; loading applies values silently (callbacks are not re-fired).

**Server-side DataStore pattern:** never let the client write to a DataStore
directly. Keep a `RemoteFunction` that validates `player` on the server, then
call `SaveConfig()`/`LoadConfig()` from a server-side Cherry UI instance, or use
the `custom` backend to bridge to your own remote.

### Search and lazy loading

The header search box filters by control name and optional `Keywords`:

```lua
Section:AddSlider({
    Name = "Max Distance",
    Keywords = { "esp", "range", "render" },
    Min = 50,
    Max = 2000,
})
```

Typing forces unbuilt tabs to build so their entries can be found. Dependencies
and search both drive the same visibility system, so filtered rows never
reappear by accident.

---

## 6. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Nothing appears | The script must be a LocalScript on the client. Check the Output window for `[CherryUI]` warnings. |
| `attempt to index nil with 'Create'` | The module tree is wrong. Folder and ModuleScript names must match the README structure exactly. |
| Menu does not toggle with RightShift | The toggle key is handled before `gameProcessed` and is not blocked by focused text boxes, so the usual cause is Studio's **Run** (F8) mode or a server `Script` — use **Play** (F5), a LocalScript, or an executor. Also rebuild a stale `dist/CherryUI.lua` (`python3 tools/bundle.py`). Rebind with `CherryUI:SetToggleKey`, or toggle in code with `CherryUI:ToggleUI()`. |
| Keybind shows "None" | Bindings accept `Enum.KeyCode` and the three mouse buttons; other input types are ignored. |
| UI is too large / small | Resize the window from the bottom-right grip, or change `Size` in `CreateWindow`. The whole window also scales with viewport size. |
| No cherry cursor | The library builds the ScreenGui when it runs on the client. Require it from a LocalScript (or paste the bundle); in Studio edit mode nothing is created. Check `CherryUI:GetCursorMode()` is not `"off"`. |
| Roblox cursor vanished after stopping the script | A hard script stop skips `CherryUI:Destroy()`. Call `CherryUI:ResetCursor()` (or `SetCursorMode("off")`) before stopping, or reset `UserInputService.MouseIconEnabled = true` in the command bar. |
| Cursor sits under the topbar | Use the default `IgnoreGuiInset = false` ScreenGui; the cursor subtracts the `CoreUISafeInsets` itself. |
| Dropdown appears behind the window | Popups need `CherryUI.Overlay`; do not reparent or destroy the library's `ScreenGui`. |
| Theme switch leaves some elements unchanged | Custom instances must be registered with `CherryUI:Styled` or `BindGradient`. |
| Config file never writes | `writefile`/`readfile` are executor functions. In Studio, use `memory` or `custom`; for live games use a validated remote + DataStore. |
| `DataStore ... can only be called on the server` | Use the `custom` backend or run the config manager on the server. |
| Player list teleport does nothing | Provide a handler: `list:SetAction("teleport", fn)`. |
| ESP preview does not animate | The library scheduler is destroyed, or `preview:Destroy()` was called. |
| Memory grows after closing tabs | Call `Window:Destroy()` / `CherryUI:Destroy()` when you are done; components disconnect their own connections. |
| Rojo will not sync / `Cannot sync a model as a place` | You are serving a model project. Serve `default.project.json` and reconnect — see [RESUME.md](RESUME.md) §3. |

### Mobile

There is no RightShift on touch devices. Add an on-screen button that calls
`CherryUI:ToggleUI()`:

```lua
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(44, 44)
button.Position = UDim2.new(0, 12, 0, 60)
CherryUI.Icons.new("layers", button, 18, CherryUI.Palette.Primary)
button.Parent = screenGui
button.Activated:Connect(function()
    CherryUI:ToggleUI()
end)
```

---

## 7. API cheat sheet

The short version is below; **[API.md](API.md)** is the complete reference
(every method, config key, signal, icon name and troubleshooting entry).

### Library

| Member | Description |
| --- | --- |
| `CherryUI.Version` | Library version string. |
| `CherryUI.Palette` | Active theme palette. |
| `CherryUI.ToggleKey` | Current menu keybind (`RightShift` by default). |
| `CherryUI:CreateWindow(config)` | Create a window and return it. |
| `CherryUI:Notify(config)` | Show a notification. |
| `CherryUI:SetTheme(name, animate?)` | Switch theme. |
| `CherryUI:GetThemeNames()` | Ordered theme names. |
| `CherryUI:SetToggleKey(enumItem)` | Rebind the menu toggle. |
| `CherryUI:ToggleUI()` | Toggle the primary window. |
| `CherryUI:SetCursorMode(mode)` / `GetCursorMode()` | `"always"` (default), `"menu"` or `"off"`. |
| `CherryUI:ResetCursor()` | Restore Roblox's cursor without destroying the UI. |
| `CherryUI:SaveConfig()` / `LoadConfig()` / `ResetConfig()` | Persistence. |
| `CherryUI:Styled(instance, token, property?)` | Theme bind a property. |
| `CherryUI:Destroy()` | Tear everything down. |

### Window

| Member | Description |
| --- | --- |
| `Window:AddTab(name, icon?, builder?)` | Add a tab (builder runs lazily). |
| `Window:SelectTab(tab, instant?)` | Switch tabs. |
| `Window:Open(animate?)` / `Close(animate?)` / `Toggle()` | Visibility. |
| `Window:Destroy()` | Cleanup. |

### Tab / Section

| Member | Description |
| --- | --- |
| `Tab:AddSection(name, config?)` | Group controls. |
| `Tab:AddESPPreview(config?)` | Live ESP preview card. |
| `Tab:AddPlayerList(config?)` | Player roster card. |
| `Section:AddToggle` `AddSlider` `AddDropdown` `AddButton` `AddTextBox` `AddKeybind` `AddColorPicker` `AddLabel` | Controls. |

### Icons

Icons are **drawn**, not typed: Roblox's fonts have no coverage for the usual
symbols (`⌕ ✕ ▾ ✓ ◉`), which render as empty boxes. Pass a name, and the library
draws it.

| Member | Description |
| --- | --- |
| `CherryUI.Icons.new(kind, parent, size, color)` | Draw an icon (`"target"`, `"close"`, `"check"`, `"chevron"`, `"eye"`, `"layers"`, `"players"`, `"settings"`, `"search"`, `"refresh"`, `"copy"`, `"diamond"`, `"info"`, `"warning"`, `"success"`, `"error"`, `"cursor"`). |
| `Icons.setColor(icon, color)` / `setTransparency(icon, alpha)` / `setSize(icon, size, info?)` | Restyle a drawn icon. |
| `Icons.bindTheme(icon, CherryUI, token)` | Keep it in sync with the palette. |
| `Icons.resolve(name)` | Map a glyph / friendly name to a kind (`nil` = render as text). |

Tab icons and notification icons take the same names: `window:AddTab("Combat", "target")`,
`CherryUI:Notify({ Icon = "success" })`.

### Component

| Member | Description |
| --- | --- |
| `:GetValue()` | Current value. |
| `:SetValue(value, silent?)` | Set the value (silent skips callbacks). |
| `:OnChanged(callback)` | Subscribe to changes. |
| `:AddDependency(source, expected?)` | Show only when `source` matches. |
| `:SetVisible(visible)` | Manual visibility override. |
| `:Destroy()` | Disconnect and destroy. |
