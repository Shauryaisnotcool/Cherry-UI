--[[
	Utils/Config.lua
	Serializes the whole UI state (component values, theme, menu keybind) and
	persists it through one of four backends:

	  * "memory"    - keeps the data for the current session (default)
	  * "file"      - JSON file via executor functions (writefile/readfile)
	  * "custom"    - your own save/load functions (RemoteFunction, ProfileStore...)
	  * "datastore" - DataStore:GetAsync/SetAsync (server-side or via a bridge)

	Components register themselves automatically, so saving works without any
	extra bookkeeping from the user.
]]

local HttpService = game:GetService("HttpService")

local Config = {}
Config.__index = Config

local function encode(value)
	local valueType = typeof(value)

	if valueType == "Color3" then
		return { __type = "Color3", r = value.R, g = value.G, b = value.B }
	elseif valueType == "EnumItem" then
		return { __type = "Enum", enum = tostring(value.EnumType), name = value.Name }
	elseif valueType == "table" then
		local output = {}
		for key, item in pairs(value) do
			local encoded = encode(item)
			if encoded ~= nil then
				output[key] = encoded
			end
		end
		return output
	elseif valueType == "number" or valueType == "string" or valueType == "boolean" then
		return value
	end

	return nil
end

local function decode(value)
	if type(value) ~= "table" then
		return value
	end

	if value.__type == "Color3" then
		return Color3.new(tonumber(value.r) or 0, tonumber(value.g) or 0, tonumber(value.b) or 0)
	elseif value.__type == "Enum" then
		local enumName = string.match(tostring(value.enum or ""), "Enum%.(.+)")
		local enum = enumName and Enum[enumName]
		if enum and value.name then
			return enum[value.name]
		end
		return nil
	end

	local output = {}
	for key, item in pairs(value) do
		output[key] = decode(item)
	end
	return output
end

local function executorFunction(name)
	local ok, result = pcall(function()
		return _G[name]
	end)
	if ok and type(result) == "function" then
		return result
	end

	local okGenv, genv = pcall(function()
		return getgenv and getgenv() or nil
	end)
	if okGenv and type(genv) == "table" and type(genv[name]) == "function" then
		return genv[name]
	end

	return nil
end

function Config.new(library)
	local self = setmetatable({}, Config)

	self.Library = library
	self.Components = {}
	self.Mode = "memory"
	self.Storage = nil
	self.DataStore = nil
	self.DataKey = "CherryUI_Config"
	self.FilePath = "CherryUI/config.json"
	self.Memory = nil
	self._ids = {}
	self._connections = {}
	self._dirty = false
	self._autoTask = nil
	self.Destroyed = false

	return self
end

function Config:Register(component)
	local id = component.Config.Id
	if id == nil then
		id = tostring(component.Kind) .. "_" .. tostring(component.Name)
		id = string.gsub(id, "[^%w_]", "_")
	end

	local base = id
	local index = 2
	while self._ids[id] do
		id = base .. "_" .. tostring(index)
		index += 1
	end

	self._ids[id] = true
	component.ConfigId = id

	table.insert(self.Components, component)
	self._connections[component] = component.Changed:Connect(function()
		self:MarkDirty()
	end)

	return id
end

function Config:Unregister(component)
	local index = table.find(self.Components, component)
	if index then
		table.remove(self.Components, index)
	end

	local connection = self._connections[component]
	if connection then
		connection:Disconnect()
		self._connections[component] = nil
	end
end

function Config:MarkDirty()
	self._dirty = true
end

function Config:Serialize()
	local data = {
		version = self.Library.Version,
		theme = self.Library.ThemeManager.Name,
		toggleKey = encode(self.Library.ToggleKey),
		values = {},
	}

	for _, component in ipairs(self.Components) do
		if not component.Destroyed then
			local ok, value = pcall(function()
				return component:GetValue()
			end)

			if ok and value ~= nil then
				local encoded = encode(value)
				if encoded ~= nil then
					data.values[component.ConfigId] = encoded
				end
			end
		end
	end

	return data
end

function Config:Apply(data)
	if type(data) ~= "table" then
		return false
	end

	if type(data.theme) == "string" and self.Library.Themes[data.theme] then
		self.Library:SetTheme(data.theme)
	end

	if data.toggleKey ~= nil then
		local key = decode(data.toggleKey)
		if key ~= nil then
			self.Library:SetToggleKey(key)
		end
	end

	local values = data.values
	if type(values) == "table" then
		for _, component in ipairs(self.Components) do
			local encoded = values[component.ConfigId]
			if encoded ~= nil then
				local ok, value = pcall(decode, encoded)
				if ok and value ~= nil then
					pcall(function()
						component:SetValue(value, true)
					end)
				end
			end
		end
	end

	self.Library:RefreshVisibility()
	self._dirty = false
	return true
