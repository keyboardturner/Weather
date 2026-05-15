local AddonName, WeatherAddon = ...;
local L = WeatherAddon.L;
local LibForecast = LibStub("LibForecast-1.0");
local Print = WeatherAddon.Print;

local currentIconTexture = nil;
local isIconTransitioning = false;

local WeatherForecastTextures = {
	Clear = {
		Light_Day = "Interface\\AddOns\\Weather\\Textures\\Forecast\\clear_day.png",
		Medium_Day = "Interface\\AddOns\\Weather\\Textures\\Forecast\\partialcloudy_day.png",
		Heavy_Day = "Interface\\AddOns\\Weather\\Textures\\Forecast\\cloudy_day.png",
		Light_Night = "Interface\\AddOns\\Weather\\Textures\\Forecast\\clear_night.png",
		Medium_Night = "Interface\\AddOns\\Weather\\Textures\\Forecast\\partialcloudy_night.png",
		Heavy_Night = "Interface\\AddOns\\Weather\\Textures\\Forecast\\cloudy_night.png",
	},
	Rain = {
		Light = "Interface\\AddOns\\Weather\\Textures\\Forecast\\rain_light.png",
		Medium = "Interface\\AddOns\\Weather\\Textures\\Forecast\\rain_medium.png",
		Heavy = "Interface\\AddOns\\Weather\\Textures\\Forecast\\rain_heavy.png",
	},
	Snow = {
		Light = "Interface\\AddOns\\Weather\\Textures\\Forecast\\snow_light.png",
		Medium = "Interface\\AddOns\\Weather\\Textures\\Forecast\\snow_medium.png",
		Heavy = "Interface\\AddOns\\Weather\\Textures\\Forecast\\snow_heavy.png",
	},
	Sandstorm = {
		Light = "Interface\\AddOns\\Weather\\Textures\\Forecast\\sandstorm_light.png",
		Medium = "Interface\\AddOns\\Weather\\Textures\\Forecast\\sandstorm_medium.png",
		Heavy = "Interface\\AddOns\\Weather\\Textures\\Forecast\\sandstorm_heavy.png",
	},
	Miscellaneous = "Interface\\AddOns\\Weather\\Textures\\Forecast\\misc_unknown.png",
};

WeatherAddon.WeatherIcons = {};

function WeatherAddon:CreateWeatherIcon(parent, size)
	local frame = CreateFrame("Button", nil, parent);
	frame:SetSize(size, size);
	frame:SetFixedFrameStrata(true);
	frame:SetFrameStrata("MEDIUM");
	frame:SetFixedFrameLevel(true);
	frame:SetFrameLevel(8);

	frame.BG = frame:CreateTexture(nil, "OVERLAY", nil, 3);
	frame.BG:SetAllPoints();
	frame.BG:SetColorTexture(0, 0, 0, 0.5);

	frame.Stars = frame:CreateTexture(nil, "OVERLAY", nil, 4);
	frame.Stars:SetAllPoints();
	frame.Stars:SetTexture("Interface\\AddOns\\Weather\\Textures\\Forecast\\night_stars.png");

	frame.Icon = frame:CreateTexture(nil, "OVERLAY", nil, 5);
	frame.Icon:SetAllPoints();
	if currentIconTexture then
		frame.Icon:SetTexture(currentIconTexture);
	end

	frame.mask = frame:CreateMaskTexture();
	frame.mask:SetAllPoints(frame.BG);
	frame.mask:SetTexture("interface\\common\\commonmaskcircle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE");
	frame.BG:AddMaskTexture(frame.mask);
	frame.Stars:AddMaskTexture(frame.mask);
	frame.Icon:AddMaskTexture(frame.mask);

	frame.Border = frame:CreateTexture(nil, "OVERLAY", nil, 6);
	frame.Border:SetPoint("CENTER", 0, 0);
	frame.Border:SetSize(size, size);
	frame.Border:SetTexture("Interface\\AddOns\\Weather\\Textures\\portraitmetalring.png");

	table.insert(WeatherAddon.WeatherIcons, frame);
	return frame;
