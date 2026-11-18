local _, ns = ...

local api = ns.api
local W = ns.Widgets

-- The settings window: every module's tabs down the left, grouped by module, then Profiles. Built the
-- first time it opens, after every module has registered.

local WIDTH, HEIGHT = 900, 640
local MIN_WIDTH, MIN_HEIGHT = 720, 420
local NAV_WIDTH = 186
local NAV_ROW_HEIGHT = 30
local NAV_HEADING_HEIGHT = 24
local BODY_TOP = -64 -- where the tabs and page start, under the logo and the header row beside it

-- Profiles tab ------------------------------------------------------------------------------------

local DIALOG_WIDTH, DIALOG_HEIGHT = 340, 200

-- Asks for a name and which profile to start from. onCreated runs once the profile exists and is in use.
local function CreateNewProfileDialog(config, onCreated)
	local dialog = W.CreatePanel("DibsUIOptionsNewProfile", config, DIALOG_WIDTH, DIALOG_HEIGHT, "New profile")
	dialog:SetPoint("CENTER", config)
	dialog:SetFrameStrata("DIALOG")
	dialog:Hide()
	tinsert(UISpecialFrames, dialog:GetName())

	local content = CreateFrame("Frame", nil, dialog)
	content:SetPoint("TOPLEFT", 20, -36)
	content:SetPoint("BOTTOMRIGHT", -20, 16)

	local nameLabel = W.CreateLabel(content, "GameFontHighlight", "Name")
	nameLabel:SetPoint("TOPLEFT", 0, -8)

	local nameBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	nameBox:SetSize(W.DROPDOWN_WIDTH - 6, 22)
	nameBox:SetPoint("TOPRIGHT", -3, -3)
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(32)

	local copyRow = W.CreateDropdownRow(content, "Copy from")
	copyRow:SetPoint("TOPLEFT", 0, -34)
	copyRow:SetWidth(DIALOG_WIDTH - 40)

	local problem = W.CreateLabel(content, "GameFontNormalSmall", "")
	problem:SetTextColor(1, 0.3, 0.3)
	problem:SetPoint("TOPLEFT", copyRow, "BOTTOMLEFT", 0, -6)
	problem:SetWidth(DIALOG_WIDTH - 40)

	local create = W.CreateButton(content, "Create", 110)
	create:SetPoint("BOTTOMRIGHT", content, "BOTTOM", -4, 0)

	local cancel = W.CreateButton(content, "Cancel", 110)
	cancel:SetPoint("BOTTOMLEFT", content, "BOTTOM", 4, 0)
	cancel:SetScript("OnClick", function() dialog:Hide() end)

	-- A profile name, or false to start from the default settings.
	local copyFrom

	copyRow.dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(300)
		root:CreateRadio("Default settings", function() return copyFrom == false end, function() copyFrom = false end, false)
		for _, name in ipairs(api:GetProfileNames()) do
			root:CreateRadio(name, function() return copyFrom == name end, function() copyFrom = name end, name)
		end
	end)

	create:SetScript("OnClick", function()
		local name, reason = api:CreateProfile(nameBox:GetText(), copyFrom or nil)
		if name then
			dialog:Hide()
			onCreated()
		else
			problem:SetText(reason)
		end
	end)

	nameBox:SetScript("OnEnterPressed", function() create:Click() end)
	nameBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
	nameBox:SetScript("OnTextChanged", function() problem:SetText("") end)

	dialog:SetScript("OnShow", function()
		copyFrom = api:GetProfileName()
		copyRow.dropdown:GenerateMenu()
		nameBox:SetText("")
		problem:SetText("")
		nameBox:SetFocus()
	end)
	dialog:SetScript("OnHide", function()
		nameBox:ClearFocus()
	end)

	return dialog
end

StaticPopupDialogs.DIBSUI_OPTIONS_DELETE_PROFILE = {
	text = "Delete the profile \"%s\"? Characters using it will go back to Default.",
	button1 = DELETE,
	button2 = CANCEL,
	OnAccept = function(_, data)
		if api:DeleteProfile(data.name) then
			data.onDeleted()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
}

local PROFILE_ROW_HEIGHT = 28
local PROFILE_LIST_HEIGHT = 224
local PROFILE_SCROLL_BAR_ROOM = 18

