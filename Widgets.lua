local _, ns = ...

-- Settings controls and page layout for every DibsUI addon, moved here from DibsUI's Config.lua so the
-- addons share one copy. Addons reach them through DibsUIOptions.Widgets (see README.md).


-- Each page's sections flow into as many columns as fit, up to three, each at least this wide.
local COLUMN_WIDTH = 280 -- a row's width until its page lays it out
local COLUMN_MIN_WIDTH = 220
local COLUMN_GAP = 24
local MAX_COLUMNS = 3
local SECTION_GAP = 14 -- between sections in a column
local SECTION_HEIGHT = 26
local PAGE_PADDING = 16
local HEADER_HEIGHT = 30 -- a page heading over a group of sections
local HEADER_GAP = 22 -- above a page heading that follows sections

local INPUT_WIDTH = 44
local DROPDOWN_WIDTH = 190
local DROPDOWN_MIN_WIDTH = 100

-- The switch art's size, from generate_art.py. The knob's centre moves KNOB_TRAVEL either side of the middle.
local TOGGLE_WIDTH, TOGGLE_HEIGHT = 36, 20
local KNOB_QUAD, KNOB_TRAVEL = 24, 8
local TOGGLE_SLIDE_TIME = 0.12
-- The gold of headings, tab names, buttons and switches: a little softer than the game's own.
local GOLD = { 0.93, 0.78, 0.26 }
local TOGGLE_ON = { 0.93, 0.74, 0.24 }
local TOGGLE_OFF = { 0.30, 0.30, 0.33 }

local LINK_SIZE = 20
local LINKED_COLOR = TOGGLE_ON
local UNLINKED_COLOR = { 0.55, 0.55, 0.58 }

local function FormatScale(value)
	return string.format("%.2f", value)
end

local function FormatSize(value)
	return string.format("%d", value)
end

local function FormatPercent(value)
	return string.format("%d%%", value)
end

-- The game's gold fonts, recolored with GOLD. Use these names wherever GameFontNormal* would go.
local GOLD_FONTS = {}
for name, base in pairs({
	DibsUIOptionsFontNormal = "GameFontNormal",
	DibsUIOptionsFontNormalSmall = "GameFontNormalSmall",
	DibsUIOptionsFontNormalLarge = "GameFontNormalLarge",
	DibsUIOptionsFontNormalHuge = "GameFontNormalHuge",
}) do
	local font = CreateFont(name)
	font:CopyFontObject(base)
	font:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	GOLD_FONTS[base] = name
end

-- "DibsUI", larger, in the bundled font: Dibs in shaman blue and UI in gold.
local TITLE_FONT = ns.Media("Fonts\\BarlowSemiCondensed-Bold.ttf")
local SHAMAN_BLUE = "0070dd"
local function StyleTitle(label, size)
	-- Not every client reports whether SetFont worked, so this checks the font it ended up with.
	label:SetFont(TITLE_FONT, size, "")
	if label:GetFont() ~= TITLE_FONT then
		label:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	label:SetShadowOffset(2, -2)
	label:SetShadowColor(0, 0, 0, 0.9)
	label:SetText(("|cff%sDibs|r|cff%02x%02x%02xUI|r"):format(SHAMAN_BLUE,
		math.floor(GOLD[1] * 255 + 0.5), math.floor(GOLD[2] * 255 + 0.5), math.floor(GOLD[3] * 255 + 0.5)))
end

local function CreateLabel(parent, fontObject, text)
	fontObject = GOLD_FONTS[fontObject] or fontObject
	local label = parent:CreateFontString(nil, "OVERLAY", fontObject)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return label
end

local function CreateHint(parent, text)
	local hint = CreateLabel(parent, "GameFontDisableSmall", text)
	hint:SetWordWrap(true)
	return hint
end

