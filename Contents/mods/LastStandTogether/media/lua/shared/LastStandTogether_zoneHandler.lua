local zone = {}

zone.def = {}
zone.def.center = false
zone.def.building = false
zone.def.buildingDef = false
zone.def.center = false
zone.def.radius = false

zone.buffer = 6
zone.error = false

function zone.returnDef()
    return zone.def
end

---@param player IsoObject|IsoMovingObject|IsoGameCharacter|IsoPlayer
function zone.setToCurrentBuilding(player)
    local building = player:getCurrentBuilding()
    if not building then
        zone.error = "NO BUILDING FOUND!"
        return
    end

    local buildingDef = building and building:getDef()
    if not buildingDef then
        zone.error = "NO BUILDING DEFINITION FOUND!"
        return
    end

    zone.def.building = building
    zone.def.buildingDef = buildingDef

    local buildingDefW = buildingDef:getW()
    local buildingDefH = buildingDef:getH()

    local centerX = buildingDef:getX()+(buildingDefW/2)
    local centerY = buildingDef:getY()+(buildingDefH/2)

    local boundsRadius = math.max(buildingDefW,buildingDefH)+zone.buffer

    zone.def.radius = boundsRadius
    zone.def.center = {x=centerX, y=centerY}
end


return zone