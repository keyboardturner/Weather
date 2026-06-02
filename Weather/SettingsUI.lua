local AddonName, WeatherAddon = ...;
local L = WeatherAddon.L;
local LibForecast = LibStub("LibForecast-1.0");
local Print = WeatherAddon.Print;

local REMINDER_EVENT_ID = 8
local REMINDER_TRIGGER_ID = 0

local Defaults = {
	WeatherToggles = {},
	EnableUmbrellaSounds = true,
	UmbrellaToggles = {},
	EnableReminders = true,
	ReminderSoundEnabled = true,
	ReminderSoundFile = "BNET_VoiceChat_ChannelInvite",
	ReminderSoundVolume = 1.0,
	OnlyInCharacter = false,
	WeatherMessages = true,
	DisplayIntensityAsPercentage = true,
	SpellToggles = {},
	EnableFallingSound = true,
	EnableSkyridingSound = true,
	ShowMinimapButton = true,
	LockMinimapButton = false,
	HideMinimapDecoration = false,
	MinimapButtonSize = 36,
	MinimapButtonRadius = 5,
	FramePositions = {},
	FrameSettings = {},
	EnableParasolIconReplacement = true,
	EnableScreenEffect = true,
	ScreenEffectOpacity = 1.0,
	ScreenEffectWeatherToggles = {},
	ScreenEffectInstances = {},
	TooltipWeatherStats = {
		Regional = true,
		Local = true,
	},
	["WeatherVolume_" .. LibForecast.WeatherType.Rain] = 0.25,
	["WeatherVolume_" .. LibForecast.WeatherType.Snow] = 0.50,
	["WeatherVolume_" .. LibForecast.WeatherType.Sandstorm] = 0.40,
	UmbrellaVolume = 0.50,
	SpellVolume = 0.50,
	FallingVolume = 0.50,
	SkyridingVolume = 0.25,
};

WeatherAddon.Defaults = Defaults;

local allSettingsData = {};
local ScrollView;

-- i should switch this to use localized_name, unique_key, value
local reminderSoundOptions = {
	{ key = "BNET_VoiceChat_ChannelInvite", text = L["Sound_BNET_VoiceChat_ChannelInvite"], value = 2113869 },
};

function WeatherAddon:GetReminderSoundFile(key)
	for _, opt in ipairs(reminderSoundOptions) do
		if opt.key == key then return opt.value; end
	end
	return reminderSoundOptions[1] and reminderSoundOptions[1].value;
end

local function RegisterReminderSound(key, localizedText, soundFile)
	assert(type(key) == "string" and key ~= "",
		"Weather RegisterReminderSound: key must be a non-empty string");
	assert(type(localizedText) == "string" and localizedText ~= "",
		"Weather RegisterReminderSound: localizedText must be a non-empty string");
	assert(type(soundFile) == "string" or type(soundFile) == "number",
		"Weather RegisterReminderSound: soundFile must be a string file path or fileID");

	for _, opt in ipairs(reminderSoundOptions) do
		if opt.key == key then return; end
	end

	table.insert(reminderSoundOptions, { key = key, text = localizedText, value = soundFile });

	if WeatherAddon.SettingsFrame and WeatherAddon.SettingsFrame:IsShown() then
		WeatherAddon:ToggleSettings();
		WeatherAddon:ToggleSettings();
	end
end

local function GetItemNameSafe(itemID)
	local itemName = C_Item.GetItemInfo(itemID);
	if not itemName then
		return "Accessory Toy #" .. itemID;
	end
	return itemName;
end

local function GetSpellNameSafe(spellID)
	if C_Spell and C_Spell.GetSpellInfo then
		local spellInfo = C_Spell.GetSpellInfo(spellID);
		if spellInfo then
			return spellInfo.name;
		end
	end
	return "Spell #" .. spellID;
end

function WeatherAddon:SaveFramePosition(frame, key)
	if not WeatherAddon_DB then return; end
	if not WeatherAddon_DB.FramePositions then
		WeatherAddon_DB.FramePositions = {};
	end
	local point, _, relativePoint, xOfs, yOfs = frame:GetPoint();
	WeatherAddon_DB.FramePositions[key] = {
		point = point,
		relativePoint = relativePoint,
		x = xOfs,
		y = yOfs,
	};
end

function WeatherAddon:RestoreFramePosition(frame, key)
	frame:ClearAllPoints();
	if WeatherAddon_DB and WeatherAddon_DB.FramePositions and WeatherAddon_DB.FramePositions[key] then
		local pos = WeatherAddon_DB.FramePositions[key];
		frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y);
	else
		frame:SetPoint("CENTER");
	end
end

function WeatherAddon:SaveFrameSetting(key, setting, value)
	if not WeatherAddon_DB then return; end
	if not WeatherAddon_DB.FrameSettings then WeatherAddon_DB.FrameSettings = {}; end
	if not WeatherAddon_DB.FrameSettings[key] then WeatherAddon_DB.FrameSettings[key] = {}; end
	WeatherAddon_DB.FrameSettings[key][setting] = value;
end

function WeatherAddon:RestoreFrameSettings(frame, key)
	WeatherAddon:RestoreFramePosition(frame, key);
	if WeatherAddon_DB and WeatherAddon_DB.FrameSettings and WeatherAddon_DB.FrameSettings[key] then
		local settings = WeatherAddon_DB.FrameSettings[key];
		if settings.scale then
			frame:SetScale(settings.scale);
		end
		if settings.locked ~= nil then
			frame:SetMovable(not settings.locked);
			if frame.TitleContainer then
				frame.TitleContainer:SetMovable(not settings.locked);
			end
		end
	end
end

