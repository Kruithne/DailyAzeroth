--[[
	DailyAzeroth (C) Kruithne <kruithne@gmail.com>
	Licensed under GNU General Public Licence version 3.
	
	https://github.com/Kruithne/DailyAzerothAddon

	DailyAzeroth.lua - Core engine file for the addon.
]]

local ADDON_NAME = "DailyAzeroth";
local COLOUR_CHAT_PREFIX = CreateColor(0, 0.8, 1);
local COLOUR_CHAT = CreateColor(0.41, 0.80, 0.52);
local CHAT_PREFIX = COLOUR_CHAT_PREFIX:WrapTextInColorCode("DailyAzeroth: ");

DailyAzeroth = {};
local core = DailyAzeroth;
core.eventFrame = CreateFrame("FRAME");
core.eventFrame:RegisterEvent("ADDON_LOADED");
core.eventFrame:SetScript("OnEvent", function(...) core.OnEvent(...); end);

--[[ Called when core.eventFrame receives a registered event. ]]--
core.OnEvent = function(self, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...;
		if addonName == ADDON_NAME then
			core.Load();
		end
	end
end

-- [[ Called when a registered slash command is run by the player. ]] --
core.OnCommand = function(command, editbox)
	core.ShowFrame();
end

--[[ Send a message to the default chat frame with the add-on prefix. ]]--
core.SendChatMessage = function(message)
	DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. COLOUR_CHAT:WrapTextInColorCode(message));
end

--[[ Called once when the add-on is initially loaded. ]]--
core.Load = function()
	local version = GetAddOnMetadata(ADDON_NAME, "Version");
	core.SendChatMessage("Loaded v" .. version .. "!");

	SLASH_DA1, SLASH_DA2 = "/da", "/dailyazeroth";
	SlashCmdList["DA"] = core.OnCommand;
end