end

local testOverrideHour = nil;
local testOverrideMinute = nil;

--[[
the sunrise/sunsets are at the whim of the server + region, not client or "server timezone location"
ie all NA realms are synced to blizz HQ time, which may or may not change with daylight savings
each region like EU, KO, TW, and CN are all different
it's also why oceanic is "stuck" at night time gameplay despite their own servers being physically located in australia
it'd be nice if we could get like an "environment time" function for this
]]
local function GetRegionUTCOffset()
	local region = GetCurrentRegion()
	if region == 1 then -- Americas (US Pacific)
		return -8;
	elseif region == 2 then -- Korea
		return 9;
	elseif region == 3 then -- Europe
		return 1;
	elseif region == 4 then -- Taiwan
		return 8;
	elseif region == 5 then -- China
		return 8;
	end
	return 0;
end

function WeatherAddon:GetCurrentTime()
	if testOverrideHour then
		return testOverrideHour, testOverrideMinute or 0;
	end
	local utcTime = GetServerTime();
	local regionTime = utcTime + GetRegionUTCOffset() * 3600;
	local dateTable = date("!*t", regionTime);
	return dateTable.hour, dateTable.min;
end

local function GetIntensityCategory(intensity)
	intensity = intensity or 0;
	if intensity <= 0.1 then
		return L["Light"];
	elseif intensity <= 0.5 then
		return L["Medium"];
	else
		return L["Heavy"];
	end
end

local function GetTimeOfDay()
	local hours, minutes = WeatherAddon:GetCurrentTime();
	local timeDecimal = hours + (minutes / 60);
	return (timeDecimal >= 5 and timeDecimal < 18) and L["Day"] or L["Night"]; -- sunrise / sunset times
end

--[[
handles the background of the icon changing colors with the time of day
it's not perfect or exact yet, may take some tweaking
should allow for a smooth transition between colors on a curve
ideally i could probably look at lightparam.db2, but that's more work
]]
local SkyColors = {
	{ time = 0.0, r = 0.05, g = 0.05, b = 0.10 }, -- Midnight
	{ time = 4.5, r = 0.05, g = 0.05, b = 0.15 }, -- Pre-dawn
	{ time = 5.5, r = 0.30, g = 0.15, b = 0.40 }, -- Dawn (purple)
	{ time = 6.0, r = 0.80, g = 0.40, b = 0.20 }, -- Sunrise (orange)
	{ time = 8.0, r = 0.30, g = 0.60, b = 0.90 }, -- Day (blue)
	{ time = 17.0, r = 0.30, g = 0.60, b = 0.90 }, -- Late day
	{ time = 18.0, r = 0.90, g = 0.30, b = 0.15 }, -- Sunset (red)
	{ time = 19.5, r = 0.20, g = 0.10, b = 0.40 }, -- Dusk (purple)
	{ time = 20.5, r = 0.05, g = 0.05, b = 0.10 }, -- Night
	{ time = 24.0, r = 0.05, g = 0.05, b = 0.10 }, -- Midnight wrap
};

local function Lerp(a, b, t)
	return a + (b - a) * t;
end

local FADE_STEP = 0.016
local function FadeTexture(texture, fromAlpha, toAlpha, duration, onComplete)
	local elapsed = 0;
	texture:SetAlpha(fromAlpha);
	local ticker;
	ticker = C_Timer.NewTicker(FADE_STEP, function()
		elapsed = elapsed + FADE_STEP;
		local t = math.min(elapsed / duration, 1);
		texture:SetAlpha(fromAlpha + (toAlpha - fromAlpha) * t);
		if t >= 1 then
			ticker:Cancel();
			if onComplete then
				onComplete();
			end
		end
	end)
end

