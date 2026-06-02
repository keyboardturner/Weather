local AddonName, WeatherAddon = ...;
local L = WeatherAddon.L;
local LibForecast = LibStub("LibForecast-1.0");
local Print = WeatherAddon.Print;

local itemTextures = {
	[212524] = { -- Delicate Crimson Parasol
		default = "Interface\\AddOns\\Weather\\Textures\\icon_pandaren_red.png",
	},
	[212525] = { -- Delicate Ebony Parasol
		default = "Interface\\AddOns\\Weather\\Textures\\icon_pandaren_black.png",
	},
	[212523] = { -- Delicate Jade Parasol
		default = "Interface\\AddOns\\Weather\\Textures\\icon_pandaren_green.png",
	},
	[212500] = { -- Delicate Silk Parasol
		default = "Interface\\AddOns\\Weather\\Textures\\icon_pandaren_white.png",
	},
	[182694] = { -- Stylish Black Parasol
		default = "Interface\\AddOns\\Weather\\Textures\\icon_venthyr_black.png",
	},
	[182696] = { -- The Countess's Parasol
		default = "Interface\\AddOns\\Weather\\Textures\\icon_venthyr_green.png",
	},
	[182695] = { -- Weathered Purple Parasol
		default = "Interface\\AddOns\\Weather\\Textures\\icon_venthyr_purple.png",
	},
};

local actionBarMappings = {
	{ start = 1, stop = 12, prefix = "ActionButton" }, -- Main Action Bar
	{ start = 61, stop = 72, prefix = "MultiBarBottomLeftButton" }, -- Action Bar 2
	{ start = 49, stop = 60, prefix = "MultiBarBottomRightButton" }, -- Action Bar 3
	{ start = 25, stop = 36, prefix = "MultiBarRightButton" }, -- Action Bar 4
	{ start = 37, stop = 48, prefix = "MultiBarLeftButton" }, -- Action Bar 5
	{ start = 145, stop = 156, prefix = "MultiBar5Button" }, -- Action Bar 6
	{ start = 157, stop = 168, prefix = "MultiBar6Button" }, -- Action Bar 7
	{ start = 169, stop = 180, prefix = "MultiBar7Button" }, -- Action Bar 8
};

local function UpdateActionBarTextures()
	for _, barInfo in ipairs(actionBarMappings) do
		for i = barInfo.start, barInfo.stop do
			local buttonName = barInfo.prefix .. (i - barInfo.start + 1);
			local button = _G[buttonName];
			
			local buttonID = button and button.action;
			
			if button and buttonID then
				local actionType, id, subType = GetActionInfo(buttonID);
				local slot = _G[buttonName .. "Icon"];

				if slot then
					local textureToApply = nil;

					if actionType == "item" then
						local itemData = itemTextures[id];
						if itemData then
							textureToApply = itemData.default;
						end
					elseif actionType == "macro" then
						local itemID = GetMacroItem(id);
						if itemID then
							local itemData = itemTextures[itemID];
							if itemData then
								textureToApply = itemData.default;
							end
						end
					end

					if textureToApply then
						slot:SetTexture(textureToApply);
					end
				end
			end
		end
	end
end

local function OnEvent(self, event, ...)
	UpdateActionBarTextures();
end

local f = CreateFrame("Frame");
f:RegisterEvent("PLAYER_ENTERING_WORLD");
f:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
f:RegisterEvent("ACTIONBAR_UPDATE_STATE");
f:RegisterEvent("BAG_UPDATE");
f:SetScript("OnEvent", OnEvent);

for _, barInfo in ipairs(actionBarMappings) do
	for i = barInfo.start, barInfo.stop do
		local buttonName = barInfo.prefix .. (i - barInfo.start + 1);
		local button = _G[buttonName];
		if button then
			button:HookScript("OnEnter", function()
				UpdateActionBarTextures();
			end)
		end
	end
end

-- Plumber compatibility stuffs
local plumberHooked = false;

local function UpdatePlumberFlyoutTextures(spellFlyout)
	if not spellFlyout.ItemButtons then return; end
	
	for _, button in ipairs(spellFlyout.ItemButtons) do
		if button.id and button.Icon then
			local itemData = itemTextures[button.id];
			if itemData then
				button.Icon:SetTexture(itemData.default);
			end
		end
	end
end

local function TryHookPlumber()
	if plumberHooked then return; end

	local container = _G["PlumberSecureFlyoutContainer"];
	if not container then return; end

	local spellFlyout;
	for _, child in ipairs({container:GetChildren()}) do
		if type(child.ShowActions) == "function" then
			spellFlyout = child;
			break;
		end
	end

	if spellFlyout then
		hooksecurefunc(spellFlyout, "ShowActions", function(self)
			UpdatePlumberFlyoutTextures(self);
		end)
		plumberHooked = true;
	end
end

EventUtil.ContinueOnAddOnLoaded("Plumber", function()
	TryHookPlumber();
end)


-- toybox compatibility
local function UpdateToyButtonTexture(button)
	if button and button.itemID then
		local itemData = itemTextures[button.itemID];
		if itemData then
			if button.iconTexture then
				button.iconTexture:SetTexture(itemData.default);
			end
			if button.iconTextureUncollected then
				button.iconTextureUncollected:SetTexture(itemData.default);
			end
		end
	end
end

local function UpdateAllToyButtonTextures()
	if not ToyBox or not ToyBox.iconsFrame then return; end
	for i = 1, 18 do
		local button = ToyBox.iconsFrame["spellButton"..i];
		if button then
			UpdateToyButtonTexture(button);
		end
	end
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
	if ToySpellButton_UpdateButton then
		hooksecurefunc("ToySpellButton_UpdateButton", function(self)
			UpdateToyButtonTexture(self);
		end)
	end

	if ToyBox_UpdateButtons then
		hooksecurefunc("ToyBox_UpdateButtons", function()
			RunNextFrame(UpdateAllToyButtonTextures);
		end)
	end
end)