local function InitializeCheckbox(button, data)
	button:SetHeight(30);
	button:SetScript("OnEnter", function()
		PlaySound(317793);
	end)
	
	if not button.checkbox then
		button.checkbox = CreateFrame("CheckButton", nil, button, "ChatConfigCheckButtonTemplate");
		button.checkbox:SetPoint("LEFT", 10, 0);
		button.checkbox:SetSize(24, 24);
		
		button.label = button.checkbox.Text;
		button.label:ClearAllPoints();
		button.label:SetPoint("LEFT", button.checkbox, "RIGHT", 5, 0);
		button.label:SetPoint("RIGHT", button, "RIGHT", -5, 0);
		button.label:SetJustifyH("LEFT");
	end
	
	button.checkbox:Show();
	button.label:Show();
	button.label:SetText(data.label);
	
	button.checkbox:SetScript("OnEnter", function(self)
		if data.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(data.label, 1, 1, 1);
			GameTooltip:AddLine(data.tooltip, nil, nil, nil, true);
			GameTooltip:Show();
		end
	end)
	button.checkbox:SetScript("OnLeave", GameTooltip_Hide)

	local isChecked = WeatherAddon_DB[data.key]
	if isChecked == nil then
		isChecked = data.default;
	end
	
	button.checkbox:SetChecked(isChecked);
	
	button.checkbox:SetScript("OnClick", function(self)
		local val = self:GetChecked()
		WeatherAddon_DB[data.key] = val
		if data.callback then data.callback(val); end
		PlaySound(286147);
	end)
end

local function InitializeDropdown(button, data)
	button:SetHeight(30)
	button:SetScript("OnEnter", function()
		PlaySound(317793);
	end)
	
	if not button.dropdown then
		button.dropdown = CreateFrame("DropdownButton", nil, button, "WowStyle1DropdownTemplate");
		button.dropdown:SetPoint("RIGHT", button, "RIGHT", -10, 0);
		button.dropdown:SetWidth(150);
		
		button.dropdownLabel = button:CreateFontString(nil, "OVERLAY", "GameTooltipText");
		button.dropdownLabel:SetPoint("LEFT", button, "LEFT", 24+15, 0);
		button.dropdownLabel:SetPoint("RIGHT", button.dropdown, "LEFT", -10, 0);
		button.dropdownLabel:SetJustifyH("LEFT");
	end
	
	button.dropdown:Show()
	button.dropdownLabel:Show()
	button.dropdownLabel:SetText(data.label)
	
	local function GetCurrentValue()
		return WeatherAddon_DB[data.key] or data.defaultValue
	end

	local function GetOptionID(opt)
		return data.useOptionKey and opt.key or opt.value;
	end

	local function UpdateDropdownText()
		local currentVal = GetCurrentValue()
		for _, opt in ipairs(data.options) do
			if GetOptionID(opt) == currentVal then
				button.dropdown.Text:SetText(opt.text);
				break;
			end
		end
	end

	local function GeneratorFunction(dropdown, rootDescription)
		rootDescription:SetScrollMode(300)
		for _, option in ipairs(data.options) do
			rootDescription:CreateRadio(option.text, function() return GetCurrentValue() == GetOptionID(option) end, function()
				WeatherAddon_DB[data.key] = GetOptionID(option)
				UpdateDropdownText();
				if data.callback then data.callback(GetOptionID(option)); end
			end, GetOptionID(option))
		end
	end
	
	button.dropdown:SetupMenu(GeneratorFunction)
	UpdateDropdownText()
	
	if data.tooltip then
		button.dropdown:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(button.dropdownLabel, "ANCHOR_TOPLEFT", -5, 5);
			GameTooltip:SetText(data.label, 1, 1, 1);
			GameTooltip:AddLine(data.tooltip, nil, nil, nil, true);
			GameTooltip:Show();
		end)
		button.dropdown:SetScript("OnLeave", GameTooltip_Hide)

		button.dropdownLabel:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", -5, 5);
			GameTooltip:SetText(data.label, 1, 1, 1);
			GameTooltip:AddLine(data.tooltip, nil, nil, nil, true);
			GameTooltip:Show();
		end)
		button.dropdownLabel:SetScript("OnLeave", GameTooltip_Hide)
	end
end

local function InitializeMultiCheckbox(button, data)
	button:SetHeight(30)
	button:SetScript("OnEnter", function()
		PlaySound(317793);
	end)
	
	if not button.multicheckbox then
		button.multicheckbox = CreateFrame("DropdownButton", nil, button, "WowStyle1DropdownTemplate");
		button.multicheckbox:SetPoint("RIGHT", button, "RIGHT", -10, 0);
		button.multicheckbox:SetWidth(150);

		if button.multicheckbox.Text then
			button.multicheckbox.Text:SetWordWrap(false);
		end
		
		button.multicheckboxLabel = button:CreateFontString(nil, "OVERLAY", "GameTooltipText");
		button.multicheckboxLabel:SetPoint("LEFT", button, "LEFT", 24+15, 0);
		button.multicheckboxLabel:SetPoint("RIGHT", button.multicheckbox, "LEFT", -10, 0);
		button.multicheckboxLabel:SetJustifyH("LEFT");
	end
	
	button.multicheckbox:Show()
	button.multicheckboxLabel:Show()
	button.multicheckboxLabel:SetText(data.label)
	
	local function GetCurrentValues()
		local values = WeatherAddon_DB[data.key]
		if type(values) ~= "table" then values = {} end
		
		local needsSave = false
		for _, opt in ipairs(data.options) do
			if values[opt.key] == nil then
				values[opt.key] = opt.default ~= false
				needsSave = true
			end
		end
		
		if needsSave then WeatherAddon_DB[data.key] = values end
		return values
	end

	local function UpdateDropdownText()
		local values = GetCurrentValues()
		local selected = {}
		local totalCount = 0
		
		for _, opt in ipairs(data.options) do
			totalCount = totalCount + 1
			if values[opt.key] then
				table.insert(selected, opt.text)
			end
		end
		
		if #selected == 0 then
			button.multicheckbox.Text:SetText("None");
		elseif #selected == totalCount then
			button.multicheckbox.Text:SetText("All");
		else
			 -- i should do that override thing that just shows the title name\
			-- there's a nicer way to set the dropdown text in the menu implementation guide
			button.multicheckbox.Text:SetText(table.concat(selected, ", "));
		end
	end

	local function GeneratorFunction(dropdown, rootDescription)
		rootDescription:SetScrollMode(300)
		local values = GetCurrentValues()
		
		for _, option in ipairs(data.options) do
			local checkbox = rootDescription:CreateCheckbox(
				option.text,
				function() return values[option.key] end,
				function()
					values[option.key] = not values[option.key];
					WeatherAddon_DB[data.key] = values;
					UpdateDropdownText();
					if data.callback then data.callback(values); end
				end
			)
		end
	end
	
	button.multicheckbox:SetupMenu(GeneratorFunction)
	UpdateDropdownText()
	
	if data.tooltip then
		button.multicheckbox:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(button.multicheckboxLabel, "ANCHOR_TOPLEFT", -5, 5);
			GameTooltip:SetText(data.label, 1, 1, 1);
			GameTooltip:AddLine(data.tooltip, nil, nil, nil, true);
			GameTooltip:Show();
		end)
		button.multicheckbox:SetScript("OnLeave", GameTooltip_Hide)
	end
