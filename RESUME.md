# Cherry UI — Resume Guide

Where the project stands, how to get it back into Roblox Studio with the **Rojo
plugin**, and how to **publish it to GitHub**.

If you only want to *use* the library, read [README.md](README.md) and
[setup.md](setup.md) first. This file is the maintenance/handoff counterpart:
it is about the development loop and shipping the repo.

---

## 0. 60-second resume checklist

```bash
cd "/Users/shauryaveerroy/Desktop/cherry UI library"   # repo root (has a space — quote it)

rojo --version                                          # expect Rojo 7.4+
rojo build default.project.json -o /tmp/CherryUI-Check.rbxlx   # place smoke test
mkdir -p build && rojo build model.project.json -o build/CherryUI.rbxm   # release asset
rojo plugin install                                     # Studio plugin (only once)
rojo serve                                              # leave this running
```

Then in Studio: **Plugins → Rojo → Connect** (`localhost:34872`), open your
Cherry UI LocalScript, and press **Play**. Press **RightShift** in-game to toggle
the menu.

State at the time of writing:

| Item | Status |
| --- | --- |
| Source | 31 Lua modules under [`src/`](src) (library + 5 themes + demo) |
| Toolchain | Rojo **7.7.1** via Rokit (`~/.rokit/bin/rojo`); [`aftman.toml`](aftman.toml) pins the same version |
| Project files | [`default.project.json`](default.project.json) (place) and [`model.project.json`](model.project.json) (release model) — both build cleanly |
| Static checks | 31/31 files compile with the official Luau compiler; properties/enums checked against Roblox's API dump |
| Runtime check | Mocked-runtime harness passed (tabs, controls, themes, config, teardown) — **not** committed, see §4 |
| Git | **Not initialised yet.** No `.git`, no remote, no `gh` CLI on this machine |
| Not verified | A real Studio session (visual layout, drag feel, Studio-only rendering) |

---

## 1. Toolchain

| Tool | Why | This machine |
| --- | --- | --- |
| **Rojo 7.x** | Turns `src/*.lua` into Roblox instances | `rojo 7.7.1` in `~/.rokit/bin` |
| **Roblox Studio + Rojo plugin** | The other half of live sync | install (see §2.1) |
| **git 2.5x** | Version control / GitHub | `git 2.54.0` ✅ |
| `gh` (optional) | Create repos and releases from the terminal | not installed — see §5.4 |

Install or re-pin Rojo:

```bash
rokit add rojo-rbx/rojo@7.7.1     # or: aftman install   (reads aftman.toml)
# or: cargo install rojo --version 7.7.1
```

`rojo --help` and each subcommand (`serve`, `build`, `plugin`, `sourcemap`) have
`--help`; when a flag looks different from a tutorial, trust `--help` — Rojo has
changed CLI surface between versions.

---

## 2. The Rojo plugin, end to end

### 2.1 Install the Studio plugin

Two options, pick one:

```bash
rojo plugin install      # writes the plugin into Studio's local plugins folder
# macOS: ~/Documents/Roblox/Plugins
```

- If Studio was already open, **restart it** after installing.
- Alternative: install **Rojo** (by `rojo-rbx`) from the Studio **Creator Store**
  — that is what most tutorials show and works across platforms.
- Keep the plugin version and the CLI version on the same major (7.x). A CLI/plugin
  mismatch usually shows up as "Server's protocol version" / "Project format"
  errors on connect.

### 2.2 Start the server

From the repo root:

```bash
rojo serve
```

Expected banner:

```
Rojo server listening:
  Address: localhost
  Port:    34872

Visit http://localhost:34872/ in your browser for more information.
```

Useful variants:

```bash
rojo serve --port 34873          # when 34872 is already taken
rojo serve model.project.json    # serve a different project file
```

The server watches the filesystem: **saving a `.lua` file is what triggers a
sync.** You can also open `http://localhost:34872` in a browser to confirm the
server is alive.

### 2.3 Connect in Studio

1. Studio → **Plugins** tab → **Rojo**.
2. The panel defaults to `localhost` / `34872`; click **Connect**.
3. Once connected, the project tree appears: `ReplicatedStorage.CherryUI`
   (a **ModuleScript**) with `Components`, `Core`, `Themes`, `Utils` children.
4. Edit `src/init.lua` on disk, save, and watch Studio update within a second.

If the panel lists an old connection, **Disconnect** first — a stale session is
the usual cause of "nothing syncs".

### 2.4 The two project files

| File | Root | Result | Used for |
| --- | --- | --- | --- |
| [`default.project.json`](default.project.json) | `DataModel` | `ReplicatedStorage.CherryUI` inside a **place** | `rojo serve` during development, `rojo build` for a test place |
| [`model.project.json`](model.project.json) | *(model)* | a single **ModuleScript `CherryUI`** with the library inside | the `CherryUI.rbxm` release asset |

Both are tiny and map the same source folder:

