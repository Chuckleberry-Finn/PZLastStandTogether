local onZombie = {}

---@param zombie IsoZombie|IsoGameCharacter|IsoMovingObject|IsoObject
function onZombie.collide(zombie, obj)

    if not instanceof(zombie,"IsoZombie") then return end

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end
    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.radius then return end

    local zX, zY = zombie:getX(), zombie:getY()

    local zoneX, zoneY = zoneDef.center.x, zoneDef.center.y

    local dx = zoneX - zX
    local dy = zoneY - zY
    if math.abs(dx) > zoneDef.radius*1.5 or math.abs(dy) > zoneDef.radius*1.5 then
        local target = zombie:getTarget()
        local phaseX = (target and target:getX()-zX) or dx
        local phaseY = (target and target:getY()-zY) or dy
        onZombie.phaseTo(zombie, phaseX, phaseY)
    end
end


function onZombie.phaseTo(zombie, x, y)
    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end
    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.radius then return end

    local zX, zY = zombie:getX(), zombie:getY()

    local stepX = x ~= 0 and (x > 0 and 1 or -1) or 0
    local stepY = y ~= 0 and (y > 0 and 1 or -1) or 0
    if stepX==0 and stepY==0 then return end

    local newX = zX + stepX*0.67
    local newY = zY + stepY*0.67
    zombie:setX(newX)
    zombie:setY(newY)
    zombie:setLx(newX)
    zombie:setLy(newY)
end


onZombie.onUpdateLocationSafety = {}

---@param zombie IsoZombie
function onZombie.update(zombie)

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end
    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.radius then return end

    local zX, zY = math.floor(zombie:getX()), math.floor(zombie:getY())
    local dx = (zoneDef.center.x-zX)
    local dy = (zoneDef.center.y-zY)

    if (math.abs(dx) > zoneDef.radius*1.5) or (math.abs(dy) > zoneDef.radius*1.5) then
        if zombie:getThumpTarget() then zombie:setThumpTarget(nil) end
        onZombie.onUpdateLocationSafety[zX.."_"..zY] = (onZombie.onUpdateLocationSafety[zX.."_"..zY] or 0) + 1
        if onZombie.onUpdateLocationSafety[zX.."_"..zY] > 3000 then
            onZombie.onUpdateLocationSafety[zX.."_"..zY] = nil
            onZombie.phaseTo(zombie, dx, dy)
        end
        if getDebug() then zombie:addLineChatElement("!", 1, 1, 1, UIFont.Small, 1000, "default") end

        local player = getPlayer()
        if zombie:getTarget() ~= player then zombie:spotted(player, true) end
    end
end


return onZombie