end

local function InitializeSlider(button, data)
	button:SetHeight(30)
	button:SetScript("OnEnter", function()
		PlaySound(317793);
	end)

	local options = Settings.CreateSliderOptions(data.min, data.max, data.step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, data.formatter)

	if not button.slider then
		button.slider = CreateFrame("Frame", nil, button, "MinimalSliderWithSteppersTemplate")
		button.slider:SetPoint("RIGHT", button, "RIGHT", -10, 0)
		button.slider:SetWidth(150)
		button.slider.RightText:ClearAllPoints()
		button.slider.RightText:SetPoint("TOP", button.slider, "TOP", 0, 0)

		button.sliderLabel = button:CreateFontString(nil, "OVERLAY", "GameTooltipText")
		button.sliderLabel:SetPoint("LEFT", button, "LEFT", 24+15, 0)
		button.sliderLabel:SetPoint("RIGHT", button.slider, "LEFT", -10, 0)
		button.sliderLabel:SetJustifyH("LEFT")
		button.sliderLabel:SetTextColor(1, 1, 1)
	end

	button.slider:Show()
	button.sliderLabel:Show()
	button.sliderLabel:SetText(data.label)

	if button.slider.OnValueChangedCallback then
		button.slider:UnregisterCallback("OnValueChanged", button.slider.OnValueChangedCallback)
		button.slider.OnValueChangedCallback = nil
	end

	button.slider.isInitializing = true

	local currentVal = tonumber(WeatherAddon_DB[data.key])
	if currentVal == nil then currentVal = data.defaultValue end

	button.slider:Init(currentVal, options.minValue, options.maxValue, options.steps, options.formatters)

	local function OnValueChanged(self, value)
		if button.slider.isInitializing then return end
		WeatherAddon_DB[data.key] = value
		if data.callback then data.callback(value) end
	end

	button.slider.OnValueChangedCallback = OnValueChanged
	button.slider:RegisterCallback("OnValueChanged", OnValueChanged, button.slider)

	button.slider:SetValue(currentVal)
	button.slider.isInitializing = false

	if data.tooltip then
		button.slider.Slider:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(button.sliderLabel, "ANCHOR_TOPLEFT", -5, 5)
			GameTooltip:SetText(data.label, 1, 1, 1)
			GameTooltip:AddLine(data.tooltip, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		button.slider.Slider:SetScript("OnLeave", GameTooltip_Hide)

		button.sliderLabel:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", -5, 5)
			GameTooltip:SetText(data.label, 1, 1, 1)
			GameTooltip:AddLine(data.tooltip, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		button.sliderLabel:SetScript("OnLeave", GameTooltip_Hide)
	end
end

local function InitializeHeader(button, data)
	button:SetHeight(30)
	
	if not button.headerLabel then
		button.headerLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		button.headerLabel:SetPoint("LEFT", 10, -5)
		button.headerLabel:SetPoint("RIGHT", -10, -5)
		button.headerLabel:SetJustifyH("LEFT")
		button.headerLabel:SetTextColor(1, 0.82, 0)
	end
	
	button.headerLabel:Show()
	button.headerLabel:SetText(data.label)
end

local function InitializeActionButton(buttonRow, data)
	buttonRow:SetHeight(30);
	buttonRow:SetScript("OnEnter", function()
		PlaySound(317793);
	end)

	if not buttonRow.actionBtn then
		buttonRow.actionBtn = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate");
		buttonRow.actionBtn:SetPoint("RIGHT", buttonRow, "RIGHT", -10, 0);
		buttonRow.actionBtn:SetSize(150, 24);

		buttonRow.actionLabel = buttonRow:CreateFontString(nil, "OVERLAY", "GameTooltipText");
		buttonRow.actionLabel:SetPoint("LEFT", buttonRow, "LEFT", 24+15, 0);
		buttonRow.actionLabel:SetPoint("RIGHT", buttonRow.actionBtn, "LEFT", -10, 0);
		buttonRow.actionLabel:SetJustifyH("LEFT");
		buttonRow.actionLabel:SetTextColor(1, 1, 1);
	end

	buttonRow.actionBtn:Show();
	buttonRow.actionLabel:Show();

	buttonRow.actionLabel:SetText(data.label);
	buttonRow.actionBtn:SetText(data.btnText);

	buttonRow.actionBtn:SetScript("OnClick", function(self)
		if data.callback then data.callback() end
		PlaySound(286147);
	end)

	if data.tooltip then
		buttonRow.actionBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(buttonRow.actionLabel, "ANCHOR_TOPLEFT", -5, 5);
			GameTooltip:SetText(data.label, 1, 1, 1);
			GameTooltip:AddLine(data.tooltip, nil, nil, nil, true);
			GameTooltip:Show();
		end)
		buttonRow.actionBtn:SetScript("OnLeave", GameTooltip_Hide);
	end
end

local function SettingsRowInitializer(button, data)
	if button.checkbox then button.checkbox:Hide(); button.label:Hide(); end
	if button.multicheckbox then button.multicheckbox:Hide(); button.multicheckboxLabel:Hide(); end
	if button.dropdown then button.dropdown:Hide(); button.dropdownLabel:Hide(); end
	if button.slider then button.slider:Hide(); button.sliderLabel:Hide(); end
	if button.headerLabel then button.headerLabel:Hide(); end
	if button.actionBtn then button.actionBtn:Hide(); button.actionLabel:Hide(); end

	if data.type == "checkbox" then
		InitializeCheckbox(button, data);
	elseif data.type == "dropdown" then
		InitializeDropdown(button, data);
	elseif data.type == "multicheckbox" then
		InitializeMultiCheckbox(button, data);
	elseif data.type == "slider" then
		InitializeSlider(button, data);
	elseif data.type == "header" then
		InitializeHeader(button, data);
	elseif data.type == "action_button" then
		InitializeActionButton(button, data);
	end
end

local function BuildSettingsData()
	allSettingsData = {};

	local dynamicWeatherOptions = {};
	if WeatherAddon.WeatherSounds then
		for weatherType, _ in pairs(WeatherAddon.WeatherSounds) do
			table.insert(dynamicWeatherOptions, {
				key = tostring(weatherType),
				text = WeatherAddon.WeatherNames and WeatherAddon.WeatherNames[weatherType] or tostring(weatherType),
				default = true
			})
		end
	end

	local dynamicUmbrellaOptions = {};
	if WeatherAddon.UmbrellaItemIDsBuffIDs then
		for itemID, _ in pairs(WeatherAddon.UmbrellaItemIDsBuffIDs) do
			table.insert(dynamicUmbrellaOptions, {
				key = tostring(itemID),
				text = GetItemNameSafe(itemID),
				default = true
			})
		end
		table.sort(dynamicUmbrellaOptions, function(a, b)
			return a.text < b.text;
		end)
	end

	local dynamicSpellOptions = {};
	if WeatherAddon.SpellSounds then
		for spellID, _ in pairs(WeatherAddon.SpellSounds) do
			table.insert(dynamicSpellOptions, {
				key = tostring(spellID),
				text = GetSpellNameSafe(spellID),
				default = true
			})
		end
	end

	local dynamicScreenEffectOptions = {
		{
			key = tostring(LibForecast.WeatherType.Rain),
			text = WeatherAddon.WeatherNames[LibForecast.WeatherType.Rain],
			default = true
		},
		{
			key = tostring(LibForecast.WeatherType.Snow),
			text = WeatherAddon.WeatherNames[LibForecast.WeatherType.Snow],
			default = true
		},
		{
			key = tostring(LibForecast.WeatherType.Sandstorm),
			text = WeatherAddon.WeatherNames[LibForecast.WeatherType.Sandstorm],
			default = true
		},
	};

	local dynamicInstanceOptions = {
		{ key = "party", text = L["Widget_ACT_Dungeon"], default = false },
		{ key = "raid", text = L["Widget_ACT_Raids"], default = false },
		{ key = "scenario", text = L["Widget_ACT_ScenariosDelves"], default = false },
		{ key = "pvp", text = L["Widget_ACT_Battlegrounds"], default = false },
		{ key = "arena", text = L["Widget_ACT_Arena"], default = false },
		{ key = "neighborhood", text = L["Widget_ACT_Housing"], default = false },
	};

	table.insert(allSettingsData, { type = "header", label = L["Header_AmbienceSettings"] });

	table.insert(allSettingsData, {
		type = "multicheckbox",
		key = "WeatherToggles",
		label = L["Setting_IndoorWeatherAmbience"],
		tooltip = L["Setting_IndoorWeatherAmbienceTT"],
		options = dynamicWeatherOptions
	});

	if WeatherAddon.WeatherSounds then
		local sortedWeatherTypes = {};
		for weatherType in pairs(WeatherAddon.WeatherSounds) do
			table.insert(sortedWeatherTypes, weatherType);
		end
		table.sort(sortedWeatherTypes);

		for _, weatherType in ipairs(sortedWeatherTypes) do
			local weatherName = WeatherAddon.WeatherNames and WeatherAddon.WeatherNames[weatherType] or tostring(weatherType);
			local dbKey = "WeatherVolume_" .. weatherType;
			table.insert(allSettingsData, {
				type = "slider",
				key = dbKey,
				label = string.format("%s %s", weatherName, L["Setting_IndoorWeatherVolume"]),
				tooltip = L["Setting_IndoorWeatherVolumeTT"],
				min = 0.0, max = 1.0, step = 0.05,
				defaultValue = Defaults[dbKey] or 0.25,
				formatter = function(value)
					return math.floor(value * 100 + 0.5) .. "%";
				end,
				callback = function(value)
					if WeatherAddon.RefreshAmbience then WeatherAddon:RefreshAmbience() end
				end,
			});
		end
	end

	table.insert(allSettingsData, { type = "header", label = L["Header_AccessorySettings"] });

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "EnableUmbrellaSounds",
		label = L["Setting_AccessorySounds"],
		tooltip = L["Setting_AccessorySoundsTT"],
		default = Defaults.EnableUmbrellaSounds,
	});

	table.insert(allSettingsData, {
		type = "multicheckbox",
		key = "UmbrellaToggles",
		label = L["Setting_TrackedAccessories"],
		tooltip = L["Setting_TrackedAccessoriesTT"],
		options = dynamicUmbrellaOptions
	});

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "EnableParasolIconReplacement",
		label = L["Setting_AccessoryIconReplacement"],
		tooltip = L["Setting_AccessoryIconReplacementTT"],
		default = Defaults.EnableParasolIconReplacement,
		callback = function(value)
			if WeatherAddon.UpdateActionBarTextures then
				WeatherAddon.UpdateActionBarTextures();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "slider",
		key = "UmbrellaVolume",
		label = L["Setting_AccessoriesAmbienceVolume"],
		tooltip = L["Setting_AccessoriesAmbienceVolumeTT"],
		min = 0.0, max = 1.0, step = 0.05,
		defaultValue = Defaults.UmbrellaVolume,
		formatter = function(value)
			return math.floor(value * 100 + 0.5) .. "%";
		end,
		callback = function(value)
			if WeatherAddon.RefreshAmbience then WeatherAddon:RefreshAmbience() end
		end,
	});

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "EnableReminders",
		label = L["Setting_AccessoryReminders"],
		tooltip = L["Setting_AccessoryRemindersTT"],
		default = Defaults.EnableReminders,
	});

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "ReminderSoundEnabled",
		label = L["Setting_ReminderSound"],
		tooltip = L["Setting_ReminderSoundTT"],
		default = Defaults.ReminderSoundEnabled,
	});

	table.insert(allSettingsData, {
		type = "dropdown",
		key = "ReminderSoundFile",
		label = L["Setting_ReminderSoundSelection"],
		tooltip = L["Setting_ReminderSoundSelectionTT"],
		defaultValue = Defaults.ReminderSoundFile,
		options = reminderSoundOptions,
		useOptionKey = true,
		callback = function(key)
			local file = WeatherAddon:GetReminderSoundFile(key);
			local volume = WeatherAddon_DB.ReminderSoundVolume or Defaults.ReminderSoundVolume;
			C_EncounterEvents.SetEventSound(REMINDER_EVENT_ID, REMINDER_TRIGGER_ID, { file = file, volume = volume });
			C_EncounterEvents.PlayEventSound(REMINDER_EVENT_ID, REMINDER_TRIGGER_ID);
			C_EncounterEvents.SetEventSound(REMINDER_EVENT_ID, REMINDER_TRIGGER_ID, nil);
		end,
	});

	table.insert(allSettingsData, {
		type = "slider",
		key = "ReminderSoundVolume",
		label = L["Setting_ReminderSoundVolume"],
		tooltip = L["Setting_ReminderSoundVolumeTT"],
		min = 0.0, max = 1.0, step = 0.05,
		defaultValue = Defaults.ReminderSoundVolume,
		formatter = function(value)
			return math.floor(value * 100 + 0.5) .. "%";
		end,
	});

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "OnlyInCharacter",
		label = L["Setting_TRP3_IC_Only"],
		tooltip = L["Setting_TRP3_IC_OnlyTT"],
		default = Defaults.OnlyInCharacter,
	});

	table.insert(allSettingsData, {
		type = "multicheckbox",
		key = "SpellToggles",
		label = L["Setting_WeatherAmbienceSpells"],
		tooltip = L["Setting_WeatherAmbienceSpellsTT"],
		options = dynamicSpellOptions
	});

	table.insert(allSettingsData, {
		type = "slider",
		key = "SpellVolume",
		label = L["Setting_SpellAmbienceVolume"],
		tooltip = L["Setting_SpellAmbienceVolumeTT"],
		min = 0.0, max = 1.0, step = 0.05,
		defaultValue = Defaults.SpellVolume,
		formatter = function(value)
			return math.floor(value * 100 + 0.5) .. "%";
		end,
		callback = function(value)
			if WeatherAddon.RefreshAmbience then WeatherAddon:RefreshAmbience() end
		end,
	});

	table.insert(allSettingsData, {
		type = "action_button",
		key = "ResetIgnoredSession",
		label = L["Setting_ResetIgnoredSession"],
		btnText = L["Btn_Reset"],
		tooltip = L["Setting_ResetIgnoredSessionTT"],
		callback = function()
			if WeatherAddon.ResetSessionIgnored then
				WeatherAddon:ResetSessionIgnored();
			end
		end,
	});

	table.insert(allSettingsData, { type = "header", label = L["Header_MovementSounds"] });

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "EnableFallingSound",
		label = L["Setting_FallingSounds"],
		tooltip = L["Setting_FallingSoundsTT"],
		default = Defaults.EnableFallingSound,
		callback = function(value)
			if WeatherAddon.UpdateFallingSoundState then
				WeatherAddon:UpdateFallingSoundState();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "slider",
		key = "FallingVolume",
		label = L["Setting_FallingVolume"],
		tooltip = L["Setting_FallingVolumeTT"],
		min = 0.0, max = 1.0, step = 0.05,
		defaultValue = Defaults.FallingVolume,
		formatter = function(value)
			return math.floor(value * 100 + 0.5) .. "%";
		end,
	});

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "EnableSkyridingSound",
		label = L["Setting_SkyridingSounds"],
		tooltip = L["Setting_SkyridingSoundsTT"],
		default = Defaults.EnableSkyridingSound,
		callback = function(value)
			if WeatherAddon.UpdateSkyridingSoundState then
				WeatherAddon:UpdateSkyridingSoundState();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "slider",
		key = "SkyridingVolume",
		label = L["Setting_SkyridingVolume"],
		tooltip = L["Setting_SkyridingVolumeTT"],
		min = 0.0, max = 1.0, step = 0.05,
		defaultValue = Defaults.SkyridingVolume,
		formatter = function(value)
			return math.floor(value * 100 + 0.5) .. "%";
		end,
	});

	table.insert(allSettingsData, { type = "header", label = L["Header_ScreenEffects"] });

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "EnableScreenEffect",
		label = L["Setting_EnableScreenEffect"],
		tooltip = L["Setting_EnableScreenEffectTT"],
		default = Defaults.EnableScreenEffect,
		callback = function(value)
			if WeatherAddon.RefreshScreenEffects then
				WeatherAddon:RefreshScreenEffects();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "multicheckbox",
		key = "ScreenEffectInstances",
		label = L["Setting_DisableScreenEffectsInstances"],
		tooltip = L["Setting_DisableScreenEffectsInstancesTT"],
		options = dynamicInstanceOptions,
		callback = function(value)
			if WeatherAddon.RefreshScreenEffects then
				WeatherAddon:RefreshScreenEffects();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "multicheckbox",
		key = "ScreenEffectWeatherToggles",
		label = L["Setting_ScreenEffectWeathers"],
		tooltip = L["Setting_ScreenEffectWeathersTT"],
		options = dynamicScreenEffectOptions,
		callback = function(value)
			if WeatherAddon.RefreshScreenEffects then
				WeatherAddon:RefreshScreenEffects();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "slider",
		key = "ScreenEffectOpacity",
		label = L["Setting_ScreenEffectOpacity"],
		tooltip = L["Setting_ScreenEffectOpacityTT"],
		min = 0.0, max = 1.0, step = 0.05,
		defaultValue = Defaults.ScreenEffectOpacity,
		formatter = function(value)
			return math.floor(value * 100 + 0.5) .. "%";
		end,
		callback = function(value)
			if WeatherAddon.RefreshScreenEffects then
				WeatherAddon:RefreshScreenEffects();
			end
		end,
	});

	table.insert(allSettingsData, { type = "header", label = L["Header_MinimapIcon"] });

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "ShowMinimapButton",
		label = L["Setting_ShowMinimapButton"],
		tooltip = L["Setting_ShowMinimapButtonTT"],
		default = Defaults.ShowMinimapButton,
		callback = function(value)
			if WeatherAddon.UpdateMinimapButtonVisibility then
				WeatherAddon:UpdateMinimapButtonVisibility();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "LockMinimapButton",
		label = L["Setting_LockMinimapButton"],
		tooltip = L["Setting_LockMinimapButtonTT"],
		default = Defaults.LockMinimapButton,
		callback = function(value)
			if WeatherAddon.UpdateMinimapButtonLock then
				WeatherAddon:UpdateMinimapButtonLock();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "HideMinimapDecoration",
		label = L["Setting_HideMinimapDecoration"],
		tooltip = L["Setting_HideMinimapDecorationTT"],
		default = Defaults.HideMinimapDecoration,
		callback = function(value)
			if WeatherAddon.UpdateMinimapIconDecoration then
				WeatherAddon:UpdateMinimapIconDecoration();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "slider",
		key = "MinimapButtonSize",
		label = L["Setting_MinimapButtonSize"],
		tooltip = L["Setting_MinimapButtonSizeTT"],
		min = 24, max = 64, step = 1,
		defaultValue = Defaults.MinimapButtonSize,
		formatter = function(value)
			return math.floor(value);
		end,
		callback = function(value)
			if WeatherAddon.UpdateMinimapButtonSize then
				WeatherAddon:UpdateMinimapButtonSize();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "slider",
		key = "MinimapButtonRadius",
		label = L["Setting_MinimapButtonRadius"],
		tooltip = L["Setting_MinimapButtonRadiusTT"],
		min = -20, max = 60, step = 1,
		defaultValue = Defaults.MinimapButtonRadius,
		formatter = function(value)
			return math.floor(value);
		end,
		callback = function(value)
			if WeatherAddon.UpdateMinimapButtonPosition then
				WeatherAddon:UpdateMinimapButtonPosition();
			end
		end,
	});

	table.insert(allSettingsData, {
		type = "multicheckbox",
		key = "TooltipWeatherStats",
		label = L["Setting_TooltipWeatherStats"],
		tooltip = L["Setting_TooltipWeatherStatsTT"],
		options = {
			{ key = "Regional", text = L["RegionalWeatherOption"], default = true },
			{ key = "Local", text = L["LocalWeatherOption"], default = true },
		},
	});

	table.insert(allSettingsData, { type = "header", label = L["Header_Notifications"] });

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "WeatherMessages",
		label = L["Setting_WeatherMessages"],
		tooltip = L["Setting_WeatherMessagesTT"],
		default = Defaults.WeatherMessages,
	});

	table.insert(allSettingsData, {
		type = "checkbox",
		key = "DisplayIntensityAsPercentage",
		label = L["Setting_WeatherIntensityPercent"],
		tooltip = L["Setting_WeatherIntensityPercentTT"], 
		default = Defaults.DisplayIntensityAsPercentage,
	});

	-- automatically generate search text for all entries
	for _, data in ipairs(allSettingsData) do
		if data.label then
			local tooltipText = data.tooltip or "";
			data.searchText = (data.label .. " " .. tooltipText):lower();
		end
	end

	return allSettingsData;
