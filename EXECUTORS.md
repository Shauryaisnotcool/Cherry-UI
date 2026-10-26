# Cherry UI — Executor & Publishing Guide

Two topics, nothing else:

1. **Running Cherry UI inside a Lua executor** (Synapse-class executors, Wave,
   Delta, Hydroxide, etc. — anything with `loadstring` + `HttpGet`).
2. **Publishing the library to GitHub** so that `loadstring` URL actually
   resolves for everyone who copies it.

For Studio/Rojo setup, the component API or themes, see
[setup.md](setup.md) and [README.md](README.md) instead.

---

## Part 1 — Using Cherry UI in an executor

### 1.1 What an executor gets

The repo ships two forms of the library:

| Form | Path | For whom |
| --- | --- | --- |
| Rojo module tree (`src/`, `init.lua`) | `ReplicatedStorage.CherryUI` | Studio / Rojo users (`require`) |
| **Single-file bundle** | [`dist/CherryUI.lua`](dist/CherryUI.lua) | **Executors** (`loadstring`) |

The bundle is the *same code*: `tools/bundle.py` inlines every module and
rewrites the `require(script.Utils.X)` calls into a tiny in-memory registry, so
there is no `script` object, no `ReplicatedStorage` and no module tree — one
plain Luau chunk that runs anywhere.

On execution the chunk:

- **returns** the library table (`local CherryUI = loadstring(...)()`), and
- **publishes** itself on `getgenv().CherryUI`, so a *second* script can reuse
  the same instance without loading the library twice.

The library also adapts to the executor environment automatically:

