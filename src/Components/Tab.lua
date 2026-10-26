--[[
	Components/Tab.lua
	A tab page: a scrolling column of sections plus optional embeds.

	Lazy loading: pass a builder as the third argument to `window:AddTab` and
	the heavy content is only constructed the first time the tab is selected:
		local tab = window:AddTab("Combat", "◎", function(page) ... end)
	Eager `tab:AddSection(...)` calls still work, they just build immediately.
]]

local Create = require(script.Parent.Parent.Utils.Create)
local Section = require(script.Parent.Section)
local ESPPreview = require(script.Parent.ESPPreview)
local PlayerList = require(script.Parent.PlayerList)

local Tab = {}
Tab.__index = Tab

function Tab.new(library, window, config)
	config = config or {}

	local self = setmetatable({}, Tab)

	self.Library = library
	self.Window = window
	self.Name = tostring(config.Name or "Tab")
	self.Icon = config.Icon
	self.Builder = config.Builder
	self.Built = false
	self.Destroyed = false
	self.HasContent = true
	self.Sections = {}
	self.Embeds = {}
	self._order = 0

	self.Content = Create.new("Frame", {
		Name = tostring(self.Name) .. "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = window.Content,
	})

	self.Scroller = Create.new("ScrollingFrame", {
		Name = "Scroller",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageTransparency = 0.3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Parent = self.Content,
	})
	Create.padding(self.Scroller, 2, 10, 14, 10)
	Create.list(self.Scroller, 10)
	library:Styled(self.Scroller, "Outline", "ScrollBarImageColor3")

	return self
end

function Tab:_nextOrder()
	self._order += 1
	return self._order
end

function Tab:AddSection(name, config)
	config = config or {}

	if type(name) == "table" then
		config = name
		name = config.Name
	end

	config.Name = name or config.Name or "Section"

	local section = Section.new(self.Library, self, config)
	table.insert(self.Sections, section)

	return section
end

function Tab:AddESPPreview(config)
	local preview = ESPPreview.new(self.Library, self.Scroller, config)
	preview.Frame.LayoutOrder = self:_nextOrder()
	table.insert(self.Embeds, preview)
	return preview
end

function Tab:AddPlayerList(config)
	local list = PlayerList.new(self.Library, self.Scroller, config)
	list.Frame.LayoutOrder = self:_nextOrder()
	table.insert(self.Embeds, list)
	return list
end

function Tab:EnsureBuilt()
	if self.Built or self.Destroyed then
		return self
	end

	self.Built = true

	if type(self.Builder) == "function" then
		local ok, err = pcall(self.Builder, self)
		if not ok then
			warn("[CherryUI] Tab '" .. tostring(self.Name) .. "' builder failed: " .. tostring(err))
		end
	end

	self:UpdateVisibility(false)
	return self
end

function Tab:Select()
	self.Window:SelectTab(self)
end

function Tab:UpdateVisibility(filtering)
	if self.Destroyed then
		return false
	end

	local visibleSections = 0
	for _, section in ipairs(self.Sections) do
		if section:UpdateVisibility(filtering) then
			visibleSections += 1
		end
	end

	for _, embed in ipairs(self.Embeds) do
		embed.Frame.Visible = not filtering
	end

	local hasContent = visibleSections > 0 or (not filtering and #self.Embeds > 0)
	self.HasContent = hasContent

	local transparency = hasContent and 0 or 0.5
	if self.ButtonLabel then
		self.ButtonLabel.TextTransparency = transparency
	end
	if self.ButtonIcon then
		self.ButtonIcon.TextTransparency = transparency
	end

	return hasContent
end

function Tab:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	-- Snapshot: sections unregister themselves from this tab.
	local sections = table.clone(self.Sections)
	for _, section in ipairs(sections) do
		section:Destroy()
	end
	table.clear(self.Sections)

	local embeds = table.clone(self.Embeds)
	for _, embed in ipairs(embeds) do
		embed:Destroy()
	end
	table.clear(self.Embeds)

	self.Content:Destroy()

	-- The tab button lives in the window's tab bar, not in Content.
	if self.Button then
		self.Button:Destroy()
		self.Button = nil
	end

	if self.Window.ActiveTab == self then
		self.Window.ActiveTab = nil
	end

	if self.Window.Tabs then
		local index = table.find(self.Window.Tabs, self)
		if index then
			table.remove(self.Window.Tabs, index)
		end
	end
end

return Tab
