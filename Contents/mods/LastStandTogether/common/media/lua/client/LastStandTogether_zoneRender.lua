local shopMarkerSystem = require "shop-markers.lua"
local modOptions = require "LastStandTogether_ModOptions.lua"

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


function zoneRender.drawSquare(centerX, centerY, dimensionsW, dimensionsH, color, thickness)

    local x1 = centerX - dimensionsW
    local y1 = centerY - dimensionsH
    local x2 = centerX + dimensionsW
    local y2 = centerY + dimensionsH

    local sx1, sy1 = ISCoordConversion.ToScreen(x1, y1, 0)-- Top-left
    local sx2, sy2 = ISCoordConversion.ToScreen(x2, y1, 0) -- Top-right
    local sx3, sy3 = ISCoordConversion.ToScreen(x2, y2, 0) -- Bottom-right
    local sx4, sy4 = ISCoordConversion.ToScreen(x1, y2, 0) -- Bottom-left

    zoneRender.drawEdge(sx1, sy1, sx2, sy2, thickness, color) -- Top
    zoneRender.drawEdge(sx2, sy2, sx3, sy3, thickness, color) -- Right
    zoneRender.drawEdge(sx3, sy3, sx4, sy4, thickness, color) -- Bottom
    zoneRender.drawEdge(sx4, sy4, sx1, sy1, thickness, color) -- Left
end


function zoneRender.shopMarkerScaler(x, y, z, max, zoom, scale)
    local sx1, sy1 = ISCoordConversion.ToScreen(x, y, z)
    local size = math.max((max/4), math.min(max, (max/2) * zoom * scale))
    local alpha = math.min(1, 0.5 + (zoom * 0.33))

    local x1, y1 = sx1-(size/2), sy1-(size/2)
    local x2, y2 = sx1+(size/2), sy1-(size/2)
    local x3, y3 = sx1+(size/2), sy1+(size/2)
    local x4, y4 = sx1-(size/2), sy1+(size/2)

    return x1, y1, x2, y2, x3, y3, x4, y4, alpha
end


zoneRender.pending = {dmg={},teleport={}}
function zoneRender.handleZoneEffects()

    for player,tp in pairs(zoneRender.pending.teleport) do
        LastStandTogether_Zone.teleportEntity(player, tp.x, tp.y, tp.z)
    end
    zoneRender.pending.teleport = {}

    for player,dmg in pairs(zoneRender.pending.dmg) do
        if isClient() then
            sendClientCommand(player, "LastStandTogether", "applyOutOfBoundsDamage", {dmg=dmg})
        else
            player:getBodyDamage():ReduceGeneralHealth(dmg)
        end
        player:playSound("BulletHitBody")
    end
    zoneRender.pending.dmg = {}

end


