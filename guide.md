# Cherry UI — The Complete Guide

Every piece of Cherry UI, one at a time, with copy-paste code.
No build step, no Rojo, no dependencies — one file, works in an executor and in
Roblox Studio.

- **Reference** (every property, every method): [API.md](API.md)
- **Installing into a real game with Rojo**: [setup.md](setup.md)
- **Executors**: [EXECUTORS.md](EXECUTORS.md)

---

## Contents

1. [Run it](#1-run-it)
2. [The smallest menu that works](#2-the-smallest-menu-that-works)
3. [Window](#3-window)
4. [Tabs](#4-tabs)
5. [Sections](#5-sections)
6. [Toggle](#6-toggle)
7. [Button](#7-button)
8. [Slider](#8-slider)
9. [Dropdown](#9-dropdown)
10. [TextBox](#10-textbox)
11. [Keybind](#11-keybind)
12. [ColorPicker](#12-colorpicker)
13. [Label](#13-label)
14. [Dependency boxes](#14-dependency-boxes)
15. [Search](#15-search)
16. [ESP Preview](#16-esp-preview)
17. [Player List](#17-player-list)
18. [Notifications](#18-notifications)
19. [Themes](#19-themes)
20. [Config saving](#20-config-saving)
21. [Menu key (RightShift)](#21-menu-key-rightshift)
22. [Cherry cursor](#22-cherry-cursor)
23. [Icons (including icons8)](#23-icons-including-icons8)
24. [Full menu, all together](#24-full-menu-all-together)
25. [When something does not show up](#25-when-something-does-not-show-up)

---

## 1. Run it

**In an executor.** Paste [dist/CherryUI.lua](dist/CherryUI.lua) into the editor
and execute it. It installs itself and exposes the library as a global:

```lua
local CherryUI = getgenv().CherryUI
```

**In Roblox Studio.** Put the `CherryUI` ModuleScript from
[build/CherryUI.rbxm](build/CherryUI.rbxm) in `ReplicatedStorage`, then in a
`LocalScript` under `StarterPlayerScripts`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CherryUI = require(ReplicatedStorage:WaitForChild("CherryUI"))
```

Check that you are on the right build:

```lua
print(CherryUI.Version) --> 1.2.0
```

Anything older means a stale file — rebuild with `python3 tools/bundle.py`.

> **Run it on the client.** Cherry UI builds a `ScreenGui`. In Studio use
> **Play**, not **Run**: in Run mode there is no local player, and the library
> warns about it instead of drawing nothing.

---

## 2. The smallest menu that works

```lua
local CherryUI = getgenv().CherryUI

local Window = CherryUI:CreateWindow({
    Title = "Cherry",
    Subtitle = "by you",
})

local Tab = Window:AddTab("Combat", "target")

local Section = Tab:AddSection("Aimbot")
Section:AddToggle({ Name = "Enable Aimbot" })
```

Press **RightShift** to hide or show it.

The three rules that prevent 95% of "nothing appears":

1. `AddTab` is what makes a window have pages. A window with no tabs shows an
   in-window notice telling you exactly that.
2. Code inside an `AddTab` builder function only runs the first time that tab is
   opened — controls created there do not exist before that.
3. If your script errors between `CreateWindow` and `AddTab`, you get an empty
   window. Read the Output window: the first red line names the real problem.

---

## 3. Window

```lua
local Window = CherryUI:CreateWindow({
    Title      = "Cherry",
    Subtitle   = "FPS Suite · v1.2.0",
    Width      = 640,          -- default 620
    Height     = 460,          -- default 440
    MinWidth   = 480,
    MinHeight  = 300,
    Resizable  = true,         -- false removes the resize grips
    StartOpen  = true,         -- false starts hidden (toggle with RightShift)
    ToggleKey  = Enum.KeyCode.RightShift,
    Cursor     = "always",     -- "always" | "menu" | "off"
})
```

`Size = UDim2.fromOffset(640, 460)` also works if you prefer one value.

| What you want | Code |
| --- | --- |
| Show it | `Window:Open()` |
| Hide it | `Window:Close()` |
| Flip it | `Window:Toggle()` |
| Is it on screen? | `if Window:IsOpen() then` |
| Show it with no animation | `Window:Open(false)` |
| Hide it with no animation | `Window:Close(false)` |
| In-window banner | `Window:ShowNotice({ Title = "Hi", Content = "Text" })` |
| Remove the library | `Window:Destroy()` |

Drag it by the header. Resize from the bottom-right grip, the right edge or the
bottom edge. It is clamped to the viewport, respects `CoreUISafeInsets`, and
scales down on small screens instead of running off them.

**Notices** are how the library reports problems *inside* the window instead of
only in Output:

```lua
Window:ShowNotice({
    Type = "error",          -- info | success | warning | error
    Title = "Tab failed to build",
    Content = "Toggle: attempt to index nil",
    Icon = "warning",
    Duration = 8,            -- seconds; omit to keep it until dismissed
})
```

---

## 4. Tabs

A tab is a page. You can add any number.

### 4.1 The normal way: name + icon + builder

```lua
local Combat = Window:AddTab("Combat", "target", function(tab)
    tab:AddSection("Aim"):AddToggle({ Name = "Enable Aimbot" })
end)
```

The builder runs **once**, the first time the tab is opened. Controls created
inside it do not exist until then — that is the lazy loading.

### 4.2 Without a builder (create controls yourself)

```lua
local Players = Window:AddTab("Players", "players")
Players:AddSection("Actions"):AddButton({ Text = "Refresh" })
```

### 4.3 Icon argument is optional

```lua
Window:AddTab("Misc")                                   -- no icon
Window:AddTab("Misc", "settings")                        -- drawn icon name
Window:AddTab("Misc", "rbxassetid://1234567890")         -- your own image
Window:AddTab("Misc", function(tab) end)                 -- builder only
```

Drawn icon names: `target`, `layers`, `players`, `settings`, `eye`, `search`,
`close`, `check`, `chevron`, `refresh`, `copy`, `diamond`, `info`, `warning`,
`success`, `error`, `cursor`. Emoji and plain letters work too.

### 4.4 A tab per feature, the way an FPS menu does it

```lua
local Aim = Window:AddTab("Aim", "target")
local Visuals = Window:AddTab("Visuals", "layers")
local Players = Window:AddTab("Players", "players")
local Settings = Window:AddTab("Settings", "settings")
```

### 4.5 Switching tabs from code

```lua
Window:SelectTab(Visuals)          -- animated
Window:SelectTab(Visuals, true)    -- instant
Visuals:Select()                   -- same thing through the tab
```

### 4.6 Everything a tab holds

```lua
Tab:AddSection(name)      --> Section
Tab:AddESPPreview(config) --> ESPPreview
Tab:AddPlayerList(config) --> PlayerList
Tab:EnsureBuilt()         -- run the builder now, if it has not run
Tab:Destroy()
```

---

## 5. Sections

A section is the titled card that groups controls.

```lua
local Aimbot = Tab:AddSection("Aimbot")
local Target = Tab:AddSection("Targeting")
```

Sections collapse themselves automatically when every control inside is hidden
(by search or by a dependency box), so the page never shows an empty card.

```lua
Section:AddToggle(config)
Section:AddButton(config)
Section:AddSlider(config)
Section:AddDropdown(config)
Section:AddTextBox(config)
Section:AddKeybind(config)
Section:AddColorPicker(config)
Section:AddLabel(text, config)
```

---

## 6. Toggle

```lua
local Aimbot = Section:AddToggle({
    Name = "Enable Aimbot",
    Default = false,
    Callback = function(on)
        print("aimbot", on)
    end,
})
```

```lua
Aimbot:SetValue(true)         -- fires Callback and OnChanged
Aimbot:SetValue(false, true)  -- silent: changes the value, calls nothing
Aimbot:GetValue()             --> true
Aimbot:OnChanged(function(on) print(on) end)
```

`GetValue()` always returns a boolean. Clicking anywhere on the row toggles it.

---

## 7. Button

```lua
Section:AddButton({
    Text = "Apply",
    Variant = "primary",      -- "primary" | "secondary" | "danger"
    Callback = function() print("applied") end,
})
```

```lua
local Reset = Section:AddButton({ Text = "Reset", Variant = "danger" })

Reset:SetText("Reset all")
Reset:SetEnabled(false)   -- dimmed, non-interactive
Reset:SetEnabled(true)
```

---

## 8. Slider

```lua
local FOV = Section:AddSlider({
    Name = "Field of View",
    Min = 10,
    Max = 180,
    Default = 90,
    Step = 1,             -- 0 = smooth / continuous
    Decimals = 0,         -- text precision
    Suffix = "°",
    Callback = function(value) print(value) end,
})
```

```lua
FOV:SetValue(120)
FOV:GetValue()   --> 120
```

Extra formatting when the number is not a plain integer:

```lua
local Speed = Section:AddSlider({
    Name = "Fly Speed",
    Min = 1, Max = 500, Default = 50, Step = 0.5, Decimals = 1,
    Format = function(value) return string.format("%.1f studs/s", value) end,
})
```

Drag the track, or click anywhere on it to jump to that value.

---

## 9. Dropdown

### 9.1 Single select

```lua
local HitPart = Section:AddDropdown({
    Name = "Hit Part",
    Options = { "Head", "Torso", "Nearest" },
    Default = "Head",
    Placeholder = "Choose a part",
    Callback = function(value) print(value) end,
})
```

```lua
HitPart:SetValue("Torso")
HitPart:GetValue()   --> "Torso"
HitPart:Open()
HitPart:Close()
```

### 9.2 Multi select

```lua
local Flags = Section:AddDropdown({
    Name = "Checks",
    Options = { "Wall check", "Visible only", "Team check", "FOV check" },
    Multi = true,
    Default = { "Wall check" },      -- optional
    Placeholder = "Select checks",
    Callback = function(values)
        for _, name in ipairs(values) do print(name) end
    end,
})
```

```lua
Flags:SetValue({ "Wall check", "Team check" })
Flags:GetValue()   --> { "Wall check", "Team check" }
```

### 9.3 A list that changes with the game

A dropdown's `Options` is a normal table: rewrite it and reopen the menu.

```lua
local Weapon = Section:AddDropdown({ Name = "Weapon", Options = {} })

local function refresh()
    Weapon.Options = {}
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(Weapon.Options, tool.Name)
        end
    end
    if #Weapon.Options > 0 and Weapon:GetValue() == nil then
        Weapon:SetValue(Weapon.Options[1])
    end
end

refresh()
player.Backpack.ChildAdded:Connect(refresh)
```

The option list is scrollable and **pooled**: opening the dropdown a hundred
times reuses the same row frames.

---

## 10. TextBox

```lua
local Speed = Section:AddTextBox({
    Name = "Walk Speed",
    Default = "16",
    Numeric = true,          -- rejects letters, clamps to Min/Max on commit
    Min = 8,
    Max = 500,
    Placeholder = "16",
    ClearTextOnFocus = false,
    Width = 110,             -- box width in pixels
    Callback = function(text)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = tonumber(text)
    end,
})
```

```lua
Speed:SetValue(90)
Speed:GetValue()   --> 90 (number when Numeric = true)
```

Committed on **Enter** or when the box loses focus, not on every keystroke.

Free text instead of numbers:

```lua
Section:AddTextBox({ Name = "Name", Numeric = false, Placeholder = "type here" })
```

---

## 11. Keybind

```lua
local MenuKey = Section:AddKeybind({
    Name = "Menu Keybind",
    Default = Enum.KeyCode.RightShift,
    Callback = function(key)
        CherryUI:SetToggleKey(key)
    end,
})
```

```lua
MenuKey:BeginCapture()             -- listen for the next key
MenuKey:EndCapture()               -- cancel
MenuKey:GetValue()                 --> Enum.KeyCode.RightShift
MenuKey:SetValue(Enum.KeyCode.Insert)
```

Click the row, press a key. Escape cancels. Keyboard keys and the three mouse
buttons are supported. Bind it to an *action* instead of the menu:

```lua
local AimKey = Section:AddKeybind({ Name = "Aim Key", Default = Enum.KeyCode.Q })
AimKey:OnChanged(function(key)
    -- key is an Enum.KeyCode, or an Enum.UserInputType for mouse buttons
end)
```

---

## 12. ColorPicker

```lua
local ESPColor = Section:AddColorPicker({
    Name = "ESP Color",
    Default = Color3.fromRGB(255, 77, 109),
    Callback = function(color) myESP:SetColor(color) end,
})

ESPColor:SetValue(Color3.fromRGB(0, 200, 255))
ESPColor:GetValue()   --> Color3
ESPColor:Open()
ESPColor:Close()
```

Hue strip + saturation/value area + hex readout. The popup closes itself when
you click away.

---

## 13. Label

```lua
Section:AddLabel("Only works while the master toggle is on.", { TextSize = 11 })
```

Wrapped, non-interactive, themed, destroyed with the section.

---

## 14. Dependency boxes

Hide controls until another control says otherwise.

```lua
local Aimbot = Section:AddToggle({ Name = "Enable Aimbot", Default = false })

local FOV = Section:AddSlider({ Name = "Aim FOV", Min = 1, Max = 180, Default = 80 })
FOV:AddDependency(Aimbot)              -- visible only while Aimbot is true

local Target = Section:AddDropdown({ Name = "Target", Options = { "Head", "Torso" } })
Target:AddDependency(Aimbot, true)     -- explicit expected value
```

The parent can be a toggle, a dropdown (expected value = a selected option) or
anything with `GetValue`:

```lua
local Mode = Section:AddDropdown({ Name = "Mode", Options = { "Silent", "Smooth" }, Default = "Smooth" })
local Smoothness = Section:AddSlider({ Name = "Smoothness", Min = 1, Max = 20, Default = 5 })
Smoothness:AddDependency(Mode, "Smooth")
```

Chains work: the slider only appears when the toggle is on **and** the dropdown
says Smooth. Manual control:

```lua
FOV:SetVisible(false)
FOV:SetVisible(true)
FOV:UpdateVisibility()   -- re-evaluate every dependency
```

Sections fold away when all their children are hidden, so a page with
dependencies does not leave empty cards behind.

---

## 15. Search

The search box is in the window header, above the tabs. Typing filters every
tab by control name, by its options, and by keywords you supply:

```lua
Section:AddSlider({
    Name = "Field of View",
    Keywords = { "fov", "camera", "zoom" },
})

Section:AddToggle({
    Name = "Team Check",
    Keywords = "team friendly ignore",   -- a single string works too
})
```

Drive it from code:

```lua
Window:Filter("fov")
Window:Filter("")
```

When nothing matches, the window says `No settings match "…"` instead of going
blank.

---

## 16. ESP Preview

A live preview of ESP settings — highlight, box, tracer, name tag, color — that
you hook your own drawing to. It never renders your real ESP; it shows the
player what their settings *look like*.

```lua
local Preview = Visuals:AddESPPreview({
    Name = "ESP Preview",
    Height = 300,
    Color = Color3.fromRGB(255, 77, 109),
    TargetName = "Player",
})

Preview:OnChanged(function(settings)
    -- settings = { Highlight = true, Box = true, Tracer = false,
    --              Name = true, Color = Color3, Target = {...} }
    applyMyESP(settings)
end)
```

```lua
Preview:GetSettings()
Preview:SetEnabled("Box", true)      -- "Highlight" | "Box" | "Tracer" | "Name"
Preview:Toggle("Tracer")
Preview:SetColor(Color3.fromRGB(0, 255, 170))
Preview:SetTarget({ Name = "Enemy", Health = 64, MaxHealth = 100, Distance = 120 })
```

`SetTarget` is safe to call every frame — the preview throttles its own redraw
to 30 Hz through the library's single `Heartbeat` loop and only touches the
properties that changed.

A complete, working ESP hook (drawing is yours; boxes are example maths):

```lua
local Preview = Visuals:AddESPPreview({ Name = "ESP Preview", Height = 300 })

local settings
Preview:OnChanged(function(value) settings = value end)

local draw = Drawing.new("Square")   -- executor drawing API
draw.Visible = false
draw.Thickness = 1.5
draw.Filled = false

local RunService = game:GetService("RunService")
RunService.RenderStepped:Connect(function()
    if not settings or not settings.Box then
        draw.Visible = false
        return
    end
    draw.Color = settings.Color or Color3.new(1, 1, 1)
    -- ... position `draw` over your target, then:
    draw.Visible = true
end)
```

---

## 17. Player List

Every player in the server, with actions.

```lua
local List = Players:AddPlayerList({
    Height = 340,
    OnTeleport = function(player) print("teleport", player.Name) end,
    OnSpectate = function(player) print("spectate", player.Name) end,
    OnCopy = function(player) print("copy", player.Name) end,
})
```

Built-in buttons per row:

- **TP** — calls your `OnTeleport`. Teleporting needs server authority, so you
  must supply the handler.
- **Spectate** — sets `workspace.CurrentCamera.CameraSubject` to the player's
  humanoid. Your `OnSpectate` overrides it.
- **Copy** — `setclipboard` in executors; otherwise a notification shows the name.

```lua
List:SetAction("teleport", function(player)
    local me = game.Players.LocalPlayer
    local target = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if target and me.Character and me.Character:FindFirstChild("HumanoidRootPart") then
        me.Character.HumanoidRootPart.CFrame = target.CFrame * CFrame.new(0, 0, 3)
    end
end)

List:Refresh()
```

Rows are pooled, show live health, and there is a filter box at the top. The
list refreshes on join/leave and once a second.

---

## 18. Notifications

Top-right cards, pooled, with a title, body, icon, duration and a progress bar.

```lua
local note = CherryUI:Notify({
    Title = "Injected",
    Content = "Cherry UI loaded successfully.",
    Type = "success",       -- info | success | warning | error
    Duration = 4,
    Icon = "layers",
})

note.Dismiss()
print(note.Id)
```

```lua
-- danger card with your own accent colour
CherryUI:Notify({
    Title = "Script error",
    Content = "The aimbot module failed to load.",
    Type = "error",
    Color = Color3.fromRGB(255, 92, 92),
    Duration = 8,
})

-- icon override, including your own image
CherryUI:Notify({ Title = "Done", Content = "Config saved.", Icon = "success" })
CherryUI:Notify({ Title = "Hi", Content = "Image icon.", Icon = "rbxassetid://1234567890" })
```

Hover a card to pause its timer. At most four are on screen; older ones are
reused, never re-created.

---

## 19. Themes

Five palettes ship: `Crimson` (default), `Pink`, `Purple`, `Green`, `Blue`.

```lua
CherryUI:SetTheme("Purple")
print(CherryUI:GetThemeNames())
```

The dots in the header switch themes at runtime too, and every window, control,
icon, notification and the cursor badge follows instantly.

**Your own theme:** add it before creating windows, then insert it into the
order so the header dots include it.

```lua
CherryUI.Themes.Midnight = {
    Name = "Midnight",
    Background  = Color3.fromHex("05060A"),
    Surface     = Color3.fromHex("0D1018"),
    SurfaceHigh = Color3.fromHex("151A26"),
    Primary     = Color3.fromHex("5B8CFF"),
    Accent      = Color3.fromHex("8AB0FF"),
    Text        = Color3.fromHex("F2F5FF"),
    SubText     = Color3.fromHex("9AA3BA"),
    Placeholder = Color3.fromHex("5C6478"),
    Outline     = Color3.fromHex("232A3A"),
    Danger      = Color3.fromHex("FF5A5A"),
    Success     = Color3.fromHex("4FE08C"),
    Warning     = Color3.fromHex("FFC46B"),
}

table.insert(CherryUI.ThemeOrder, "Midnight")
CherryUI:SetTheme("Midnight")
```

Reuse the palette in your own code:

```lua
local palette = CherryUI.ThemeManager.Palette
draw.Color = palette.Primary

-- or a single token, kept live:
local color = CherryUI.ThemeManager:GetColor("Primary")
```

---

## 20. Config saving

Every control registers itself with an id (`Kind_Name`), so saving needs no
bookkeeping from you. The snapshot holds every value, the theme and the menu key.

```lua
CherryUI:SaveConfig()
CherryUI:LoadConfig()
CherryUI:ResetConfig()      -- every control back to its Default
```

### 20.1 In an executor — a JSON file

```lua
CherryUI.Config:SetMode("file", { Path = "CherryUI/config.json" })
CherryUI.Config:EnableAutoSave(30)    -- autosave every 30 s, 0 disables

CherryUI:SaveConfig()
CherryUI:LoadConfig()
```

### 20.2 In a real game — DataStore

```lua
local DataStoreService = game:GetService("DataStoreService")

CherryUI.Config:SetMode("datastore", {
    Store = DataStoreService:GetDataStore("CherryUI"),
    Key = "settings",
})
```

The store must be reachable from the script's context; saving UI state for the
*local player* is a client concern, so use a RemoteFunction if the DataStore
lives on the server.

### 20.3 Anywhere — bring your own save/load

```lua
CherryUI.Config:SetMode("custom", {
    save = function(data) myRemote:FireServer(data) end,
    load = function() return myRemote:InvokeServer() end,
})
```

### 20.4 Loading on startup, saving on exit

```lua
-- after every control exists:
local ok = CherryUI:LoadConfig()
if not ok then
    CherryUI:Notify({ Title = "Config", Content = "No saved config yet.", Type = "info" })
end

game:BindToClose(function() CherryUI:SaveConfig() end)
```

`Callback` functions do **not** run while a config is being restored — call your
apply functions once after loading if you need the effects:

```lua
CherryUI:LoadConfig()
applySettings()        -- your own function that reads GetValue() from each control
```

---

## 21. Menu key (RightShift)

The library binds **RightShift** through `ContextActionService` at priority
`3000` *and* through `UserInputService`, so a game that binds the same key
cannot swallow it. One press produces exactly one toggle.

```lua
CherryUI:SetToggleKey(Enum.KeyCode.Insert)
print(CherryUI.ToggleKey)                              --> Enum.KeyCode.Insert
print(CherryUI.Util.keyName(CherryUI.ToggleKey))       --> "Insert"

CherryUI:OnToggleKeyChanged(function(key)
    print("menu key is now", key)
end)
```

A rebind UI in one section:

```lua
Section:AddKeybind({
    Name = "Menu Keybind",
    Default = Enum.KeyCode.RightShift,
    Callback = function(key) CherryUI:SetToggleKey(key) end,
})

Section:AddButton({
    Text = "Reset menu key",
    Variant = "secondary",
    Callback = function() CherryUI:SetToggleKey(Enum.KeyCode.RightShift) end,
})
```

**If RightShift still does nothing:**

| Cause | Fix |
| --- | --- |
| A Keybind control is capturing | Click elsewhere / press Escape; captures expire after 5 s |
| Another script binds RightShift *after* Cherry UI | It can no longer swallow the toggle (priority 3000), but rebind to be sure |
| The window was created with `StartOpen = false` and the keybind failed | `Window:Open()` once to test |
| Your executor blocks `ContextActionService` | The `UserInputService` path still works; check `print(CherryUI.Util.keyName(CherryUI.ToggleKey))` |
| Two windows exist, the empty one on top | `CherryUI:Diagnose()` lists windows; destroy the extra one |

---

## 22. Cherry cursor

Cherry UI keeps Roblox's own arrow and paints a small cherry badge that trails
the pointer, with a dip on click. It never covers the hotspot.

```lua
CherryUI:SetCursorMode("always")   -- default: badge always visible
CherryUI:SetCursorMode("menu")     -- only while a window is open
CherryUI:SetCursorMode("off")      -- no badge

print(CherryUI:GetCursorMode())
CherryUI:ResetCursor()             -- back to "always"
```

The badge hides in first person / shift-lock and comes back on unlock.

---

## 23. Icons (including icons8)

Cherry UI draws its own icons from frames, so they render identically on every
client and need no upload. When you want real raster icons — icons8's set, your
own PNGs, anything — point a kind at a Roblox asset id.

### 23.1 Why an asset id and not an icons8 URL

Roblox `ImageLabel.Image` only accepts `rbxassetid://…` (or `rbxthumb://…`).
It cannot load `https://img.icons8.com/…` directly: an arbitrary URL is either
blocked or shows as a broken image. So the workflow is **download → upload to
Roblox → use the id**.

### 23.2 Uploading an icons8 icon

1. Open the icon on [icons8.com](https://icons8.com), pick **PNG**, **100 px**,
   and a **white** (or any single-colour) glyph — Cherry UI tints icons with the
   theme, so white survives recolouring best.
2. In Roblox Studio open **View → Asset Manager**, or in a browser open the
   [Creator Dashboard → Development Items → Images](https://create.roblox.com/dashboard/creations?activeTab=Image).
3. **Upload** the PNG and wait for moderation (usually seconds, sometimes
   minutes). Copy the id from the asset page URL — the number after
   `/catalog/` or `?id=`.
4. Use it as `rbxassetid://THAT_NUMBER`.

> Uploaded images must be **owned by you** (or public) for other players to see
> them. In an executor, only *your* client needs the asset, so a freshly uploaded
> one works immediately.

### 23.3 Mapping icons8 icons to Cherry UI kinds

Register once, right after loading:

```lua
CherryUI:SetIcons({
    target   = "rbxassetid://1111111111",   -- icons8 "crosshair"
    layers   = "rbxassetid://2222222222",   -- icons8 "layers"
    players  = "rbxassetid://3333333333",   -- icons8 "conference-call"
    settings = "rbxassetid://4444444444",   -- icons8 "settings"
    eye      = "rbxassetid://5555555555",   -- icons8 "eye"
    search   = "rbxassetid://6666666666",   -- icons8 "search"
    close    = "rbxassetid://7777777777",   -- icons8 "delete"
    check    = "rbxassetid://8888888888",   -- icons8 "checkmark"
    chevron  = "rbxassetid://9999999999",   -- icons8 "chevron-down"
    refresh  = "rbxassetid://1010101010",   -- icons8 "refresh"
    copy     = "rbxassetid://1212121212",   -- icons8 "copy"
    diamond  = "rbxassetid://1313131313",   -- icons8 "diamond"
    info     = "rbxassetid://1414141414",   -- icons8 "info"
    warning  = "rbxassetid://1515151515",   -- icons8 "error"
    success  = "rbxassetid://1616161616",   -- icons8 "checkmark"
    error    = "rbxassetid://1717171717",   -- icons8 "cancel"
    cursor   = "rbxassetid://1818181818",   -- icons8 "cursor"
})
```

Replace the placeholder ids with yours. Anything you leave out keeps the drawn
icon, so you can convert just the tabs you care about.

### 23.4 Per-component icons

```lua
Window:AddTab("Combat", "rbxassetid://1111111111")

CherryUI:Notify({
    Title = "Loaded",
    Content = "Using icons8 icons.",
    Icon = "rbxassetid://1616161616",
})
```

### 23.5 The rest of the icon API

```lua
local Icons = CherryUI.Icons

Icons.setImage("target", "rbxassetid://1111111111")   -- one kind
Icons.setImage("target", nil)                          -- back to drawn
Icons.getImage("target")

local icon = Icons.new("target", someFrame, 20, CherryUI.ThemeManager:GetColor("Primary"))
Icons.setColor(icon, Color3.new(1, 1, 1))
Icons.setSize(icon, 26, CherryUI.Tween.Info.Fast)
Icons.setTransparency(icon, 0.4)
Icons.bindTheme(icon, CherryUI, "Primary")
```

Image icons are tinted with `ImageColor3`, so they follow the theme like drawn
ones do.

---

## 24. Full menu, all together

A complete, working four-tab FPS menu with dependencies, ESP preview, player
list, notifications and config. Paste it after loading the library.

```lua
local CherryUI = getgenv().CherryUI
local PlayersService = game:GetService("Players")
local LocalPlayer = PlayersService.LocalPlayer

-- 1. Window ---------------------------------------------------------------
local Window = CherryUI:CreateWindow({
    Title = "Cherry",
    Subtitle = "FPS Suite",
    Width = 660,
    Height = 470,
    Resizable = true,
})

-- 2. Combat ---------------------------------------------------------------
local Combat = Window:AddTab("Combat", "target", function(tab)
    local Aim = tab:AddSection("Aimbot")

    local enabled = Aim:AddToggle({
        Name = "Enable Aimbot",
        Default = false,
        Callback = function(on)
            CherryUI:Notify({
                Title = "Aimbot",
                Content = on and "Enabled." or "Disabled.",
                Type = on and "success" or "info",
                Duration = 2,
            })
        end,
    })

    local fov = Aim:AddSlider({ Name = "Aim FOV", Min = 1, Max = 180, Default = 80, Suffix = "°" })
    fov:AddDependency(enabled)

    local part = Aim:AddDropdown({ Name = "Hit Part", Options = { "Head", "Torso", "Nearest" }, Default = "Head" })
    part:AddDependency(enabled)

    local key = Aim:AddKeybind({ Name = "Aim Key", Default = Enum.KeyCode.Q })
    key:AddDependency(enabled)

    local Target = tab:AddSection("Targeting")
    Target:AddDropdown({
        Name = "Team",
        Options = { "Enemies", "Everyone" },
        Default = "Enemies",
        Keywords = { "team", "friendly" },
    })
    Target:AddSlider({ Name = "Smoothness", Min = 1, Max = 30, Default = 8 })
end)

-- 3. Visuals --------------------------------------------------------------
local Visuals = Window:AddTab("Visuals", "layers", function(tab)
    local preview = tab:AddESPPreview({ Name = "ESP Preview", Height = 300 })
    local settings = preview:GetSettings()

    preview:OnChanged(function(value)
        settings = value
    end)

    local Box = tab:AddSection("Box")
    Box:AddColorPicker({
        Name = "Box Color",
        Default = Color3.fromRGB(255, 77, 109),
        Callback = function(color) preview:SetColor(color) end,
    })
    Box:AddSlider({ Name = "Box Thickness", Min = 1, Max = 6, Default = 2, Step = 1 })
    Box:AddDropdown({
        Name = "Box Style",
        Options = { "Full", "Corners", "Thin" },
        Default = "Corners",
    })

    local Tracer = tab:AddSection("Tracer")
    Tracer:AddToggle({ Name = "Tracer", Default = true, Callback = function(on) preview:SetEnabled("Tracer", on) end })
    Tracer:AddSlider({ Name = "Tracer Length", Min = 10, Max = 100, Default = 40 })
end)

-- 4. Players --------------------------------------------------------------
local PlayersTab = Window:AddTab("Players", "players", function(tab)
    local list = tab:AddPlayerList({ Height = 330 })

    list:SetAction("teleport", function(player)
        local me = LocalPlayer
        local target = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if target and me.Character and me.Character:FindFirstChild("HumanoidRootPart") then
            me.Character.HumanoidRootPart.CFrame = target.CFrame * CFrame.new(0, 0, 3)
        end
    end)
end)

-- 5. Settings -------------------------------------------------------------
local Settings = Window:AddTab("Settings", "settings", function(tab)
    local General = tab:AddSection("General")

    General:AddSlider({
        Name = "FOV",
        Min = 70, Max = 120, Default = 70,
        Callback = function(value)
            if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = value end
        end,
    })

    General:AddKeybind({
        Name = "Menu Keybind",
        Default = Enum.KeyCode.RightShift,
        Callback = function(key) CherryUI:SetToggleKey(key) end,
    })

    General:AddButton({
        Text = "Save config",
        Variant = "primary",
        Callback = function()
            CherryUI:SaveConfig()
            CherryUI:Notify({ Title = "Config", Content = "Saved.", Type = "success" })
        end,
    })

    local themes = tab:AddSection("Themes")
    themes:AddDropdown({
        Name = "Theme",
        Options = CherryUI:GetThemeNames(),
        Default = "Crimson",
        Callback = function(name) CherryUI:SetTheme(name) end,
    })
end)

-- 6. Welcome --------------------------------------------------------------
CherryUI:Notify({
    Title = "Cherry UI",
    Content = string.format("Loaded v%s · RightShift toggles the menu.", CherryUI.Version),
    Type = "success",
    Duration = 5,
})
```

---

## 25. When something does not show up

**The window is there but empty.** No tab was ever added — the window shows a
notice saying so. Check Output for the first error before `AddTab`.

**Text is invisible but switches and sliders work.** An interrupted animation
left the subtree transparent. Cherry UI re-checks this on every open and prints
`[CherryUI] Restored N invisible property`. Force it immediately:

```lua
CherryUI:Diagnose()
```

**Nothing at all.** You are in Studio **Run** mode (no LocalPlayer), or the
script errored before `CreateWindow`, or `getgenv().CherryUI` is nil because the
library was never executed in that environment.

**The menu key does nothing.** See [§21](#21-menu-key-rightshift).

**A second window sits on top of the first.** Use one window; the library warns
and the keybind toggles every window together.

**An icon is a red/blank square.** That `rbxassetid://` is wrong, not yet
approved, or not owned by you. `Icons.setImage(kind, nil)` returns to the drawn
icon.

**Old behaviour after an update.** `print(CherryUI.Version)` and compare with the
release; re-paste [dist/CherryUI.lua](dist/CherryUI.lua).

Useful one-liners:

```lua
print(CherryUI.Version)
print(CherryUI:GetPrimaryWindow().Title)
print(CherryUI.Util.keyName(CherryUI.ToggleKey))
print(#CherryUI:GetThemeNames(), "themes")
CherryUI:Diagnose()
```

---

MIT © Cherry UI
