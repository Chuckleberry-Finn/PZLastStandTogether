local zoneRender = require "LastStandTogether_zoneRender.lua"
Events.OnPostRender.Add(zoneRender.drawZoneEffects)
Events.OnTick.Add(zoneRender.handleZoneEffects)

local onZombie = require "LastStandTogether_onZombie.lua"
Events.OnZombieUpdate.Add(onZombie.update)
Events.OnObjectCollide.Add(onZombie.collide)

require "shop-clientEvents.lua"
local shopMarkerSystem = require "shop-markers.lua"
Events.OnPostRender.Remove(shopMarkerSystem.render)