```jsonc
// default.project.json — a place
{ "name": "CherryUI",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": { "CherryUI": { "$path": "src" } }
  } }
```

```jsonc
// model.project.json — a model
{ "name": "CherryUI",
  "tree": { "$path": "src" } }
```

`src/init.lua` is what makes `src/` become a **ModuleScript** rather than a
Folder — that is Rojo's `init.lua` rule, and the reason `require(script.Utils.Create)`
style paths in the source line up with the synced tree.

> **Why `DataModel`?** Studio only allows *place* sync when the project's root is
> a `DataModel`. With a `Folder` root, `rojo serve` refuses with:
> *"Cannot sync a model as a place. Ensure Rojo is serving a project file that has
> a DataModel at the root of its tree."* That error was the previous failure in
> this repo and is already fixed — if you see it again, you are serving the wrong
> project file (`model.project.json` is a model on purpose).

**Important:** a place project manages the tree it declares. Manual edits made in
Studio *inside* `ReplicatedStorage.CherryUI` are overwritten on the next sync —
change files in `src/` instead. Keep unrelated code out of that one folder, and
let git (not Studio) be the source of truth.

### 2.5 Running the demo

[`src/Example.lua`](src/Example.lua) is a full FPS menu, but Rojo syncs it as a
**ModuleScript** inside the library, so it never auto-runs. Either:

- **Paste it** into a `LocalScript` under
  `StarterPlayer/StarterPlayerScripts` (what [setup.md](setup.md) documents), or
- **Require it** from a two-line loader LocalScript:

  ```lua
  -- StarterPlayer/StarterPlayerScripts/CherryDemo
  require(game:GetService("ReplicatedStorage"):WaitForChild("CherryUI").Example)
  ```

  The example body has no `return`, so requiring it executes the menu and yields
  `nil`; `require` caches it, so it runs once per session. It ships inside the
  release model too — if you want a leaner `CherryUI.rbxm`, delete `Example` from
  the built model or drop `src/Example.lua` before building.

### 2.6 What maps to what

| On disk | In Studio |
| --- | --- |
| `foo.lua` | `ModuleScript` named `foo` |
| `foo.client.lua` | `LocalScript` |
| `foo.server.lua` | `Script` |
| `init.lua` in a folder | turns that folder into a `ModuleScript` |
| any directory | `Folder` |
| `*.model.json` | instances (great for a `RemoteEvent`, etc.) |
| `*.rbxmx` / `*.rbxm` | a model |

Live sync cannot set every property (Terrain/CSG, `MeshPart.MeshId`,
`HttpService.HttpEnabled`, …). For those, `rojo build` a place and open it.

---

## 3. Rojo troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `Cannot sync a model as a place` | Serving a model project (e.g. `model.project.json`). Serve `default.project.json`, then reconnect. |
| `Failed to parse project file` | JSON syntax error in the project file — trailing comma or comment. Validate: `python3 -m json.tool default.project.json`. |
| `error: Address already in use` | Another `rojo serve` (or a previous session) owns 34872. Reuse it, or `rojo serve --port 34873` and connect to that port. |
| Plugin connects but nothing appears | Connected to a different project/port, or you are looking in the wrong place — the tree lives **under `ReplicatedStorage`**, not at the top of Explorer. |
| Plugin spins forever / "Connection refused" | `rojo serve` is not running, or the firewall is blocking it. Re-run the serve command and read its banner. |
| Edits in Studio vanish | Place sync overwrites managed instances; edit `src/` instead. |
| Changes are not picked up | Save the file, and make sure the path you edited is the one the project maps (`src/`, not a copy). |
| Weird behaviour after editing the project file | Studio reconnect **and** restart `rojo serve` — the project file is read at startup. |
| `.DS_Store` in `git status` | macOS metadata. Rojo ignores file types it doesn't know, and [`.gitignore`](.gitignore) keeps them out of commits. |
| Plugin missing from the Plugins tab | Studio was open during `rojo plugin install`; restart Studio. |
| `No such file or directory` when building | Rojo will not create the output folder. `mkdir -p build` first. |
| Paths with spaces (`cherry UI library`) | Fine for Rojo and git, but quote them in the shell. |

---

## 4. Checking changes without Studio

Fast static loop (no plugins, no Studio):

```bash
# 1. Compile every module with the official Luau compiler
curl -sL -o /tmp/luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-macos.zip
mkdir -p /tmp/luaubin && unzip -o -q /tmp/luau.zip -d /tmp/luaubin
fail=0; for f in $(find src -name '*.lua' | sort); do
  /tmp/luaubin/luau-compile --binary "$f" >/dev/null || { echo "FAIL $f"; fail=1; }
done; echo "compile fail=$fail"       # expect: compile fail=0

# 2. Build smoke test — catches project-file and tree errors
rojo build default.project.json -o /tmp/CherryUI-Check.rbxlx
# expect "31 ModuleScript" + "4 Folder" instances in the output

# 3. For editor/IDE intelligence (Roblox types, not just Lua)
rojo sourcemap default.project.json -o sourcemap.json
```

