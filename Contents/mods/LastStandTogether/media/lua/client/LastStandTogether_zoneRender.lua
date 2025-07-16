local zoneRender = {}

function zoneRender.drawSquare(centerX, centerY, radius, color, thickness)
    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end

    local x1 = centerX - radius
    local y1 = centerY - radius
    local x2 = centerX + radius
    local y2 = centerY + radius

    local sx1, sy1 = ISCoordConversion.ToScreen(x1, y1, 0)-- Top-left
    local sx2, sy2 = ISCoordConversion.ToScreen(x2, y1, 0) -- Top-right
    local sx3, sy3 = ISCoordConversion.ToScreen(x2, y2, 0) -- Bottom-right
    local sx4, sy4 = ISCoordConversion.ToScreen(x1, y2, 0) -- Bottom-left

    LST_zone.drawEdge(sx1, sy1, sx2, sy2, thickness, color) -- Top
    LST_zone.drawEdge(sx2, sy2, sx3, sy3, thickness, color) -- Right
    LST_zone.drawEdge(sx3, sy3, sx4, sy4, thickness, color) -- Bottom
    LST_zone.drawEdge(sx4, sy4, sx1, sy1, thickness, color) -- Left
end


function zoneRender.playerStatus()
    local player = getPlayer()
    if not player then return end

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end

    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.radius then return end

    local pX, pY = player:getX(), player:getY()
    local dx = zoneDef.center.x-pX
    local dy = zoneDef.center.y-pY

    ---circle math, save for later maybe
    --local distance = math.sqrt(dx * dx + dy * dy)
    --if distance > zoneDef.radius then

    if (math.abs(dx) > zoneDef.radius) or (math.abs(dy) > zoneDef.radius) then

        local tick = (SandboxVars.LastStandTogether.OutOutBoundsTick or 2) * 1000

        LST_zone.players[player] = LST_zone.players[player] or getTimestampMs()+tick

        local color = {r=1, g=0.125490196 , b=0.125490196, a=1}
        local sx1, sy1 = ISCoordConversion.ToScreen(pX, pY, 0.8)-- Top-left
        local w = 64

        local diff = (LST_zone.players[player]-getTimestampMs())
        local fill = 1-math.max(0,math.min(1,diff/tick))

        getRenderer():renderRect(sx1-(w/2), sy1, w, 8, 0.2, 0.2,0.2, 1)

        if fill >= 1 then
            LST_zone.players[player] = nil
            local dmg = SandboxVars.LastStandTogether.OutOfBoundsDamage or 5
            player:getBodyDamage():ReduceGeneralHealth(dmg)
            player:playSound("BulletHitBody")
        end

        getRenderer():renderRect(sx1-(w/2), sy1, fill * w, 8, color.r, color.g, color.b, color.a)
        --zoneRender.drawSquare(pX, pY, 0.3, color, 2)
    else
        LST_zone.players[player] = nil
    end
end


function zoneRender.draw()
    if not getPlayer() then return end

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end

    ---@type BuildingDef
    local zoneDef = LST_zone.def
    if not zoneDef then return end

    ---@type BuildingDef
    local bDef = zoneDef.buildingDef
    if not bDef then return end

    local color = {r=0.854901961, g=0.64705882352 , b=0.125490196, a=0.5}
    zoneRender.drawSquare(zoneDef.center.x, zoneDef.center.y, zoneDef.radius, color, 3)

    color = {r=0.854901961, g=0.125490196 , b=0.125490196, a=0.5}
    zoneRender.drawSquare(zoneDef.center.x, zoneDef.center.y, zoneDef.radius*2, color, 1)
end

return zoneRender