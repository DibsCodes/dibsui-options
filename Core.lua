local addonName, ns = ...

-- DibsUI-Options holds what every DibsUI addon shares: one settings window, the profiles, the minimap
-- button and the controls the pages are built from. Each addon registers itself as a module (see
-- README.md for the API). The settings themselves stay each module's own, in its table of the profile.

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

function ns.Media(name)
	return MEDIA .. name
end

-- A texture that stays crisp at any UI scale instead of snapping to the pixel grid.
function ns.CreateArt(parent, layer, fileName)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(ns.Media(fileName))
	texture:SetSnapToPixelGrid(false)
	texture:SetTexelSnappingBias(0)
	return texture
end

ns.TITLE = "DibsUI"

function ns.Print(message)
	print("|cffffd100" .. ns.TITLE .. "|r: " .. message)
end

ns.DEFAULT_PROFILE = "Default"
local MAX_NAME_LENGTH = 32

-- Settings shared by the whole account, whichever profile a character uses.
local ACCOUNT_DEFAULTS = {
	showMinimapButton = true,
	minimapAngle = 225, -- degrees anticlockwise from 3 o'clock, so the lower left of the minimap
}

-- The public API, as the global DibsUIOptions. Bump API_VERSION when something here changes in a way
-- a module could notice, and keep old functions working where possible: the addons update separately.
local API_VERSION = 1
local api = { version = API_VERSION }
DibsUIOptions = api
ns.api = api

local modules = {} -- by key
local moduleOrder = {}
local db -- DibsUIOptionsDB once it's loaded
local characterKey
local profileName

local function CopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and CopyTable(value) or value
	end
	return copy
end

-- Saved settings ----------------------------------------------------------------------------------

