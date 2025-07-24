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
    if math.abs(dx) > zoneDef.radius or math.abs(dy) > zoneDef.radius then
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

    if (math.abs(dx) > zoneDef.radius) or (math.abs(dy) > zoneDef.radius) then

        local player = getPlayer()
        if zombie:getTarget() ~= player then
            zombie:spotted(player, true)
        end

        local phaseCheck = onZombie.onUpdateLocationSafety[zombie]

        onZombie.onUpdateLocationSafety[zombie] = (phaseCheck and phaseCheck.loc==zombie:getSquare() and phaseCheck)
                or {time=getTimestampMs()+5000, loc=zombie:getSquare()}
        --- if phase check value exists and the square is the same return back OR create new

        if phaseCheck and phaseCheck.time < getTimestampMs() then
            onZombie.onUpdateLocationSafety[zombie] = nil
            onZombie.phaseTo(zombie, dx, dy)
        end
    else
        onZombie.onUpdateLocationSafety[zombie] = nil
    end

    if getDebug() or getPlayer():isNoClip() then zombie:addLineChatElement("!", 1, 1, 1, UIFont.Small, 1000, "default") end
end


return onZombie