-- The profile in use, and every profile on the account in a list. Clicking one uses it on this
-- character. Switching places every module's frames again, so all of this is locked in combat.
local function BuildProfiles(content, context)
	local isLocked = false
	local TOGGLE_ON = W.TOGGLE_ON

	local profilesCard = W.CreateCard(content, "Profiles")
	profilesCard:Add(W.CreateLabel(profilesCard, "GameFontHighlight", "Current profile"), 4)
	local current = profilesCard:Add(W.CreateLabel(profilesCard, "GameFontNormalLarge", ""), 6)

	-- The list keeps its own height and scroll bar, and stretches with the section.
	local listHolder = profilesCard:Add(CreateFrame("Frame", nil, profilesCard), 12)
	listHolder:SetHeight(PROFILE_LIST_HEIGHT)

	local listBack = listHolder:CreateTexture(nil, "BACKGROUND")
	listBack:SetColorTexture(0, 0, 0, 0.3)
	listBack:SetAllPoints()

	local list = CreateFrame("Frame", nil, listHolder, "WowScrollBoxList")
	list:SetPoint("TOPLEFT", 2, -2)
	list:SetPoint("BOTTOMRIGHT", -PROFILE_SCROLL_BAR_ROOM, 2)

	local scrollBar = CreateFrame("EventFrame", nil, listHolder, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", list, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 4, 0)

	local function Refresh()
		current:SetText(api:GetProfileName())
		list:SetDataProvider(CreateDataProvider(api:GetProfileNames()))
	end

	local function OnProfileChanged()
		context.SyncAll()
	end

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(PROFILE_ROW_HEIGHT)
	view:SetElementInitializer("Button", function(row, name)
		if not row.label then
			local highlight = row:CreateTexture(nil, "HIGHLIGHT")
			highlight:SetAllPoints()
			highlight:SetColorTexture(1, 1, 1, 0.08)

			row.inUse = row:CreateTexture(nil, "BACKGROUND")
			row.inUse:SetAllPoints()
			row.inUse:SetColorTexture(TOGGLE_ON[1], TOGGLE_ON[2], TOGGLE_ON[3], 0.15)

			row.label = W.CreateLabel(row, "GameFontHighlight", "")
			row.label:SetPoint("LEFT", 10, 0)
			row.label:SetPoint("RIGHT", -64, 0)

			row.tag = W.CreateLabel(row, "GameFontNormalSmall", "In use")
			row.tag:SetPoint("RIGHT", -10, 0)

			row.delete = CreateFrame("Button", nil, row)
			row.delete:SetSize(18, 18)
			row.delete:SetPoint("RIGHT", -8, 0)
			row.delete:SetNormalAtlas("common-icon-redx")
			row.delete:SetHighlightAtlas("common-icon-redx", "ADD")
		end

		local inUse = name == api:GetProfileName()
		row.label:SetText(name)
		row.inUse:SetShown(inUse)
		row.tag:SetShown(inUse)
		row.delete:SetShown(api:CanDeleteProfile(name))

		row:SetScript("OnClick", function()
			if not isLocked and api:UseProfile(name) then
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
				OnProfileChanged()
			end
		end)
		row.delete:SetScript("OnClick", function()
			if not isLocked then
				StaticPopup_Show("DIBSUI_OPTIONS_DELETE_PROFILE", name, nil, { name = name, onDeleted = Refresh })
			end
		end)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(list, scrollBar, view)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(list, scrollBar)

	local manageCard = W.CreateCard(content, "Manage")
	local dialog = CreateNewProfileDialog(context.window, OnProfileChanged)

	local newProfile = manageCard:Add(W.CreateButton(manageCard, "New profile", 150), 8, true)
	newProfile:SetScript("OnClick", function() dialog:Show() end)

	local help = manageCard:Add(W.CreateLabel(manageCard, "GameFontHighlightSmall",
		"Profiles are shared by every character on your account, and each character remembers which one it uses.\n\n"
		.. "A profile holds the settings of every DibsUI addon, so switching changes them all.\n\n"
		.. "Click a profile to use it on this character.\n\n"
		.. "The minimap button's settings are the same in every profile."), 14)
	help:SetWordWrap(true)

	return {
		Sync = Refresh,
		SetCombatLocked = function(locked)
			isLocked = locked
			newProfile:SetEnabled(not locked)
			list:SetAlpha(locked and 0.5 or 1)
			if locked then
				dialog:Hide()
			end
		end,
		Layout = W.CreateFlow(content, { profilesCard, manageCard }),
	}
end

-- The window ----------------------------------------------------------------------------------------

-- The saved size, kept between the smallest the window can be and the screen.
local function GetWindowSize()
	local maxWidth = math.max(MIN_WIDTH, UIParent:GetWidth() or MIN_WIDTH)
	local maxHeight = math.max(MIN_HEIGHT, UIParent:GetHeight() or MIN_HEIGHT)
	local width = tonumber(ns.account.configWidth) or WIDTH
	local height = tonumber(ns.account.configHeight) or HEIGHT
	return math.min(math.max(width, MIN_WIDTH), maxWidth), math.min(math.max(height, MIN_HEIGHT), maxHeight), maxWidth, maxHeight
end

-- Drag the bottom right corner to resize the window. Every page lays itself out again to fit.
local function CreateResizeGrip(frame)
	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetFrameLevel(frame:GetFrameLevel() + 20)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			frame:StartSizing("BOTTOMRIGHT")
		end
	end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		ns.account.configWidth = math.floor(frame:GetWidth() + 0.5)
		ns.account.configHeight = math.floor(frame:GetHeight() + 0.5)
	end)
	return grip
end

-- The tabs down the left: a highlight on hover, and a gold bar and tint on the one that's open.
local function CreateNavButton(parent, text)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(NAV_ROW_HEIGHT)
	local on = W.TOGGLE_ON

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.08)

	local selected = button:CreateTexture(nil, "BACKGROUND")
	selected:SetAllPoints()
	selected:SetColorTexture(on[1], on[2], on[3], 0.15)

	local bar = button:CreateTexture(nil, "ARTWORK")
	bar:SetWidth(3)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("BOTTOMLEFT")
	bar:SetColorTexture(on[1], on[2], on[3], 1)

	local label = W.CreateLabel(button, "GameFontNormal", text)
	label:SetPoint("LEFT", 12, 0)
	label:SetPoint("RIGHT", -6, 0)

	function button:SetSelected(isSelected)
		selected:SetShown(isSelected)
		bar:SetShown(isSelected)
		label:SetFontObject(isSelected and "GameFontHighlight" or "DibsUIOptionsFontNormal")
	end
	button:SetSelected(false)
	return button