-- DibsUIOptionsDB = {
--   profiles = { [profile name] = { [module key] = that module's settings } },
--   characters = { ["Name - Realm"] = profile name, unless it's Default },
--   account = { showMinimapButton, minimapAngle, configWidth, configHeight, configTab },
--   modules = { [module key] = that module's account-wide settings },
--   imported = { [module key] = true once its old settings have been brought in },
-- }
local function LoadSettings()
	local saved = type(DibsUIOptionsDB) == "table" and DibsUIOptionsDB or {}
	DibsUIOptionsDB = saved
	for _, key in ipairs({ "profiles", "characters", "account", "modules", "imported" }) do
		if type(saved[key]) ~= "table" then
			saved[key] = {}
		end
	end
	for name, profile in pairs(saved.profiles) do
		if type(name) ~= "string" or type(profile) ~= "table" then
			saved.profiles[name] = nil
		end
	end
	saved.profiles[ns.DEFAULT_PROFILE] = saved.profiles[ns.DEFAULT_PROFILE] or {}
	for key, value in pairs(ACCOUNT_DEFAULTS) do
		if type(saved.account[key]) ~= type(value) then
			saved.account[key] = value
		end
	end
	db = saved
	ns.account = saved.account

	-- A character whose profile has been deleted goes back to Default.
	characterKey = UnitName("player") .. " - " .. GetRealmName()
	local name = saved.characters[characterKey]
	if type(name) ~= "string" or not saved.profiles[name] then
		name = ns.DEFAULT_PROFILE
		saved.characters[characterKey] = nil
	end
	profileName = name
end

-- A module's table in a profile, made and cleaned by the module if it's missing or out of date.
local function GetModuleTable(profile, key)
	local module = modules[key]
	local settings = profile[key]
	if type(settings) ~= "table" then
		settings = {}
	end
	if module and module.cleanProfile then
		settings = module.cleanProfile(settings) or settings
	end
	profile[key] = settings
	return settings
end

-- Modules -----------------------------------------------------------------------------------------

-- info = {
--   key = "DibsUI",                 -- unique, also the key of its settings in each profile
--   title = "DibsUI",               -- shown in the window
--   order = 10,                     -- tabs are grouped by module in this order
--   cleanProfile = function(settings) return settings end, -- fills defaults, fixes bad values
--   tabs = { { label = "General", build = function(content, context, relayout) return options end }, ... },
--   onProfileChanged = function(settings) end, -- after the character switches profile (never in combat)
--   isLocked = function() return true end,    -- whether its frames are locked
--   setLocked = function(locked) end,         -- lock or unlock its frames (never in combat)
-- }
-- A tab's build returns { Sync = function, SetCombatLocked = function(locked), Layout = function(width) },
-- the same as DibsUI's own tabs. Register at the module's ADDON_LOADED, before reading settings.
function api:RegisterModule(info)
	assert(type(info) == "table" and type(info.key) == "string", "RegisterModule needs a key")
	assert(db, "DibsUI-Options hasn't loaded its settings yet")
	if not modules[info.key] then
		moduleOrder[#moduleOrder + 1] = info.key
	end
	modules[info.key] = info
	table.sort(moduleOrder, function(a, b)
		local orderA, orderB = modules[a].order or 100, modules[b].order or 100
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a < b
	end)
	if ns.OnModulesChanged then
		ns.OnModulesChanged()
	end
end

function ns.GetModules()
	local list = {}
	for i, key in ipairs(moduleOrder) do
		list[i] = modules[key]
	end
	return list
end

-- The module's settings in the profile this character uses.
function api:GetProfile(key)
	return GetModuleTable(db.profiles[profileName], key)
end

-- The module's account-wide settings, the same for every profile.
function api:GetAccount(key)
	local settings = db.modules[key]
	if type(settings) ~= "table" then
		settings = {}
		db.modules[key] = settings
	end
	return settings
end

-- Brings a module's settings from before DibsUI-Options in, once. profiles is { [name] = settings },
-- characters is { ["Name - Realm"] = name }. Profiles and choices that already exist here are kept.
-- account is copied into the module's account table, and minimap = { show, angle } into the shared one.
function api:ImportOnce(key, data)
	if db.imported[key] then
		return false
	end
	db.imported[key] = true
	for name, settings in pairs(data.profiles or {}) do
		if type(name) == "string" and type(settings) == "table" then
			local profile = db.profiles[name] or {}
			db.profiles[name] = profile
			if profile[key] == nil then
				profile[key] = CopyTable(settings)
			end
		end
	end
	for character, name in pairs(data.characters or {}) do
		if type(character) == "string" and type(name) == "string" and db.characters[character] == nil then
			db.characters[character] = name
		end
	end
	if type(data.account) == "table" then
		local account = api:GetAccount(key)
		for field, value in pairs(data.account) do
			if account[field] == nil then
				account[field] = type(value) == "table" and CopyTable(value) or value
			end
		end
	end
	if type(data.minimap) == "table" then
		if type(data.minimap.show) == "boolean" then
			db.account.showMinimapButton = data.minimap.show
		end
		if type(data.minimap.angle) == "number" then
			db.account.minimapAngle = data.minimap.angle
		end
	end
	if type(data.window) == "table" then
		db.account.configWidth = db.account.configWidth or data.window.width
		db.account.configHeight = db.account.configHeight or data.window.height
	end
	-- The imported choice for this character takes effect now.
	local name = db.characters[characterKey]
	if type(name) == "string" and db.profiles[name] then
		profileName = name
	end
	return true
end

-- Profiles ----------------------------------------------------------------------------------------

function api:GetProfileName()
	return profileName
end

-- Default first, then the rest alphabetically.
function api:GetProfileNames()
	local names = {}
	for name in pairs(db.profiles) do
		if name ~= ns.DEFAULT_PROFILE then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	table.insert(names, 1, ns.DEFAULT_PROFILE)
	return names
end

-- The name with spaces trimmed, or nil and the reason it can't be used. Names differing only in
-- capitals count as the same, so the list never shows two that look alike.
function api:CheckProfileName(name)
	name = (name or ""):match("^%s*(.-)%s*$")
	if name == "" then
		return nil, "Type a name for the profile."
	end
	if #name > MAX_NAME_LENGTH then
		return nil, "That name is too long."
	end
	for existing in pairs(db.profiles) do
		if existing:lower() == name:lower() then
			return nil, "There's already a profile with that name."
		end
	end
	return name
end

-- Switching moves secure frames in every module, so it can't happen in combat. Returns whether it did.
function api:UseProfile(name)
	if not db.profiles[name] or InCombatLockdown() then
		return false
	end
	profileName = name
	db.characters[characterKey] = name ~= ns.DEFAULT_PROFILE and name or nil
	for _, module in ipairs(ns.GetModules()) do
		if module.onProfileChanged then
			local settings = api:GetProfile(module.key)
			local ok, err = pcall(module.onProfileChanged, settings)
			if not ok then
				geterrorhandler()(err)
			end
		end
	end
	return true
end

-- A new profile with copyFrom's settings (every module's, installed or not), or the defaults when
-- copyFrom is nil, which this character then uses. Returns its name, or nil and the reason.
function api:CreateProfile(name, copyFrom)
	local problem
	name, problem = api:CheckProfileName(name)
	if not name then
		return nil, problem
	end
	if InCombatLockdown() then
		return nil, "Profiles can't be changed during combat."
	end
	local source = copyFrom and db.profiles[copyFrom]
	db.profiles[name] = source and CopyTable(source) or {}
	api:UseProfile(name)
	return name
end

-- Default and the profile in use can't be deleted.
function api:CanDeleteProfile(name)
	return name ~= ns.DEFAULT_PROFILE and name ~= profileName and db.profiles[name] ~= nil
end

-- Characters that used it go back to Default.
function api:DeleteProfile(name)
	if not api:CanDeleteProfile(name) or InCombatLockdown() then
		return false
	end
	db.profiles[name] = nil
	for character, used in pairs(db.characters) do
		if used == name then
			db.characters[character] = nil
		end
	end
	return true
end

-- Locking -----------------------------------------------------------------------------------------

-- Locked while every module's frames are.
function api:IsLocked()
	for _, module in ipairs(ns.GetModules()) do
		if module.isLocked and not module.isLocked() then
			return false
		end
	end
	return true
end

-- Locks or unlocks every module's frames. Not in combat.
function api:SetLocked(locked)
	if InCombatLockdown() then
		return false
	end
	for _, module in ipairs(ns.GetModules()) do
		if module.setLocked then
			local ok, err = pcall(module.setLocked, locked)
			if not ok then
				geterrorhandler()(err)
			end
		end
	end
	if ns.OnLockChanged then
		ns.OnLockChanged()
	end
	return true
end

-- A module that locks or unlocks by itself (such as from a slash command) says so here, so the window's
-- button shows the right words.
function api:NotifyLockChanged()
	if ns.OnLockChanged then
		ns.OnLockChanged()
	end
end

function api:Print(message)
	ns.Print(message)
end

-- Startup -----------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		self:UnregisterEvent("ADDON_LOADED")
		LoadSettings()
	elseif event == "PLAYER_LOGIN" then
		ns.CreateMinimapButton()
		ns.RegisterGameSettings()
	end
end)
