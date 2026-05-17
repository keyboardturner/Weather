local AddonName, WeatherAddon = ...;
local L = WeatherAddon.L;
local LibForecast = LibStub("LibForecast-1.0");

local SOUND_CHANNEL = "Ambience";
local frame = CreateFrame("Frame");

local function Print(text)
	local textColor = CreateColor(0.2, 0.8, 1.0):GenerateHexColor();
	local addonNameColored = WrapTextInColorCode(L["TOC_Title"], textColor);
	local addonNameJoiner = string.join(": ", addonNameColored, "%s");
	local text = string.format(addonNameJoiner, text);
	
	return DEFAULT_CHAT_FRAME:AddMessage(text, 1, 1, 1);
end

WeatherAddon.Print = Print;

local WeatherNames = {
	[LibForecast.WeatherType.Clear] = L["Clear"],
	[LibForecast.WeatherType.Rain] = L["Rain"],
	[LibForecast.WeatherType.Snow] = L["Snow"],
	[LibForecast.WeatherType.Sandstorm] = L["Sandstorm"],
	[LibForecast.WeatherType.Miscellaneous] = L["Miscellaneous"],
	[LibForecast.WeatherType.Unknown] = L["Unknown"],
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

local WeatherSounds = {
	[LibForecast.WeatherType.Rain] = {
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
	[LibForecast.WeatherType.Snow] = {
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
	[LibForecast.WeatherType.Sandstorm] = {
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

local WeatherForecastTextures = {
	Clear = {
		Light_Day = "Interface\\AddOns\\Weather\\Forecast\\clear_day.png",
		Medium_Day = "Interface\\AddOns\\Weather\\Forecast\\partialcloudy_day.png",
		Heavy_Day = "Interface\\AddOns\\Weather\\Forecast\\cloudy_day.png",
		Light_Night = "Interface\\AddOns\\Weather\\Forecast\\clear_night.png",
		Medium_Night = "Interface\\AddOns\\Weather\\Forecast\\partialcloudy_night.png",
		Heavy_Night = "Interface\\AddOns\\Weather\\Forecast\\cloudy_night.png",
	};
	Rain = {
		Light = "Interface\\AddOns\\Weather\\Forecast\\rain_light.png",
		Medium = "Interface\\AddOns\\Weather\\Forecast\\rain_medium.png",
		Heavy = "Interface\\AddOns\\Weather\\Forecast\\rain_heavy.png",
	};
	Snow = {
		Light = "Interface\\AddOns\\Weather\\Forecast\\snow_light.png",
		Medium = "Interface\\AddOns\\Weather\\Forecast\\snow_medium.png",
		Heavy = "Interface\\AddOns\\Weather\\Forecast\\snow_heavy.png",
	};
	Sandstorm = {
		Light = "Interface\\AddOns\\Weather\\Forecast\\sandstorm_light.png",
		Medium = "Interface\\AddOns\\Weather\\Forecast\\sandstorm_medium.png",
		Heavy = "Interface\\AddOns\\Weather\\Forecast\\sandstorm_heavy.png",
	};
	Miscellaneous = "Interface\\AddOns\\Weather\\Forecast\\misc_unknown.png", -- also unknown
};

WeatherAddon.WeatherForecastTextures = WeatherForecastTextures;

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

	local weatherInfo = LibForecast:GetCurrentWeatherInfo()
	local weatherType = weatherInfo.type
	local weatherIntensity = weatherInfo.intensity or 1
	if WeatherAddon_DB.WeatherToggles and not WeatherAddon_DB.WeatherToggles[tostring(weatherType)] then return; end

	local soundTable = nil;
	local categoryVol = 0.5;
	
	if isIndoors then
		soundTable = WeatherSounds[weatherType];
		local volKey = "WeatherVolume_" .. weatherType;
		local volDefault = WeatherAddon.Defaults and WeatherAddon.Defaults[volKey] or 0.5;
		categoryVol = WeatherAddon_DB[volKey] ~= nil and WeatherAddon_DB[volKey] or volDefault;
	elseif hasUmbrella and not isIndoors then
		if weatherType == LibForecast.WeatherType.Rain then
			soundTable = UmbrellaSounds;
			categoryVol = WeatherAddon_DB.UmbrellaVolume or 0.5;
		end
	elseif activeSpellID and not isIndoors then
		if weatherType == LibForecast.WeatherType.Rain then
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

local function OnEvent(self, event, ...)
	if event == "PLAYER_LOGOUT" then
		StopAllAmbience();
	elseif event == "CVAR_UPDATE" then
		local cvarName = ...;
		if cvarName == "Sound_EnableAllSound" or cvarName == "Sound_EnableAmbience" or cvarName == "Sound_MasterVolume" or cvarName == "Sound_AmbienceVolume" then
			CheckEnvironment();
		end
	else
		CheckEnvironment();
		WeatherAddon:CheckUmbrellaReminder();
	end
end

local function OnWeatherChanged(event, weatherType, weatherInfo)
	if WeatherAddon_DB and WeatherAddon_DB.WeatherMessages then
		local weatherName = WeatherNames[weatherType] or "Unknown";
		local intensity = weatherInfo.intensity or 0;
		
		local formattedIntensity;
		if WeatherAddon_DB.DisplayIntensityAsPercentage then
			formattedIntensity = math.floor((intensity * 100) + 0.5) .. "%";
		else
			formattedIntensity = tostring(intensity);
		end
		
		local recordID = weatherInfo.recordID;
		
		Print(string.format(L["ChangedWeather"], weatherName, formattedIntensity));
	end

	if isSoundEnabled and (isIndoors or hasUmbrella or activeSpellID) then
		StopAllAmbience();
		RunNextFrame(PlayNextTrack);
	end
	
	WeatherAddon:CheckUmbrellaReminder();
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

frame:SetScript("OnEvent", OnEvent);
LibForecast.RegisterCallback(frame, "OnWeatherChanged", OnWeatherChanged);