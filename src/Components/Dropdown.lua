--[[
	Components/Dropdown.lua
	Single- and multi-select dropdown with a scrollable, pooled option list.

	The menu is created lazily the first time it is opened and lives in the
	library overlay so it is never clipped by the tab's scrolling frame. Option
	rows come from an instance pool, so opening a dropdown repeatedly does not
	create garbage.
]]

local Base = require(script.Parent.Parent.Utils.Base)
local Create = require(script.Parent.Parent.Utils.Create)
local Tween = require(script.Parent.Parent.Utils.Tween)
local Icons = require(script.Parent.Parent.Utils.Icons)
local Pool = require(script.Parent.Parent.Utils.Pool)
local Popup = require(script.Parent.Parent.Utils.Popup)

local Dropdown = setmetatable({}, { __index = Base })
Dropdown.__index = Dropdown

function Dropdown.new(library, section, config)
	config = config or {}
	config.Height = config.Height or 34

	local self = Base.new(library, section, "Dropdown", config)
	setmetatable(self, Dropdown)

	self.Multi = config.Multi == true
	self.Placeholder = config.Placeholder or "Select..."
	self.Options = {}
	self._optionSet = {}
	self._rendered = {}
	self._widgets = {}
	self.IsOpen = false

	for _, option in ipairs(config.Options or {}) do
		local text = tostring(option)
		if text ~= "" and not self._optionSet[text] then
			self._optionSet[text] = true
			table.insert(self.Options, text)
		end
	end

	if self.Multi then
		self.Value = {}
		if type(config.Default) == "table" then
			for _, item in ipairs(config.Default) do
				local text = tostring(item)
				if self._optionSet[text] and not table.find(self.Value, text) then
					table.insert(self.Value, text)
				end
			end
		end
		self.Default = table.clone(self.Value)
	else
		local default = config.Default
		if type(default) ~= "string" or not self._optionSet[default] then
			default = self.Options[1]
		end
		self.Value = default
		self.Default = default
	end

	self.Hit = Create.textButton({
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = self.Holder,
	})
	self:AddHover(self.Hit)

	self.Label = Create.label({
		Name = "Label",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.5, -8, 1, 0),
		Text = self.Name,
		TextSize = 13,
		ZIndex = 3,
		Parent = self.Hit,
	})
	library:Styled(self.Label, "Text", "TextColor3")

	self.ValueLabel = Create.label({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -26, 0.5, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = self.Hit,
	})

	self.Chevron = Icons.new("chevron", self.Hit, 12, library.Palette.SubText, 3)
	self.Chevron.AnchorPoint = Vector2.new(1, 0.5)
	self.Chevron.Position = UDim2.new(1, -10, 0.5, 0)
	Icons.bindTheme(self.Chevron, library, "SubText")

	self:_renderField()

	self:_track(self.Hit.Activated:Connect(function()
		if self.Destroyed then
			return
		end
		if self.IsOpen then
			self:Close()
		else
			self:Open()
		end
	end))

	self:OnThemeChanged(function()
		self:_renderField()
	end)

	return self
end

function Dropdown:_isSelected(option)
	if self.Multi then
		return table.find(self.Value, option) ~= nil
	end
	return self.Value == option
end

function Dropdown:_renderField()
	local palette = self.Library.Palette
	local text
	local empty = false

	if self.Multi then
		local count = #self.Value
		if count == 0 then
			text = self.Placeholder
			empty = true
		elseif count == 1 then
			text = self.Value[1]
		elseif count == 2 then
			text = self.Value[1] .. ", " .. self.Value[2]
		else
			text = self.Value[1] .. " +" .. tostring(count - 1)
		end
	else
		empty = self.Value == nil
		text = self.Value or self.Placeholder
	end

	self.ValueLabel.Text = text
	self.ValueLabel.TextColor3 = empty and palette.Placeholder or palette.Text
end

function Dropdown:_setChevron(open)
	Tween.play(self.Chevron, { Rotation = open and 180 or 0 }, Tween.Info.Fast)
end

