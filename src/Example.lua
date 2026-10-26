--[[
	Example.lua
	A complete, FPS-themed Cherry UI menu.

	Place this LocalScript in StarterPlayerScripts (or StarterGui) and make sure
	the CherryUI module is at ReplicatedStorage.CherryUI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CherryUI = require(ReplicatedStorage:WaitForChild("CherryUI"))

local Window = CherryUI:CreateWindow({
	Title = "Cherry",
	Subtitle = "FPS Suite · v" .. CherryUI.Version,
	Size = UDim2.fromOffset(640, 460),
	ToggleKey = Enum.KeyCode.RightShift,
})

--------------------------------------------------------------------------
-- Combat
--------------------------------------------------------------------------

Window:AddTab("Combat", "◎", function(tab)
	local aim = tab:AddSection("Aimbot")
	local aimMaster = aim:AddToggle({
		Name = "Enable Aimbot",
		Default = false,
		Callback = function(enabled)
			print("[Cherry] Aimbot:", enabled)
		end,
	})

	aim:AddSlider({
		Name = "Field of View",
		Min = 10,
		Max = 360,
		Default = 90,
		Suffix = "°",
	}):AddDependency(aimMaster)

	aim:AddSlider({
		Name = "Smoothing",
		Min = 0,
		Max = 1,
		Default = 0.18,
		Decimals = 2,
	}):AddDependency(aimMaster)

	aim:AddDropdown({
		Name = "Hitbox",
		Options = { "Head", "Torso", "Nearest" },
		Default = "Head",
	}):AddDependency(aimMaster)

	aim:AddKeybind({
		Name = "Aim Key",
		Default = Enum.KeyCode.E,
	}):AddDependency(aimMaster)

	local trigger = tab:AddSection("Triggerbot")
	local triggerMaster = trigger:AddToggle({ Name = "Enable Triggerbot", Default = false })
	trigger:AddSlider({
		Name = "Delay",
		Min = 0,
		Max = 250,
		Default = 45,
		Suffix = " ms",
	}):AddDependency(triggerMaster)
	trigger:AddSlider({
		Name = "Hit Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = "%",
	}):AddDependency(triggerMaster)

	local weapon = tab:AddSection("Weapon")
	weapon:AddToggle({ Name = "No Recoil", Default = true })
	weapon:AddToggle({ Name = "No Spread", Default = true })
	weapon:AddToggle({ Name = "Instant Reload", Default = false })
	weapon:AddButton({
		Name = "Reset Weapon Settings",
		Variant = "Secondary",
		Callback = function()
			CherryUI:Notify({
				Title = "Weapon settings reset",
				Content = "Recoil, spread and reload are back to defaults.",
				Type = "success",
				Icon = "✓",
			})
		end,
	})
end)

--------------------------------------------------------------------------
-- Visuals + live ESP preview
--------------------------------------------------------------------------

Window:AddTab("Visuals", "◈", function(tab)
	local preview = tab:AddESPPreview({
		Name = "ESP Preview",
		Height = 300,
	})

	local esp = tab:AddSection("Player ESP")
	local espMaster = esp:AddToggle({ Name = "Enable ESP", Default = true })

	esp:AddColorPicker({
		Name = "ESP Color",
		Default = CherryUI.Palette.Primary,
		Callback = function(color)
			preview:SetColor(color)
		end,
	}):AddDependency(espMaster)

	esp:AddDropdown({
		Name = "Elements",
		Multi = true,
		Options = { "Box", "Name", "Health", "Distance", "Tracer" },
		Default = { "Box", "Name", "Health" },
	}):AddDependency(espMaster)

	esp:AddSlider({
		Name = "Max Distance",
		Min = 50,
		Max = 2000,
		Default = 500,
		Step = 50,
		Suffix = " studs",
	}):AddDependency(espMaster)

	esp:AddDropdown({
		Name = "Team Check",
		Options = { "Enemy", "Everyone", "Team" },
		Default = "Enemy",
	}):AddDependency(espMaster)

	-- Hook the preview into a real ESP implementation.
	preview:OnChanged(function(settings)
		-- settings.Highlight / Box / Tracer / Name, settings.Color, settings.Target
		print("[Cherry] ESP preview:", settings.Box, settings.Tracer, settings.Color)
	end)

	local world = tab:AddSection("World")
	world:AddToggle({ Name = "Fullbright", Default = false })
	world:AddToggle({ Name = "Remove Fog", Default = false })
	world:AddSlider({
		Name = "Field of View",
		Min = 60,
		Max = 120,
		Default = 70,
		Suffix = "°",
	})
end)

--------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------

local playersTab = Window:AddTab("Players", "☰")
local playerList = playersTab:AddPlayerList({ Height = 340 })

local teleportRemote = ReplicatedStorage:FindFirstChild("TeleportRequest")
playerList:SetAction("teleport", function(player)
	if teleportRemote and teleportRemote:IsA("RemoteEvent") then
		teleportRemote:FireServer(player)
	else
		CherryUI:Notify({
			Title = "Teleport unavailable",
			Content = "Add a TeleportRequest RemoteEvent to enable this action.",
			Type = "warning",
		})
	end
end)

playersTab:AddSection("Notes"):AddLabel(
	"Teleport needs a server-side handler. Copy also needs executor clipboard access."
)

--------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------

Window:AddTab("Settings", "⚙", function(tab)
	local appearance = tab:AddSection("Appearance")
	local themeDropdown = appearance:AddDropdown({
		Name = "Theme",
		Options = CherryUI:GetThemeNames(),
		Default = CherryUI.ThemeManager.Name,
		Callback = function(theme)
			CherryUI:SetTheme(theme)
		end,
	})
	-- Keep the dropdown in sync with the theme dots / loaded config.
	CherryUI.ThemeManager.Changed:Connect(function(theme)
		themeDropdown:SetValue(theme, true)
	end)

	local menuKey = appearance:AddKeybind({
		Name = "Menu Key",
		Default = CherryUI.ToggleKey,
		Callback = function(key)
			CherryUI:SetToggleKey(key)
		end,
	})
	-- Keep the pill in sync when the key is changed elsewhere (e.g. config load).
	CherryUI:OnToggleKeyChanged(function(key)
		menuKey:SetValue(key, true)
	end)

	local notifications = tab:AddSection("Notifications")
	notifications:AddButton({
		Name = "Success Notification",
		Variant = "Primary",
		Callback = function()
			CherryUI:Notify({
				Title = "Injected",
				Content = "Cherry UI loaded successfully.",
				Type = "success",
				Icon = "✓",
				Duration = 4,
			})
		end,
	})
	notifications:AddButton({
		Name = "Warning Notification",
		Variant = "Secondary",
		Callback = function()
			CherryUI:Notify({
				Title = "Unsaved changes",
				Content = "Your config has unsaved changes.",
				Type = "warning",
				Icon = "!",
				Duration = 4,
			})
		end,
	})
	notifications:AddButton({
		Name = "Danger Notification",
		Variant = "Danger",
		Callback = function()
			CherryUI:Notify({
				Title = "Kick detected",
				Content = "The server rejected your last action.",
				Type = "error",
				Icon = "×",
				Duration = 5,
			})
		end,
	})

	local config = tab:AddSection("Config")
	config:AddDropdown({
		Name = "Storage",
		Options = { "Memory", "File" },
		Default = "Memory",
		Callback = function(value)
			if value == "File" then
				CherryUI.Config:SetMode("file", { Path = "CherryUI/config.json" })
			else
				CherryUI.Config:SetMode("memory")
			end
		end,
	})
	config:AddButton({
		Name = "Save Config",
		Variant = "Primary",
		Callback = function()
			local ok = CherryUI:SaveConfig()
			CherryUI:Notify({
				Title = ok and "Config saved" or "Save failed",
				Content = ok and "Your settings were written to storage." or "Check the console for details.",
				Type = ok and "success" or "error",
			})
		end,
	})
	config:AddButton({
		Name = "Load Config",
		Variant = "Secondary",
		Callback = function()
			local ok = CherryUI:LoadConfig()
			CherryUI:Notify({
				Title = ok and "Config loaded" or "Nothing to load",
				Content = ok and "Your saved settings were applied." or "Save a config first.",
				Type = ok and "success" or "warning",
			})
		end,
	})
	config:AddButton({
		Name = "Reset Config",
		Variant = "Danger",
		Callback = function()
			CherryUI:ResetConfig()
			CherryUI:Notify({ Title = "Config reset", Content = "Defaults restored.", Type = "warning" })
		end,
	})

	local input = tab:AddSection("Input Test")
	input:AddTextBox({
		Name = "Walk Speed",
		Numeric = true,
		Min = 8,
		Max = 100,
		Default = 16,
		Callback = function(value)
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = value
			end
		end,
	})
	input:AddSlider({
		Name = "Transparency",
		Min = 0,
		Max = 1,
		Default = 0.5,
		Decimals = 2,
	})
end)

--------------------------------------------------------------------------
-- Welcome
--------------------------------------------------------------------------

CherryUI:Notify({
	Title = "Cherry UI " .. CherryUI.Version,
	Content = "Press RightShift to toggle the menu. Use the search bar to filter settings.",
	Icon = "◈",
	Duration = 6,
})