local function ShowTooltip(owner, title, text)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title)
	if text then
		GameTooltip:AddLine(text, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
end

-- A gold heading with a divider under it, the way the game's settings group their options.
local function CreateSection(parent, text)
	local section = CreateFrame("Frame", nil, parent)
	section:SetSize(COLUMN_WIDTH, SECTION_HEIGHT)

	local label = CreateLabel(section, "GameFontNormal", text)
	label:SetPoint("TOPLEFT", 0, -2)

	local divider = section:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider")
	divider:SetHeight(1)
	divider:SetPoint("BOTTOMLEFT", 0, 4)
	divider:SetPoint("BOTTOMRIGHT", 0, 4)
	return section
end

-- An iOS style switch: a pill that turns gold with its knob sliding right when on.
local function CreateToggle(parent, onChange)
	local toggle = CreateFrame("Button", nil, parent)
	toggle:SetSize(TOGGLE_WIDTH, TOGGLE_HEIGHT)
	toggle:SetMotionScriptsWhileDisabled(true)

	local track = ns.CreateArt(toggle, "BACKGROUND", "ToggleTrack")
	track:SetAllPoints()

	local glow = ns.CreateArt(toggle, "HIGHLIGHT", "ToggleTrack")
	glow:SetAllPoints()
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.15)

	local knob = ns.CreateArt(toggle, "ARTWORK", "ToggleKnob")
	knob:SetSize(KNOB_QUAD, KNOB_QUAD)

	-- 0 is off and 1 is on. In between while the knob slides.
	local position, from, to, elapsed = 0, 0, 0, 0

	local function Draw()
		knob:SetPoint("CENTER", toggle, "CENTER", (position * 2 - 1) * KNOB_TRAVEL, 0)
		track:SetVertexColor(
			TOGGLE_OFF[1] + (TOGGLE_ON[1] - TOGGLE_OFF[1]) * position,
			TOGGLE_OFF[2] + (TOGGLE_ON[2] - TOGGLE_OFF[2]) * position,
			TOGGLE_OFF[3] + (TOGGLE_ON[3] - TOGGLE_OFF[3]) * position)
	end

	local function Slide(self, delta)
		elapsed = elapsed + delta
		local progress = math.min(elapsed / TOGGLE_SLIDE_TIME, 1)
		position = from + (to - from) * (1 - (1 - progress) ^ 2)
		Draw()
		if progress >= 1 then
			self:SetScript("OnUpdate", nil)
		end
	end

	function toggle:SetChecked(checked, animate)
		self.checked = checked
		to = checked and 1 or 0
		if animate then
			from, elapsed = position, 0
			self:SetScript("OnUpdate", Slide)
		else
			self:SetScript("OnUpdate", nil)
			position = to
			Draw()
		end
	end

	function toggle:GetChecked()
		return self.checked
	end

	toggle:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked, true)
		PlaySound(self.checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		onChange(self.checked)
	end)
	toggle:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
	toggle:SetScript("OnDisable", function(self) self:SetAlpha(0.4) end)

	toggle:SetChecked(false)
	return toggle
end

-- A label with a switch at the right. Clicking anywhere on the row flips the switch.
local function CreateToggleRow(parent, text, onChange)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(COLUMN_WIDTH, 30)

	local label = CreateLabel(row, "GameFontHighlight", text)
	label:SetPoint("LEFT")

	local toggle = CreateToggle(row, onChange)
	toggle:SetPoint("RIGHT")
	row.toggle = toggle
	row.label = label

	row:SetScript("OnClick", function()
		if toggle:IsEnabled() then
			toggle:Click()
		end
	end)

	function row:SetEnabled(enabled)
		toggle:SetEnabled(enabled)
		label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
	end

	return row
end

-- A switch for something that isn't built yet: greyed out and off, with a tag saying so. Each one keeps
-- the name of the feature it's holding a place for, which is also in the implementation notes.
local function CreatePlaceholderRow(parent, text, feature)
	local row = CreateToggleRow(parent, text, function() end)
	row.feature = feature
	row:SetEnabled(false)
	row.toggle:SetChecked(false)
	local tag = CreateLabel(row, "GameFontDisableSmall", "Coming soon")
	tag:SetPoint("RIGHT", row.toggle, "LEFT", -8, 0)
	row:SetScript("OnEnter", function(self)
		ShowTooltip(self, text, "Not built yet. This switch will work in a later version.")
	end)
	row:SetScript("OnLeave", HideTooltip)
	-- Combat locking leaves these alone.
	row.SetEnabled = function() end
	return row