end

-- A module's name over its tabs, shown once there's more than one module.
local function CreateNavHeading(parent, text)
	local heading = W.CreateLabel(parent, "GameFontDisableSmall", text:upper())
	heading:SetHeight(NAV_HEADING_HEIGHT)
	heading:SetJustifyV("BOTTOM")
	return heading
end

-- Every tab, in order: each module's, then Profiles. id is how the open tab is remembered.
local function GetTabs()
	local tabs = {}
	for _, module in ipairs(ns.GetModules()) do
		for _, tab in ipairs(module.tabs or {}) do
			tabs[#tabs + 1] = { id = module.key .. ":" .. tab.label, label = tab.label, build = tab.build, module = module }
		end
	end
	tabs[#tabs + 1] = { id = "Profiles", label = "Profiles", build = BuildProfiles }
	return tabs
end

-- "DibsUI" on its own plate across the window's top edge, in the bars' style: slanted ends and a silver
-- and gold double border (TitlePlate, from generate_art.py). The plate's art is 128 x 40 units, cut
-- into a left end, a middle band that stretches to fit the name, and a right end.
local PLATE_SCALE = 1.1
local PLATE_ART_WIDTH = 128
local PLATE_END = 20 -- units at each end holding the slant and border
local PLATE_PADDING = 8 -- between the name and the ends
local PLATE_SIZE = 1.05 -- the plate's scale on the window

local function CreateTitlePlate(frame)
	local titleText = frame.TitleContainer and frame.TitleContainer.TitleText or frame.TitleText
	if titleText then
		titleText:SetText("")
		titleText:Hide()
	end

	local plate = CreateFrame("Frame", nil, frame)
	-- Above the window's border, which the template draws well above the window itself. The border only
	-- reaches its level after the window is made, so this is set each time the window shows.
	local function Raise()
		plate:SetFrameLevel((frame.NineSlice or frame):GetFrameLevel() + 20)
	end
	Raise()
	frame:HookScript("OnShow", Raise)
	local endWidth, height = PLATE_END * PLATE_SCALE, 40 * PLATE_SCALE

	local function Slice(u0, u1)
		local slice = ns.CreateArt(plate, "ARTWORK", "TitlePlate")
		slice:SetTexCoord(u0 / PLATE_ART_WIDTH, u1 / PLATE_ART_WIDTH, 0, 1)
		slice:SetHeight(height)
		return slice
	end
	local left = Slice(0, PLATE_END)
	left:SetWidth(endWidth)
	left:SetPoint("TOPLEFT")
	local right = Slice(PLATE_ART_WIDTH - PLATE_END, PLATE_ART_WIDTH)
	right:SetWidth(endWidth)
	right:SetPoint("TOPRIGHT")
	local middle = Slice(PLATE_END, PLATE_END + 4)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

	local name = plate:CreateFontString(nil, "OVERLAY")
	W.StyleTitle(name, 26)
	name:SetPoint("CENTER", 0, 1)
	plate:SetSize(name:GetStringWidth() + 2 * (endWidth + PLATE_PADDING), height)
	-- Across the window's top edge, standing above it. Offsets here are in the plate's own scale.
	plate:SetScale(PLATE_SIZE)
	plate:SetPoint("CENTER", frame, "TOP", 0, 2 / PLATE_SIZE)
	-- Keeps the plate on screen too when the window is dragged to the top.
	frame:SetClampRectInsets(0, 0, height * PLATE_SIZE / 2 + 2, 0)
	return plate
end

local function CreateConfig()
	local width, height, maxWidth, maxHeight = GetWindowSize()
	local frame = W.CreatePanel("DibsUIConfig", UIParent, width, height, ns.TITLE, "PortraitFrameFlatTemplate")
	frame:SetPortraitToAsset(ns.Media("Logo"))
	CreateTitlePlate(frame)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, maxWidth, maxHeight)
	else
		frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
		frame:SetMaxResize(maxWidth, maxHeight)
	end
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetDontSavePosition(true)
	tinsert(UISpecialFrames, frame:GetName())
	CreateResizeGrip(frame)

	-- The open page's name, beside the logo.
	local pageTitle = W.CreateLabel(frame, "GameFontHighlightLarge", "")
	pageTitle:SetPoint("TOPLEFT", 70, -36)

	local minimapToggle = W.CreateToggleRow(frame, "Show minimap button", ns.SetMinimapButtonShown)
	minimapToggle:SetWidth(minimapToggle.label:GetStringWidth() + 12 + W.TOGGLE_WIDTH)
	minimapToggle:SetPoint("TOPRIGHT", -14, -28)

	-- Unlocking moves every module's frames, so it's here where every page can reach it. It says what
	-- pressing it does.
	local lockButton = W.CreateButton(frame, "Unlock frames", 130)
	lockButton:SetPoint("RIGHT", minimapToggle, "LEFT", -24, 0)
	local function SyncLockButton()
		lockButton:SetText(api:IsLocked() and "Unlock frames" or "Lock frames")
	end
	lockButton:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		api:SetLocked(not api:IsLocked())
	end)
	ns.OnLockChanged = SyncLockButton

	local nav = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	nav:SetPoint("TOPLEFT", 10, BODY_TOP)
	nav:SetPoint("BOTTOMLEFT", 10, 30)
	nav:SetWidth(NAV_WIDTH)

	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", nav, "TOPRIGHT", 6, 0)
	inset:SetPoint("BOTTOMRIGHT", -8, 30)

	local tabs = GetTabs()
	local pages, navButtons = {}, {}
	frame.navButtons = navButtons

	-- After a profile switch every page shows the new profile's settings.
	local context = { window = frame }
	function context.SyncAll()
		SyncLockButton()
		for _, page in ipairs(pages) do
			page.options.Sync()
		end
	end

	local function SelectTab(index)
		for i, page in ipairs(pages) do
			navButtons[i]:SetSelected(i == index)
			page:SetShown(i == index)
		end
		pageTitle:SetText(tabs[index].label)
		ns.account.configTab = tabs[index].id
	end
	frame.SelectTab = SelectTab

	-- With more than one module, each one's tabs sit under its name. Profiles stands apart at the end.
	local showHeadings = #ns.GetModules() > 1
	local y, lastModule = -6, nil
	for i, tab in ipairs(tabs) do
		if tab.module ~= lastModule then
			if showHeadings and tab.module then
				local heading = CreateNavHeading(nav, tab.module.title or tab.module.key)
				heading:SetPoint("TOPLEFT", 12, y)
				y = y - NAV_HEADING_HEIGHT - 2
			elseif not tab.module and i > 1 then
				y = y - 10
			end
			lastModule = tab.module
		end
		local button = CreateNavButton(nav, tab.label)
		button:SetPoint("TOPLEFT", 4, y)
		button:SetPoint("RIGHT", -4, 0)
		button:SetScript("OnClick", function()
			SelectTab(i)
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		end)
		navButtons[i] = button
		y = y - NAV_ROW_HEIGHT - 2

		local page = W.CreateScrollPage(inset)
		local function relayout() page:Relayout() end
		page.options = tab.build(page.content, context, relayout)
		page.options.relayout = relayout
		pages[i] = page
	end

	local combatNote = W.CreateLabel(frame, "GameFontDisableSmall", "Frame size, position and profiles can't be changed during combat")
	combatNote:SetPoint("BOTTOM", 0, 11)

	local function SetCombatLocked(locked)
		lockButton:SetEnabled(not locked)
		for _, page in ipairs(pages) do
			if page.options.SetCombatLocked then
				page.options.SetCombatLocked(locked)
			end
		end
		combatNote:SetShown(locked)
	end

	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
	end)

	frame:SetScript("OnShow", function()
		minimapToggle.toggle:SetChecked(ns.account.showMinimapButton)
		context.SyncAll()
		SetCombatLocked(InCombatLockdown())
		for _, page in ipairs(pages) do
			page:Relayout()
		end
	end)

	-- Opens on the tab used last, or the first.
	local start = 1
	for i, tab in ipairs(tabs) do
		if tab.id == ns.account.configTab then
			start = i
		end
	end
	SelectTab(start)
	frame.tabs = tabs
	return frame