-- [[ Creates the main frame for the add-on. ]] --
core.CreateFrame = function()
	if core.frame ~= nil then
		return;
	end

	local frame = CreateFrame("FRAME", ADDON_NAME .. "MainFrame", UIParent);
	frame:SetSize(415, 227);
	frame:SetPoint("CENTER", 0.6, 0.6);

	local backdrop = frame:CreateTexture("$parentBackdrop", "BACKGROUND");
	backdrop:SetHorizTile(true);
	backdrop:SetVertTile(true);
	backdrop:SetTexture([[Interface\Garrison\GarrisonLandingPageMiddleTile]], true, true);
	backdrop:SetPoint("TOPLEFT", -180, 130);
	backdrop:SetPoint("BOTTOMRIGHT", 180, -130);

	local Helper_CreateFramePart = function(sizeX, sizeY, anchorPoint, anchorX, anchorY, texCoord, layer) 
		local tex = frame:CreateTexture(nil, layer);
		tex:SetTexture([[Interface\Garrison\GarrisonLandingPage]]);
		tex:SetPoint(anchorPoint, frame, anchorPoint, anchorX, anchorY);
		tex:SetSize(sizeX, sizeY);
		tex:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4]);
		return tex;
	end

	Helper_CreateFramePart(414, 92, "TOP", 0, 159, {520 / 1024, 933 / 1024, 315 / 1024, 406 / 1024}); -- Top
	Helper_CreateFramePart(414, 88, "BOTTOM", 0, -158, {27 / 1024, 439 / 1024, 0, 87 / 1024}); -- Bottom
	Helper_CreateFramePart(95, 227, "LEFT", -208, 0, {27 / 1024, 120 / 1024, 148 / 1024, 373 / 1024}); -- Left
	Helper_CreateFramePart(95, 227, "RIGHT", 210, 0, {124 / 1024, 216 / 1024, 267 / 1024, 491 / 1024}); -- Right
	Helper_CreateFramePart(211, 160, "TOPLEFT", -210, 160, {520 / 1024, 729 / 1024, 730 / 1024, 888 / 1024}); -- Top-left
	Helper_CreateFramePart(211, 160, "TOPRIGHT", 211, 160, {218 / 1024, 428 / 1024, 802 / 1024, 961 / 1024}); -- Top-right
	Helper_CreateFramePart(211, 160, "BOTTOMLEFT", -210, -160, {731 / 1024, 940 / 1024, 457 / 1024, 615 / 1024}); -- Bottom-left
	Helper_CreateFramePart(211, 160, "BOTTOMRIGHT", 211, -160, {521 / 1024, 729 / 1024, 457 / 1024, 615 / 1024}); -- Bottom-right
	local header = Helper_CreateFramePart(770, 61, "TOP", 0, 125, {29 / 1024, 797 / 1024, 87 / 1024, 146 / 1024}, "ARTWORK");

	-- Header text.
	local headerText = frame:CreateFontString("$parentToastTitle", nil, "QuestFont_Enormous");
	headerText:SetPoint("TOPLEFT", header, "TOPLEFT", 20, -17);
	headerText:SetText(ADDON_NAME);
	frame.headerTitle = headerText;

	-- Close button
	CreateFrame("BUTTON", "$parentCloseButton", frame, "UIPanelCloseButton"):SetPoint("TOPRIGHT", 195, 145);

	-- Item frames.
	core.OnItemFrameEnter = function(self)
		self.backdrop:SetTexCoord(520 / 1024, 920 / 1024, 408 / 1024, 455 / 1024);
	end

	core.OnItemFrameLeave = function(self)
		self.backdrop:SetTexCoord(404 / 1024, 804 / 1024, 197 / 1024, 244 / 1024);
	end

	local previous = nil;
	for i = 1, 8 do
		local itemFrame = CreateFrame("FRAME", "$parentItemFrame" .. i, frame);
		itemFrame:SetSize(402, 49);
		itemFrame:SetScript("OnEnter", core.OnItemFrameEnter);
		itemFrame:SetScript("OnLeave", core.OnItemFrameLeave);

		if previous then
			itemFrame:SetPoint("TOP", previous, "BOTTOM");
		else
			itemFrame:SetPoint("TOPRIGHT", 145, 55);
		end

		-- Backdrop for each entry.
		local itemFrameTexture = itemFrame:CreateTexture("$parentBackdrop");
		itemFrameTexture:SetTexture([[Interface\Garrison\GarrisonLandingPage]]);
		itemFrameTexture:SetAllPoints(true);
		itemFrameTexture:SetTexCoord(404 / 1024, 804 / 1024, 197 / 1024, 244 / 1024);
		itemFrame.backdrop = itemFrameTexture;

		-- Icon for each entry.
		local itemFrameIcon = itemFrame:CreateTexture("$parentIcon", "ARTWORK", nil, 1);
		itemFrameIcon:SetSize(36, 36);
		itemFrameIcon:SetPoint("LEFT", itemFrameTexture, "LEFT", 8, 0);
		itemFrameIcon:SetTexture([[Interface\ICONS\INV_BabyMurloc3_yellow]]);
		itemFrame.icon = itemFrameIcon;

		-- Nice border for each icon.
		local itemFrameIconBorder = itemFrame:CreateTexture("$parentIconBorder", "ARTWORK", nil, 2);
		itemFrameIconBorder:SetTexture([[Interface\Common\WhiteIconFrame]]);
		itemFrameIconBorder:SetSize(36, 36);
		itemFrameIconBorder:SetPoint("CENTER", itemFrameIcon);

		-- Used to display the title of each entry.
		local itemFrameTitle = itemFrame:CreateFontString("$parentTitle", nil, "GameFontHighlightLarge");
		itemFrameTitle:SetJustifyH("LEFT");
		itemFrameTitle:SetSize(290, 15);
		itemFrameTitle:SetPoint("TOPLEFT", 63, -8);
		itemFrameTitle:SetTextColor(0.75, 0.75, 0.73);
		itemFrameTitle:SetText("Item Frame " .. i);

		-- Used for each entries "note".
		local itemFrameText = itemFrame:CreateFontString("$parentText", nil, "GameFontNormal");
		itemFrameText:SetJustifyH("LEFT");
		itemFrameText:SetSize(390, 0);
		itemFrameText:SetPoint("TOPLEFT", itemFrameTitle, "BOTTOMLEFT", 0, -5);
		itemFrameText:SetTextColor(0.792, 0.690, 0.529, 1);
		itemFrameText:SetText("Testing!");

		previous = itemFrameTexture;
	end

	core.frame = frame;
end

-- [[ Shows the main frame, creating it first if needed. ]] --
core.ShowFrame = function()
	core.CreateFrame(); -- Create our frame if needed.

	if not core.frame:IsShown() then
		core.frame:Show();
	end
end