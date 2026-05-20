local addonName, WeatherCollector = ...

local L = {};
WeatherCollector.L = L;

local function defaultFunc(L, key)
 -- If this function was called, we have no localization for this key.
 -- We could complain loudly to allow localizers to see the error of their ways, 
 -- but, for now, just return the key as its own localization. This allows you to—avoid writing the default localization out explicitly.
 return key;
end
setmetatable(L, {__index=defaultFunc});

local LOCALE = GetLocale()

if LOCALE == "enUS" then
	-- The EU English game client also
	-- uses the US English locale code.
	L["Clear"] = "Clear"
	L["Rain"] = "Rain"
	L["Snow"] = "Snow"
	L["Sandstorm"] = "Sandstorm"
	L["Firestorm"] = "Firestorm"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN
	

return end

if LOCALE == "esMX" then
	-- Spanish (Mexico) translations go here
	L["Clear"] = "Despejado"
	L["Rain"] = "Lluvia"
	L["Snow"] = "Nieve"
	L["Sandstorm"] = "Tormenta de arena"
	L["Firestorm"] = "Tormenta de fuego"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

return end

if LOCALE == "esES" then
	-- Spanish translations go here
	L["Clear"] = "Despejado"
	L["Rain"] = "Lluvia"
	L["Snow"] = "Nieve"
	L["Sandstorm"] = "Tormenta de arena"
	L["Firestorm"] = "Tormenta de fuego"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

return end

if LOCALE == "deDE" then
	-- German translations go here
	L["Clear"] = "Klar"
	L["Rain"] = "Regen"
	L["Snow"] = "Schnee"
	L["Sandstorm"] = "Sandsturm"
	L["Firestorm"] = "Feuersturm"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

return end

if LOCALE == "frFR" then
	-- French translations go here
	L["Clear"] = "Dégagé"
	L["Rain"] = "Pluie"
	L["Snow"] = "Neige"
	L["Sandstorm"] = "Tempête de sable"
	L["Firestorm"] = "Tempête de feu"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

return end

if LOCALE == "itIT" then
	-- Italian translations go here
	L["Clear"] = "Sereno"
	L["Rain"] = "Pioggia"
	L["Snow"] = "Neve"
	L["Sandstorm"] = "Tempesta di sabbia"
	L["Firestorm"] = "Tempesta di fuoco"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

return end

if LOCALE == "ptBR" then
	-- Brazilian Portuguese translations go here
	L["Clear"] = "Céu limpo"
	L["Rain"] = "Chuva"
	L["Snow"] = "Neve"
	L["Sandstorm"] = "Tempestade de areia"
	L["Firestorm"] = "Tempestade de fogo"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

-- Note that the EU Portuguese WoW client also
-- uses the Brazilian Portuguese locale code.
return end

if LOCALE == "ruRU" then
	-- Russian translations go here
	L["Clear"] = "Ясно"
	L["Rain"] = "Дождь"
	L["Snow"] = "Снег"
	L["Sandstorm"] = "Песчаная буря"
	L["Firestorm"] = "Огненная буря"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

return end

if LOCALE == "koKR" then
	-- Korean translations go here
	L["Clear"] = "맑음"
	L["Rain"] = "비"
	L["Snow"] = "눈"
	L["Sandstorm"] = "모래폭풍"
	L["Firestorm"] = "화염폭풍"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

return end

if LOCALE == "zhCN" then
	-- Simplified Chinese translations go here
	L["Clear"] = "晴朗"
	L["Rain"] = "下雨"
	L["Snow"] = "下雪"
	L["Sandstorm"] = "沙尘暴"
	L["Firestorm"] = "火焰风暴"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

return end

if LOCALE == "zhTW" then
	-- Traditional Chinese translations go here
	L["Clear"] = "晴朗"
	L["Rain"] = "下雨"
	L["Snow"] = "下雪"
	L["Sandstorm"] = "沙塵暴"
	L["Firestorm"] = "火焰風暴"
	L["Miscellaneous"] = BINDING_HEADER_MISC
	L["Unknown"] = UNKNOWN

return end
