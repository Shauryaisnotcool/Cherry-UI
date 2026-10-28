# Using icons8 icons with Cherry UI

Cherry UI ships hand-drawn vector icons so it works with zero uploads. If you
prefer [icons8](https://icons8.com)'s raster set, you can point any icon name at
your own uploaded image — the whole library (tabs, close button, search,
dropdown chevrons/checks, notification types) picks it up.

> **Roblox cannot load `https://img.icons8.com/...` directly.** `ImageLabel.Image`
> only accepts Roblox assets (`rbxassetid://...`). A raw URL is blocked or shows
> as a broken image, so every icon has to be downloaded and uploaded to Roblox
> once. There is no way around that — it is a Roblox platform rule, not a
> Cherry UI limitation.

---

## 1. Pick and download the icons

Use the **PNG**, **100 px**, **white** (or any single flat colour) version of each
icon. Flat white strokes are best because Cherry UI tints icons with
`ImageColor3`, so they follow the active theme. Skip the coloured 3D style.

Recommended icons8 search terms for the built-in names:

| Cherry UI name | Used for | icons8 search |
| --- | --- | --- |
| `target` | Combat tab | `crosshair` |
| `layers` | Visuals tab | `layers` |
| `players` | Players tab | `conference call` |
| `settings` | Settings tab | `settings` |
| `eye` | Spectate | `eye` |
| `search` | Search box | `search` |
| `close` | Window close | `delete` / `close` |
| `check` | Dropdown selection | `checkmark` |
| `chevron` | Dropdown arrow | `chevron down` |
| `refresh` | Player list refresh | `refresh` |
| `copy` | Copy name | `copy` |
| `diamond` | Notifications | `diamond` |
| `info` | Info notice | `info` |
| `warning` | Warning notice | `error` |
| `success` | Success notice | `checkmark` |
| `error` | Error notice | `cancel` |

## 2. Upload each PNG to Roblox

**Studio:** `View → Asset Manager → Images → Upload`, or drag the PNG into the
Explorer's Images folder.

**Browser:** [Creator Dashboard → Creations → Development Items → Upload
Image](https://create.roblox.com/dashboard/creations?activeTab=Image).

After moderation (seconds to minutes) the asset gets an id: the number in its
URL, e.g. `https://www.roblox.com/library/1234567890/icon` → `1234567890`.

Use it as `"rbxassetid://1234567890"`.

> For other players to see an image it must be **public** or owned by them. In an
> executor only your own client renders it, so a private upload works there.

## 3. Register the ids

Copy [`icons8.lua`](icons8.lua), fill in the ids, and run it **immediately after
loading Cherry UI, before `CreateWindow`** (icons are real frames, so kinds
rendered earlier keep the drawn version):

```lua
local CherryUI = getgenv().CherryUI
local pack = loadstring(game:HttpGet("<raw url>/docs/icons8/icons8.lua"))()
CherryUI:SetIcons(pack)
```

Or inline:

```lua
CherryUI:SetIcons({
    target  = "rbxassetid://1111111111",
    layers  = "rbxassetid://2222222222",
    players = "rbxassetid://3333333333",
    settings = "rbxassetid://4444444444",
    close   = "rbxassetid://7777777777",
})
```

Names you leave out keep the drawn icon, so you can convert one tab at a time.
An empty string or `nil` also means "keep drawn".

## 4. Per-item overrides

Anywhere an icon is accepted:

```lua
Window:AddTab("Combat", "rbxassetid://1111111111")

CherryUI:Notify({ Title = "Done", Content = "Saved.", Icon = "rbxassetid://8888888888" })
```

## 5. Undo

```lua
local Icons = CherryUI.Icons
Icons.setImage("target", nil)     -- back to the drawn icon
Icons.getImage("target")          -- -> nil
```

## 6. Style tips

- **Keep one stroke weight.** icons8 has "regular", "filled" and "3D" families;
  mixing them looks worse than the drawn set.
- **White on transparent.** Any other colour gets multiplied by the theme tint and
  turns muddy.
- **18–100 px is enough.** Icons are drawn at 14–22 px in the UI; bigger sources
  only cost memory.
- **Squared aspect ratio.** Cherry UI gives image icons a square frame.

## 7. Troubleshooting

| Symptom | Cause |
| --- | --- |
| Red/blank square | Wrong id, asset not approved yet, or not public/owned |
| Icon does not change | `SetIcons` ran *after* the window/tab was built — restart the UI or rebuild that window |
| Icon is a solid block | The PNG is a coloured square; use a transparent white glyph |
| Icon looks blurry | Source PNG smaller than ~48 px |
