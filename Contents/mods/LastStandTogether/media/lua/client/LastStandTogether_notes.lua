--- def = {}
--def.center = false
--def.building = false
--def.buildingDef = false
--def.center = false
--def.radius = false

--[[
Able to set:
number of waves
cooldown between waves
Zombies per wave
Zombie increase per wave

How long the waves are ?
A popup WAVE 3.... WAVE 4...

--]]

--- DEBUG TEST
--[[
if not LastStandTogether_Zone then print("ERROR NO LastStandTogether_Zone") else print("LastStandTogether_Zone FOUND") end
LastStandTogether_Zone.setToCurrentBuilding(getPlayer())
if LastStandTogether_Zone.error then
    print("ERROR:", LastStandTogether_Zone.error)
    getPlayer():Say(LastStandTogether_Zone.error or "")
end
--]]

--[[
local waveGen = require "LastStandTogether_waveGenerator.lua"
waveGen.spawnZombies(10)
--]]