local zoneRender = {}

function zoneRender.draw(player)

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end

    ---@type BuildingDef
    local zoneDef = LST_zone.def
    --def.center = false
    --def.building = false
    --def.buildingDef = false
    --def.center = false
    --def.radius = false

    ---@type BuildingDef
    local bDef = zoneDef.buildingDef

    local x1 = bDef:getX()
    local y1 = bDef:getY()

    local x2 = bDef:getX2()
    local y2 = bDef:getY2()

    local color = {r=0.854901961, g=0.64705882352 , b=0.125490196, a=0.75}

    getRenderer():renderline(nil, x1, y1, x1, y2, color.r, color.g, color.b, color.a, 6)

    getRenderer():renderline(nil, x1, y1, x2, y1, color.r, color.g, color.b, color.a, 6)

    getRenderer():renderline(nil, x1, y2, x2, y2, color.r, color.g, color.b, color.a, 6)

    getRenderer():renderline(nil, x2, y1, x2, y2, color.r, color.g, color.b, color.a, 6)
end

return zoneRender