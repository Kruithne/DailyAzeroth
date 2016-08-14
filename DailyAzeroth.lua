--[[
	DailyAzeroth (C) Kruithne <kruithne@gmail.com>
	Licensed under GNU General Public Licence version 3.
	
	https://github.com/Kruithne/DailyAzerothAddon

	DailyAzeroth.lua - Core engine file for the addon.
]]

-- Core container for stuffs.
DailyAzeroth = {
	Name = "DailyAzeroth",
	ItemCount = 12,
	Sorting = "Name",
	SortMethod = 1, -- 1 = Ascending, 2 = Descending,
	SortTabs = {},
	SelectCount = 0,
	ShowCompleted = false,
	SelectedFilter = "All",
	ICON_DATA = {}
};

local defaultFilter = {
	Name = "All",
	Colour =  {r = 1.0, g = 1.0, b = 1.0, colorStr = "ffffffff"}
};

local CreationPanel = {};
local IconPickFrames = {};

local CLASSES = {
	{"HUNTER", "Hunter"},
    {"WARLOCK", "Warlock"},
    {"PRIEST", "Priest"},
    {"PALADIN", "Paladin"},
    {"MAGE", "Mage"},
    {"ROGUE", "Rogue"},
    {"DRUID", "Druid"},
    {"SHAMAN", "Shaman"},
    {"WARRIOR", "Warrior"},
    {"DEATHKNIGHT", "Death Knight"},
    {"MONK", "Monk"},
    {"DEMONHUNTER", "Demon Hunter"}
};

