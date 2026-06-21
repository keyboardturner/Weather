local AddonName, WeatherAddon = ...;
local LibForecast = LibStub("LibForecast-1.0");
local Print = WeatherAddon.Print;

local FADE_DURATION = 10.0
local MAX_ALPHA = 0.30 -- any higher than this feels a bit too intense

local WeatherColors = {
	[LibForecast.WeatherType.Rain] = { 0.20, 0.45, 0.85 },
	[LibForecast.WeatherType.Snow] = { 0.90, 0.95, 1.00 },
	[LibForecast.WeatherType.Sandstorm] = { 0.72, 0.52, 0.10 },
	[LibForecast.WeatherType.Firestorm] = { 0.95, 0.32, 0.08 },
};

local isIndoors = false;
local effectFrame, colorTex;
local displayColor = { 0, 0, 0 };
local pendingColor = { 0, 0, 0 };
local pendingAlpha = 0;
local curAlpha = 0;
local fadeState = "idle";
local curWeatherType = LibForecast.WeatherType.Unknown;
local curIntensity = 0;

local function GetDB(key)
	if WeatherAddon_DB ~= nil and WeatherAddon_DB[key] ~= nil then
		return WeatherAddon_DB[key];
	end
	return WeatherAddon.Defaults[key];
end

local function IsEnabled()
	return GetDB("EnableScreenEffect") ~= false;
end

local inInstanceStatus = false;
local instanceTypeStatus = "none";

local function ComputeTargetAlpha(weatherType, intensity)
	if not IsEnabled() then return 0; end
	if isIndoors then return 0; end
	
	local inInstance, instanceType = IsInInstance();
	if inInstance and instanceType and instanceType ~= "none" then
		local instanceSettings = GetDB("ScreenEffectInstances");
		-- suppress the screen effect in selected instance types
		if instanceSettings and instanceSettings[instanceType] == true then
			return 0;
		end
	end

	if not WeatherColors[weatherType] then return 0; end

	local toggles = GetDB("ScreenEffectWeatherToggles");
	if toggles and toggles[tostring(weatherType)] == false then
		return 0;
	end

	local opacity = GetDB("ScreenEffectOpacity") or 1.0;
	return math.max(0, math.min(MAX_ALPHA, intensity * opacity * MAX_ALPHA));
end

local function CopyColor(src)
	return { src[1], src[2], src[3] };
end

local function ColorsMatch(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3];
end

local function ApplyTexture()
	colorTex:SetColorTexture(displayColor[1], displayColor[2], displayColor[3], curAlpha);
end

local function OnUpdate(self, elapsed)
	local rate = elapsed / FADE_DURATION;

	if fadeState == "out" then
		curAlpha = math.max(curAlpha - rate, 0);
		ApplyTexture();

		if curAlpha <= 0 then
			displayColor = CopyColor(pendingColor);

			if pendingAlpha > 0 then
				fadeState = "in";
			else
				fadeState = "idle";
				self:SetScript("OnUpdate", nil);
			end
		end

	elseif fadeState == "in" then
		if curAlpha < pendingAlpha then
			curAlpha = math.min(curAlpha + rate, pendingAlpha);
		else
			curAlpha = math.max(curAlpha - rate, pendingAlpha);
		end
		ApplyTexture();

		if curAlpha == pendingAlpha then
			fadeState = "idle";
			self:SetScript("OnUpdate", nil);
		end
	end
end

local function StartAnimation()
	if effectFrame then
		effectFrame:SetScript("OnUpdate", OnUpdate);
	end
end

local function TriggerWeatherTransition(weatherType, intensity)
	local newColor = WeatherColors[weatherType] or { 0, 0, 0 };
	local newAlpha = ComputeTargetAlpha(weatherType, intensity);

	pendingColor = CopyColor(newColor);
	pendingAlpha = newAlpha;

	if curAlpha > 0 and not ColorsMatch(displayColor, newColor) then
		fadeState = "out";
	else
		if curAlpha <= 0 then
			displayColor = CopyColor(newColor);
		end
		fadeState = "in";
	end

	StartAnimation();
