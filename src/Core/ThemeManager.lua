--[[
	Core/ThemeManager.lua
	Runtime theme switching with live recoloring.

	Components register their themeable instances with `:Bind`, and the manager
	re-applies the palette when `:SetTheme` is called. Color properties are
	tweened so switching themes feels like part of the UI instead of a hard cut.
	Gradients are handled through `:BindGradient`, which rebuilds the
	ColorSequence from palette tokens.
]]

local Tween = require(script.Parent.Parent.Utils.Tween)
local Signal = require(script.Parent.Parent.Utils.Signal)

local DEFAULT_THEME = "Crimson"
local THEME_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ThemeManager = {}
ThemeManager.__index = ThemeManager

function ThemeManager.new(themes, defaultName)
	local self = setmetatable({}, ThemeManager)

	self.Themes = themes or {}
	self.Name = defaultName or DEFAULT_THEME

	if not self.Themes[self.Name] then
		for name in self.Themes do
			self.Name = name
			break
		end
	end

	self.Palette = {}
	self.Bindings = {}
	self.Changed = Signal.new()
	self._loaded = false

	self:_loadPalette(self.Name)

	return self
end

function ThemeManager:_loadPalette(name)
	local theme = self.Themes[name]
	if not theme then
		return
	end

	-- Start from the base theme so a partial palette still resolves every token.
	local base = self.Themes[DEFAULT_THEME] or theme
	local merged = {}

	for token, color in base do
		if typeof(color) == "Color3" then
			merged[token] = color
		end
	end

	for token, color in theme do
		if typeof(color) == "Color3" then
			merged[token] = color
		end
	end

	table.clear(self.Palette)
	for token, color in merged do
		self.Palette[token] = color
	end

	self.Palette.Accent = self.Palette.Accent or self.Palette.Primary
end

function ThemeManager:GetColor(token)
	return self.Palette[token]
end

function ThemeManager:SetTheme(name, animate)
	if not self.Themes[name] then
		warn("[CherryUI] Unknown theme: " .. tostring(name))
		return false
	end

	if name == self.Name and self._loaded then
		return true
	end

	local previous = {}
	for token, color in self.Palette do
		previous[token] = color
	end

	self.Name = name
	self:_loadPalette(name)
	self._loaded = true

	for index = 1, #self.Bindings do
		local binding = self.Bindings[index]

		if binding.Kind == "property" then
			local color = self.Palette[binding.Token]
			local instance = binding.Instance

			if color and instance then
				if animate and previous[binding.Token] ~= color then
					Tween.play(instance, { [binding.Property] = color }, THEME_TWEEN)
				else
					instance[binding.Property] = color
				end
			end
		elseif binding.Kind == "custom" and binding.Apply then
			binding.Apply(self.Palette)
		end
	end

	self.Changed:Fire(name)
	return true
end

-- Sets the instance's color immediately and keeps it in sync with the theme.
function ThemeManager:Bind(instance, property, token)
	property = property or "BackgroundColor3"
	token = token or "Surface"

	local binding = {
		Kind = "property",
		Instance = instance,
		Property = property,
		Token = token,
	}

	local color = self.Palette[token] or self.Palette.Surface
	if color then
		instance[property] = color
	end

	table.insert(self.Bindings, binding)

	local connection
	connection = instance.Destroying:Connect(function()
		self:Unbind(binding)
		if connection then
			connection:Disconnect()
		end
	end)
	binding.Connection = connection

	return instance
end

function ThemeManager:BindGradient(gradient, tokens)
	local resolved = tokens or { "Primary", "Accent" }
	local owner = gradient

	local binding = self:BindCustom(function(palette)
		local keypoints = {}
		local count = math.max(#resolved, 1)

		for index = 1, count do
			local color = palette[resolved[index]] or palette.Primary or Color3.new(1, 1, 1)
			local time = 0
			if count > 1 then
				time = (index - 1) / (count - 1)
			end
			table.insert(keypoints, ColorSequenceKeypoint.new(time, color))
		end

		gradient.Color = ColorSequence.new(keypoints)
	end, owner)

	binding.Owner = owner
	return binding
end

-- Registers an arbitrary callback that receives the new palette.
-- `owner` (optional) cleans the binding up when the owner is destroyed.
function ThemeManager:BindCustom(apply, owner)
	local binding = {
		Kind = "custom",
		Apply = apply,
		Owner = owner,
	}

	table.insert(self.Bindings, binding)
	apply(self.Palette)

	if owner then
		local connection
		connection = owner.Destroying:Connect(function()
			self:Unbind(binding)
			if connection then
				connection:Disconnect()
			end
		end)
		binding.Connection = connection
	end

	return binding
end

function ThemeManager:Unbind(binding)
	if not binding then
		return
	end

	local index = table.find(self.Bindings, binding)
	if index then
		table.remove(self.Bindings, index)
	end

	if binding.Connection then
		binding.Connection:Disconnect()
		binding.Connection = nil
	end
end

function ThemeManager:Destroy()
	for index = 1, #self.Bindings do
		local binding = self.Bindings[index]
		if binding.Connection then
			binding.Connection:Disconnect()
			binding.Connection = nil
		end
	end

	table.clear(self.Bindings)
	self.Changed:Destroy()
end

return ThemeManager
