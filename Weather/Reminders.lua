local AddonName, WeatherAddon = ...;
local L = WeatherAddon.L;
local LibForecast = LibStub("LibForecast-1.0");
local Print = WeatherAddon.Print;

local sessionIgnored = false;
local lastReminderTime = 0;
local REMINDER_THROTTLE_SECONDS = 30;
local lastWarnedExpiration = 0;
local expirationTimer = nil;
local queuedReminderTimer = nil;
local trp3Ready = false;
local REMINDER_EVENT_ID = 8;
local REMINDER_TRIGGER_ID = 0;

local playerKey;

-- accessories are per-character customizable
WeatherAddon.CharDefaults = {
	SelectedParasol = "Random"
};

local itemIconReplacement = {
	[212523] = "Interface\\AddOns\\Weather\\Textures\\icon_pandaren_green.png",
	[212524] = "Interface\\AddOns\\Weather\\Textures\\icon_pandaren_red.png",
	[212525] = "Interface\\AddOns\\Weather\\Textures\\icon_pandaren_black.png",
	[212500] = "Interface\\AddOns\\Weather\\Textures\\icon_pandaren_white.png",
	[182696] = "Interface\\AddOns\\Weather\\Textures\\icon_venthyr_green.png",
	[182695] = "Interface\\AddOns\\Weather\\Textures\\icon_venthyr_purple.png",
	[182694] = "Interface\\AddOns\\Weather\\Textures\\icon_pandaren_black.png",
};

local randomIcon = "Interface\\AddOns\\Weather\\Textures\\icon_venthyr_silhuoette.png";

local popup = CreateFrame("Frame", "Weather_AccessoryReminderFrame", UIParent);
popup.height = 70;
popup.width = 280;
popup:SetSize(popup.width, popup.height);
popup:SetPoint("CENTER", 0, 100);
popup:SetFrameStrata("DIALOG");
popup:SetAlpha(0);
popup:Hide();

local bg = popup:CreateTexture(nil, "BACKGROUND");
bg:SetPoint("CENTER", popup, "CENTER");
bg:SetWidth(popup.width);
bg:SetHeight(popup.height);
bg:SetAtlas("bonusobjectives-title-bg");
popup.bg = bg;

local content = CreateFrame("Frame", nil, popup);
content:SetAllPoints(popup);
content:SetAlpha(1);
popup.content = content;

popup.animState = "IDLE";
popup.animTime = 0;

function popup.OnUpdateAnim(self, elapsed)
	self.animTime = self.animTime + elapsed;

	-- height growth
	if self.animState == "GROWING" then
		local p = self.animTime / 0.25;
		if p >= 1 then
			self.bg:SetHeight(popup.height);
			self.animState = "FADING_IN";
			self.animTime = 0;
		else
			p = 1 - (1 - p) ^ 3;
			self.bg:SetHeight(1 + ((popup.height - 1) * p));
		end
	elseif self.animState == "FADING_IN" then
		local p = self.animTime / 0.25;
		if p >= 1 then
			self.content:SetAlpha(1);
			self.animState = "IDLE";
			self:SetScript("OnUpdate", nil);
		else
			self.content:SetAlpha(p);
		end
	elseif self.animState == "FADING_OUT" then
		local p = self.animTime / 0.3;
		if p >= 1 then
			self:SetAlpha(0);
			self.animState = "IDLE";
			self:SetScript("OnUpdate", nil);
			if not InCombatLockdown() then
				self:Hide();
			end
		else
			self:SetAlpha(1 - p);
		end
	end
end

function popup:FadeIn()
	if InCombatLockdown() then return end
	
	if self:IsShown() and self.animState ~= "FADING_OUT" then
		if self.animState == "IDLE" then
			self:SetAlpha(1);
		end
		return;
	end

	self:Show();
	self.animState = "GROWING";
	self.animTime = 0;
	self:SetAlpha(1);
	self.bg:SetHeight(1);
	self.content:SetAlpha(0);
	self:SetScript("OnUpdate", self.OnUpdateAnim);
end

function popup:FadeOut()
	if not self:IsShown() then return; end
	self.animState = "FADING_OUT";
	self.animTime = 0;
	self:SetScript("OnUpdate", self.OnUpdateAnim);
end

local function MergeDefaults(target, defaults)
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			if type(target[k]) ~= "table" then
				target[k] = {};
			end
			MergeDefaults(target[k], v);
		elseif target[k] == nil then
			target[k] = v;
		end
	end