end

function Config:SetMode(mode, options)
	options = options or {}
	self.Mode = mode

	if mode == "file" then
		self.FilePath = options.Path or options.FilePath or self.FilePath
	elseif mode == "custom" then
		self.Storage = {
			save = options.save or options.Save,
			load = options.load or options.Load,
		}
	elseif mode == "datastore" then
		self.DataStore = options.Store or options.store
		self.DataKey = options.Key or options.key or self.DataKey
	end
end

function Config:Save()
	if self.Destroyed then
		return false
	end

	local data = self:Serialize()
	self._dirty = false
	self.Memory = data

	local success = false
	local mode = self.Mode

	if mode == "file" then
		local writefile = executorFunction("writefile")
		if not writefile then
			warn("[CherryUI] writefile is unavailable, keeping the config in memory instead.")
			return true
		end

		local folder = string.match(self.FilePath, "^(.+)/[^/]+$")
		if folder then
			local isfolder = executorFunction("isfolder")
			local makefolder = executorFunction("makefolder")
			if isfolder and makefolder then
				local checked, exists = pcall(isfolder, folder)
				if not checked or not exists then
					pcall(makefolder, folder)
				end
			end
		end

		local ok, err = pcall(writefile, self.FilePath, HttpService:JSONEncode(data))
		if not ok then
			warn("[CherryUI] Failed to write config: " .. tostring(err))
		end
		success = ok
	elseif mode == "custom" and self.Storage and type(self.Storage.save) == "function" then
		local ok, err = pcall(self.Storage.save, data)
		if not ok then
			warn("[CherryUI] Custom save failed: " .. tostring(err))
		end
		success = ok
	elseif mode == "datastore" and self.DataStore then
		local ok, err = pcall(function()
			self.DataStore:SetAsync(self.DataKey, data)
		end)
		if not ok then
			warn("[CherryUI] DataStore save failed: " .. tostring(err))
		end
		success = ok
	else
		-- Memory mode: `self.Memory` is the saved state.
		success = true
	end

	return success
end

function Config:Load()
	if self.Destroyed then
		return false
	end

	local data = nil
	local mode = self.Mode

	if mode == "file" then
		local readfile = executorFunction("readfile")
		local isfile = executorFunction("isfile")
		if not readfile then
			return false
		end
		if isfile then
			local checked, exists = pcall(isfile, self.FilePath)
			if not checked or not exists then
				return false
			end
		end

		local ok, contents = pcall(readfile, self.FilePath)
		if not ok or type(contents) ~= "string" or contents == "" then
			return false
		end

		local decoded, parsed = pcall(HttpService.JSONDecode, HttpService, contents)
		if not decoded then
			warn("[CherryUI] Config file is not valid JSON: " .. tostring(parsed))
			return false
		end
		data = parsed
	elseif mode == "custom" and self.Storage and type(self.Storage.load) == "function" then
		local ok, result = pcall(self.Storage.load)
		if not ok then
			warn("[CherryUI] Custom load failed: " .. tostring(result))
			return false
		end
		data = result
	elseif mode == "datastore" and self.DataStore then
		local ok, result = pcall(function()
			return self.DataStore:GetAsync(self.DataKey)
		end)
		if not ok then
			warn("[CherryUI] DataStore load failed: " .. tostring(result))
			return false
		end
		data = result
	else
		data = self.Memory
	end

	if type(data) ~= "table" then
		return false
	end

	return self:Apply(data)
end

function Config:Reset()
	for _, component in ipairs(self.Components) do
		if component.Default ~= nil then
			local defaultValue = component.Default
			if type(defaultValue) == "table" then
				local copy = {}
				for key, value in pairs(defaultValue) do
					copy[key] = value
				end
				defaultValue = copy
			end

			pcall(function()
				component:SetValue(defaultValue, true)
			end)
		end
	end

	self.Library:SetTheme(self.Library.ThemeOrder[1] or "Crimson")
	self.Library:SetToggleKey(Enum.KeyCode.RightShift)
	self.Library:RefreshVisibility()
	self._dirty = false
	return true
end

function Config:EnableAutoSave(interval)
	if self._autoTask then
		return
	end

	self._autoTask = self.Library.Scheduler:Every(interval or 30, function()
		if self._dirty then
			self:Save()
		end
	end)
end

function Config:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	if self._autoTask then
		self.Library.Scheduler:Remove(self._autoTask)
		self._autoTask = nil
	end

	for _, connection in self._connections do
		connection:Disconnect()
	end

	table.clear(self._connections)
	table.clear(self.Components)
	table.clear(self._ids)
end

return Config