local CLASS_COLOURS = {
    ["HUNTER"] = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
    ["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, colorStr = "ff9482c9" },
    ["PRIEST"] = { r = 1.0, g = 1.0, b = 1.0, colorStr = "ffffffff" },
    ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
    ["MAGE"] = { r = 0.41, g = 0.8, b = 0.94, colorStr = "ff69ccf0" },
    ["ROGUE"] = { r = 1.0, g = 0.96, b = 0.41, colorStr = "fffff569" },
    ["DRUID"] = { r = 1.0, g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
    ["SHAMAN"] = { r = 0.0, g = 0.44, b = 0.87, colorStr = "ff0070de" },
    ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12 , b = 0.23, colorStr = "ffc41f3b" },
    ["MONK"] = { r = 0.0, g = 1.00 , b = 0.59, colorStr = "ff00ff96" },
    ["DEMONHUNTER"] = { r = 0.30, g = 0.84, b = 0.15, colorStr = "ff4dd827" }
};

local taskTypes = {"Daily", "Weekly", "Misc"};

local autoCompleteDefault = "No auto-complete";
local autoCompleteQuest = "Quest Complete";
local autoCompleteEntity = "Mob Slain";

local autoCompleteTypes = {
	[autoCompleteDefault] = "",
	[autoCompleteQuest] = "Put quest title here!",
	[autoCompleteEntity] = "Put mob name here!"
};

local DA = DailyAzeroth;
local PLAYER_GUID = UnitGUID("player");

--
-- Local Functions
--

local function ColourString(input, colour)
	return "|c" .. colour.colorStr .. input .. FONT_COLOR_CODE_CLOSE;
end

local function PrintMessage(m)
	DEFAULT_CHAT_FRAME:AddMessage(BATTLENET_FONT_COLOR_CODE .. "DailyAzeroth: " .. FONT_COLOR_CODE_CLOSE .. m);
end

local function ResetUserData()
	DailyAzerothData = {
		Filters = {},
		Tracks = {}
	};
end

local function RegisterSortTab(tab, sortType)
	table.insert(DailyAzeroth.SortTabs, tab);
	tab.SortType = sortType;
end

local function RefreshButtons()
	if DA.SelectCount > 0 then
		DailyAzerothMainCompleteButton:Enable();
		DailyAzerothMainDeleteButton:Enable();
	else
		DailyAzerothMainCompleteButton:Disable();
		DailyAzerothMainDeleteButton:Disable();
	end
end

local function Load()

	CreationPanel = {
		["Frame"] = DailyAzerothCreationPanel,
		["IconPickHighlight"]  = DailyAzerothCreationPanelIconPickHighlight,
		["Buttons"] = {
			["Create"] = DailyAzerothCreationPanelCreateButton,
			["IconPrev"] = DailyAzerothCreationPanelIconPrev,
			["IconNext"] = DailyAzerothCreationPanelIconNext
		},
		["Fields"] = {
			["Title"] = DailyAzerothCreationPanelTitleField,
			["Character"] = DailyAzerothCreationPanelCharacterField,
			["Note"] = DailyAzerothCreationPanelNoteField,
			["Type"] = DailyAzerothCreationPanelTypeField,
			["ACType"] = DailyAzerothCreationPanelCompleteTypeField,
			["ACValue"] = DailyAzerothCreationPanelCompleteDataField
		}
	};

	-- Init user data if none exists.
	if DailyAzerothData == nil then
		ResetUserData();
	end
	
	for index, track in pairs(DailyAzerothData.Tracks) do
		track.Selected = false;
	end
	
	RegisterSortTab(DailyAzerothTitleSort, "Name");
	RegisterSortTab(DailyAzerothCharacterSort, "Character");
	RegisterSortTab(DailyAzerothNoteSort, "Note");
	RegisterSortTab(DailyAzerothTypeSort, "Type");
	
	RefreshButtons();

	local old = GetQuestReward;
	GetQuestReward = function(...)
		old(...);
		DailyAzeroth_ACHandle(autoCompleteQuest, GetTitleText());
	end

	-- Hook toast anchoring
	local anchorHook = AlertFrame_SetDigsiteCompleteToastFrameAnchors;
	AlertFrame_SetDigsiteCompleteToastFrameAnchors = function(anchor)
		anchor = anchorHook(anchor);
		DailyAzeroth_FixToastAnchors(anchor);
	end
end

local function UpdateTimers()
	local lastSTR = DailyAzerothData.LastSTR;
	local lastLoadTime = DailyAzerothData.LastLoadTime;

	if lastSTR == nil then lastSTR = 0; end
	if lastLoadTime == nil then lastLoadTime = 0; end

	local currentTime = time();
	local currentSTR = GetQuestResetTime();

	if (currentSTR > lastSTR) or (currentTime - lastLoadTime > 86400) then
		DailyAzeroth_ResetTasks("Daily");
	end

	DailyAzerothData.LastSTR = currentSTR;
	DailyAzerothData.LastLoadTime = currentTime;
end

local function UpdateSelectCount()
	DailyAzerothMainSelectedText:SetText(DA.SelectCount .. " tasks selected.");
end

local function GetNonCompletedTracks()
	local tracks = DailyAzerothData.Tracks;
	local newTracks = {};
	
	for index, track in pairs(tracks) do
		if not track.Completed then
			table.insert(newTracks, track);
		end
	end
	
	return newTracks;
end

local function FilterExists(charName)
	for index, value in pairs(DailyAzerothData.Filters) do
		if value.Name == charName then
			return true;
		end
	end
	
	return false;
end

local function ColourCharacterName(charName)
	for index, value in pairs(DailyAzerothData.Filters) do
		if value.Name == charName then
			return ColourString(charName, value.Colour);
		end
	end
	return charName;
end

local function FilterTracks(tracks)
	local newTracks = {};
	
	for index, value in pairs(tracks) do
		if value ~= nil and (DA.SelectedFilter == "All" or value.Character == DA.SelectedFilter) then
			table.insert(newTracks, value);
		end
	end
	
	return newTracks;
end

--
-- Global Functions
--

function DailyAzeroth_FixToastAnchors(alertAnchor)
	-- skip work if there hasn't been a toast yet
	if ( DailyAzerothToast1 ) then
		for i = 1, MAX_ACHIEVEMENT_ALERTS do
			local frame = _G["DailyAzerothToast"..i];
			if ( frame and frame:IsShown() ) then
				frame:SetPoint("BOTTOM", alertAnchor, "TOP", 0, 10);
				alertAnchor = frame;
			end
		end
	end
	return alertAnchor;
end

function DailyAzeroth_ShowToast(icon, title)
	local frame = DailyAzeroth_GetToastFrame();
	if ( not frame ) then
	    -- We ran out of frames! Bail!
	    return;
	end

	PlaySound("UI_Scenario_Ending");
	 
	local frameName = frame:GetName();
	local displayName = _G[frameName.."Name"];
	 
	displayName:SetText(title);
	 
	_G[frameName.."IconTexture"]:SetTexture(icon);
	 
	AlertFrame_AnimateIn(frame);
	AlertFrame_FixAnchors();
end
 
function DailyAzeroth_GetToastFrame()
	local name, frame, previousFrame;
	for i=1, MAX_ACHIEVEMENT_ALERTS do
		name = "DailyAzerothToast" .. i;
		frame = _G[name];

		if ( frame ) then
			if ( not frame:IsShown() ) then
				return frame;
			end
		else
			frame = CreateFrame("Button", name, UIParent, "DailyAzerothToastTemplate");
			if ( not previousFrame ) then
				frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 128);
			else
				frame:SetPoint("BOTTOM", previousFrame, "TOP", 0, -10);
			end
			return frame;
		end
		previousFrame = frame;
	end
	return nil;
