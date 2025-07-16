LastStandTogether_Zone = require "LastStandTogether_zoneHandler.lua"
--- def = {}
--def.center = false
--def.building = false
--def.buildingDef = false
--def.center = false
--def.radius = false


--- DEBUG TEST
--[[
if not LastStandTogether_Zone then print("ERROR NO LastStandTogether_Zone") else print("LastStandTogether_Zone FOUND") end
LastStandTogether_Zone.setToCurrentBuilding(getPlayer())
if LastStandTogether_Zone.error then
    print("ERROR:", LastStandTogether_Zone.error)
    getPlayer():Say(LastStandTogether_Zone.error or "")
end
--]]