- GUI parent: uses `gethui()` when the executor exposes it (draws above the
  game's own UI), falls back to `PlayerGui`, with `pcall` guards so a hostile
  `gethui` cannot break loading.
- Cherry cursor: **on by default** — the Roblox pointer is replaced the moment
  the chunk runs (see §1.5).
- Config storage: file mode uses `writefile`/`readfile`, clipboard uses
  `setclipboard` — each one degrades gracefully when missing (§1.6).

### 1.2 Load the library

**Option A — straight from GitHub (most common).** After the repo is public
(see Part 2), one line:

```lua
local CherryUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/Cherry-UI/main/dist/CherryUI.lua"))()
```

> Use the `raw.githubusercontent.com` URL, not a `github.com/.../blob/...` page
> link — `HttpGet` downloads the page HTML from a blob URL and `loadstring`
> fails on it. The "Raw" button in the file viewer gives you the right URL.

**Option B — from a release asset.** Download `dist/CherryUI.lua` from the
GitHub Releases page, drop it into the executor's workspace folder, then:

```lua
local CherryUI = loadstring(readfile("CherryUI.lua"))()
```

**Option C — paste manually.** Open `dist/CherryUI.lua` in an editor, copy all
of it, paste into the executor's script box, execute. Same result, no network.

To guard against double-loading (e.g. two scripts both pulling the URL):

```lua
local CherryUI = getgenv().CherryUI
if not CherryUI then
    CherryUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/Cherry-UI/main/dist/CherryUI.lua"))()
end
```

### 1.3 Minimal menu

```lua
local CherryUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/Cherry-UI/main/dist/CherryUI.lua"))()

local Window = CherryUI:CreateWindow({
    Title = "My Script",
    Subtitle = "v1.0",
    ToggleKey = Enum.KeyCode.RightShift, -- default; rebind in Settings or here
})

Window:AddTab("Combat", "◎", function(tab)
    local section = tab:AddSection("Aimbot")
    local master = section:AddToggle({ Name = "Enable Aimbot" })
    section:AddSlider({ Name = "FOV", Min = 10, Max = 360, Default = 90, Suffix = "°" }):AddDependency(master)
end)

CherryUI:Notify({ Title = "Loaded", Content = "Press RightShift to open the menu.", Type = "success", Duration = 4 })
```

### 1.4 The full demo menu

[`src/Example.lua`](src/Example.lua) is a complete FPS menu (aimbot, triggerbot,
ESP preview, player list, settings, notifications). It detects *all three*
install styles, so in an executor you simply run the bundle first, then paste
the example unchanged into the same chunk (or a second script — it picks the
library up from `getgenv().CherryUI`).

Fastest way to get a combined file:

```bash
python3 tools/bundle.py --include-example --out /tmp/CherryUIDemo.lua
```

paste *that* into the executor and execute.

### 1.5 The cherry cursor

Loading Cherry UI replaces the default Roblox pointer with the animated cherry
cursor — this happens as soon as the chunk executes, before any window exists.

```lua
CherryUI:SetCursorMode("always")  -- default: cherry pointer everywhere
CherryUI:SetCursorMode("menu")    -- cherry only while a Cherry UI window is open
CherryUI:SetCursorMode("off")     -- restore the Roblox cursor entirely
CherryUI:ResetCursor()            -- same as "off"; handy after a hard script stop
```

You can also set it per window: `CherryUI:CreateWindow({ Cursor = "menu" })`.

If another script of yours needs the system pointer (drawing ESP lines with
`Mouse.Icon`, for example), switch to `"off"` or `"menu"` rather than fighting
the cursor module.

### 1.6 Executor-only features

**Config to disk** — `writefile`/`readfile` power JSON persistence:

```lua
CherryUI.Config:SetMode("file", { Path = "MyScript/config.json" })
CherryUI:SaveConfig()   -- writes toggles, sliders, keybinds, theme
CherryUI:LoadConfig()   -- restores them on next execution
```

If `writefile` is unavailable the library warns once and keeps the config in
memory for the session — nothing errors.

**Clipboard** — the player list's "copy name" action calls `setclipboard`
when the executor provides it; otherwise it falls back to a notification.

**Notifications from your own code:**

```lua
CherryUI:Notify({
    Title = "Kill confirmed",
    Content = "Target eliminated at 214 studs.",
    Type = "success",          -- "success" | "warning" | "error" | info (default)
    Icon = "✓",
    Duration = 4,              -- seconds
})
```

### 1.7 Executor troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `loadstring` is nil | Your executor disabled it. Enable "loadstring" / "Http Requests" in its settings, or use paste-in (Option C). |
| `HttpGet` returns HTML / syntax error near top of file | You used the `blob` page URL. Use `raw.githubusercontent.com/.../main/dist/CherryUI.lua`. |
| Nothing appears, no errors | The executor hid the GUI differently. The library already tries `gethui()` → `PlayerGui`; if your executor uses a custom container, create the window with your own parent via the executor's API or report it. |
| Window opens but the Roblox cursor still shows | Another script reset `Mouse.Icon`. Cherry re-applies on theme/visibility changes; call `CherryUI:SetCursorMode("always")` to force it. |
| Menu key does nothing | A TextBox is focused (typing captures keys), or another script bound the same key. `CherryUI:SetToggleKey(Enum.KeyCode.RightControl)` to move it. |
| Config never persists | `writefile` missing (§1.6), or the folder doesn't exist — pass a path whose folder the executor can create, e.g. `"MyScript/config.json"`. |
| Two menus after re-execute | You loaded the chunk twice. Reuse `getgenv().CherryUI` (§1.2 guard), or call `CherryUI:Destroy()` on the old instance first. |
| UI vanishes on respawn | It cannot — the ScreenGui sets `ResetOnSpawn = false`. If it happens, another script destroyed your `gethui` container. |

---

## Part 2 — Publishing to GitHub

The executor story depends on one thing: `dist/CherryUI.lua` reachable at a
stable raw URL on a public repo. Publishing is four phases: **verify → commit →
push → release.**

### 2.1 Verify before you publish

The bundle in `dist/` is *generated* — a stale one is the classic "works in
Studio, broken in executor" bug, because Studio syncs `src/` and executors run
`dist/`.

```bash
cd "cherry UI library"

# 1. Rebuild the bundle from current src/ — always do this first
python3 tools/bundle.py                   # writes dist/CherryUI.lua

# 2. Compile-check every module (Luau, not vanilla Lua)
fail=0; for f in $(find src -name '*.lua' | sort); do
  luau-compile --binary "$f" >/dev/null || { echo "FAIL $f"; fail=1; }
done; echo "compile fail=$fail"           # expect: compile fail=0

# 3. Syntax-check the generated chunk itself
luau-compile --binary dist/CherryUI.lua >/dev/null && echo "bundle OK"
# expect: bundle OK
# (don't *run* the bundle outside Roblox — it calls game:GetService, which
#  only exists in Studio or an executor)

# 4. Secret scan — never publish tokens
grep -rniE "api[_-]?key|token|secret|password" --include="*.lua" --include="*.json" --include="*.md" .
```

Bump the version when releasing: `self.Version` in
[`src/init.lua`](src/init.lua) (the bundler stamps it into the bundle header),
then rebuild once more.

### 2.2 First-time repo setup

```bash
# One-time identity (this machine may not have one yet)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

git init -b main
git add .
git status --short                         # eyeball it: no build/, no .DS_Store, no .freebuff/
git commit -m "Cherry UI 1.0.0: performance-focused Roblox UI library"
```

What belongs in git: `src/`, `dist/CherryUI.lua` (**yes — committed**, it is the
artifact executors download), `tools/`, docs, project files, `LICENSE`.
What is ignored: `build/` and `*.rbxm` (release assets are attached to the
release, not committed), `sourcemap.json`, `.freebuff/`, `.DS_Store` — see
[`.gitignore`](.gitignore).

### 2.3 Create the remote and push

**Web UI:** github.com → **New repository** → `Cherry-UI`, public, and create it
**without** README/.gitignore/license (this repo already has all three). Then:

```bash
git remote add origin https://github.com/YOUR_NAME/Cherry-UI.git
git push -u origin main
```

**Or `gh` CLI** (`brew install gh && gh auth login` first):

```bash
gh repo create Cherry-UI --public --source=. --remote=origin --push \
  --description "A high-performance, cherry-picked UI library for Roblox FPS games"
```

Authentication (token or browser flow) is the one step that needs you at the
keyboard.

**Immediately after the first push**, replace the `YOUR_NAME` placeholder in
the `loadstring` snippets with your real GitHub username, in:

- this file (§1.2, §1.3),
- [`README.md`](README.md) quick start,
- [`setup.md`](setup.md) §2 Option D.

That URL is now the library's public entry point — every executor user runs
exactly that line, so keep the path stable (`main` branch, `dist/CherryUI.lua`).

### 2.4 Tag and cut a release

Releases give users two download buttons and pin a version. Attach **both**
assets — `.rbxm` for Studio users, `.lua` for executor users:

```bash
mkdir -p build
rojo build model.project.json -o build/CherryUI.rbxm   # Studio model asset
python3 tools/bundle.py                                # refresh dist/CherryUI.lua

git add src dist/CherryUI.lua
git commit -m "Cherry UI v1.1.0"
git tag -a v1.1.0 -m "Cherry UI v1.1.0"
git push origin main v1.1.0

# with gh:
gh release create v1.1.0 build/CherryUI.rbxm dist/CherryUI.lua \
  --title "Cherry UI v1.1.0" \
  --notes "…what changed…"

# without gh: Repo → Releases → Draft a new release → pick the tag
#             → drag both files into Assets → Publish
```

Users then load a pinned version instead of `main`:

```lua
local CherryUI = loadstring(game:HttpGet("https://github.com/YOUR_NAME/Cherry-UI/releases/download/v1.1.0/CherryUI.lua"))()
```

### 2.5 The everyday loop afterwards

```bash
# ... edit src/Components/Slider.lua etc., test in Studio with rojo serve
# ... and in an executor with:  python3 tools/bundle.py  → paste dist/CherryUI.lua

git add src dist/CherryUI.lua
git commit -m "Slider: clamp value on focus loss"
git push
```

Rule of thumb: **every commit that touches `src/` also commits the rebuilt
`dist/CherryUI.lua`.** If you forget, executor users silently run old code —
rebuild and amend or follow up with a "Rebuild bundle" commit.

### 2.6 Repo polish (5 minutes, worth it)

- **Topics**: `roblox` `roblox-ui` `ui-library` `luau` `rojo` `fps` `gui`.
- **License**: GitHub auto-detects MIT from `LICENSE`.
- **Social preview**: 1280×640 image — logo plus a window capture.
- **Screenshots**: README currently uses vector mockups
  (`docs/screenshot_*.svg`); swap in real captures when you have them.
- **Keep `USER`/`YOUR_NAME` placeholders out** of the final published docs —
  search for them before the first push:

  ```bash
  grep -rn "YOUR_NAME\|USER/" README.md setup.md EXECUTORS.md
  ```

---

## Cheat sheet

| Task | Command / line |
| --- | --- |
| Rebuild the executor bundle | `python3 tools/bundle.py` |
| Bundle + demo menu in one file | `python3 tools/bundle.py --include-example --out /tmp/CherryUIDemo.lua` |
| Build the Studio model asset | `rojo build model.project.json -o build/CherryUI.rbxm` |
| Load in an executor | `loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/Cherry-UI/main/dist/CherryUI.lua"))()` |
| Publish changes | rebuild bundle → `git add src dist` → commit → `git push` |
| Cut a version | bump `Version` in `src/init.lua` → rebuild → tag → `gh release create …` |

Questions about Studio/Rojo usage belong in [setup.md](setup.md); the
component-by-component API reference is there too (§7).