end

popup:RegisterEvent("ADDON_LOADED");
popup:RegisterEvent("PLAYER_REGEN_DISABLED");
popup:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddon = ...;
		if loadedAddon == AddonName then
			local name, realm = UnitFullName("player");
			if not realm or realm == "" then
				realm = GetRealmName();
			end
			playerKey = name .. "-" .. realm;

			WeatherAddon_DB = WeatherAddon_DB or {};
			
			if WeatherAddon.Defaults then
				MergeDefaults(WeatherAddon_DB, WeatherAddon.Defaults);
			end

			WeatherAddon_DB.CharacterParasols = WeatherAddon_DB.CharacterParasols or {};

			if WeatherAddon_DB.CharacterParasols[playerKey] == nil then
				WeatherAddon_DB.CharacterParasols[playerKey] = WeatherAddon.CharDefaults.SelectedParasol;
			end

			self:UnregisterEvent("ADDON_LOADED");
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		self:SetScript("OnUpdate", nil);
		self.animState = "IDLE";
		self:SetAlpha(0);
		self:Hide();
	end
end)

local headerBg = popup.content:CreateTexture(nil, "BACKGROUND");
headerBg:SetAtlas("UI-QuestTracker-Primary-Objective-Header");
headerBg:SetSize(250, 35);
headerBg:SetPoint("BOTTOM", popup.content, "TOP", 0, 0);

local title = popup.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
title:SetPoint("CENTER", headerBg, "CENTER", 0, 0);
title:SetText(L["RainingNotification"]);
title:SetTextColor(1, 0.82, 0);

local toyButton = CreateFrame("Button", nil, popup.content, "SecureActionButtonTemplate");
toyButton:SetSize(44, 44);
toyButton:SetPoint("CENTER", 0, 5);

local icon = toyButton:CreateTexture(nil, "BACKGROUND");
icon:SetAllPoints(toyButton);
icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
toyButton.icon = icon;

toyButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress");
toyButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");

toyButton:SetAttribute("useOnKeyDown", false);
toyButton:RegisterForClicks("LeftButtonUp");

local function MenuGenerator(owner, rootDescription)
	rootDescription:CreateRadio(L["RandomTrackedAccessories"],
		function() return WeatherAddon_DB.CharacterParasols[playerKey] == "Random"; end,
		function()
			WeatherAddon_DB.CharacterParasols[playerKey] = "Random";
			WeatherAddon:UpdateReminderButton();
		end
	)

	-- specific accessory options (only show those enabled in SettingsUI + usable)
	for itemIDStr, isEnabled in pairs(WeatherAddon_DB.UmbrellaToggles) do
		if isEnabled then
			local itemID = tonumber(itemIDStr);
			if C_ToyBox.IsToyUsable(itemID) then
				local itemName = C_Item.GetItemInfo(itemID);
				local display = itemName or ("Item #" .. itemID);

				rootDescription:CreateRadio(display,
					function() return WeatherAddon_DB.CharacterParasols[playerKey] == itemID; end,
					function()
						WeatherAddon_DB.CharacterParasols[playerKey] = itemID;
						WeatherAddon:UpdateReminderButton();
					end
				)
			end
		end
	end
end

toyButton:SetScript("OnMouseDown", function(self, button)
	if button == "RightButton" then
		if InCombatLockdown() then return; end
		MenuUtil.CreateContextMenu(self, MenuGenerator);
	end
end)

toyButton:SetScript("OnEnter", function(self)
	if self.currentItemID then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		
		local spellID = WeatherAddon.UmbrellaItemIDsBuffIDs[self.currentItemID];
		
		if spellID then
			GameTooltip:SetSpellByID(spellID);
		else
			GameTooltip:SetItemByID(self.currentItemID);
		end
		
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(L["RightClickForSettings"], 0, 1, 0);
		
		GameTooltip:Show();
	end
end)

toyButton:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end)

