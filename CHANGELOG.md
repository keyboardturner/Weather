[Full Changelog & Previous Releases](https://github.com/keyboardturner/Weather/releases)

# 0.0.4

The weather type "Firestorm" is now fully supported. If you ever encounter this, make sure to report where you found it, as it seems particularly elusive. It will be classified differently, similar to Rain, Clear, Snow, and Sandstorm.
 - The addon now supports changing record IDs as weather types. This is mostly a back-end compatibility issue, but blizz seem to like to use these during cutscenes(?)

# 0.0.3a

Reminders now hide upon entering combat (oops)

# 0.0.3

Added option to toggle the regional and local weathers in the minimap forecast button

Added option to choose weather intensity style in the chat message as either a percentage or decimal scale

Added volume sliders to Indoor Weather Ambience, Accessories Ambience, Spells Ambience, and Falling / Skyriding Ambience
 - These were previously playing in the "UI SFX" channel while copying the ambience volume value - they should now all be in the Ambience channel by default (much like rain in game) and no longer scaling with the SFX channel
 - The base volume of these sound files are now boosted, but the default volumes are kept low. This should additionally help accomodate odd disparities between combined volume sliders without raising the base volume

Modified the collector panel:
 - Changed the expand/collapse buttons of sub-headers to be less prominent compared to the main headers
 - Added a totalled regional weather section at the top of the subzone list similar to the icon buttons

Adjusted the reminders to pause if all parasols are on cooldown

# 0.0.2a

Minimap forecast icon & almanac now ignore "unknown" weather encounters

Added "secret" Ctrl+Shift+Right Click to delete subzone data

Modified the "Clear" sun icon to be slightly more stylized to indicate it is in fact a sun and not a circular cheese wheel or dinner plate

# 0.0.2

Added options to hide Screen Effects in certain instance types

Added search filter to the Almanac to allow searching by zone, subzone, and weather type

# 0.0.1

Release version:

Added the following features:
 - Indoor Ambience
   - Includes options for Rain, Snow, and Sandstorm
 - Weather Toy Accessory Reminders
   - Includes options for rain-patter ambience sounds, tracking specififc accessories, reminders, reminder sounds+volume, "In Character" (trp3), and specific barrier spells
 - Movement Sounds
   - Includes options for toggling falling or skyriding sounds
 - Screen Effects
   - Includes options for Rain, Snow, and Sandstorm, and a slider for opacity
 - Time of Day Icon
   - Includes options for icon size and distance from minimap
 - Weather Collector Almanac