local AddonName, WeatherAddon = ...;
local L = WeatherAddon.L;
--local LibForecast = LibStub("LibForecast-1.0");
local build = select(4, GetBuildInfo());

local IsForever = build >= 16000 and build < 20000;
WeatherAddon.IsForever = IsForever;

local SOUND_CHANNEL = "Ambience";
local frame = CreateFrame("Frame");

local function Print(...)
	local textColor = CreateColor(0.2, 0.8, 1.0):GenerateHexColor();
	local addonNameColored = WrapTextInColorCode(L["TOC_Title"], textColor);
	local addonNameJoiner = string.join(": ", addonNameColored, "%s");
	
	local args = {...};
	for i = 1, #args do
		args[i] = tostring(args[i]);
	end
	local fullText = table.concat(args, " ");
	
	local formattedText = string.format(addonNameJoiner, fullText);
	return DEFAULT_CHAT_FRAME:AddMessage(formattedText, 1, 1, 1);
end

WeatherAddon.Print = Print;

local WeatherType = {
	Clear = 0,
	Rain = 1,
	Snow = 2,
	Sandstorm = 3,
	Miscellaneous = 4,
	Firestorm = 5,
	Unknown = -1,
};

WeatherAddon.WeatherType = WeatherType;

local WeatherNames = {
	[WeatherType.Clear] = L["Clear"],
	[WeatherType.Rain] = L["Rain"],
	[WeatherType.Snow] = L["Snow"],
	[WeatherType.Sandstorm] = L["Sandstorm"],
	[WeatherType.Miscellaneous] = L["Miscellaneous"],
	[WeatherType.Firestorm] = L["Firestorm"],
	[WeatherType.Unknown] = L["Unknown"],
};

WeatherAddon.WeatherNames = WeatherNames;

local isIndoors = false
local hasUmbrella = false;
local activeSpellID = nil;
local isSoundEnabled = true;
local activeSoundHandles = {};
local playbackTimer = nil;
local AMBIENCE_EVENT_ID = 8;
local AMBIENCE_TRIGGER_ID = 0;
local lastReminderTime = 0;
local REMINDER_THROTTLE_SECONDS = 30;
local lastWarnedExpiration = 0;

local lastWeatherType = nil;
local lastWeatherIntensity = nil;
local lastWeatherPrintTime = 0;
local WEATHER_PRINT_COOLDOWN = 15;

local WeatherSounds = {
	[WeatherType.Rain] = {
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_000_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_001_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_002_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_003_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_004_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_005_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_006_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_007_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_008_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_009_faded_boostedx2.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_rain_010_faded_boostedx2.ogg", duration = 60 },
	},
	[WeatherType.Snow] = {
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_004_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_005_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_006_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_007_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_008_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_009_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_snow_010_faded.ogg", duration = 60 },
	},
	[WeatherType.Sandstorm] = {
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_004_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_005_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_006_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_007_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_008_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_009_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\indoor_sandstorm_010_faded.ogg", duration = 60 },
	},
};

WeatherAddon.WeatherSounds = WeatherSounds;

local UmbrellaSounds = {
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_000_faded.ogg", duration = 60 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_001_faded.ogg", duration = 60 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_002_faded.ogg", duration = 60 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_003_faded.ogg", duration = 60 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_004_faded.ogg", duration = 60 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_005_faded.ogg", duration = 60 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_006_faded.ogg", duration = 60 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_007_faded.ogg", duration = 60 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_008_faded.ogg", duration = 60 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\umbrellarain_009_faded.ogg", duration = 60 },
};

local UmbrellaItemIDsBuffIDs = {
	[212523] = 431994,
	[212524] = 431998,
	[212525] = 432001,
	[212500] = 431949,
	[182696] = 341624,
	[182695] = 341682,
	[182694] = 341678,
};

WeatherAddon.UmbrellaItemIDsBuffIDs = UmbrellaItemIDsBuffIDs;

local SpellSounds = {
	[17] = { -- power word shield
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_004_faded.ogg", duration = 60 },
	},
	[235450] = { -- prismatic barrier
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_004_faded.ogg", duration = 60 },
	},
	[11426] = { -- ice barrier
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_004_faded.ogg", duration = 60 },
	},
	[235313] = { -- blazing barrier
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_004_faded.ogg", duration = 60 },
	},
	[108416] = { -- dark pact
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_004_faded.ogg", duration = 60 },
	},
	[186265] = { -- aspect of the turtle
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_004_faded.ogg", duration = 60 },
	},
	[642] = { -- divine shield
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\magicshield_004_faded.ogg", duration = 60 },
	},
	[48707] = { -- anti-magic shell
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_000_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_001_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_002_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_003_faded.ogg", duration = 60 },
		{ file = "Interface\\AddOns\\Weather\\Sounds\\firebarrier_004_faded.ogg", duration = 60 },
	},


	[122708] = CopyTable(UmbrellaSounds),
};