end

function DailyAzeroth_DeleteSelectedFilter()
	if DA.SelectedFilter ~= "All" then
		-- Delete this filter.
		for index, filter in pairs(DailyAzerothData.Filters) do
			if filter.Name == DA.SelectedFilter then
				DailyAzerothData.Filters[index] = nil;
			end
		end
		
		-- Delete tracks using this filter
		for index, track in pairs(DailyAzerothData.Tracks) do
			if track.Character == DA.SelectedFilter then
				DailyAzerothData.Tracks[index] = nil;
			end
		end
		
		-- Select the "All" filter.
		DailyAzerothFilterButton1:Click();
	end
end

function DailyAzeroth_ResetTasks(taskType)
	if taskType == "Daily" then
		DailyAzerothData.LastSTR = GetQuestResetTime();
		DailyAzerothData.LastLoadTime = time();
	end

	for index, track in pairs(DailyAzerothData.Tracks) do
		if track.Type == taskType then
			track.Completed = false;
		end
	end
	
	DailyAzeroth_UpdateButtons();
end

local selectedIconIndex = 0;
local selectedIcon = nil;

function DailyAzeroth_CreateNewTask()
	local taskName = CreationPanel.Fields.Title:GetText();
	local filterIndex = CreationPanel.Fields.Character.selectedValue;
	local note = CreationPanel.Fields.Note:GetText();
	local typeIndex = CreationPanel.Fields.Type.selectedValue;

	local ACValue = nil;
	local ACType = CreationPanel.Fields.ACType.selectedValue;

	if ACType == autoCompleteDefault or ACType == 0 then
		ACType = nil;
	else
		ACValue = CreationPanel.Fields.ACValue:GetText();
		if string.len(ACValue) == 0 then
			ACType = nil;
			ACValue = nil;
		end
	end
	
	if selectedIcon ~= nil and string.len(taskName) > 0 and typeIndex > 0 then
		local filters = {};
	
		if filterIndex == 0 then
			for index, filter in pairs(DailyAzerothData.Filters) do
				table.insert(filters, filter.Name);
			end
		else		
			local filter = DailyAzerothData.Filters[filterIndex];
			if filter == nil then
				return;
			end
			
			table.insert(filters, filter.Name);
		end
		
		for index, character in pairs(filters) do
				local newTask = {
				Name = taskName,
				Character = character,
				Note = note,
				Type = taskTypes[typeIndex],
				Icon = selectedIcon,
				Completed = false,
				Selected = false,
				ACType = ACType,
				ACValue = ACValue
			};
			
			table.insert(DailyAzerothData.Tracks, newTask);
		end
		
		DailyAzeroth_UpdateButtons();
		CreationPanel.Frame:Hide();
	end
end

function DailyAzeroth_CreateNewFilter()
	local classValue = DailyAzerothSlideOutFilterClassDropDown.selectedValue;
	local characterName = DailyAzerothSlideOutNewFilterNameField:GetText();
	
	if classValue > 0 and string.len(characterName) > 0 then
		if not FilterExists(characterName) then
			local newFilter = {
				Name = characterName,
				Colour = CLASS_COLOURS[CLASSES[classValue][1]];
			};
			
			table.insert(DailyAzerothData.Filters, newFilter);
			DailyAzeroth_UpdateFilters();
			DailyAzerothSlideOut:Hide();
		end
	end
