local zoneRender = {}

function zoneRender.drawEdge(x1, y1, x2, y2, width, color)
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


function zoneRender.drawSquare(centerX, centerY, radius, color, thickness)

    local x1 = centerX - radius
    local y1 = centerY - radius
    local x2 = centerX + radius
    local y2 = centerY + radius

    local sx1, sy1 = ISCoordConversion.ToScreen(x1, y1, 0)-- Top-left
    local sx2, sy2 = ISCoordConversion.ToScreen(x2, y1, 0) -- Top-right
    local sx3, sy3 = ISCoordConversion.ToScreen(x2, y2, 0) -- Bottom-right
    local sx4, sy4 = ISCoordConversion.ToScreen(x1, y2, 0) -- Bottom-left

    zoneRender.drawEdge(sx1, sy1, sx2, sy2, thickness, color) -- Top
    zoneRender.drawEdge(sx2, sy2, sx3, sy3, thickness, color) -- Right
    zoneRender.drawEdge(sx3, sy3, sx4, sy4, thickness, color) -- Bottom
    zoneRender.drawEdge(sx4, sy4, sx1, sy1, thickness, color) -- Left
end


function zoneRender.drawZoneEffects()
    local player = getPlayer()
    if not player then return end

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end

    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.radius then return end

    local pX, pY = player:getX(), player:getY()
    local dx = math.abs(zoneDef.center.x-pX)
    local dy = math.abs(zoneDef.center.y-pY)

    if ((dx) > zoneDef.radius) or ((dy) > zoneDef.radius) then

        local zoom = getCore():getZoom(0)

        local fadeRate = SandboxVars.LastStandTogether.OutOfBoundsFade or 0.33
        if fadeRate < 1 then
            local inner = zoneDef.radius
            local outer = inner * (1 + fadeRate)
            local transitionRange = outer - inner
            local maxFadeDistSquared = transitionRange * transitionRange * 2
            local excessX = dx > inner and (dx - inner) or 0
            local excessY = dy > inner and (dy - inner) or 0
            local fadeDistSq = excessX * excessX + excessY * excessY
            local fade = fadeDistSq > 0 and math.min(1, fadeDistSq / maxFadeDistSquared) or 0
            fade = fade * fade * (3 - 2 * fade)
            getRenderer():renderRect(0, 0, getCore():getScreenWidth()*zoom, getCore():getScreenHeight()*zoom, 0.1, 0.1, 0.1, fade)
        end

        if ((dx) > zoneDef.radius*1.75) or ((dy) > zoneDef.radius*1.76) then
            local outerZoneColor = {r=0.854901961, g=0.125490196 , b=0.125490196, a=0.9}
            zoneRender.drawSquare(zoneDef.center.x, zoneDef.center.y, zoneDef.radius*2, outerZoneColor, 5)
        end

        if ((dx) > zoneDef.radius*2) or ((dy) > zoneDef.radius*2) then
            local minX = zoneDef.center.x - (zoneDef.radius*2)
            local maxX = zoneDef.center.x + (zoneDef.radius*2)
            local minY = zoneDef.center.y - (zoneDef.radius*2)
            local maxY = zoneDef.center.y + (zoneDef.radius*2)

            local clampedX = math.max(minX, math.min(player:getX(), maxX))
            local clampedY = math.max(minY, math.min(player:getY(), maxY))

            if ((dx) > zoneDef.radius*2.5) or ((dy) > zoneDef.radius*2.5) then clampedX, clampedY = zoneDef.center.x, zoneDef.center.y end

            player:setX(clampedX)
            player:setY(clampedY)
            player:setLx(clampedX)
            player:setLy(clampedY)
            player:setZ(0)
        end

        local tick = (SandboxVars.LastStandTogether.OutOutBoundsTick or 2) * 1000

        LST_zone.players[player] = LST_zone.players[player] or getTimestampMs()+tick

        local color = {r=1, g=0.125490196 , b=0.125490196, a=1}
        local sx1, sy1 = ISCoordConversion.ToScreen(pX, pY, 0.9)
        local w = 64*zoom
        local h = 8*zoom
        local diff = (LST_zone.players[player]-getTimestampMs())
        local fill = 1-math.max(0,math.min(1,diff/tick))

        getRenderer():renderRect((sx1-(w/2)), sy1-(h*zoom), w, h, 0.2, 0.2,0.2, 1)

        if fill >= 1 then
            LST_zone.players[player] = nil
            local dmg = SandboxVars.LastStandTogether.OutOfBoundsDamage or 5
            player:getBodyDamage():ReduceGeneralHealth(dmg)
            player:playSound("BulletHitBody")
        end

        getRenderer():renderRect((sx1-(w/2)), sy1-(h*zoom), (fill * w), h, color.r, color.g, color.b, color.a)
    else
        LST_zone.players[player] = nil
    end

    local zoneColor = {r=0.854901961, g=0.64705882352 , b=0.125490196, a=0.5}
    zoneRender.drawSquare(zoneDef.center.x, zoneDef.center.y, zoneDef.radius, zoneColor, 3)
end


return zoneRender