`luau-analyze` also runs, but on its own it flags `game`, `Instance` and
`EnumItem` as unknown, because those come from Roblox. Point
[luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) at the `sourcemap.json`
above for real Roblox-aware diagnostics; plain `luau-analyze` output is expected
noise unless you feed it Roblox definitions.

A mocked-runtime harness (fake `Instance.new`, `TweenService`, `Players`, …) was
used to execute every constructor and lifecycle path once; it lives outside the
repo and is deliberately not committed. Re-create it if you touch construction
logic, otherwise §2.3's Play test is the practical check.

---

## 5. Publishing to GitHub

### 5.1 One-time git identity

This machine has no global git identity yet, so the first commit would fail:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### 5.2 Prepare the repo

Already in place: [`LICENSE`](LICENSE) (MIT), [`README.md`](README.md),
[`setup.md`](setup.md), [`RESUME.md`](RESUME.md), `docs/` (logo + mockups),
[`default.project.json`](default.project.json), [`model.project.json`](model.project.json),
[`aftman.toml`](aftman.toml), and [`.gitignore`](.gitignore) which keeps
`.DS_Store`, `.freebuff/`, `build/`, `sourcemap.json` and Roblox binaries out.

Before committing, sanity-check what you are about to publish:

```bash
grep -rniE "api[_-]?key|token|secret|password" --include="*.lua" --include="*.json" --include="*.md" .
```

### 5.3 First commit

```bash
cd "/Users/shauryaveerroy/Desktop/cherry UI library"
git init -b main
git add .
git status --short                              # eyeball the list before committing
git check-ignore -v .DS_Store build/CherryUI.rbxm   # both should be ignored
git commit -m "Cherry UI 1.0.0: performance-focused Roblox UI library

Library, five themes, ESP preview, player list, config saving and docs."
```

### 5.4 Create the remote

**Option A — GitHub web UI (no extra tools):**

1. github.com → **New repository** → name `Cherry-UI`, public, **no** README /
   .gitignore / license (the repo already has them).
2. Copy the two commands GitHub shows:

```bash
git remote add origin https://github.com/<you>/Cherry-UI.git
git push -u origin main
```

**Option B — `gh` CLI** (not installed here; `brew install gh` then `gh auth login`):

```bash
gh repo create Cherry-UI --public --source=. --remote=origin --push \
  --description "A high-performance, cherry-picked UI library for Roblox FPS games"
```

With either option you now have `origin/main` pushed. Authentication prompts for
a personal access token or the browser flow — that is the one step that needs you
at the keyboard.

### 5.5 Repo polish that actually matters

- **Description**: “A high-performance, cherry-picked UI library for Roblox FPS games.”
- **Topics**: `roblox` `roblox-ui` `ui-library` `luau` `lua` `rojo` `fps` `gui`.
- **License**: GitHub should auto-detect MIT from `LICENSE`.
- **Screenshots**: `README.md` currently points at `docs/screenshot_main.svg` and
  `docs/screenshot_esp.svg` (vector mockups). Replace them with real Studio
  captures (`docs/screenshot_main.png`) once you have them, and keep the old files
  or delete them — nothing else references them.
- **Social preview**: Settings → General → Social preview, upload a 1280×640
  image (the logo + a window capture works well).

### 5.6 Tag and release the model asset

The release is what `setup.md` “Option C” tells users to download, so attach the
built model, not the source:

```bash
mkdir -p build
rojo build model.project.json -o build/CherryUI.rbxm

git tag -a v1.0.0 -m "Cherry UI v1.0.0"
git push origin v1.0.0

# with gh:
gh release create v1.0.0 build/CherryUI.rbxm \
  --title "Cherry UI v1.0.0" \
  --notes "First release: window, tabs, sections, eight controls, five themes, live ESP preview, player list, config saving, search, dependency boxes."
```

Without `gh`: push the tag, then Repo → **Releases → Draft a new release** → choose
`v1.0.0` → drag `build/CherryUI.rbxm` into the assets box → Publish.

Build outputs are gitignored on purpose: the `.rbxm` belongs in the release, not
in a commit.

### 5.7 The everyday loop afterwards

```bash
rojo serve                       # in one terminal, while you work in Studio
# ... edit src/*.lua, test with RightShift in-game ...

git add src setup.md README.md
git commit -m "Slider: clamp value on focus loss"
git push
```

Never commit `.freebuff/`, Studio autosaves, or generated `build/` output.

---

## 6. If something is confusing

| I want to… | Read |
| --- | --- |
| Load the library in a game | [README.md](README.md) quick start |
| Install manually / without plugins | [setup.md](setup.md) §2 Option B |
| Every component's API | [setup.md](setup.md) §7 cheat sheet |
| Sync with Rojo, fix Rojo errors | this file §2–§3 |
| Publish to GitHub | this file §5 |
