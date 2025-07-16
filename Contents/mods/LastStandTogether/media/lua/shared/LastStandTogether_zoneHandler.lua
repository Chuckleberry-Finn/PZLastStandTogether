local zone = {}

zone.def = {}
zone.def.center = false
zone.def.building = false
zone.def.buildingDef = false
zone.def.center = false
zone.def.radius = false

zone.error = false
zone.players = {}

function zone.returnDef()
    return zone.def
end


function zone.drawEdge(x1, y1, x2, y2, width, color)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then return end
    local px, py = -dy / len, dx / len
    local ox, oy = px * (width / 2), py * (width / 2)

    local x1a, y1a = x1 + ox, y1 + oy
    local x1b, y1b = x1 - ox, y1 - oy
    local x2a, y2a = x2 + ox, y2 + oy
    local x2b, y2b = x2 - ox, y2 - oy

    getRenderer():renderPoly(x1a, y1a, x2a, y2a, x2b, y2b, x1b, y1b, color.r, color.g, color.b, color.a)
end


---@param player IsoObject|IsoMovingObject|IsoGameCharacter|IsoPlayer
function zone.setToCurrentBuilding(player)

    zone.def = {}

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

    local centerX = (buildingDef:getX()+(buildingDefW/2))
    local centerY = (buildingDef:getY()+(buildingDefH/2))

    local boundsRadius = math.max(buildingDefW,buildingDefH) + (SandboxVars.LastStandTogether.BufferSize or 6)

    zone.def.radius = boundsRadius
    zone.def.center = {x=centerX, y=centerY}
end


return zone