local zoneRender = require "LastStandTogether_zoneRender.lua"
Events.OnPostFloorLayerDraw.Add(zoneRender.drawZoneEffects)