end

function DailyAzeroth_InitTypeDropdown()
	for index, value in pairs(taskTypes) do
		local info = UIDropDownMenu_CreateInfo();
		
		info.text = value;
		info.value = index;
		info.func = DailyAzeroth_ClickFilterDropdown;
		
		UIDropDownMenu_AddButton(info);
	end
end

function DailyAzeroth_InitCompleteTypeDropdown()
	for title, placeholder in pairs(autoCompleteTypes) do
		local info = UIDropDownMenu_CreateInfo();

		info.text = title;
		info.value = title;
		info.func = DailyAzeroth_ClickAutoCompleteDropdown;

		UIDropDownMenu_AddButton(info);
	end
end

function DailyAzeroth_InitCharacterDropdown()
	local info = UIDropDownMenu_CreateInfo();
	
	info.text = "All Characters";
	info.value = 0;
	info.func = DailyAzeroth_ClickFilterDropdown;
	
	UIDropDownMenu_AddButton(info);
	
	for index, value in pairs(DailyAzerothData.Filters) do
		info = UIDropDownMenu_CreateInfo();
		
		info.text = ColourString(value.Name, value.Colour);
		info.value = index;
		info.func = DailyAzeroth_ClickFilterDropdown;
		
		UIDropDownMenu_AddButton(info);
	end
end

function DailyAzeroth_InitIconDropdown()
	for key, icons in pairs(DA.ICON_DATA) do
		local info = UIDropDownMenu_CreateInfo();

		info.text = key;
		info.value = key;
		info.func = DailyAzeroth_ClickIconDropdown;

		UIDropDownMenu_AddButton(info);
	end
end

function DailyAzeroth_InitFilterDropdown()
	for index, value in pairs(CLASSES) do
		local info = UIDropDownMenu_CreateInfo();
		
		info.text = ColourString(value[2], CLASS_COLOURS[value[1]]);
		info.value = index;
		info.func = DailyAzeroth_ClickFilterDropdown;
		
		UIDropDownMenu_AddButton(info);
	end
end

function DailyAzeroth_ClickFilterDropdown(self, arg1, arg2, checked)
	if not checked then
		UIDropDownMenu_SetSelectedValue(UIDROPDOWNMENU_OPEN_MENU, self.value);
	end
end

function DailyAzeroth_ClickAutoCompleteDropdown(self, arg1, arg2, checked)
	if not checked then
		UIDropDownMenu_SetSelectedValue(UIDROPDOWNMENU_OPEN_MENU, self.value);
		CreationPanel.Fields.ACValue:SetText(autoCompleteTypes[self.value]);
	end
end

local iconPickOffset = 1;
local iconPickSelected = nil;

function DailyAzeroth_ClickIconDropdown(self, arg1, arg2, checked)
	if not checked then
		UIDropDownMenu_SetSelectedValue(UIDROPDOWNMENU_OPEN_MENU, self.value);
		iconPickSelected = self.value;
		iconPickOffset = 1;
		selectedIconIndex = 0;
		DailyAzeroth_UpdateIconPick();
	end
end

function DailyAzeroth_SelectIcon(self)
	selectedIcon = self.iconValue;
	selectedIconIndex = self.iconIndex;
	CreationPanel.IconPickHighlight:SetPoint("CENTER", self, "CENTER");
	CreationPanel.IconPickHighlight:Show();
end

