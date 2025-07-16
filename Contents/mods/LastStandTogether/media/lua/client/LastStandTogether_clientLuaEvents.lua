local zoneRender = require "LastStandTogether_zoneRender.lua"
Events.OnPostFloorLayerDraw.Add(zoneRender.draw)
Events.OnPostFloorLayerDraw.Add(zoneRender.playerStatus)

LastStandTogether_Zone = LastStandTogether_Zone or require "LastStandTogether_zoneHandler.lua"
Events.OnZombieDead.Add(LastStandTogether_Zone.onDead)