end

local function OnWeatherChanged(event, weatherType, weatherInfo)
	if weatherType == LibForecast.WeatherType.Unknown and weatherInfo.recordID then
		weatherType = WeatherAddon.RecordIDsTable[weatherInfo.recordID] or weatherType;
	end

	curWeatherType = weatherType;
	curIntensity = weatherInfo.intensity or 0;
	TriggerWeatherTransition(curWeatherType, curIntensity);
end

function WeatherAddon:RefreshScreenEffects()
	if not effectFrame then return; end

	pendingColor = CopyColor(WeatherColors[curWeatherType] or { 0, 0, 0 });
	pendingAlpha = ComputeTargetAlpha(curWeatherType, curIntensity);

	if curAlpha <= 0 then
		displayColor = CopyColor(pendingColor);
	end

	if fadeState == "idle" and curAlpha ~= pendingAlpha then
		fadeState = "in";
		StartAnimation();
	end
end

local function BuildEffectFrame()
	effectFrame = CreateFrame("Frame", "Weather_ScreenEffectFrame", WorldFrame);
	effectFrame:SetFrameStrata("BACKGROUND");
	effectFrame:SetFrameLevel(0);
	effectFrame:SetPoint("CENTER", WorldFrame, "CENTER", 0, 0);
	effectFrame:SetSize(WorldFrame:GetWidth(), WorldFrame:GetHeight());

	colorTex = effectFrame:CreateTexture(nil, "BACKGROUND", nil, -8);
	colorTex:SetAllPoints(effectFrame);
	colorTex:SetColorTexture(0, 0, 0, 0);
end

local function CheckEnvironment()
	local currentlyIndoors = not IsOutdoors();
	local currentInInstance, currentInstanceType = IsInInstance();
	
	if currentlyIndoors ~= isIndoors or currentInInstance ~= inInstanceStatus or currentInstanceType ~= instanceTypeStatus then
		isIndoors = currentlyIndoors;
		inInstanceStatus = currentInInstance;
		instanceTypeStatus = currentInstanceType;
		WeatherAddon:RefreshScreenEffects();
	end
end

local initFrame = CreateFrame("Frame");
initFrame:RegisterEvent("PLAYER_LOGIN");
initFrame:RegisterEvent("DISPLAY_SIZE_CHANGED");
initFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM");
initFrame:RegisterEvent("NEW_WMO_CHUNK");
initFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED");
initFrame:RegisterEvent("AREA_POIS_UPDATED");
initFrame:RegisterEvent("FOG_OF_WAR_UPDATED");
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
initFrame:RegisterEvent("ZONE_CHANGED");
initFrame:RegisterEvent("ZONE_CHANGED_INDOORS");
initFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");

initFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if WeatherAddon_DB then
			for key, defaultVal in pairs(WeatherAddon.Defaults) do
				if WeatherAddon_DB[key] == nil then
					WeatherAddon_DB[key] = type(defaultVal) == "table" and CopyTable(defaultVal) or defaultVal;
				end
			end
		end

		BuildEffectFrame();
		
		isIndoors = not IsOutdoors();

		local info = LibForecast:GetCurrentWeatherInfo();
		curWeatherType = info.type;
		
		if curWeatherType == LibForecast.WeatherType.Unknown and info.recordID then
			curWeatherType = WeatherAddon.RecordIDsTable[info.recordID] or curWeatherType;
		end
		
		curIntensity = info.intensity or 0;

		TriggerWeatherTransition(curWeatherType, curIntensity);

		self:UnregisterEvent("PLAYER_LOGIN");

	elseif event == "DISPLAY_SIZE_CHANGED" then
		if effectFrame then
			effectFrame:SetSize(WorldFrame:GetWidth(), WorldFrame:GetHeight());
		end
	else
		CheckEnvironment();
	end
end)

LibForecast.RegisterCallback(initFrame, "OnWeatherChanged", OnWeatherChanged);