end

local WeatherMeowFrameMixin = {};

WeatherMeowFrameMixin.SoundFileList = {
	5852001, 5852003, 5852005, 5852007, 5852009,
	5852011, 5852013, 5852015, 5852017, 5852019,
	5852021, 5852023, 5852025, 5852027, 5852029,
	5852031, 5852033,
	4618261, 4618269,
	7545101, 7545103, 7545105, 7545107, 7545109,
	7545111, 7545113, 7545115, 7545117, 7545119,
	7545121, 7545123, 7545125
};

function WeatherMeowFrameMixin:OnLoad()
	self.clickCount = 0;
	self.clickThreshold = 20;
	self.timeFrame = 0.2;
	self.lastClickTime = 0;
	self:RegisterForClicks("AnyDown", "AnyUp");
end

function WeatherMeowFrameMixin:OnClick(button, down)
	if not down then
		self.Icon:SetTexCoord(0, 1, 0, 1);
	else
		self.Icon:SetTexCoord(0.03, 0.97, 0.03, 0.97);
	end

	local currentTime = GetTime()
	if currentTime - self.lastClickTime > self.timeFrame then
		self:ResetClicks();
	end

	self.clickCount = self.clickCount + 1;
	self.lastClickTime = currentTime;

	if self.clickCount >= self.clickThreshold then
		self:ResetClicks();
		self:Mrow();
	end
