local zoneRender = require "LastStandTogether_zoneRender.lua"
Events.OnPostFloorLayerDraw.Add(zoneRender.drawZoneEffects)

local onZombie = require "LastStandTogether_onZombie.lua"
Events.OnZombieUpdate.Add(onZombie.update)