end

-- A chain that shows whether two frames share one width. Gold and joined while linked, grey and pulled
-- apart while not. Clicking it links or unlinks them. link = { isLinked = function, setLinked =
-- function(linked), names = { first, second } }.
local function CreateLinkButton(parent, link)
	local names = link.names
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(LINK_SIZE, LINK_SIZE)
	button:SetMotionScriptsWhileDisabled(true)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	local glow = button:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.35)

	function button:Sync()
		local linked = link.isLinked()
		local art = ns.Media(linked and "LinkOn" or "LinkOff")
		local color = linked and LINKED_COLOR or UNLINKED_COLOR
		icon:SetTexture(art)
		glow:SetTexture(art)
		icon:SetVertexColor(color[1], color[2], color[3])
	end

	button:SetScript("OnClick", function(self)
		link.setLinked(not link.isLinked())
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if parent.OnLinkChanged then
			parent:OnLinkChanged()
		end
		self:GetScript("OnEnter")(self)
	end)
	button:SetScript("OnEnter", function(self)
		if link.isLinked() then
			ShowTooltip(self, "Widths linked", string.format(
				"The %s and %s share one width. Changing either one on its own tab unlinks them. Click to unlink.",
				names[1], names[2]))
		else
			ShowTooltip(self, "Widths unlinked", string.format(
				"The %s and %s each have their own width. Click to link them again: the %s takes the %s's width.",
				names[1], names[2], names[2], names[1]))
		end
	end)
	button:SetScript("OnLeave", HideTooltip)
	button:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
	button:SetScript("OnDisable", function(self) self:SetAlpha(0.4) end)
	return button
end

-- A label, Blizzard's minimal slider with step arrows, and a box for typing an exact value. With a link,
-- a chain button sits at the top right, beside the label.
local function CreateSliderRow(parent, text, range, format, getValue, setValue, link)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(COLUMN_WIDTH, 48)

	local label = CreateLabel(row, "GameFontHighlight", text)
	label:SetPoint("TOPLEFT", 0, -4)
	row.label = label

	local input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	input:SetSize(INPUT_WIDTH, 20)
	input:SetPoint("BOTTOMRIGHT", 0, 2)
	input:SetAutoFocus(false)
	input:SetMaxLetters(5)
	input:SetJustifyH("CENTER")

	local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
	slider:SetPoint("BOTTOMLEFT", 0, 2)
	slider:SetPoint("RIGHT", input, "LEFT", -12, 0)
	slider:SetHeight(20)
	slider:Init(getValue(), range.min, range.max, math.floor((range.max - range.min) / range.step + 0.5))

	if link then
		row.link = CreateLinkButton(row, link)
		row.link:SetPoint("TOPRIGHT", 0, 0)
	end

	-- The slider can only rest on its steps, while a typed value can be exact. So moving the
	-- slider from code mustn't feed its snapped value back in as a new setting.
	local isSyncing = false

	function row:Sync()
		isSyncing = true
		slider:SetValue(getValue())
		isSyncing = false
		input:SetText(format(getValue()))
		input:SetCursorPosition(0)
		if row.link then
			row.link:Sync()
		end
	end

	-- Changing a frame's own width can unlink it, which its chain shows straight away.
	local function Changed(value)
		setValue(value)
		if row.link then
			row.link:Sync()
		end
	end

	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if not isSyncing then
			Changed(value)
			input:SetText(format(getValue()))
		end
	end, row)

	input:SetScript("OnEnterPressed", function(self)
		local value = tonumber((self:GetText():gsub("%%", "")))
		if value then
			Changed(value)
		end
		self:ClearFocus()
		row:Sync()
	end)
	input:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		row:Sync()
	end)
	input:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	-- The value and the link can be locked separately: a General width is greyed while unlinked, but its
	-- link still works.
	function row:SetEnabled(enabled, linkEnabled)
		if not enabled then
			input:ClearFocus()
		end
		slider:SetEnabled(enabled)
		input:SetEnabled(enabled)
		label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
		if self.link then
			if linkEnabled == nil then
				linkEnabled = enabled
			end
			self.link:SetEnabled(linkEnabled)
		end
	end

	return row