local function UpdateBackgroundDynamic()
	local h, m = WeatherAddon:GetCurrentTime();
	local currentTime = h + (m / 60);

	local startColor, endColor;
	for i = 1, #SkyColors - 1 do
		if currentTime >= SkyColors[i].time and currentTime <= SkyColors[i+1].time then
			startColor = SkyColors[i];
			endColor = SkyColors[i+1];
			break;
		end
	end
	if not startColor then
		startColor, endColor = SkyColors[1], SkyColors[2];
	end

	local span = endColor.time - startColor.time;
	local t = (span > 0) and ((currentTime - startColor.time) / span) or 0;
	local r = Lerp(startColor.r, endColor.r, t);
	local g = Lerp(startColor.g, endColor.g, t);
	local b = Lerp(startColor.b, endColor.b, t);

	local starAlpha;
	if currentTime >= 5.5 and currentTime < 6.5 then
		starAlpha = 1 - ((currentTime - 5.5) / 1.0);
	elseif currentTime >= 6.5 and currentTime < 19.0 then
		starAlpha = 0;
	elseif currentTime >= 19.0 and currentTime < 20.5 then
		starAlpha = (currentTime - 19.0) / 1.5;
	else
		starAlpha = 1;
	end

	for _, frame in ipairs(WeatherAddon.WeatherIcons) do
		if frame ~= minimapBtn or not (WeatherAddon_DB and WeatherAddon_DB.HideMinimapDecoration) then
			frame.BG:SetColorTexture(r, g, b, 1);
			frame.Stars:SetAlpha(starAlpha);
		end
	end
end

-- smooth transition between icons when changing weather and time of day
local function UpdateWeatherIcon()
	UpdateBackgroundDynamic()

	local weatherInfo = LibForecast:GetCurrentWeatherInfo();
	if not weatherInfo then return; end

	local weatherType = weatherInfo.type;
	local intensityStr = GetIntensityCategory(weatherInfo.intensity);
	local newTexturePath = WeatherForecastTextures.Miscellaneous;

	if weatherType == LibForecast.WeatherType.Clear then
		local timeOfDay = GetTimeOfDay();
		newTexturePath = WeatherForecastTextures.Clear[intensityStr .. "_" .. timeOfDay];
	elseif weatherType == LibForecast.WeatherType.Rain then
		newTexturePath = WeatherForecastTextures.Rain[intensityStr];
	elseif weatherType == LibForecast.WeatherType.Snow then
		newTexturePath = WeatherForecastTextures.Snow[intensityStr];
	elseif weatherType == LibForecast.WeatherType.Sandstorm then
		newTexturePath = WeatherForecastTextures.Sandstorm[intensityStr];
	end

	if not newTexturePath or newTexturePath == currentIconTexture or isIconTransitioning then return; end
	isIconTransitioning = true;

	local function applyAndFadeIn()
		currentIconTexture = newTexturePath;
		for _, frame in ipairs(WeatherAddon.WeatherIcons) do
			frame.Icon:SetTexture(newTexturePath);
			FadeTexture(frame.Icon, 0, 1, 0.4);
		end
		C_Timer.After(0.4, function() isIconTransitioning = false end);
	end

	if currentIconTexture then
		for _, frame in ipairs(WeatherAddon.WeatherIcons) do
			FadeTexture(frame.Icon, 1, 0, 0.3);
		end
		C_Timer.After(0.3, applyAndFadeIn);
	else
		applyAndFadeIn();
	end
end

WeatherAddon.UpdateWeatherIcon = UpdateWeatherIcon;

--[[
"borrows" a bit from the idea of LibDBIcon
however LibDBIcon didn't exactly do what i wanted, like make the button larger
plus it'd get caught and hidden away in those minimap button frame addons
]]
local BUTTON_RADIUS = 5;