end

function WeatherMeowFrameMixin:ResetClicks()
	self.clickCount = 0;
end

function WeatherMeowFrameMixin:Mrow()
	local sound = self.SoundFileList[math.random(1, #self.SoundFileList)];
	PlaySoundFile(sound, "SFX");
end

function WeatherAddon:CreateSettingsUI()
	local frame = CreateFrame("Frame", "Weather_SettingsFrame", UIParent, "PortraitFrameTemplateMinimizable");
	frame:SetSize(450, 500);
	frame:SetMovable(true);
	frame:EnableMouse(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", function(self)
		frame:StopMovingOrSizing();
		if frame:IsMovable() then
			frame:StartMoving();
		end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing();
		WeatherAddon:SaveFramePosition(self, "SettingsFrame");
	end)

	WeatherAddon:RestoreFrameSettings(frame, "SettingsFrame");

	frame:SetToplevel(true);
	frame:SetClampedToScreen(true);
	frame:SetTitle(L["Weather_Settings"]);

	frame.TitleContainer:EnableMouse(true);
	frame.TitleContainer:RegisterForDrag("LeftButton");

	frame.TitleContainer:SetScript("OnDragStart", function(self)
		frame:StopMovingOrSizing();
		if frame:IsMovable() then
			frame:StartMoving();
		end
	end)

	frame.TitleContainer:SetScript("OnDragStop", function(self)
		frame:StopMovingOrSizing();
		WeatherAddon:SaveFramePosition(frame, "SettingsFrame");
	end)

	frame.TitleContainer:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then
			MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
				rootDescription:CreateTitle(L["Weather_Settings"]);

				local function IsLocked()
					return not frame:IsMovable();
				end
				local function ToggleLock()
					local locked = not frame:IsMovable();
					frame:SetMovable(locked);
					if frame.TitleContainer then
						frame.TitleContainer:SetMovable(locked);
					end
					WeatherAddon:SaveFrameSetting("SettingsFrame", "locked", not locked);
				end
				rootDescription:CreateCheckbox(L["LockFrame"], IsLocked, ToggleLock);

				rootDescription:CreateButton(L["ResetPosition"], function()
					frame:ClearAllPoints();
					frame:SetPoint("CENTER");
					WeatherAddon:SaveFramePosition(frame, "SettingsFrame");
				end)

				local submenu = rootDescription:CreateButton(L["UIScale"]);
				local presets = { 1.4, 1.2, 1.0, 0.8, 0.6 };
				for _, scale in ipairs(presets) do
					local text = string.format("%d%%", scale * 100);
					submenu:CreateRadio(text,
						function()
							return math.abs(frame:GetScale() - scale) < 0.01;
						end,
						function()
							frame:SetScale(scale);
							WeatherAddon:SaveFrameSetting("SettingsFrame", "scale", scale);
						end
					)
				end
			end)
		end
	end)

	tinsert(UISpecialFrames, "Weather_SettingsFrame");

	frame.Bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0);
	frame.Bg:SetPoint("TOPLEFT", 1, -24);
	frame.Bg:SetPoint("BOTTOMRIGHT", -2, 2);
	frame.Bg:SetColorTexture(0.1, 0.1, 0.1, 0.9);

	-- tab 1 contents
	local settingsContainer = CreateFrame("Frame", nil, frame);
	settingsContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -35);
	settingsContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5);

	local SearchBox = CreateFrame("EditBox", nil, settingsContainer, "SearchBoxTemplate");
	SearchBox:SetPoint("TOPLEFT", settingsContainer, "TOPLEFT", 65, 0);
	SearchBox:SetPoint("TOPRIGHT", settingsContainer, "TOPRIGHT", -25, 0);
	SearchBox:SetHeight(20);
	SearchBox:SetAutoFocus(false);

	local ScrollBox = CreateFrame("Frame", nil, settingsContainer, "WowScrollBoxList");
	ScrollBox:SetPoint("TOPLEFT", 5, -25);
	ScrollBox:SetPoint("BOTTOMRIGHT", -20, 5);

	local ScrollBar = CreateFrame("EventFrame", nil, settingsContainer, "MinimalScrollBar");
	ScrollBar:SetPoint("TOPLEFT", ScrollBox, "TOPRIGHT", 10, 0);
	ScrollBar:SetPoint("BOTTOMLEFT", ScrollBox, "BOTTOMRIGHT", 10, 0);

	-- background nineslice
	local settingsListBg = settingsContainer:CreateTexture(nil, "BACKGROUND", nil, -2);
	settingsListBg:SetPoint("TOPLEFT", ScrollBox, "TOPLEFT", -2, 2);
	settingsListBg:SetPoint("BOTTOMRIGHT", ScrollBox, "BOTTOMRIGHT", 2, -2);
	settingsListBg:SetAtlas("GO-bg-Group");
	settingsListBg:SetTextureSliceMargins(10, 10, 10, 10);
	settingsListBg:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched);

	settingsListBg.BgIcon = settingsContainer:CreateTexture(nil, "BACKGROUND", nil, 1);
	settingsListBg.BgIcon:SetPoint("CENTER", 0, 0);
	settingsListBg.BgIcon:SetSize(settingsContainer:GetWidth()*.75, settingsContainer:GetWidth()*.75);
	settingsListBg.BgIcon:SetTexture("Interface\\AddOns\\Weather\\Textures\\Forecast\\rain_heavy.png");
	settingsListBg.BgIcon:SetDesaturated(true);
	settingsListBg.BgIcon:SetVertexColor(0.1, 0.1, 0.1, 0.25);

	local ScrollView = CreateScrollBoxListLinearView();
	ScrollUtil.InitScrollBoxListWithScrollBar(ScrollBox, ScrollBar, ScrollView);
	
	ScrollView:SetElementInitializer("Button", SettingsRowInitializer);
	ScrollView:SetElementExtent(30);
	
	ScrollView:SetPadding(5, 5, 5, 5, 5);

	local function FilterSettings()
		local query = SearchBox:GetText():lower();
		local filtered = {};
		
		for _, data in ipairs(allSettingsData) do
			if query == "" or (data.searchText and data.searchText:find(query, 1, true)) then
				table.insert(filtered, data);
			end
		end
		
		local dataProvider = CreateDataProvider(filtered);
		ScrollView:SetDataProvider(dataProvider);
	end

	SearchBox:HookScript("OnTextChanged", function(self)
		self.t = 0;
		self:SetScript("OnUpdate", function(self, elapsed)
			self.t = self.t + elapsed;
			if self.t >= 0.2 then
				self.t = 0;
				self:SetScript("OnUpdate", nil);
				FilterSettings();
			end
		end)
	end)

	BuildSettingsData();
	FilterSettings();

	-- tab 2 contents, only shows with the weather collector module
	local collectorEnabled = C_AddOns.IsAddOnLoaded("Weather_Collector");
	local dataContainer;

	if collectorEnabled then
		dataContainer = WeatherAddon:CreateDataUI(frame);
		WeatherAddon.dataContainer = dataContainer;
		dataContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -35);
		dataContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 10);
		dataContainer:Hide();
	end

	-- tab 1 button press thingy
	local tab1 = CreateFrame("Button", "WeatherAddonTab1", frame, "PanelTabButtonTemplate");
	tab1:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 15, 2);
	tab1:SetText(L["Settings"]);
	PanelTemplates_TabResize(tab1, 0);

	local function SelectTab(tabID)
		PanelTemplates_SetTab(frame, tabID);
		if tabID == 1 then
			settingsContainer:Show();
			if dataContainer then
				dataContainer:Hide();
			end
			frame:SetTitle(L["Weather_Settings"]);
		elseif tabID == 2 and dataContainer then
			settingsContainer:Hide();
			dataContainer:Show();
			frame:SetTitle(L["WeatherData"]);
		end
		WeatherAddon.activeTab = tabID;
		PlaySound(316468);
	end

	WeatherAddon.SelectTab = SelectTab;

	tab1:SetScript("OnClick", function()
		SelectTab(1);
	end)

	-- tab 2 button press thingy
	if collectorEnabled then
		local tab2 = CreateFrame("Button", "WeatherAddonTab2", frame, "PanelTabButtonTemplate");
		tab2:SetPoint("LEFT", tab1, "RIGHT", 0, 0);
		tab2:SetText(L["WeatherData"]);
		PanelTemplates_TabResize(tab2, 0);
		tab2:SetScript("OnClick", function()
			SelectTab(2);
		end);
	end

	local numTabs = collectorEnabled and 2 or 1;
	frame.numTabs = numTabs;
	PanelTemplates_SetNumTabs(frame, numTabs);
	SelectTab(1);

	WeatherAddon.SettingsFrame = frame;

	if WeatherAddon.CreateWeatherIcon then
		local portraitIcon = WeatherAddon:CreateWeatherIcon(frame, 60);
		portraitIcon:SetAllPoints(frame.PortraitContainer.CircleMask);
		portraitIcon.Border:Hide();
		portraitIcon:EnableMouse(true);

		FrameUtil.SpecializeFrameWithMixins(portraitIcon, WeatherMeowFrameMixin);
		portraitIcon:OnLoad();
		portraitIcon:SetScript("OnClick", portraitIcon.OnClick);

		if WeatherAddon.UpdateWeatherIcon then
			WeatherAddon.UpdateWeatherIcon();
		end

		portraitIcon:SetScript("OnEnter", function(self)
			if Weather_Collector and Weather_Collector.FlushCurrentDuration then
				Weather_Collector.FlushCurrentDuration();
			end
			if WeatherAddon.RefreshDataPanel then
				WeatherAddon.RefreshDataPanel();
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["WeatherForecast"]);
			if WeatherAddon.AppendWeatherTooltip then
				WeatherAddon:AppendWeatherTooltip(GameTooltip);
			end
			GameTooltip:Show();
		end)
		portraitIcon:SetScript("OnLeave", GameTooltip_Hide);
	end

	frame:Hide();

	frame:SetScript("OnShow", function()
		PlaySound(315305);
	end)
	frame:SetScript("OnHide", function()
		PlaySound(315305);
		PlaySound(12189);
	end)