function WeatherAddon:UpdateReminderButton()
	if InCombatLockdown() or not playerKey then return; end

	local selectedItemID;
	local charSelection = WeatherAddon_DB.CharacterParasols[playerKey];

	if charSelection == "Random" then
		local available = {};
		for itemIDStr, isEnabled in pairs(WeatherAddon_DB.UmbrellaToggles) do
			local itemID = tonumber(itemIDStr);
			if isEnabled and C_ToyBox.IsToyUsable(itemID) then
				table.insert(available, itemID);
			end
		end

		if #available > 0 then
			selectedItemID = available[math.random(1, #available)];
		else
			selectedItemID = 212523;
		end
	else
		selectedItemID = tonumber(charSelection);
	end

	toyButton:SetAttribute("type1", "item");
	toyButton:SetAttribute("item1", "item:" .. selectedItemID);

	toyButton.currentItemID = selectedItemID;

	local displayIcon;
	if charSelection == "Random" then
		displayIcon = randomIcon;
	else
		displayIcon = itemIconReplacement[selectedItemID];
	end

	local item = Item:CreateFromItemID(selectedItemID);
	item:ContinueOnItemLoad(function()
		-- prio the custom icon, fall back to blizz icon if nil
		local finalIcon = displayIcon or C_Item.GetItemIconByID(selectedItemID);
		if finalIcon then
			toyButton.icon:SetTexture(finalIcon);
		end
	end)

	if WeatherAddon_DB.ReminderSoundEnabled and not popup:IsShown() then
		local soundFile = WeatherAddon:GetReminderSoundFile(WeatherAddon_DB.ReminderSoundFile);
		local volume = WeatherAddon_DB.ReminderSoundVolume or 1.0;
		C_EncounterEvents.SetEventSound(REMINDER_EVENT_ID, REMINDER_TRIGGER_ID, { file = soundFile, volume = volume });
		C_EncounterEvents.PlayEventSound(REMINDER_EVENT_ID, REMINDER_TRIGGER_ID);
		C_EncounterEvents.SetEventSound(REMINDER_EVENT_ID, REMINDER_TRIGGER_ID, nil);
	end
end

popup:SetScript("OnShow", function()
	WeatherAddon:UpdateReminderButton();
end)

local ignoreButton = CreateFrame("Button", nil, popup.content);
ignoreButton:SetSize(24, 24);
ignoreButton:SetPoint("TOPRIGHT", -5, -5);
ignoreButton:SetNormalAtlas("perks-dropdown-clear");
ignoreButton:SetHighlightAtlas("perks-dropdown-clear", "ADD");
ignoreButton:Hide();

ignoreButton:SetScript("OnClick", function()
	sessionIgnored = true;
	popup:FadeOut();
	
	if queuedReminderTimer then
		queuedReminderTimer:Cancel();
		queuedReminderTimer = nil;
	end

	Print(L["RemindersIgnoredForSession"]);
end)

ignoreButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(L["IgnoreSession"]);
	GameTooltip:Show();
end)
ignoreButton:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end)

-- only show ignore button when mousing over the popup
popup.content:SetScript("OnUpdate", function(self)
	if self:IsMouseOver() then
		ignoreButton:Show();
	else
		ignoreButton:Hide();
	end
end)

local function GetParasolCooldown()
	if not playerKey or not WeatherAddon_DB or not WeatherAddon_DB.CharacterParasols then 
		return 0; 
	end
	
	local charSelection = WeatherAddon_DB.CharacterParasols[playerKey];
	local minRemaining = nil;
	local currentTime = GetTime();

	if charSelection == "Random" then
		for itemIDStr, isEnabled in pairs(WeatherAddon_DB.UmbrellaToggles) do
			local itemID = tonumber(itemIDStr);
			if isEnabled and C_ToyBox.IsToyUsable(itemID) then
				local start, duration = C_Item.GetItemCooldown(itemID);
				local remaining = 0;
				if start and start > 0 and duration > 0 then
					remaining = (start + duration) - currentTime;
				end
				
				if not minRemaining or remaining < minRemaining then
					minRemaining = remaining;
				end
				
				if remaining <= 0 then
					return 0;
				end
			end
		end
	else
		local itemID = tonumber(charSelection);
		if itemID and C_ToyBox.IsToyUsable(itemID) then
			local start, duration = C_Item.GetItemCooldown(itemID);
			local remaining = 0;
			if start and start > 0 and duration > 0 then
				remaining = (start + duration) - currentTime;
			end
			minRemaining = remaining;
		end
	end

	return minRemaining and math.max(0, minRemaining) or 0;
end

