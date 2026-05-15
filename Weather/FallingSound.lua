local AddonName, WeatherAddon = ...;
local L = WeatherAddon.L;
local LibForecast = LibStub("LibForecast-1.0");
local Print = WeatherAddon.Print;

local SOUND_CHANNEL = "Ambience";
local FALL_DELAY_SECONDS = 1.5;
local TICK_RATE = 0.1;
local SOUND_FALLOFF = 50;

local FallingSounds = {
	{ file = "Interface\\AddOns\\Weather\\Sounds\\falling_000_faded_60percent.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\falling_001_faded_60percent.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\falling_002_faded_60percent.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\falling_003_faded_60percent.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\falling_004_faded_60percent.ogg", duration = 10 },
	{ file = "Interface\\AddOns\\Weather\\Sounds\\falling_005_faded_60percent.ogg", duration = 10 },
};

local fallTicker = nil;
local isFalling = false;
local fallStartTime = 0;
local activeSoundHandle = nil;
local playbackTimer = nil;
local landingTicker = nil;

-- checks against the autogenned data_slowfallspells
local function HasSlowFallBuff()
	if not WeatherAddon.SlowFallEffectTable then return false; end
	
	for _, spellID in ipairs(WeatherAddon.SlowFallEffectTable) do
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID);
		if aura then
			return true;
		end
	end
	return false;
end

local function StopFallingSound()
	if playbackTimer then
		playbackTimer:Cancel();
		playbackTimer = nil;
	end

	if landingTicker then
		landingTicker:Cancel();
		landingTicker = nil;
	end

	if activeSoundHandle then
		StopSound(activeSoundHandle, SOUND_FALLOFF);
		activeSoundHandle = nil;
	end
end

local function StartNextFallingSound()
	if not isFalling or #FallingSounds == 0 then return; end
	
	local randomIndex = math.random(1, #FallingSounds);
	local soundData = FallingSounds[randomIndex];
	
	local willPlay, handle = PlaySoundFile(soundData.file, SOUND_CHANNEL);
	if willPlay then
		activeSoundHandle = handle;
	end

	--queue to account for next sound to crossfade
	playbackTimer = C_Timer.NewTimer(soundData.duration - 2.5, StartNextFallingSound);
end

local function CheckFallingState()
	local currentlyFalling = IsFalling();

	-- sometimes falling is still true when it shouldn't be
	if currentlyFalling then
		local isGliding = false;
		if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
			isGliding = C_PlayerInfo.GetGlidingInfo();
		end

		local isBusyOrInvalid = UnitIsDeadOrGhost("player") or isGliding or UnitInVehicle("player") or UnitHasVehicleUI("player") or HasSlowFallBuff();
		
		if isBusyOrInvalid then
			currentlyFalling = false;
		end
	end

	if currentlyFalling then
		if not isFalling then
			isFalling = true;
			fallStartTime = GetTime();
		else
			if not activeSoundHandle and (GetTime() - fallStartTime >= FALL_DELAY_SECONDS) then
				StartNextFallingSound();
			end
		end
	else
		if isFalling then
			isFalling = false;
			fallStartTime = 0;
			StopFallingSound();
		end
	end
end

local f = CreateFrame("Frame");
f:RegisterEvent("PLAYER_ENTERING_WORLD");

function WeatherAddon:UpdateFallingSoundState()
	local isEnabled = WeatherAddon_DB and WeatherAddon_DB.EnableFallingSound;
	if isEnabled == nil then isEnabled = true; end

	if isEnabled then
		if not fallTicker then
			fallTicker = C_Timer.NewTicker(TICK_RATE, CheckFallingState);
		end
		
		f:RegisterEvent("CRITERIA_UPDATE");
		f:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED");
		f:RegisterEvent("SPELL_UPDATE_USABLE");
		f:RegisterUnitEvent("UNIT_AURA", "player");
	else
		if fallTicker then
			fallTicker:Cancel();
			fallTicker = nil;
		end
		if landingTicker then
			landingTicker:Cancel();
			landingTicker = nil;
		end
		
		isFalling = false;
		fallStartTime = 0;
		StopFallingSound();
		
		f:UnregisterEvent("CRITERIA_UPDATE");
		f:UnregisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED");
		f:UnregisterEvent("SPELL_UPDATE_USABLE");
		f:UnregisterEvent("UNIT_AURA");
	end
end

f:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		WeatherAddon:UpdateFallingSoundState();
		self:UnregisterEvent("PLAYER_ENTERING_WORLD");
	elseif event == "UNIT_AURA" then
		if isFalling and HasSlowFallBuff() then
			isFalling = false;
			fallStartTime = 0;
			StopFallingSound();
		end
	else
		if isFalling then
			if landingTicker then
				landingTicker:Cancel();
			end
			
			-- need to review later, can rapidly jump to avoid stopping
			landingTicker = C_Timer.NewTicker(0.5, function()
				if not IsFalling() then
					isFalling = false;
					fallStartTime = 0;
					StopFallingSound();
				end
			end, 6)
		end
	end
end)