end

function WeatherAddon:ToggleSettings(tabID)
	if not WeatherAddon.SettingsFrame then
		WeatherAddon:CreateSettingsUI();
	end

	tabID = tabID or 1;
	local frame = WeatherAddon.SettingsFrame;

	local function FlagDataPanelIfNeeded()
		if tabID == 2 and WeatherAddon.dataContainer then
			WeatherAddon.dataContainer.selectCurrentOnShow = true;
		end
	end

	if not frame:IsShown() then
		FlagDataPanelIfNeeded();
		frame:Show();
		WeatherAddon.SelectTab(tabID);
	elseif WeatherAddon.activeTab == tabID then
		frame:Hide();
	else
		FlagDataPanelIfNeeded();
		WeatherAddon.SelectTab(tabID);
	end
end

SLASH_WEATHERSETTINGS1 = L["SLASH_WEATHER1"];
SLASH_WEATHERSETTINGS2 = L["SLASH_WEATHER2"];
SLASH_WEATHERSETTINGS3 = L["SLASH_WEATHER3"];
SLASH_WEATHERSETTINGS4 = L["SLASH_WEATHER4"];

SlashCmdList["WEATHERSETTINGS"] = function(msg)
	WeatherAddon:ToggleSettings();
end

-- Public API
-- external addons can use this to add more notification sounds
Weather_API = {
	RegisterReminderSound = RegisterReminderSound,
};

