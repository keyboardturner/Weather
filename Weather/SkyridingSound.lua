local AddonName, WeatherAddon = ...;
local L = WeatherAddon.L;
local LibForecast = LibStub("LibForecast-1.0");
local Print = WeatherAddon.Print;

local SOUND_CHANNEL = "Ambience";
local TICK_RATE = 0.1;
local SOUND_FALLOFF = 1000;
local CROSSFADE_OFFSET = 2.5;

local SkyridingSounds = {
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_000_faded.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_001_faded.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_002_faded.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_003_faded.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_004_faded.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_005_faded.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_006_faded.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_007_faded.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_008_faded.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\skyriding_lvl2_009_faded.ogg", duration = 10 },
};

local MAX_LAYERS = 6;
local SoundLayers = {};
for i = 1, MAX_LAYERS do
	SoundLayers[i] = {
		active = false,
		handles = {},
		playbackTimer = nil
	};
end

local skyridingTicker = nil;

local function PlayLayerLoop(layerIndex)
	local layer = SoundLayers[layerIndex];
	if not layer.active or #SkyridingSounds == 0 then return; end
	
	local randomIndex = math.random(1, #SkyridingSounds);
	local soundData = SkyridingSounds[randomIndex];
	
	local willPlay, handle = PlaySoundFile(soundData.file, SOUND_CHANNEL);
	if willPlay and handle then
		layer.handles[handle] = true;
		
		-- clean up the handle from the tracking table once its duration finishes naturally
		C_Timer.After(soundData.duration, function()
			if layer.handles then
				layer.handles[handle] = nil;
			end
		end)
	end

	-- queue up the next sound in this layer with an overlap for crossfading
	local nextPlayDelay = math.max(0.1, soundData.duration - CROSSFADE_OFFSET)
	layer.playbackTimer = C_Timer.NewTimer(nextPlayDelay, function()
		PlayLayerLoop(layerIndex);
	end)
end

local function StartLayer(layerIndex)
	local layer = SoundLayers[layerIndex];
	if layer.active then return; end
	
	layer.active = true;
	PlayLayerLoop(layerIndex);
end

local function StopLayer(layerIndex)
	local layer = SoundLayers[layerIndex];
	if not layer.active then return; end
	
	layer.active = false;
	
	if layer.playbackTimer then
		layer.playbackTimer:Cancel();
		layer.playbackTimer = nil;
	end
	
	for handle, _ in pairs(layer.handles) do
		StopSound(handle, SOUND_FALLOFF);
	end
	wipe(layer.handles);
end

local function CheckSkyridingState()
	local isGliding, canGlide, forwardSpeed = false, false, 0;
	
	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo();
	end

	if isGliding then
		-- calculate how many tracks should be playing based on speed
		-- every 15 yds/s is 1 track layered on
		local targetTracks = math.min(MAX_LAYERS, math.max(1, math.floor(forwardSpeed / 15)));
		
		for i = 1, MAX_LAYERS do
			if i <= targetTracks then
				StartLayer(i);
			else
				StopLayer(i);
			end
		end
	else
		for i = 1, MAX_LAYERS do
			StopLayer(i);
		end
	end
end

function WeatherAddon:UpdateSkyridingSoundState()
	local isEnabled = WeatherAddon_DB and WeatherAddon_DB.EnableSkyridingSound
	if isEnabled == nil then
		isEnabled = true;
	end

	if isEnabled then
		if not skyridingTicker then
			skyridingTicker = C_Timer.NewTicker(TICK_RATE, CheckSkyridingState);
		end
	else
		if skyridingTicker then
			skyridingTicker:Cancel();
			skyridingTicker = nil;
		end
		
		for i = 1, MAX_LAYERS do
			StopLayer(i);
		end
	end
end

local f = CreateFrame("Frame");
f:RegisterEvent("PLAYER_ENTERING_WORLD");

f:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		WeatherAddon:UpdateSkyridingSoundState();
		self:UnregisterEvent("PLAYER_ENTERING_WORLD");
	end
end)