WeatherAddon.SpellSounds = SpellSounds;

local function StopAllAmbience()
	if playbackTimer then
		playbackTimer:Cancel();
		playbackTimer = nil;
	end
	
	for handle in pairs(activeSoundHandles) do
		StopSound(handle, 2000);
	end
	wipe(activeSoundHandles);
end

--[[
i have a future idea to add some of the placeable umbrella chair toys
basically place down the toy (successful cast), check player current position,
and proceed to play ambience if within ~5 yards of that placed location
this will not be for release though
]]
local function CheckForUmbrellaBuff()
	if not WeatherAddon_DB.EnableUmbrellaSounds then return false; end

	for itemID, spellID in pairs(UmbrellaItemIDsBuffIDs) do
		if WeatherAddon_DB.UmbrellaToggles[tostring(itemID)] then
			local spellAura = C_UnitAuras.GetPlayerAuraBySpellID(spellID);
			if spellAura then return true; end
		end
	end
	return false;
end

local function CheckForSpellBuff()
	if not WeatherAddon_DB.SpellToggles then return nil; end

	for spellID, _ in pairs(SpellSounds) do
		if WeatherAddon_DB.SpellToggles[tostring(spellID)] then
			local spellAura = C_UnitAuras.GetPlayerAuraBySpellID(spellID);
			if spellAura then return spellID; end
		end
	end
	return nil;
end

local function CheckSoundEnabled()
	local allSound = C_CVar.GetCVar("Sound_EnableAllSound")
	local ambience = C_CVar.GetCVar("Sound_EnableAmbience")
	local allSFX = C_CVar.GetCVar("Sound_EnableSFX")
	
	local masterVol = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 1
	local ambVol = tonumber(C_CVar.GetCVar("Sound_AmbienceVolume")) or 1

	if allSound == "0" or ambience == "0" or allSFX == "0" or masterVol == 0 or ambVol == 0 then
		return false;
	end
	return true;
end

