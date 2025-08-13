local zoneRender = require "LastStandTogether_zoneRender.lua"
Events.OnPostFloorLayerDraw.Add(zoneRender.drawZoneEffects)

local onZombie = require "LastStandTogether_onZombie.lua"
Events.OnZombieUpdate.Add(onZombie.update)
Events.OnObjectCollide.Add(onZombie.collide)

require "shop-clientEvents.lua"
local shopMarkerSystem = require "shop-markers.lua"
Events.OnPostFloorLayerDraw.Remove(shopMarkerSystem.render)