function zoneRender.drawZoneEffects()
    local player = getPlayer()
    if not player then return end

    if not lastStandTogetherWaveAlert.instance or not lastStandTogetherWaveAlert.instance:getIsVisible() then return end

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end

    local debug = (player:isNoClip() and getDebug())

    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.dimensions then return end

    local pX, pY, pZ = player:getX(), player:getY(), player:getZ()
    local dx = math.abs(zoneDef.center.x-pX)
    local dy = math.abs(zoneDef.center.y-pY)
    local zoom = getCore():getZoom(0)

    if zoneDef.shopMarkersRooms then

        local building = player:getCurrentBuilding()
        local buildingDef = building and building:getDef()
        local buildingID = buildingDef and buildingDef:getID()

        if buildingID == zoneDef.buildingID then

            local roomDef = player:getCurrentRoomDef()
            local currentRoomID = roomDef and roomDef:getID()
            for roomID,coord in pairs(zoneDef.shopMarkersRooms) do
                if currentRoomID == roomID then
                    local shops = zoneDef.shopMarkersInRoom and zoneDef.shopMarkersInRoom[roomID]
                    if shops then
                        for s=1, #shops do
                            local shop = shops[s]

                            local x1, y1, x2, y2, x3, y3, x4, y4, alpha = zoneRender.shopMarkerScaler(shop.x, shop.y, shop.z+0.33, 64, zoom, 1)

                            shopMarkerSystem.drawMarkerQuad("", x1, y1, x2, y2, x3, y3, x4, y4, alpha)

                            local markerKey = "lst_room_"..roomID.."_"..s
                            shopMarkerSystem.checkHover(markerKey, shop.shopID, shop.x, shop.y, shop.z+0.33)
                        end
                    end
                else

                    local zDiff = (coord.z > pZ and "_up") or (coord.z < pZ and "_down") or ""
                    local distX = math.abs(coord.x - pX)
                    local distY = math.abs(coord.y - pY)
                    local distance = math.sqrt(distX * distX + distY * distY)
                    local normalized = math.min(distance / 150, 1)
                    local scale = 15 * normalized
                    local x1, y1, x2, y2, x3, y3, x4, y4, alpha = zoneRender.shopMarkerScaler(coord.x, coord.y, pZ+0.5, 100, zoom*1.5, (scale/0.33))

                    shopMarkerSystem.drawMarkerQuad(zDiff, x1, y1, x2, y2, x3, y3, x4, y4, alpha)
                end
            end
        end
    end

    if ((dx) > zoneDef.dimensions.w) or ((dy) > zoneDef.dimensions.h) then

        local fadeRate = SandboxVars.LastStandTogether.OutOfBoundsFade or 0.33
        if fadeRate > 0 and (not debug) then
            local innerW = zoneDef.dimensions.w
            local innerH = zoneDef.dimensions.h

            local outerW = innerW * (1 + fadeRate)
            local outerH = innerH * (1 + fadeRate)

            local transitionRangeX = outerW - innerW
            local transitionRangeY = outerH - innerH

            local maxFadeDistSquared = transitionRangeX * transitionRangeX + transitionRangeY * transitionRangeY

            local excessX = math.max(0, math.abs(dx) - innerW)
            local excessY = math.max(0, math.abs(dy) - innerH)

            local fadeDistSq = excessX * excessX + excessY * excessY
            local fade = fadeDistSq > 0 and math.min(1, fadeDistSq / maxFadeDistSquared) or 0

            fade = fade * fade * (3 - 2 * fade)
            getRenderer():renderRect(
                    0, 0,
                    getCore():getScreenWidth() * zoom,
                    getCore():getScreenHeight() * zoom,
                    0.1, 0.1, 0.1, fade
            )
        end

        if ((dx) > zoneDef.dimensions.w*1.75) or ((dy) > zoneDef.dimensions.h*1.76) then
            local outerZoneColor = {r=0.854901961, g=0.125490196 , b=0.125490196, a=0.9}
            zoneRender.drawSquare(zoneDef.center.x, zoneDef.center.y,
                    zoneDef.dimensions.w*2, zoneDef.dimensions.h*2,
                    outerZoneColor, 10)
        end


        if (not debug) then
            if ((dx) > zoneDef.dimensions.w*2) or ((dy) > zoneDef.dimensions.h*2) then
                local clampedX, clampedY = zoneDef.center.x, zoneDef.center.y

                if not (((dx) > zoneDef.dimensions.w*2.5) or ((dy) > zoneDef.dimensions.h*2.5)) then
                    local minX = zoneDef.center.x - (zoneDef.dimensions.w*2) + 1
                    local maxX = zoneDef.center.x + (zoneDef.dimensions.w*2) - 1
                    local minY = zoneDef.center.y - (zoneDef.dimensions.h*2) + 1
                    local maxY = zoneDef.center.y + (zoneDef.dimensions.h*2) - 1
                    clampedX = math.max(minX, math.min(player:getX(), maxX))
                    clampedY = math.max(minY, math.min(player:getY(), maxY))
                end

                zoneRender.pending.teleport[player] = {x=clampedX, y=clampedY, z=pZ}
            end
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
            zoneRender.pending.dmg[player] = dmg
        end

        getRenderer():renderRect((sx1-(w/2)), sy1-(h*zoom), (fill * w), h, color.r, color.g, color.b, color.a)
    else
        LST_zone.players[player] = nil
    end

    local zoneColor = modOptions.getZoneColor()
    zoneRender.drawSquare(zoneDef.center.x, zoneDef.center.y, zoneDef.dimensions.w, zoneDef.dimensions.h, zoneColor, 3)
end


return zoneRender