end

-- A label on the left and Blizzard's dropdown on the right. In a narrow section the dropdown gives up
-- width so it doesn't run into its label.
local function CreateDropdownRow(parent, text, rowWidth, dropdownWidth)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(rowWidth or COLUMN_WIDTH, 34)

	local label = CreateLabel(row, "GameFontHighlight", text)
	label:SetPoint("LEFT")
	row.label = label

	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(dropdownWidth or DROPDOWN_WIDTH)
	dropdown:SetPoint("RIGHT")
	row.dropdown = dropdown

	function row:FitWidth(width)
		local room = width - label:GetStringWidth() - 16
		dropdown:SetWidth(math.max(math.min(dropdownWidth or DROPDOWN_WIDTH, room), DROPDOWN_MIN_WIDTH))
	end

	function row:SetEnabled(enabled)
		dropdown:SetEnabled(enabled)
		label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
	end
	return row
end

-- The newer grey and gold buttons from Blizzard's recent panels, in place of the old red ones.
-- The hover art replaces the normal art rather than being a highlight texture: highlight textures draw in
-- the HIGHLIGHT layer, above the button's text, and this art is opaque, so the text vanished on hover.
local BUTTON_ART = {
	normal = "common-button-tertiary-normal",
	hover = "common-button-tertiary-hover",
}

local function CreateButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, 24)
	button:SetNormalAtlas(BUTTON_ART.normal)
	button:SetPushedAtlas("common-button-tertiary-pressed")
	button:SetDisabledAtlas("common-button-tertiary-disabled")
	button:SetNormalFontObject(DibsUIOptionsFontNormal)
	button:SetHighlightFontObject(GameFontHighlight)
	button:SetDisabledFontObject(GameFontDisable)
	button:SetPushedTextOffset(0, -1)
	button:SetText(text)
	button:HookScript("OnEnter", function(self)
		if self:IsEnabled() then
			self:GetNormalTexture():SetAtlas(BUTTON_ART.hover)
		end
	end)
	button:HookScript("OnLeave", function(self)
		self:GetNormalTexture():SetAtlas(BUTTON_ART.normal)
	end)
	button:HookScript("OnDisable", function(self)
		self:GetNormalTexture():SetAtlas(BUTTON_ART.normal)
	end)
	return button
end

-- A color swatch the size of the game's own, shown faded while the color is the default.
local function CreateSwatch(parent)
	local swatch = CreateFrame("Button", nil, parent, "ColorSwatchTemplate")
	-- The template passes clicks on to its parent, which would flip a switch on the row as well.
	swatch:SetPropagateMouseClicks(false)
	swatch:SetSize(22, 22)
	swatch.SwatchBg:SetSize(20, 20)
	swatch.InnerBorder:SetSize(18, 18)
	swatch.Color:SetSize(16, 16)

	function swatch:SetSwatchColor(r, g, b, isDefault)
		self:SetColorRGB(r, g, b)
		self:SetAlpha(isDefault and 0.5 or 1)
	end
	return swatch
end

-- Opens the game's color picker on a color. onPick gets each color as it's dragged, and the starting one
-- again if the picker is cancelled.
local function PickColor(r, g, b, onPick, onCancel)
	ColorPickerFrame:SetupColorPickerAndShow({
		r = r, g = g, b = b,
		swatchFunc = function()
			onPick({ ColorPickerFrame:GetColorRGB() })
		end,
		cancelFunc = onCancel,
	})
end

-- Each font shows in its own typeface in the dropdown. Menus don't allow SetFont on their text,
-- so every font gets a font object instead.
local previewFonts = {}

