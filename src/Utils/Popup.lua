--[[
	Utils/Popup.lua
	A themed floating panel used by the dropdown and color picker.

	Popups live in the library overlay (not inside the scrolling tab), so they
	are never clipped by the window, and a full-screen click catcher closes them
	when the user clicks outside. Only one popup can be open at a time.
]]

local Create = require(script.Parent.Create)
local Tween = require(script.Parent.Tween)

local Popup = {}
Popup.__index = Popup

function Popup.new(library, config)
	config = config or {}

	local self = setmetatable({}, Popup)

	self.Library = library
	self.Width = config.Width or 200
	self.Height = config.Height or 140
	self.OnClose = config.OnClose
	self.IsOpen = false
	self.Destroyed = false

	self.Catcher = Create.new("TextButton", {
		Name = "PopupCatcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 900,
		Parent = library.Overlay,
	})

	self.Frame = Create.new("Frame", {
		Name = config.Name or "Popup",
		Size = UDim2.fromOffset(self.Width, self.Height),
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 901,
		Parent = library.Overlay,
	})
	library:Styled(self.Frame, "Surface", "BackgroundColor3")
	Create.corner(self.Frame, 10)
	library:Styled(Create.stroke(self.Frame, library.Palette.Outline, 1, 0.25), "Outline", "Color")

	self.Scale = Create.new("UIScale", { Scale = 1, Parent = self.Frame })

	self.Catcher.Activated:Connect(function()
		self:Close()
	end)

	return self
end

function Popup:SetSize(width, height)
	self.Width = width
	self.Height = height
	self.Frame.Size = UDim2.fromOffset(width, height)
end

function Popup:Open(anchor)
	if self.Destroyed or self.IsOpen or not anchor then
		return
	end

	self.IsOpen = true
	self.Library:SetActivePopup(self)

	self.Catcher.Visible = true
	self.Frame.Visible = true

	local overlay = self.Library.Overlay
	local overlayPosition = overlay.AbsolutePosition
	local overlaySize = overlay.AbsoluteSize
	local anchorPosition = anchor.AbsolutePosition - overlayPosition
	local anchorSize = anchor.AbsoluteSize
	local width = self.Width
	local height = self.Height

	local x = anchorPosition.X + anchorSize.X - width
	local y = anchorPosition.Y + anchorSize.Y + 6

	if y + height > overlaySize.Y - 8 then
		y = anchorPosition.Y - height - 6
	end

	x = math.clamp(x, 8, math.max(8, overlaySize.X - width - 8))
	y = math.clamp(y, 8, math.max(8, overlaySize.Y - height - 8))

	self.Frame.Position = UDim2.fromOffset(x, y)
	self.Frame.GroupTransparency = 1
	self.Scale.Scale = 0.96

	Tween.play(self.Frame, { GroupTransparency = 0 }, Tween.Info.Snap)
	Tween.play(self.Scale, { Scale = 1 }, Tween.Info.Fast)
end

function Popup:Close()
	if not self.IsOpen then
		return
	end

	self.IsOpen = false

	if self.Library:GetActivePopup() == self then
		self.Library:SetActivePopup(nil)
	end

	self.Catcher.Visible = false

	Tween.play(self.Frame, { GroupTransparency = 1 }, Tween.Info.Snap)

	task.delay(0.1, function()
		if not self.IsOpen and not self.Destroyed then
			self.Frame.Visible = false
		end
	end)

	if self.OnClose then
		local ok, err = pcall(self.OnClose)
		if not ok then
			warn("[CherryUI] Popup close handler error: " .. tostring(err))
		end
	end
end

function Popup:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	if self.Library:GetActivePopup() == self then
		self.Library:SetActivePopup(nil)
	end

	self.Catcher:Destroy()
	self.Frame:Destroy()
end

return Popup