function DailyAzeroth_UpdateIconPick()
	if iconPickSelected ~= nil then
		-- Reset icon pagation.
		CreationPanel.Buttons.IconPrev:Disable();
		CreationPanel.Buttons.IconNext:Disable();

		CreationPanel.IconPickHighlight:Hide();

		-- Hide any cached frames before re-use.
		for key, value in ipairs(IconPickFrames) do
			value:Hide();
		end

		local icons = DA.ICON_DATA[iconPickSelected];
		local x = 225;
		local y = -55;

		if #icons > iconPickOffset + 59 then
			CreationPanel.Buttons.IconNext:Enable();
		end

		if iconPickOffset > 1 then
			CreationPanel.Buttons.IconPrev:Enable();
		end

		for i = iconPickOffset, iconPickOffset + 59 do
			if i > #icons then break; end
			local frameName = "DailyAzerothFramePickIcon" .. i;
			local frame = _G[frameName];

			-- Init frame
			if frame == nil then
				frame = CreateFrame("BUTTON", frameName, CreationPanel.Frame);
				frame:SetWidth(32);
				frame:SetHeight(32);

				frame.tex = frame:CreateTexture(nil, "BACKGROUND");
				frame.tex:SetAllPoints(frame);

				frame:SetScript("OnClick", DailyAzeroth_SelectIcon);
			end

			frame.tex:SetTexture("Interface\\Icons\\" .. icons[i]);
			frame.iconValue = icons[i];
			frame.iconIndex = i;
			frame:SetPoint("TOPLEFT", CreationPanel.Frame, "TOPLEFT", x, y);
			frame:Show();

			if i % 10 == 0 then
				x = 225;
				y = y - 35;
			else
				x = x + 35;
			end

			table.insert(IconPickFrames, frame);

			if i == selectedIconIndex then
				CreationPanel.IconPickHighlight:SetPoint("CENTER", frame, "CENTER");
				CreationPanel.IconPickHighlight:Show();
			end
		end
	end
end

function DailyAzeroth_IconPickPrevious()
	iconPickOffset = iconPickOffset - 60;
	if iconPickOffset < 1 then
		iconPickOffset = 1;
	end

	DailyAzeroth_UpdateIconPick();
end

function DailyAzeroth_IconPickNext()
	iconPickOffset = iconPickOffset + 60;
	DailyAzeroth_UpdateIconPick();
end

function DailyAzeroth_NewFilterButtonClick()
	-- Name field.
	DailyAzerothSlideOutNewFilterNameField:SetText("");
	DailyAzerothSlideOut:Show();
end

function DailyAzeroth_ToggleCompleted(button)
	DA.ShowCompleted = button:GetChecked();
	DailyAzeroth_UpdateButtons();
end

function DailyAzeroth_CompleteSelected()
	for index, track in pairs(DailyAzerothData.Tracks) do
		if track.Selected then
			track.Completed = true;
			
			if track.Selected then
				track.Selected = false;
				DA.SelectCount = DA.SelectCount - 1;
				RefreshButtons();
			end
		end
	end
	
	UpdateSelectCount();
	DailyAzeroth_UpdateButtons();
end

function DailyAzeroth_DeleteSelected()
	for index, track in pairs(DailyAzerothData.Tracks) do
		if track.Selected then
			DailyAzerothData.Tracks[index] = nil;
			DA.SelectCount = DA.SelectCount - 1;
			RefreshButtons();
		end
	end
	
	UpdateSelectCount();
	DailyAzeroth_UpdateButtons();
end

function DailyAzeroth_OnFilterClick(button, filter)
	DA.SelectedFilter = filter.Name;
	DailyAzeroth_UpdateFilters();
	DailyAzeroth_UpdateButtons();
end

function DailyAzeroth_OnClickSortColumn(button)
	if DA.Sorting == button.SortType then
		-- We're already sorting by this, switch the sort order.
		if DA.SortMethod == 1 then
			DA.SortMethod = 2;
		else
			DA.SortMethod = 1;
		end
	else
		DA.Sorting = button.SortType;
	end
	
	DailyAzeroth_UpdateButtons();
	
	-- Update the arrow graphics.
	for index, tab in pairs(DA.SortTabs) do
		DailyAzeroth_CheckSortColumn(tab);
	end
end

function DailyAzeroth_CheckSortColumn(button)
	local arrow = _G[button:GetName() .. "Arrow"];
	
	if DA.Sorting == button.SortType then
		arrow:Show();
		if DA.SortMethod == 1 then
			arrow:SetTexCoord(0, 0.5625, 1.0, 0);
		else
			arrow:SetTexCoord(0, 0.5625, 0, 1.0);
		end
	else
		arrow:Hide();
	end
end

function DailyAzeroth_ClearButtonHighlights()
	for i = 1, DA.ItemCount do
		local button = _G["DailyAzerothButton" .. i];
		button:UnlockHighlight();
		button.Selected = false;
	end
end