end

local config

function ns.ToggleConfig()
	if not config then
		config = CreateConfig()
		config:Hide()
	end
	config:SetShown(not config:IsShown())
end

-- Opens the window, on a module's first tab (or the tab with that label) when given.
function api:Open(moduleKey, tabLabel)
	if not (config and config:IsShown()) then
		ns.ToggleConfig()
	end
	if moduleKey then
		for i, tab in ipairs(config.tabs) do
			if tab.module and tab.module.key == moduleKey and (not tabLabel or tab.label == tabLabel) then
				config.SelectTab(i)
				break
			end
		end
	end
end

function api:Toggle()
	ns.ToggleConfig()
end

-- Locks or unlocks every module's frames, like the button at the top of the window, and says which.
-- Like the button, it waits for combat to end.
local function ToggleLocked()
	if InCombatLockdown() then
		ns.Print("frames can't be locked or unlocked during combat.")
		return
	end
	local locked = not api:IsLocked()
	api:SetLocked(locked)
	if locked then
		ns.Print("frames locked.")
	else
		ns.Print("frames unlocked. Type /dibsui lock again to lock them.")
	end
end

local function PrintCommands()
	local list = { "/dui opens or closes the settings", "/dui lock locks or unlocks the frames" }
	for _, module in ipairs(ns.GetModules()) do
		if module.slash then
			list[#list + 1] = "/dui " .. module.slash .. " opens " .. (module.title or module.key) .. "'s settings"
		end
	end
	ns.Print(table.concat(list, ", ") .. ".")
end

-- /dibsui opens or closes the settings, /dibsui lock locks or unlocks the frames, and a module's word
-- (its slash, such as "party") opens the window on that module's tab.
SLASH_DIBSUI1 = "/dibsui"
SLASH_DIBSUI2 = "/dui"
SlashCmdList.DIBSUI = function(message)
	local command = (message or ""):match("^%s*(.-)%s*$"):lower()
	if command == "" then
		ns.ToggleConfig()
		return
	elseif command == "lock" then
		ToggleLocked()
		return
	end
	for _, module in ipairs(ns.GetModules()) do
		if module.slash and module.slash:lower() == command then
			api:Open(module.key)
			return
		end
	end
	PrintCommands()
end

-- The game's own settings ------------------------------------------------------------------------

-- DibsUI's page under the game's Options, AddOns: the logo, the installed addons, and a button that
-- opens the full window. The settings live in that window, so this page only points to it.
function ns.RegisterGameSettings()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
		return
	end
	local panel = CreateFrame("Frame")

	local logo = panel:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(ns.Media("Logo"))
	logo:SetSize(64, 64)
	logo:SetPoint("TOPLEFT", 12, -12)

	local title = W.CreateLabel(panel, "GameFontNormalHuge", ns.TITLE)
	W.StyleTitle(title, 36)
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -6)

	local subtitle = W.CreateLabel(panel, "GameFontHighlight", "")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	panel:SetScript("OnShow", function()
		local names = {}
		for _, module in ipairs(ns.GetModules()) do
			local version = C_AddOns.GetAddOnMetadata(module.addon or module.key, "Version")
			names[#names + 1] = (module.title or module.key) .. (version and (" |cff9d9d9d" .. version .. "|r") or "")
		end
		subtitle:SetText("Installed: " .. (#names > 0 and table.concat(names, ", ") or "none"))
	end)

	local open = W.CreateButton(panel, "Open DibsUI settings", 190)
	open:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -18)
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then
			HideUIPanel(SettingsPanel)
		end
		api:Open()
	end)

	local help = W.CreateLabel(panel, "GameFontHighlightSmall",
		"You can also type /dibsui or /dui, or click the DibsUI minimap button. /dibsui lock locks or unlocks the frames.")
	help:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -12)

	local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
	Settings.RegisterAddOnCategory(category)
end