if Weather_API then
	Weather_API.RegisterReminderSound("Sound_AlarmClockWarning2", L["Sound_AlarmClockWarning2"], 567399);
	Weather_API.RegisterReminderSound("Sound_UI_BnetToast", L["Sound_UI_BnetToast"], 567402);
	Weather_API.RegisterReminderSound("FX_Ship_Bell_Chime_01", L["FX_Ship_Bell_Chime_01"], 1129273);
	Weather_API.RegisterReminderSound("FX_Ship_Bell_Chime_02", L["FX_Ship_Bell_Chime_02"], 1129274);
	Weather_API.RegisterReminderSound("FX_Ship_Bell_Chime_03", L["FX_Ship_Bell_Chime_03"], 1129275);
	Weather_API.RegisterReminderSound("RaidWarning", L["RaidWarning"], 567397);
	Weather_API.RegisterReminderSound("FX_DarkMoonFaire_Bell", L["FX_DarkMoonFaire_Bell"], 1100031);
	Weather_API.RegisterReminderSound("BellTollHorde", L["BellTollHorde"], 565853);
	Weather_API.RegisterReminderSound("BellTollTribal", L["BellTollTribal"], 566027);
	Weather_API.RegisterReminderSound("KharazahnBellToll", L["KharazahnBellToll"], 566254);
	Weather_API.RegisterReminderSound("BellTollNightElf", L["BellTollNightElf"], 566558);
	Weather_API.RegisterReminderSound("BellTollAlliance", L["BellTollAlliance"], 566564);
end