function Dropdown:_ensureMenu()
	if self.Popup then
		return
	end

	self.Popup = Popup.new(self.Library, {
		Name = "DropdownMenu",
		Width = 180,
		Height = 120,
		OnClose = function()
			self.IsOpen = false
			self:_setChevron(false)
		end,
	})

	self.List = Create.new("ScrollingFrame", {
		Name = "Options",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = self.Library.Palette.Outline,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = self.Popup.Frame,
	})
	Create.padding(self.List, 4)
	Create.list(self.List, 2)

	self.Pool = Pool.new(function()
		local option = Create.textButton({
			Name = "Option",
			Size = UDim2.new(1, 0, 0, 28),
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = nil,
		})
		Create.corner(option, 6)
		Create.padding(option, 0, 8, 0, 10)

		local check = Icons.new("check", option, 13, self.Library.Palette.Primary, 4)
		check.AnchorPoint = Vector2.new(1, 0.5)
		check.Position = UDim2.new(1, -9, 0.5, 0)
		check.Visible = false

		self._widgets[option] = { Check = check }

		option.Activated:Connect(function()
			local value = option:GetAttribute("Option")
			if type(value) == "string" and value ~= "" and not self.Destroyed then
				self:_select(value)
			end
		end)

		option.MouseEnter:Connect(function()
			Tween.play(option, { BackgroundTransparency = 0.4 }, Tween.Info.Fast)
		end)

		option.MouseLeave:Connect(function()
			local value = option:GetAttribute("Option")
			local selected = type(value) == "string" and self:_isSelected(value)
			Tween.play(option, { BackgroundTransparency = selected and 0.75 or 1 }, Tween.Info.Fast)
		end)

		return option
	end, function(option)
		option:SetAttribute("Option", nil)
		option.Text = ""
		local widgets = self._widgets[option]
		if widgets then
			widgets.Check.Visible = false
		end
		option.BackgroundTransparency = 1
	end, 4)
end

function Dropdown:_renderOptions()
	if not self.Popup then
		return
	end

	for _, item in ipairs(self._rendered) do
		self.Pool:Release(item.Button)
	end
	table.clear(self._rendered)

	local palette = self.Library.Palette

	for index, option in ipairs(self.Options) do
		local button = self.Pool:Get(self.List)
		local widgets = self._widgets[button]
		local selected = self:_isSelected(option)

		button.LayoutOrder = index
		button:SetAttribute("Option", option)
		button.Text = option
		button.TextColor3 = selected and palette.Primary or palette.Text
		button.BackgroundColor3 = palette.SurfaceHigh
		button.BackgroundTransparency = selected and 0.75 or 1

		widgets.Check.Visible = selected
		Icons.setColor(widgets.Check, palette.Primary)

		table.insert(self._rendered, { Button = button })
	end

	self.List.CanvasSize = UDim2.new(0, 0, 0, #self.Options * 30 + 8)
	self.List.ScrollBarImageColor3 = palette.Outline

	local width = math.clamp(self.Holder.AbsoluteSize.X * 0.5, 180, 280)
	local height = math.clamp(#self.Options * 30 + 12, 44, 240)
	self.Popup:SetSize(width, height)
end

function Dropdown:Open()
	if self.Destroyed or self.IsOpen or #self.Options == 0 then
		return
	end

	self:_ensureMenu()
	self:_renderOptions()

	self.IsOpen = true
	self.Popup:Open(self.Holder)
	self:_setChevron(true)
end

function Dropdown:Close()
	if not self.IsOpen then
		return
	end

	self.IsOpen = false
	self:_setChevron(false)

	if self.Popup then
		self.Popup:Close()
	end
end

function Dropdown:_select(option)
	if self.Multi then
		local index = table.find(self.Value, option)
		if index then
			table.remove(self.Value, index)
		else
			table.insert(self.Value, option)
		end

		self:_renderField()
		self:_renderOptions()
		self:_commit(self:GetValue(), false)
	else
		if self.Value ~= option then
			self.Value = option
			self:_renderField()
			self:_renderOptions()
			self:_commit(option, false)
		end
		self:Close()
	end
end

function Dropdown:SetValue(value, silent)
	if self.Destroyed then
		return
	end

	if self.Multi then
		local list = {}
		if type(value) == "table" then
			for _, item in ipairs(value) do
				local text = tostring(item)
				if self._optionSet[text] and not table.find(list, text) then
					table.insert(list, text)
				end
			end
		end
		self.Value = list
	else
		local text = type(value) == "string" and value or nil
		if text == nil or not self._optionSet[text] then
			text = self.Options[1]
		end
		self.Value = text
	end

	self:_renderField()
	if self.Popup then
		self:_renderOptions()
	end
	self:_commit(self:GetValue(), silent)
end

function Dropdown:GetValue()
	if self.Multi then
		return table.clone(self.Value)
	end
	return self.Value
end

function Dropdown:Destroy()
	if self.Destroyed then
		return
	end

	if self.Popup then
		self.Popup:Destroy()
		self.Popup = nil
	end

	if self.Pool then
		self.Pool:Destroy()
		self.Pool = nil
	end

	table.clear(self._rendered)
	table.clear(self._widgets)

	Base.Destroy(self)
end

return Dropdown