function DailyAzeroth_UpdateHighlight(button, track)
	if track.Selected then
		button:LockHighlight();
	else
		button:UnlockHighlight();
	end
end

function DailyAzeroth_OnButtonClick(button, track)
	if track.Selected then
		DA.SelectCount = DA.SelectCount - 1;
		track.Selected = false;
	else
		DA.SelectCount = DA.SelectCount + 1;
		track.Selected = true;
	end
	
	RefreshButtons();
	DailyAzeroth_UpdateHighlight(button, track);
	UpdateSelectCount();
end

function DailyAzeroth_UpdateButtons()
	local tracks = {};
	
	if DA.ShowCompleted then
		tracks = DailyAzerothData.Tracks;
	else
		tracks = GetNonCompletedTracks();
	end
	
	tracks = FilterTracks(tracks);

	table.sort(tracks, function(a, b)
		if DA.SortMethod == 1 then
			return a[DA.Sorting] < b[DA.Sorting];
		else
			return a[DA.Sorting] > b[DA.Sorting];
		end
	end);
	
	local trackCount = #tracks;
	local index = FauxScrollFrame_GetOffset(DailyAzerothScrollFrame);
	
	-- Loop all of the buttons.
	for i = 1, DA.ItemCount do
		local track = tracks[index + 1];
		local button = _G["DailyAzerothButton" .. i];
		
		if track ~= nil then
			local nameField = _G[button:GetName() .. "Name"];
			local characterField = _G[button:GetName() .. "Character"];
			local noteField = _G[button:GetName() .. "Note"];
			local typeField = _G[button:GetName() .. "Type"];
			
			local icon = _G[button:GetName() .. "ItemIconTexture"];
			
			DailyAzeroth_UpdateHighlight(button, track);
			
			icon:SetTexture("Interface/Icons/" .. track.Icon);
			
			if track.Completed then
				nameField:SetText(GREEN_FONT_COLOR_CODE .. track.Name .. FONT_COLOR_CODE_CLOSE);
				characterField:SetText(GREEN_FONT_COLOR_CODE .. track.Character .. FONT_COLOR_CODE_CLOSE);
				noteField:SetText(GREEN_FONT_COLOR_CODE .. track.Note .. FONT_COLOR_CODE_CLOSE);
				typeField:SetText(GREEN_FONT_COLOR_CODE .. track.Type .. FONT_COLOR_CODE_CLOSE);
			else				
				nameField:SetText(track.Name);			
				characterField:SetText(ColourCharacterName(track.Character));
				noteField:SetText(track.Note);
				typeField:SetText(track.Type);
			end
			
			if track.Selected then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end
			
			button.Track = track;
			button:Show();
		else
			button:Hide();
		end
		
		index = index + 1;
	end
	
	FauxScrollFrame_Update(DailyAzerothScrollFrame, trackCount, DA.ItemCount, 37);
end

function DailyAzeroth_ACHandle(acType, name)
	local tracks = GetNonCompletedTracks();
	local updated = false;

	for index, track in pairs(tracks) do
		if track.ACType == acType and track.ACValue == name and track.Character == UnitName("player") then
			track.Completed = true;
			
			if track.Selected then
				track.Selected = false;
				DA.SelectCount = DA.SelectCount - 1;
				RefreshButtons();
			end

			updated = true;

			DailyAzeroth_ShowToast("Interface\\Icons\\" .. track.Icon, track.Name);
			PrintMessage(track.Name .. " completed!");
		end
	end

	if updated then
		UpdateSelectCount();
		DailyAzeroth_UpdateButtons();
	end
end

