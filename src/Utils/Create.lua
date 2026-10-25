--[[
	Utils/Create.lua
	Small helpers around Instance.new. Every Cherry UI element is built in code,
	so these helpers keep the component files short and visually consistent.

	`Create.new` applies properties before parenting the instance, which avoids a
	layout/update pass for every property assignment.
]]

local Create = {}

local function applyProperties(instance, properties)
	for key, value in properties do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
end

function Create.new(className, properties, children)
	local instance = Instance.new(className)

	if properties then
		applyProperties(instance, properties)
	end

	if children then
		for index = 1, #children do
			children[index].Parent = instance
		end
	end

	if properties and properties.Parent then
		instance.Parent = properties.Parent
	end

	return instance
end

function Create.corner(parent, radius)
	return Create.new("UICorner", {
		CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 8),
		Parent = parent,
	})
end

function Create.stroke(parent, color, thickness, transparency)
	return Create.new("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Create.padding(parent, top, right, bottom, left)
	if right == nil then
		right = top
	end
	if bottom == nil then
		bottom = top
	end
	if left == nil then
		left = right
	end

	return Create.new("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft = UDim.new(0, left or 0),
		Parent = parent,
	})
end

function Create.list(parent, padding, sortOrder)
	return Create.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = sortOrder or Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 0),
		Parent = parent,
	})
end

function Create.label(properties)
	local base = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}

	for key, value in properties do
		base[key] = value
	end

	return Create.new("TextLabel", base)
end

function Create.textButton(properties)
	local base = {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 13,
	}

	for key, value in properties do
		base[key] = value
	end

	return Create.new("TextButton", base)
end

--[[
	Creates a soft drop shadow made of three stacked frames.
	The layers are placed as siblings behind `frame`, so the caller must place
	both inside a wrapper that is large enough to show the spread.
]]
function Create.shadow(container, frame, color, spread, radius)
	spread = spread or 6
	local layers = {}

	for index = 1, 3 do
		local offset = spread * (index / 3)
		local shadow = Create.new("Frame", {
			Name = "Shadow" .. index,
			BackgroundColor3 = color or Color3.new(0, 0, 0),
			BackgroundTransparency = 0.86 + index * 0.04,
			Position = UDim2.fromOffset(-offset, -offset + 3),
			Size = UDim2.new(1, offset * 2, 1, offset * 2),
			ZIndex = math.max((frame.ZIndex or 2) - 1, 1),
			Parent = container,
		})
		Create.corner(shadow, (radius or 14) + offset)
		table.insert(layers, shadow)
	end

	return layers
end

return Create
