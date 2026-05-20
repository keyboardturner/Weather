local AddonName, WeatherCollector = ...;
local L = WeatherCollector.L;

local frame = CreateFrame("Frame");

local LibForecast = LibStub("LibForecast-1.0")

Weather_Collector_DB = Weather_Collector_DB or {};

local currentUIMapID = nil;
local currentSubzone = nil;
local currentWeatherType = nil;
local weatherStartTime = nil;
local isForcedWeatherActive = false;
local isSceneActive = false;

local WeatherNames = {
	[LibForecast.WeatherType.Clear] = L["Clear"],
	[LibForecast.WeatherType.Rain] = L["Rain"],
	[LibForecast.WeatherType.Snow] = L["Snow"],
	[LibForecast.WeatherType.Sandstorm] = L["Sandstorm"],
	[LibForecast.WeatherType.Miscellaneous] = L["Miscellaneous"],
	[LibForecast.WeatherType.Firestorm] = L["Firestorm"],
	[LibForecast.WeatherType.Unknown] = L["Unknown"],
};

local function IsForcedWeatherActive()
	if not WeatherCollector.ForceWeatherEffectTable then return false; end
	for i = 1, #WeatherCollector.ForceWeatherEffectTable do
		local spellID = WeatherCollector.ForceWeatherEffectTable[i];
		if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
			return true;
		end
	end
	return false;
end

local function GetCurrentLocationInfo()
	local mapID = C_Map.GetBestMapForUnit("player");
	local subzone = GetMinimapZoneText();
	if not subzone or subzone == "" then
		subzone = "Unknown";
	end
	
	return mapID, subzone;
end

local function RecordCurrentWeatherDuration()
	if currentUIMapID and currentSubzone and currentWeatherType and weatherStartTime then
		local currentTime = GetTime();
		local duration = currentTime - weatherStartTime;

		if duration > 0 then
			local weatherName = WeatherNames[currentWeatherType] or "Unknown";

			Weather_Collector_DB[currentUIMapID] = Weather_Collector_DB[currentUIMapID] or {};
			Weather_Collector_DB[currentUIMapID][currentSubzone] = Weather_Collector_DB[currentUIMapID][currentSubzone] or {};
			
			local currentDuration = Weather_Collector_DB[currentUIMapID][currentSubzone][weatherName] or 0;
			Weather_Collector_DB[currentUIMapID][currentSubzone][weatherName] = currentDuration + duration;
		end
	end
end

local function UpdateAuraState()
	local currentlyForced = IsForcedWeatherActive();

	if currentlyForced ~= isForcedWeatherActive then
		local currentTime = GetTime();

		if currentlyForced then
			RecordCurrentWeatherDuration();
			isForcedWeatherActive = true;
			weatherStartTime = nil;
		else
			isForcedWeatherActive = false;
			if not isSceneActive then
				weatherStartTime = currentTime;
			else
				weatherStartTime = nil;
			end
		end
	end
end

local function UpdateState(newMapID, newSubzone, newWeatherType)
	local currentTime = GetTime();

	if newMapID ~= currentUIMapID or newSubzone ~= currentSubzone or newWeatherType ~= currentWeatherType then
		RecordCurrentWeatherDuration();

		currentUIMapID = newMapID;
		currentSubzone = newSubzone;
		currentWeatherType = newWeatherType;

		if isForcedWeatherActive or isSceneActive then
			weatherStartTime = nil;
		else
			weatherStartTime = currentTime;
		end
	end
end

local function CheckEnvironment()
	local newMapID, newSubzone = GetCurrentLocationInfo();
	local weatherInfo = LibForecast:GetCurrentWeatherInfo();
	local newWeatherType = weatherInfo and weatherInfo.type or LibForecast.WeatherType.Unknown;

	if newWeatherType == LibForecast.WeatherType.Unknown and weatherInfo and weatherInfo.recordID then
		newWeatherType = WeatherAddon.RecordIDsTable[weatherInfo.recordID] or newWeatherType;
	end

	UpdateAuraState();
	UpdateState(newMapID, newSubzone, newWeatherType);
end

local function OnWeatherChanged(event, weatherType, weatherInfo)
	local newMapID, newSubzone = GetCurrentLocationInfo();
	
	if weatherType == LibForecast.WeatherType.Unknown and weatherInfo.recordID then
		weatherType = WeatherAddon.RecordIDsTable[weatherInfo.recordID] or weatherType;
	end
	
	UpdateState(newMapID, newSubzone, weatherType);
end

local function OnEvent(self, event, ...)
	if event == "UNIT_AURA" then
		local unit = ...;
		if unit == "player" then
			UpdateAuraState();
		end
	elseif event == "CLIENT_SCENE_OPENED" then
		RecordCurrentWeatherDuration();
		isSceneActive = true;
		weatherStartTime = nil;
	elseif event == "CLIENT_SCENE_CLOSED" then
		isSceneActive = false;
		CheckEnvironment();
	elseif event == "PLAYER_LOGOUT" then
		RecordCurrentWeatherDuration()
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
		CheckEnvironment();
	end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("PLAYER_LOGOUT");
frame:RegisterEvent("ZONE_CHANGED");
frame:RegisterEvent("ZONE_CHANGED_INDOORS");
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
frame:RegisterEvent("CLIENT_SCENE_OPENED");
frame:RegisterEvent("CLIENT_SCENE_CLOSED");
frame:RegisterUnitEvent("UNIT_AURA", "player");
frame:SetScript("OnEvent", OnEvent);

LibForecast.RegisterCallback(frame, "OnWeatherChanged", OnWeatherChanged);

Weather_Collector = Weather_Collector or {};
function Weather_Collector.FlushCurrentDuration()
	RecordCurrentWeatherDuration()
	if not isForcedWeatherActive and not isSceneActive then
		weatherStartTime = GetTime();
	end
end