function WeatherAddon:CheckUmbrellaReminder()
	if not WeatherAddon_DB.EnableReminders or sessionIgnored then return; end

	local isGliding = false;
	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		isGliding = C_PlayerInfo.GetGlidingInfo();
	end

	local notInCharacter = false;
	if WeatherAddon_DB.OnlyInCharacter and trp3Ready and C_AddOns.IsAddOnLoaded("totalRP3") then -- i don't like the gauntlet
		if TRP3_API and AddOn_TotalRP3 and AddOn_TotalRP3.Player and AddOn_TotalRP3.Player.GetCurrentUser then
			local user = AddOn_TotalRP3.Player.GetCurrentUser();
			if user and user.IsInCharacter and not user:IsInCharacter() then
				notInCharacter = true;
			end
		end
	end

	-- horrendously long, should i table these?
	local isBusyOrInvalid = UnitIsDeadOrGhost("player")
		or IsMounted() or isGliding
		or UnitInVehicle("player")
		or UnitHasVehicleUI("player")
		or (C_PetBattles and C_PetBattles.IsInBattle())
		or notInCharacter;


	if expirationTimer then
		expirationTimer:Cancel();
		expirationTimer = nil;
	end

	local weatherInfo = LibForecast:GetCurrentWeatherInfo();
	local weatherType = weatherInfo.type;
	
	if weatherType == LibForecast.WeatherType.Unknown and weatherInfo.recordID then
		weatherType = WeatherAddon.RecordIDsTable[weatherInfo.recordID] or weatherType;
	end
	
	if isBusyOrInvalid or WeatherAddon.isIndoors or weatherType ~= LibForecast.WeatherType.Rain then
		if popup:IsShown() and not InCombatLockdown() then
			popup:FadeOut();
		end
		return;
	end

	local activeAura = nil
	for itemIDStr, isEnabled in pairs(WeatherAddon_DB.UmbrellaToggles) do
		if isEnabled then
			local spellID = WeatherAddon.UmbrellaItemIDsBuffIDs[tonumber(itemIDStr)];
			local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID);
			if aura then
				activeAura = aura;
				break;
			end
		end
	end

	local currentTime = GetTime();
	local shouldShow = false;

	if not activeAura then
		local throttleRemaining = 0;
		if (currentTime - lastReminderTime <= REMINDER_THROTTLE_SECONDS) then
			throttleRemaining = REMINDER_THROTTLE_SECONDS - (currentTime - lastReminderTime);
		end

		local itemCDRemaining = GetParasolCooldown();
		
		local totalWaitTime = math.max(throttleRemaining, itemCDRemaining);

		if totalWaitTime > 0 then
			if not queuedReminderTimer then
				queuedReminderTimer = C_Timer.NewTimer(totalWaitTime + 5, function()
					queuedReminderTimer = nil;
					WeatherAddon:CheckUmbrellaReminder();
				end)
			end
		else
			shouldShow = true;
			lastReminderTime = currentTime;
			lastWarnedExpiration = 0;
		end
	else
		if activeAura.expirationTime > 0 then
			local timeLeft = activeAura.expirationTime - currentTime

			if timeLeft <= 60 then
				if lastWarnedExpiration ~= activeAura.expirationTime then
					shouldShow = true;
					lastWarnedExpiration = activeAura.expirationTime;
				end
			else
				if popup:IsShown() and not InCombatLockdown() then
					popup:FadeOut();
				end
				
				local timeUntilWarning = timeLeft - 60
				expirationTimer = C_Timer.NewTimer(timeUntilWarning, function()
					WeatherAddon:CheckUmbrellaReminder();
				end)
			end
		else
			if popup:IsShown() and not InCombatLockdown() then
				popup:FadeOut();
			end
		end
	end

	if shouldShow and not InCombatLockdown() then
		WeatherAddon:UpdateReminderButton();
		popup:FadeIn();
	end
end

function WeatherAddon:ResetSessionIgnored()
	if sessionIgnored then
		sessionIgnored = false;
		Print(L["RemindersRestored"]);
		WeatherAddon:CheckUmbrellaReminder();
	end
end

EventUtil.ContinueOnAddOnLoaded("totalRP3", function()
	if TRP3_API and TRP3_Addon then
		TRP3_API.RegisterCallback(TRP3_Addon, "REGISTER_DATA_UPDATED", function()
			trp3Ready = true -- i don't like the gauntlet
			if WeatherAddon_DB and WeatherAddon_DB.OnlyInCharacter then
				WeatherAddon:CheckUmbrellaReminder();
			end
		end)
	end
end)