function DailyAzeroth_UpdateFilters()
	local filterCount = #DailyAzerothData.Filters;
	local index = FauxScrollFrame_GetOffset(DailyAzerothFilterScrollFrame);

	for i = 1, 15 do
		_G["DailyAzerothFilterButton" .. i]:Hide();
	end

	local buttonIndex = 1;
	for i = index, filterCount do
		--local filterIndex = index - 1;
		local filter = nil;
		local button = _G["DailyAzerothFilterButton" .. buttonIndex];

		if index == 0 then
			filter = defaultFilter;
		else
			filter = DailyAzerothData.Filters[index];
		end

		if filter ~= nil then
			-- Check if we have enough buttons to make the scroll frame
			-- appear and shrink the buttons to prevent overlapping.
			if filterCount > 15 then
				button:SetWidth(136);
			else
				button:SetWidth(156);
			end
			
			local normalText = _G[button:GetName() .. "NormalText"];
			local normalTexture = _G[button:GetName() .. "NormalTexture"];
			local line = _G[button:GetName() .. "Lines"];
			
			button:SetText(ColourString(filter.Name, filter.Colour));
			normalText:SetPoint("LEFT", button, "LEFT", 20, 0);
			normalTexture:SetAlpha(0.0);    
			
			if filterCount == index then
				line:SetTexCoord(0.4375, 0.875, 0, 0.625);
			else
				line:SetTexCoord(0, 0.4375, 0, 0.625);
			end
			
			if filter.Name == DA.SelectedFilter then
				button:LockHighlight();
				button.Selected = true;
			else
				button:UnlockHighlight();
				button.Selected = false;
			end
			
			line:Show();
			button:Show();
			button.Filter = filter;
			buttonIndex = buttonIndex + 1;
		end

		index = index + 1;
	end
	
	FauxScrollFrame_Update(DailyAzerothFilterScrollFrame, filterCount, 15, 20);
end

function FilterButton_SetType(button, type, text, isLast)
    local normalText = _G[button:GetName().."NormalText"];
    local normalTexture = _G[button:GetName().."NormalTexture"];
    local line = _G[button:GetName().."Lines"];
    if ( type == "class" ) then
        button:SetText(text);
        normalText:SetPoint("LEFT", button, "LEFT", 4, 0);
        normalTexture:SetAlpha(1.0);    
        line:Hide();
    elseif ( type == "subclass" ) then
        button:SetText(HIGHLIGHT_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE);
        normalText:SetPoint("LEFT", button, "LEFT", 12, 0);
        normalTexture:SetAlpha(0.4);
        line:Hide();
    elseif ( type == "invtype" ) then
        button:SetText(HIGHLIGHT_FONT_COLOR_CODE..text..FONT_COLOR_CODE_CLOSE);
        normalText:SetPoint("LEFT", button, "LEFT", 20, 0);
        normalTexture:SetAlpha(0.0);    
        if ( isLast ) then
            line:SetTexCoord(0.4375, 0.875, 0, 0.625);
        else
            line:SetTexCoord(0, 0.4375, 0, 0.625);
        end
        line:Show();
    end
    button.type = type; 
end

--
-- Event Handling
--

local eventFrame = CreateFrame("FRAME");
eventFrame.QLU = 0;
eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:RegisterEvent("QUEST_LOG_UPDATE");
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");

local tappedUnits = {};

eventFrame:SetScript("OnEvent", function(sender, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...;
		if addonName == DA.Name then
			Load();
		end
	elseif event == "QUEST_LOG_UPDATE" then
		if eventFrame.QLU < 2 then
			eventFrame.QLU = eventFrame.QLU + 1;

			if eventFrame.QLU == 2 then
				UpdateTimers();
			end
		else
			if GetQuestResetTime() > DailyAzerothData.LastSTR then
				DailyAzeroth_ResetTasks("Daily");
			end
		end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subEvent, _, attackerGUID, _, _, _, guid, name = ...;

		if subEvent == "SWING_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_DAMAGE" then
			-- Ensure we don't already have this unit tracked.
			if tappedUnits[guid] ~= nil then return; end

			-- Ensure it's us attacking and not us being attacked.
			if attackerGUID ~= PLAYER_GUID or guid == PLAYER_GUID then return; end

			tappedUnits[guid] = true;
		elseif subEvent == "UNIT_DIED" then
			if tappedUnits[guid] ~= nil then
				if tappedUnits[guid] == true then
					DailyAzeroth_ACHandle(autoCompleteEntity, name);
				end

				tappedUnits[guid] = nil;
			end
		end
	end
end);

--
-- Command Handling
--

SLASH_DA1, SLASH_DA2 = '/da', '/dailyazeroth';

local function handleCommand(msg, editbox)
	ShowUIPanel(DailyAzerothFrame);
end

SlashCmdList["DA"] = handleCommand;