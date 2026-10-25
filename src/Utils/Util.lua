--[[
	Utils/Util.lua
	Small, dependency-free helpers shared by the components.
]]

local Util = {}

local SPECIAL_KEYS = {
	[Enum.KeyCode.LeftShift] = "LShift",
	[Enum.KeyCode.RightShift] = "RShift",
	[Enum.KeyCode.LeftControl] = "LCtrl",
	[Enum.KeyCode.RightControl] = "RCtrl",
	[Enum.KeyCode.LeftAlt] = "LAlt",
	[Enum.KeyCode.RightAlt] = "RAlt",
	[Enum.KeyCode.Return] = "Enter",
	[Enum.KeyCode.Backspace] = "Backspace",
	[Enum.KeyCode.Escape] = "Esc",
	[Enum.KeyCode.Space] = "Space",
	[Enum.UserInputType.MouseButton1] = "Mouse1",
	[Enum.UserInputType.MouseButton2] = "Mouse2",
	[Enum.UserInputType.MouseButton3] = "Mouse3",
}

function Util.clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	elseif value > maximum then
		return maximum
	end
	return value
end

function Util.round(value, decimals)
	decimals = decimals or 0
	local multiplier = 10 ^ decimals
	return math.floor(value * multiplier + 0.5) / multiplier
end

-- Formats a number without trailing zeros ("12.50" -> "12.5").
function Util.trimNumber(value, decimals)
	decimals = decimals or 0
	local rounded = Util.round(value, decimals)

	if decimals <= 0 then
		return string.format("%.0f", rounded)
	end

	local text = string.format("%." .. tostring(decimals) .. "f", rounded)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")

	if text == "" or text == "-0" then
		text = "0"
	end

	return text
end

-- Converts a key code / user input type into a short display label.
function Util.keyName(value)
	if typeof(value) ~= "EnumItem" then
		return "None"
	end

	local special = SPECIAL_KEYS[value]
	if special then
		return special
	end

	local name = value.Name
	name = string.gsub(name, "(%l)(%u)", "%1 %2")
	return name
end

function Util.matchesInput(input, binding)
	if typeof(binding) ~= "EnumItem" then
		return false
	end

	if binding.EnumType == Enum.KeyCode then
		return input.KeyCode == binding
	elseif binding.EnumType == Enum.UserInputType then
		return input.UserInputType == binding
	end

	return false
end

function Util.hex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Util.fromHex(text)
	if type(text) ~= "string" then
		return nil
	end

	local full = string.match(text, "#?(%x%x%x%x%x%x)")
	if full then
		return Color3.fromHex(full)
	end

	local short = string.match(text, "#?(%x%x%x)")
	if short then
		local r = string.sub(short, 1, 1)
		local g = string.sub(short, 2, 2)
		local b = string.sub(short, 3, 3)
		return Color3.fromHex(r .. r .. g .. g .. b .. b)
	end

	return nil
end

-- Copies text to the clipboard when an executor provides `setclipboard`.
function Util.copy(text)
	local copyFunction = nil

	local ok = pcall(function()
		copyFunction = setclipboard
	end)

	if ok and type(copyFunction) == "function" then
		local copied = pcall(copyFunction, tostring(text))
		return copied
	end

	return false
end

return Util