local function AngleToPosition(button, angle)
	local rad = math.rad(angle);
	
	local radiusOffset = (WeatherAddon_DB and WeatherAddon_DB.MinimapButtonRadius) or BUTTON_RADIUS;
	
	local r = (Minimap:GetWidth() / 2) + radiusOffset;
	local x = math.cos(rad) * r;
	local y = math.sin(rad) * r;
	button:ClearAllPoints();
	button:SetPoint("CENTER", Minimap, "CENTER", x, y);
end

-- not a setting in the UI as a player probably can't comprehend the unit circle
local function RestoreMinimapPosition(button)
	local angle = (WeatherAddon_DB and WeatherAddon_DB.MinimapAngle) or 157;
	AngleToPosition(button, angle);
end

-- very specifically this has to be the MinimapBackdrop
-- tying it to Minimap or MinimapCluster causes the minimap to explode???
local minimapBtn = WeatherAddon:CreateWeatherIcon(MinimapBackdrop, 36);
minimapBtn:SetClampedToScreen(true);
minimapBtn:RegisterForDrag("LeftButton");

minimapBtn:SetScript("OnDragStart", function(self)
	self:SetScript("OnUpdate", function(self)
		local scale = Minimap:GetEffectiveScale();
		local cx, cy = Minimap:GetCenter();
		local mx, my = GetCursorPosition();
		mx, my = mx / scale, my / scale;

		local angle = math.deg(math.atan2(my - cy, mx - cx)) % 360;

		if not WeatherAddon_DB then
			WeatherAddon_DB = {};
		end
		WeatherAddon_DB.MinimapAngle = angle;

		AngleToPosition(self, angle);
	end)
end)
minimapBtn:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil);
end)

local function PushMinimapButton(self)
	local inset = 1.5;

	--self.BG:ClearAllPoints();
	--self.BG:SetPoint("TOPLEFT", inset, -inset);
	--self.BG:SetPoint("BOTTOMRIGHT", -inset, inset);

	--self.Stars:ClearAllPoints();
	--self.Stars:SetPoint("TOPLEFT", inset, -inset);
	--self.Stars:SetPoint("BOTTOMRIGHT", -inset, inset);

	self.Icon:ClearAllPoints();
	self.Icon:SetPoint("TOPLEFT", inset, -inset);
	self.Icon:SetPoint("BOTTOMRIGHT", -inset, inset);

	--local size = self:GetWidth();
	--self.Border:SetSize((size * 1.36) - (inset * 2), (size * 1.36) - (inset * 2));
end

local function ReleaseMinimapButton(self)
	--self.BG:ClearAllPoints();
	--self.BG:SetAllPoints();

	--self.Stars:ClearAllPoints();
	--self.Stars:SetAllPoints();

	self.Icon:ClearAllPoints();
	self.Icon:SetAllPoints();

	--local size = self:GetWidth();
	--self.Border:SetSize(size * 1.36, size * 1.36);
end

minimapBtn:HookScript("OnMouseDown", PushMinimapButton);
minimapBtn:HookScript("OnMouseUp", ReleaseMinimapButton);
minimapBtn:HookScript("OnLeave", ReleaseMinimapButton);


minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp");
minimapBtn:SetScript("OnClick", function(self, button)
	if button == "LeftButton" and WeatherAddon.ToggleSettings then
		WeatherAddon:ToggleSettings(1);
	elseif button == "RightButton" and WeatherAddon.ToggleSettings then
		if C_AddOns.IsAddOnLoaded("Weather_Collector") then
			WeatherAddon:ToggleSettings(2);
		else
			WeatherAddon:ToggleSettings(1);
		end
	end
end)

function WeatherAddon:UpdateMinimapButtonVisibility()
	local show = true;
	if WeatherAddon_DB and WeatherAddon_DB.ShowMinimapButton ~= nil then
		show = WeatherAddon_DB.ShowMinimapButton;
	end
	
	if show then
		minimapBtn:Show();
	else
		minimapBtn:Hide();
	end
end

