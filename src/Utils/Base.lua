--[[
	Utils/Base.lua
	Shared behavior for every Cherry UI control.

	Each control gets a row `Holder` inside its section's card, a `Changed`
	signal, lazy show/hide support for dependencies and search filtering, and a
	consistent `:Destroy()` cleanup path. Controls inherit from this table and
	only implement their visual layer plus `:SetValue()`.
]]

local Create = require(script.Parent.Create)
local Signal = require(script.Parent.Signal)
local Tween = require(script.Parent.Tween)

local Base = {}
Base.__index = Base

local function matches(expected, value)
	if type(expected) == "function" then
		local ok, result = pcall(expected, value)
		return ok and result and true or false
	elseif type(expected) == "table" then
		for _, item in ipairs(expected) do
			if value == item then
				return true
			end
		end
		return false
	end
	return value == expected
end

function Base.new(library, section, kind, config)
	config = config or {}

	local self = setmetatable({}, Base)

	self.Library = library
	self.Section = section
	self.Window = section.Tab.Window
	self.Kind = kind
	self.Name = tostring(config.Name or kind)
	self.Config = config
	self.Default = config.Default
	self.Destroyed = false
	self.Visible = true
	self.SearchMatch = true
	self.ManualVisible = true
	self.Dependencies = {}
	self.RowHeight = config.Height or 34

	self.Changed = Signal.new()
	self._connections = {}

	self.Holder = Create.new("Frame", {
		Name = self.Name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, self.RowHeight),
		ClipsDescendants = true,
		Parent = section.Body,
	})
	self.Holder.LayoutOrder = section:_nextOrder()

	library.Config:Register(self)
	self.SearchEntry = self.Window:RegisterSearchEntry(self)

	return self
end

function Base:GetValue()
	return self.Value
end

--[[
	Stores the value, then fires the public `Changed` signal and the optional
	config callback. `silent` is used by the config manager so restoring a saved
	state does not re-trigger the user's callbacks.
]]
function Base:_commit(value, silent)
	self.Value = value

	if silent then
		return
	end

	self.Changed:Fire(value)

	local callback = self.Config.Callback or self.Config.OnChanged
	if type(callback) == "function" then
		local ok, err = pcall(callback, value)
		if not ok then
			warn("[CherryUI] " .. tostring(self.Kind) .. " callback error: " .. tostring(err))
		end
	end
end

function Base:SetValue(value, silent)
	self:_commit(value, silent)
end

function Base:OnChanged(callback)
	return self.Changed:Connect(callback)
end

function Base:OnThemeChanged(callback)
	self:_track(self.Library.ThemeManager.Changed:Connect(callback))
end

function Base:_track(connection)
	table.insert(self._connections, connection)
	return connection
end

--[[
	Hides this control unless `source:GetValue()` matches `expected`.
	`expected` can be a literal, an array of allowed values, or a predicate.

		local master = section:AddToggle({ Name = "Enable Aimbot" })
		section:AddSlider({ Name = "FOV" }):AddDependency(master)
]]
function Base:AddDependency(source, expected)
	if expected == nil then
		expected = true
	end

	table.insert(self.Dependencies, {
		Source = source,
		Expected = expected,
	})

	self:_track(source.Changed:Connect(function()
		self:UpdateVisibility()
	end))

	self:UpdateVisibility()
	return self
end

function Base:SetVisible(visible)
	self.ManualVisible = visible ~= false
	self:UpdateVisibility()
	return self
end

function Base:UpdateVisibility()
	if self.Destroyed then
		return
	end

	local visible = self.ManualVisible and self.SearchMatch

	if visible then
		for _, dependency in ipairs(self.Dependencies) do
			local source = dependency.Source
			local met = false

			if not source.Destroyed then
				met = matches(dependency.Expected, source:GetValue())
			end

			if not met then
				visible = false
				break
			end
		end
	end

	if visible == self.Visible then
		return
	end

	self.Visible = visible
	self._visibilityToken = (self._visibilityToken or 0) + 1
	local token = self._visibilityToken

	if visible then
		self.Holder.Visible = true
		Tween.play(self.Holder, { Size = UDim2.new(1, 0, 0, self.RowHeight) }, Tween.Info.Fast)
	else
		Tween.play(self.Holder, { Size = UDim2.new(1, 0, 0, 0) }, Tween.Info.Fast)
		task.delay(0.16, function()
			if not self.Destroyed and self._visibilityToken == token then
				self.Holder.Visible = false
			end
		end)
	end

	self.Section:UpdateVisibility()
end

-- Adds the standard hover highlight. `target` receives the mouse events.
function Base:AddHover(target)
	target = target or self.Holder

	local hover = Create.new("Frame", {
		Name = "Hover",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = self.Holder,
	})
	Create.corner(hover, 6)
	self.Library:Styled(hover, "SurfaceHigh", "BackgroundColor3")

	self:_track(target.MouseEnter:Connect(function()
		Tween.play(hover, { BackgroundTransparency = 0.5 }, Tween.Info.Fast)
	end))

	self:_track(target.MouseLeave:Connect(function()
		Tween.play(hover, { BackgroundTransparency = 1 }, Tween.Info.Fast)
	end))

	return hover
end

function Base:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	self.Library.Config:Unregister(self)
	self.Window:UnregisterSearchEntry(self)

	local index = self.Section and table.find(self.Section.Components, self)
	if index then
		table.remove(self.Section.Components, index)
	end

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)

	self.Changed:Destroy()
	self.Holder:Destroy()

	if self.Section and not self.Section.Destroyed then
		self.Section:UpdateVisibility()
	end

	self.Value = nil
	self.SearchEntry = nil
end

return Base