local function GetPreviewFont(path)
	if not previewFonts[path] then
		local font = CreateFont("DibsUIOptionsFontPreview" .. (#previewFonts + 1))
		previewFonts[#previewFonts + 1] = font
		font:CopyFontObject(GameFontHighlight)
		local _, size = GameFontHighlight:GetFont()
		font:SetFont(path, size, "")
		previewFonts[path] = font
	end
	return previewFonts[path]
end

local function SameFont(a, b)
	return a ~= nil and b ~= nil and a:upper() == b:upper()
end

-- Fills a dropdown with every font, each in its own typeface. With nilLabel, the first choice is "no font
-- of its own" (such as following the master font), which get returns as nil. A saved font that can't be
-- loaded any more shows as that first choice, which is what it falls back to. getFonts returns
-- { { name, path }, ... }; without it, the game's fonts and LibSharedMedia's.
local function SetUpFontMenu(dropdown, get, set, nilLabel, getFonts)
	getFonts = getFonts or ns.GetFonts
	dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(360)
		if nilLabel then
			root:CreateRadio(nilLabel, function() return get() == nil end, function() set(nil) end, false)
		end
		for _, font in ipairs(getFonts()) do
			local radio = root:CreateRadio(font.name,
				function() return SameFont(get(), font.path) end,
				function() set(font.path) end, font)
			radio:AddInitializer(function(button)
				button.fontString:SetFontObject(GetPreviewFont(font.path))
			end)
		end
	end)
	dropdown:SetSelectionTranslator(function(selection)
		return selection.data and selection.data.name or nilLabel
	end)
	-- Only fonts that load are listed, so nothing is picked when the saved one can't load: it shows what
	-- the text falls back to instead. The master font falls back to the game's.
	dropdown:SetDefaultText(nilLabel or "Friz Quadrata")
end

-- A dropdown of { key, label } choices. onPicked runs after the setting changes.
local function SetUpChoiceMenu(dropdown, list, get, set)
	dropdown:SetupMenu(function(_, root)
		for _, item in ipairs(list) do
			root:CreateRadio(item.label, function() return get() == item.key end, function() set(item.key) end, item)
		end
	end)
	dropdown:SetSelectionTranslator(function(selection)
		return selection.data.label
	end)
end

-- Layout ------------------------------------------------------------------------------------------

-- A section of a page: a heading and the rows under it, stacked. Hidden rows are left out and the rest
-- close up, so a section can change with what's picked. Rows take the section's width unless they
-- keep their own, like buttons.
-- Without a title the rows start at the top, for a section right under a page heading.
local function CreateCard(parent, title)
	local card = CreateFrame("Frame", nil, parent)
	card:SetSize(COLUMN_WIDTH, SECTION_HEIGHT)
	card.top = 0
	if title then
		local heading = CreateSection(card, title)
		heading:SetPoint("TOPLEFT")
		heading:SetPoint("TOPRIGHT")
		card.top = SECTION_HEIGHT + 2
	end
	card.entries = {}

	-- gap is the space above the row.
	function card:Add(region, gap, keepWidth)
		self.entries[#self.entries + 1] = { region = region, gap = gap or 0, keepWidth = keepWidth }
		return region
	end
	return card
end

local function GetRegionHeight(region)
	if region.GetStringHeight then
		return region:GetStringHeight() or 0
	end
	return region:GetHeight() or 0
end

-- Stacks a section's shown rows at this width. Returns its height.
local function LayoutCard(card, width)
	card:SetWidth(width)
	local y = card.top
	for _, entry in ipairs(card.entries) do
		local region = entry.region
		if region:IsShown() then
			y = y + entry.gap
			region:ClearAllPoints()
			region:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
			if not entry.keepWidth then
				region:SetWidth(width)
				if region.FitWidth then
					region:FitWidth(width)
				end
			end
			y = y + GetRegionHeight(region)
		end
	end
	card:SetHeight(y)
	return y
end

local function PlaceCard(card, parent, x, y, width)
	local height = LayoutCard(card, width)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	return height
end

-- Lays shown sections out in as many columns as fit the width, each going under the shortest column
-- so far, so the first ones fill the top row in order. Returns how far down the tallest column ends.
local function LayoutCards(cards, parent, x, y, width)
	local columns = math.floor((width + COLUMN_GAP) / (COLUMN_MIN_WIDTH + COLUMN_GAP))
	columns = math.max(1, math.min(MAX_COLUMNS, columns))
	local columnWidth = (width - (columns - 1) * COLUMN_GAP) / columns
	local depths = {}
	for i = 1, columns do
		depths[i] = 0
	end
	for _, card in ipairs(cards) do
		if card:IsShown() then
			local shortest = 1
			for i = 2, columns do
				if depths[i] < depths[shortest] then
					shortest = i
				end
			end
			local height = PlaceCard(card, parent, x + (shortest - 1) * (columnWidth + COLUMN_GAP), y + depths[shortest], columnWidth)
			depths[shortest] = depths[shortest] + height + SECTION_GAP
		end
	end
	local deepest = 0
	for i = 1, columns do
		deepest = math.max(deepest, depths[i] - SECTION_GAP)
	end
	return y + deepest
end

-- A larger gold heading across the page, over a group of sections such as one frame's texts.
local function CreatePageHeader(parent, text)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(HEADER_HEIGHT)
	local label = CreateLabel(header, "GameFontNormalLarge", text)
	label:SetPoint("TOPLEFT", 0, -2)
	local divider = header:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider")
	divider:SetHeight(1)
	divider:SetPoint("BOTTOMLEFT", 0, 6)
	divider:SetPoint("BOTTOMRIGHT", 0, 6)
	header.isHeader = true
	return header
end

-- A page's contents, top to bottom: headings across the page, sections flowing into columns, and wide
-- sections (marked span) that sit on their own row, like a text picker. Returns the layout function.
local function CreateFlow(content, items)
	return function(pageWidth)
		local x, y = PAGE_PADDING, PAGE_PADDING
		local pending = {}
		local function Flush()
			if #pending > 0 then
				y = LayoutCards(pending, content, x, y, pageWidth) + SECTION_GAP
				pending = {}
			end
		end
		for i, item in ipairs(items) do
			if item.isHeader then
				Flush()
				if i > 1 then
					y = y + HEADER_GAP - SECTION_GAP
				end
				item:ClearAllPoints()
				item:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
				item:SetWidth(pageWidth)
				y = y + HEADER_HEIGHT
			elseif item.span then
				Flush()
				if item:IsShown() then
					y = y + PlaceCard(item, content, x, y, math.min(pageWidth, item.span)) + SECTION_GAP
				end
			else
				pending[#pending + 1] = item
			end
		end
		Flush()
		return y - SECTION_GAP
	end
end

-- A tab's page: its content scrolls with the mouse wheel or the scroll bar at the right, and is laid
-- out again whenever the window changes size or a page shows or hides some of its rows.
local function CreateScrollPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()
	page:Hide()

	local scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
	scrollBar:SetPoint("TOPRIGHT", -8, -8)
	scrollBar:SetPoint("BOTTOMRIGHT", -8, 8)

	local scroll = CreateFrame("ScrollFrame", nil, page)
	scroll:SetClipsChildren(true)
	scroll:SetPoint("TOPLEFT", 0, -2)
	scroll:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -4, -6)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollBar)
	page.content = content

	function page:Relayout()
		local width = scroll:GetWidth()
		if not self.options or not width or width <= 2 * PAGE_PADDING then
			return
		end
		local height = self.options.Layout(width - 2 * PAGE_PADDING)
		content:SetSize(width, height + PAGE_PADDING)
	end

	scroll:SetScript("OnSizeChanged", function() page:Relayout() end)
	-- A page shows the current settings whenever it's opened, since another page may share some of them.
	page:SetScript("OnShow", function()
		if page.options then
			page.options.Sync()
		end
		page:Relayout()
	end)
	return page
end

-- A flat Blizzard panel with a title and close button.
local function CreatePanel(name, parent, width, height, title, template)
	local frame = CreateFrame("Frame", name, parent, template or "DefaultPanelFlatTemplate")
	frame:SetSize(width, height)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetTitle(title)

	-- The flat background is built from atlas pieces, and the simulator is missing some of them. A plain
	-- fill underneath keeps the window from being see-through if a client lacks them too.
	local fill = frame.Bg:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetAllPoints()
	local color = PANEL_BACKGROUND_COLOR
	if color then
		fill:SetColorTexture(color.r, color.g, color.b, 1)
	else
		fill:SetColorTexture(0.07, 0.07, 0.08, 1)
	end

	if not frame.CloseButton then
		CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
	end
	return frame
end

-- The game's fonts, then any from LibSharedMedia. Only the ones this client can load are offered.
local GAME_FONTS = {
	{ name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
	{ name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
	{ name = "Skurri", path = "Fonts\\SKURRI.TTF" },
	{ name = "2002", path = "Fonts\\2002.TTF" },
	{ name = "Page Text", path = "Fonts\\K_PAGETEXT.TTF" },
	{ name = "Damage", path = "Fonts\\K_DAMAGE.TTF" },
}

local fontProbe = UIParent:CreateFontString()

function ns.GetFonts(extra)
	local fonts, seen = {}, {}
	local function Add(name, path)
		local id = path:upper()
		if not seen[id] and fontProbe:SetFont(path, 12, "") ~= false then
			seen[id] = true
			fonts[#fonts + 1] = { name = name, path = path }
		end
	end
	for _, font in ipairs(extra or {}) do
		Add(font.name, font.path)
	end
	for _, font in ipairs(GAME_FONTS) do
		Add(font.name, font.path)
	end
	local media = LibStub and LibStub("LibSharedMedia-3.0", true)
	if media then
		for _, name in ipairs(media:List("font")) do
			local path = media:Fetch("font", name, true)
			if type(path) == "string" then
				Add(name, path)
			end
		end
	end
	return fonts
end

-- What addons use, through DibsUIOptions.Widgets. Keep this list in step with README.md.
ns.Widgets = {
	-- Sizes and colors a page may need to line its own pieces up with these.
	COLUMN_WIDTH = COLUMN_WIDTH,
	COLUMN_GAP = COLUMN_GAP,
	SECTION_GAP = SECTION_GAP,
	PAGE_PADDING = PAGE_PADDING,
	INPUT_WIDTH = INPUT_WIDTH,
	DROPDOWN_WIDTH = DROPDOWN_WIDTH,
	TOGGLE_WIDTH = TOGGLE_WIDTH,
	TOGGLE_ON = TOGGLE_ON,
	GOLD = GOLD,
	TOGGLE_OFF = TOGGLE_OFF,

	FormatScale = FormatScale,
	FormatSize = FormatSize,
	FormatPercent = FormatPercent,

	CreateLabel = CreateLabel,
	StyleTitle = StyleTitle,
	CreateHint = CreateHint,
	ShowTooltip = ShowTooltip,
	HideTooltip = HideTooltip,
	CreateSection = CreateSection,
	CreateToggle = CreateToggle,
	CreateToggleRow = CreateToggleRow,
	CreatePlaceholderRow = CreatePlaceholderRow,
	CreateLinkButton = CreateLinkButton,
	CreateSliderRow = CreateSliderRow,
	CreateDropdownRow = CreateDropdownRow,
	CreateButton = CreateButton,
	CreateSwatch = CreateSwatch,
	PickColor = PickColor,
	SetUpFontMenu = SetUpFontMenu,
	SetUpChoiceMenu = SetUpChoiceMenu,
	GetFonts = ns.GetFonts,

	CreateCard = CreateCard,
	LayoutCard = LayoutCard,
	PlaceCard = PlaceCard,
	LayoutCards = LayoutCards,
	CreatePageHeader = CreatePageHeader,
	CreateFlow = CreateFlow,
	CreateScrollPage = CreateScrollPage,
	CreatePanel = CreatePanel,
}

ns.api.Widgets = ns.Widgets
