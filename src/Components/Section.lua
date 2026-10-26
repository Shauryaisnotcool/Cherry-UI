--[[
	Components/Section.lua
	A titled card inside a tab that groups related controls.

	Sections own their controls, hand out layout order, and collapse themselves
	when every child is hidden by search or a dependency.
]]

local Create = require(script.Parent.Parent.Utils.Create)

local Button = require(script.Parent.Button)
local ColorPicker = require(script.Parent.ColorPicker)
local Dropdown = require(script.Parent.Dropdown)
local Keybind = require(script.Parent.Keybind)
local Slider = require(script.Parent.Slider)
local TextBox = require(script.Parent.TextBox)
local Toggle = require(script.Parent.Toggle)

local Section = {}
Section.__index = Section

function Section.new(library, tab, config)
	config = config or {}

	local self = setmetatable({}, Section)

	self.Library = library
	self.Tab = tab
	self.Name = tostring(config.Name or "Section")
	self.Components = {}
	self.StaticCount = 0
	self.Destroyed = false
	self._order = 0

	local palette = library.Palette

	self.Frame = Create.new("Frame", {
		Name = self.Name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = tab:_nextOrder(),
		Parent = tab.Scroller,
	})
	Create.list(self.Frame, 6)

	self.Header = Create.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Parent = self.Frame,
	})

	self.Accent = Create.new("Frame", {
		Name = "Accent",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(3, 12),
		Parent = self.Header,
	})
	Create.corner(self.Accent, 2)
	library.ThemeManager:BindGradient(
		Create.new("UIGradient", { Rotation = 90, Parent = self.Accent }),
		{ "Primary", "Accent" }
	)

	self.HeaderLabel = Create.label({
		Name = "Title",
		Text = string.upper(self.Name),
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -12, 1, 0),
		Parent = self.Header,
	})
	library:Styled(self.HeaderLabel, "Primary", "TextColor3")

	self.Body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 0.1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = self.Frame,
	})
	library:Styled(self.Body, "Surface", "BackgroundColor3")
	Create.corner(self.Body, 10)
	library:Styled(Create.stroke(self.Body, palette.Outline, 1, 0.35), "Outline", "Color")
	Create.padding(self.Body, 5, 6, 5, 6)
	Create.list(self.Body, 0)

	return self
end

function Section:_nextOrder()
	self._order += 1
	return self._order
end

function Section:_add(component)
	table.insert(self.Components, component)
	self:UpdateVisibility()
	return component
end

function Section:AddToggle(config)
	return self:_add(Toggle.new(self.Library, self, config))
end

function Section:AddButton(config)
	return self:_add(Button.new(self.Library, self, config))
end

function Section:AddSlider(config)
	return self:_add(Slider.new(self.Library, self, config))
end

function Section:AddDropdown(config)
	return self:_add(Dropdown.new(self.Library, self, config))
end

function Section:AddTextBox(config)
	return self:_add(TextBox.new(self.Library, self, config))
end

function Section:AddKeybind(config)
	return self:_add(Keybind.new(self.Library, self, config))
end

function Section:AddColorPicker(config)
	return self:_add(ColorPicker.new(self.Library, self, config))
end

-- Simple non-interactive text block (destroyed with the section).
function Section:AddLabel(text, config)
	config = config or {}

	local label = Create.label({
		Name = "Label",
		Text = tostring(text),
		TextSize = config.TextSize or 12,
		TextWrapped = true,
		TextColor3 = self.Library.Palette.SubText,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Body,
	})
	self.Library:Styled(label, "SubText", "TextColor3")
	self.StaticCount += 1
	self:UpdateVisibility()

	return label
end

function Section:UpdateVisibility(filtering)
	if self.Destroyed then
		return false
	end

	local visibleCount = 0
	for _, component in ipairs(self.Components) do
		if not component.Destroyed and component.Visible then
			visibleCount += 1
		end
	end

	-- Label-only sections (notes, descriptions) have no controls to count.
	local hasVisible = visibleCount > 0
		or (not filtering and #self.Components == 0 and self.StaticCount > 0)
	self.Frame.Visible = hasVisible

	return hasVisible
end

function Section:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	-- Snapshot: each component unregisters itself from this section.
	local components = table.clone(self.Components)
	for _, component in ipairs(components) do
		component:Destroy()
	end
	table.clear(self.Components)

	if self.Tab and self.Tab.Sections then
		local index = table.find(self.Tab.Sections, self)
		if index then
			table.remove(self.Tab.Sections, index)
		end
	end

	self.Frame:Destroy()

	if self.Tab and not self.Tab.Destroyed then
		self.Tab:UpdateVisibility()
	end
end

return Section