function WeatherAddon:UpdateMinimapButtonLock()
	local isLocked = WeatherAddon_DB and WeatherAddon_DB.LockMinimapButton;
	if isLocked then
		-- anti-woke function that removes drag. tragic.
		minimapBtn:RegisterForDrag();
	else
		-- of course the left supports drag smh
		minimapBtn:RegisterForDrag("LeftButton");
	end
end

function WeatherAddon:UpdateMinimapButtonSize()
	local size = (WeatherAddon_DB and WeatherAddon_DB.MinimapButtonSize) or 36;
	minimapBtn:SetSize(size, size);
	minimapBtn.Border:SetSize(size*1.36, size*1.36);
end

function WeatherAddon:UpdateMinimapButtonPosition()
	RestoreMinimapPosition(minimapBtn);
end

function WeatherAddon:UpdateMinimapIconDecoration()
	local hide = WeatherAddon_DB and WeatherAddon_DB.HideMinimapDecoration;
	if hide then
		minimapBtn.BG:Hide();
		minimapBtn.Stars:Hide();
		minimapBtn.Border:Hide();
	else
		minimapBtn.BG:Show();
		minimapBtn.Stars:Show();
		minimapBtn.Border:Show();
	end
end

-- pulls from the sub module addon
local function GetCollectorStats(mapID, subzone)
	if not Weather_Collector_DB or not mapID then
		return nil, 0, nil, 0;
	end
	local zoneData = Weather_Collector_DB[mapID];
	if not zoneData then
		return nil, 0, nil, 0;
	end

	-- organize thing ideally by continent in the zone list
	local regional = {};
	local regionalTotal = 0;
	for _, subzoneData in pairs(zoneData) do
		for weatherName, duration in pairs(subzoneData) do
			regional[weatherName] = (regional[weatherName] or 0) + duration;
			regionalTotal = regionalTotal + duration;
		end
	end

	local localData = {};
	local localTotal = 0;
	local subzoneDB = subzone and zoneData[subzone];
	if subzoneDB then
		for weatherName, duration in pairs(subzoneDB) do
			localData[weatherName] = duration;
			localTotal = localTotal + duration;
		end
	end

	if regionalTotal == 0 then return nil, 0, nil, 0 end
	return regional, regionalTotal, (localTotal > 0 and localData or nil), localTotal;
end

local function FormatPct(pct)
	local rounded = math.floor(pct * 10 + 0.5) / 10;
	if rounded == math.floor(rounded) then
		return math.floor(rounded) .. "%";
	end
	return string.format("%.1f%%", rounded);
end

local function SortedWeatherEntries(data, total)
	local entries = {};
	for name, duration in pairs(data) do
		table.insert(entries, { name = name, pct = (duration / total) * 100 });
	end
	table.sort(entries, function(a, b) return a.pct > b.pct end);
	return entries;
end

function WeatherAddon:AppendWeatherTooltip(tooltip)
	local weatherInfo = LibForecast:GetCurrentWeatherInfo();
	if weatherInfo and WeatherAddon.WeatherNames then
		local weatherName = WeatherAddon.WeatherNames[weatherInfo.type] or L["Unknown"];
		local intensityStr = GetIntensityCategory(weatherInfo.intensity);
		tooltip:AddLine(string.format(L["CurrentWeatherIntensity"], weatherName, intensityStr), 1, 1, 1);
	end

	-- from Weather_Collector
	local mapID = C_Map.GetBestMapForUnit("player");
	local subzone = GetMinimapZoneText();
	if not subzone or subzone == "" then
		subzone = nil;
	end

	local regional, regionalTotal, localData, localTotal = GetCollectorStats(mapID, subzone);

	if regional and regionalTotal > 0 then
		local mapInfo = mapID and C_Map.GetMapInfo(mapID);
		local zoneName = (mapInfo and mapInfo.name) or "Unknown Zone"; -- if no map info there's probably something weird (housing) going on

		tooltip:AddLine(" ");
		tooltip:AddLine(string.format(L["RegionalWeather"], zoneName), 1, 0.82, 0);

		for _, entry in ipairs(SortedWeatherEntries(regional, regionalTotal)) do
			-- skip very small entries - most weathers (even rare) will be at least 1%
			-- this should remove weathers that get caught between zone transitions and other random entries
			if entry.pct >= 0.05 then
				tooltip:AddLine("  " .. entry.name .. " - " .. FormatPct(entry.pct), 1, 1, 1);
			end
		end
	end

	if localData and localTotal > 0 and subzone then
		tooltip:AddLine(" ");
		tooltip:AddLine(string.format(L["LocalWeather"], subzone), 1, 0.82, 0);

		for _, entry in ipairs(SortedWeatherEntries(localData, localTotal)) do
			if entry.pct >= 0.05 then
				tooltip:AddLine("  " .. entry.name .. " - " .. FormatPct(entry.pct), 1, 1, 1);
			end
		end
	end
