local zoneRender = require "LastStandTogether_zoneRender.lua"
Events.OnPostFloorLayerDraw.Add(zoneRender.drawZoneEffects)

local zombieUpdate = require "LastStandTogether_zombieUpdate.lua"
Events.OnZombieUpdate.Add(zombieUpdate.retarget)