local function PlayNextTrack()
	if not isSoundEnabled or (not isIndoors and not hasUmbrella and not activeSpellID) then return; end

	local weatherInfo = C_Weather.GetCurrentWeather()
	local weatherType = weatherInfo and weatherInfo.type or WeatherType.Clear

	local weatherIntensity = weatherInfo and weatherInfo.intensity or 1
	if WeatherAddon_DB.WeatherToggles and not WeatherAddon_DB.WeatherToggles[tostring(weatherType)] then return; end

	local soundTable = nil;
	local categoryVol = 0.5;
	
	if isIndoors then
		soundTable = WeatherSounds[weatherType];
		local volKey = "WeatherVolume_" .. weatherType;
		local volDefault = WeatherAddon.Defaults and WeatherAddon.Defaults[volKey] or 0.5;
		categoryVol = WeatherAddon_DB[volKey] ~= nil and WeatherAddon_DB[volKey] or volDefault;
	elseif hasUmbrella and not isIndoors then
		if weatherType == WeatherType.Rain then
			soundTable = UmbrellaSounds;
			categoryVol = WeatherAddon_DB.UmbrellaVolume or 0.5;
		end
	elseif activeSpellID and not isIndoors then
		if weatherType == WeatherType.Rain then
			soundTable = SpellSounds[activeSpellID];
			categoryVol = WeatherAddon_DB.SpellVolume or 0.5;
		end
	end
	
	if soundTable and #soundTable > 0 then
		local randomIndex = math.random(1, #soundTable);
		local soundData = soundTable[randomIndex];
		
		local soundFile = soundData.file;
		local soundDuration = soundData.duration;
		
		--local ambVol = tonumber(C_CVar.GetCVar("Sound_AmbienceVolume")) or 1;
		
		local finalVol = weatherIntensity * categoryVol;
		
		C_EncounterEvents.SetEventSound(AMBIENCE_EVENT_ID, AMBIENCE_TRIGGER_ID, { file = soundFile, channel = SOUND_CHANNEL, volume = finalVol });
		
		local soundHandle = C_EncounterEvents.PlayEventSound(AMBIENCE_EVENT_ID, AMBIENCE_TRIGGER_ID);
		
		C_EncounterEvents.SetEventSound(AMBIENCE_EVENT_ID, AMBIENCE_TRIGGER_ID, nil);
		
		if soundHandle then
			activeSoundHandles[soundHandle] = true;
			
			C_Timer.After(soundDuration, function()
				activeSoundHandles[soundHandle] = nil;
			end)
		end

		local nextTrackDelay = math.max(0.1, soundDuration - 5);
		playbackTimer = C_Timer.NewTimer(nextTrackDelay, PlayNextTrack);
	else
		StopAllAmbience();
	end
end

function WeatherAddon:RefreshAmbience()
	if isSoundEnabled and (isIndoors or hasUmbrella or activeSpellID) then
		StopAllAmbience();
		RunNextFrame(PlayNextTrack); -- sometimes the ambience would die completely
	end
end

local function CheckEnvironment()
	local currentlyIndoors = not IsOutdoors()
	local currentUmbrellaStatus = CheckForUmbrellaBuff()
	local currentSpellID = currentUmbrellaStatus and nil or CheckForSpellBuff()
	local currentlySoundEnabled = CheckSoundEnabled()

	if currentlyIndoors ~= isIndoors or currentUmbrellaStatus ~= hasUmbrella or currentSpellID ~= activeSpellID or currentlySoundEnabled ~= isSoundEnabled then
		isIndoors = currentlyIndoors;
		WeatherAddon.isIndoors = isIndoors;
		hasUmbrella = currentUmbrellaStatus;
		activeSpellID = currentSpellID;
		isSoundEnabled = currentlySoundEnabled;
		
		StopAllAmbience();
		
		if isSoundEnabled and (isIndoors or hasUmbrella or activeSpellID) then
			PlayNextTrack();
		end
	end
end

local function OnWeatherChanged(weatherType, weatherInfo, isLogin)
	weatherInfo = weatherInfo or {};
	weatherType = weatherType or WeatherType.Clear;
	local intensity = weatherInfo.intensity or 0;
	local now = GetTime();

	local weatherHasChanged = (weatherType ~= lastWeatherType) or (intensity ~= lastWeatherIntensity);

	if WeatherAddon_DB and WeatherAddon_DB.WeatherMessages then
		if isLogin or (weatherHasChanged and (now - lastWeatherPrintTime >= WEATHER_PRINT_COOLDOWN)) then
			local weatherName = WeatherNames[weatherType] or WeatherNames[WeatherType.Unknown] or "Unknown";
			
			local formattedIntensity;
			if WeatherAddon_DB.DisplayIntensityAsPercentage then
				formattedIntensity = math.floor((intensity * 100) + 0.5) .. "%";
			else
				formattedIntensity = tostring(intensity);
			end
			
			Print(string.format(L["ChangedWeather"], weatherName, formattedIntensity));
			lastWeatherPrintTime = now;
		end
	end

	if isSoundEnabled and (isIndoors or hasUmbrella or activeSpellID) then
		StopAllAmbience();
		RunNextFrame(PlayNextTrack);
	end
	
	WeatherAddon:CheckUmbrellaReminder();
end

local function OnEvent(self, event, ...)
	if event == "PLAYER_LOGOUT" then
		StopAllAmbience();
	elseif event == "CVAR_UPDATE" then
		local cvarName = ...;
		if cvarName == "Sound_EnableAllSound" or cvarName == "Sound_EnableAmbience" or cvarName == "Sound_MasterVolume" or cvarName == "Sound_AmbienceVolume" then
			CheckEnvironment();
		end
	elseif event == "WEATHER_CHANGED" then
		local weatherInfo = C_Weather.GetCurrentWeather();
		OnWeatherChanged(weatherInfo and weatherInfo.type, weatherInfo, false);
	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = ...;
		CheckEnvironment();
		WeatherAddon:CheckUmbrellaReminder();
		
		if isInitialLogin or isReloadingUi then
			local weatherInfo = C_Weather.GetCurrentWeather();
			OnWeatherChanged(weatherInfo and weatherInfo.type, weatherInfo, true);
		end
	else
		CheckEnvironment();
		WeatherAddon:CheckUmbrellaReminder();
	end
end

frame:RegisterEvent("CVAR_UPDATE");
frame:RegisterUnitEvent("UNIT_AURA", "player");
frame:RegisterEvent("MINIMAP_UPDATE_ZOOM");
frame:RegisterEvent("NEW_WMO_CHUNK");
frame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED");
frame:RegisterEvent("AREA_POIS_UPDATED");
frame:RegisterEvent("FOG_OF_WAR_UPDATED");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("ZONE_CHANGED");
frame:RegisterEvent("ZONE_CHANGED_INDOORS");
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
frame:RegisterEvent("PLAYER_LOGOUT");
frame:RegisterEvent("WEATHER_CHANGED");

frame:SetScript("OnEvent", OnEvent);