end

minimapBtn:SetScript("OnEnter", function(self)
	if Weather_Collector and Weather_Collector.FlushCurrentDuration then
		Weather_Collector.FlushCurrentDuration();
	end
	if WeatherAddon.RefreshDataPanel then
		WeatherAddon.RefreshDataPanel();
	end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT");
	GameTooltip:SetText(L["WeatherForecast"]);
	WeatherAddon:AppendWeatherTooltip(GameTooltip);
	local isLocked = WeatherAddon_DB and WeatherAddon_DB.LockMinimapButton;
	GameTooltip:Show();
end)
minimapBtn:SetScript("OnLeave", GameTooltip_Hide);

local globalEventFrame = CreateFrame("Frame");
globalEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
globalEventFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		WeatherAddon:UpdateMinimapButtonSize();
		WeatherAddon:UpdateMinimapButtonVisibility();
		WeatherAddon:UpdateMinimapButtonLock();
		RestoreMinimapPosition(minimapBtn);
		WeatherAddon:UpdateMinimapIconDecoration();

		UpdateWeatherIcon();

		--[[
		on fresh login WoW fires the "Weather changed to..." console message
		LibForecast should usually catch these, but just in case,
		check every second until we get a known weather type (or give up
		after 10s so we never leak a ticker indefinitely)
		]]
		local retries = 0;
		local initTicker;
		initTicker = C_Timer.NewTicker(1, function()
			retries = retries + 1;
			local weatherInfo = LibForecast:GetCurrentWeatherInfo();
			if weatherInfo.type ~= LibForecast.WeatherType.Unknown or retries >= 10 then
				UpdateWeatherIcon();
				initTicker:Cancel();
			end
		end)
	end
end)

LibForecast.RegisterCallback(globalEventFrame, "OnWeatherChanged", UpdateWeatherIcon);
C_Timer.NewTicker(60, UpdateWeatherIcon);

--[[
SLASH_WEATHERTEST1 = "/weathertest"
SLASH_WEATHERTEST2 = "/wt"
SlashCmdList["WEATHERTEST"] = function(msg)
	msg = strtrim(msg or "");

	if msg == "reset" then
		testOverrideHour = nil;
		testOverrideMinute = nil;
		Print("Weather Time set back to realm time");
		UpdateWeatherIcon();
		return;
	end

	local h, m = msg:match("(%d+)%s*:?%s*(%d*)");
	if h then
		testOverrideHour = tonumber(h);
		testOverrideMinute = tonumber(m) or 0;
		if testOverrideHour > 23 then testOverrideHour = 23; end
		if testOverrideMinute > 59 then testOverrideMinute = 59; end
		Print(string.format("Weather Time set to %02d:%02d", testOverrideHour, testOverrideMinute));
		UpdateWeatherIcon();
	else
		Print("Weather Time Test Commands:");
		Print("  /wt <hour:minute> - Overrides the time of day (/wt 18:30)");
		Print("  /wt reset - returns the addon to normal server time");
	end
end
--]]
