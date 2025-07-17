local waveGen = require "LastStandTogether_waveGenerator.lua"

local zone = {}

zone.def = {}
zone.def.center = false
zone.def.building = false
zone.def.buildingDef = false
zone.def.center = false
zone.def.radius = false
zone.def.error = false

zone.def.wave = false
zone.def.nextWaveTime = false
zone.def.popMulti = false

zone.players = {}
zone.schedulingProcess = false
zone.initiateLoop = false


function zone.onDead(zombie)
    local attacker = zombie:getAttackedBy()
    if attacker then
        local value = SandboxVars.LastStandTogether.MoneyPerKill
        local walletID = getOrSetWalletID(attacker)
        if not walletID then
            local moneyTypes = _internal.getMoneyTypes()
            local type = moneyTypes[ZombRand(#moneyTypes)+1]
            local money = InventoryItemFactory.CreateItem(type)
            if money then
                generateMoneyValue(money, value, true)
                attacker:getInventory():AddItem(money)
            end
            return
        end
        sendClientCommand("shop", "transferFunds", {playerWalletID=walletID, amount=value})
    end
end


function zone.scheduleWave()
    if zone.schedulingProcess then return end
    zone.schedulingProcess = true

    if not zone.def.popMulti then
        zone.def.popMulti = 1
    else
        zone.def.popMulti = zone.def.popMulti * (SandboxVars.LastStandTogether.WavePopMultiplier or 1.5)
    end

    if not zone.def.wave then
        zone.def.wave = 0
        local cooldown = 60000 * (SandboxVars.LastStandTogether.SetUpGracePeriod or 10)
        zone.def.nextWaveTime = getTimestampMs() + cooldown
    else
        zone.def.wave = zone.def.wave + 1
        local numberOf = zone.def.popMulti * (SandboxVars.LastStandTogether.NumberOfZombiesPerWave or 10)
        waveGen.spawnZombies(numberOf)
        zone.def.nextWaveTime = nil
    end

    zone.schedulingProcess = false
    zone.sendZoneDef()
end


function zone.schedulerLoop()
    if not zone.initiateLoop or not zone.def then return end

    local zombiesLeft = getWorld():getCell():getZombieList():size()

    if not zone.def.wave and (not zone.def.nextWaveTime or getTimestampMs() > zone.def.nextWaveTime) then
        zone.scheduleWave()
        return
    end

    if zone.def.wave and not zone.def.nextWaveTime and zombiesLeft <= 0 then
        local cooldown = 60000 * (SandboxVars.LastStandTogether.CoolDownBetweenWave or 5)
        zone.def.nextWaveTime = getTimestampMs() + cooldown
        zone.sendZoneDef()
        return
    end

    if zone.def.wave and zone.def.nextWaveTime and getTimestampMs() > zone.def.nextWaveTime and zombiesLeft <= 0 then
        zone.scheduleWave()
        return
    end
end


function zone.sendZoneDef()
    if isServer() then
        sendServerCommand("LastStandTogether", "updateZone", zone.def)
    else
        if not lastStandTogetherWaveAlert.instance then
            lastStandTogetherWaveAlert:setToScreen()
        end
    end
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
    if building and zone.def.building and zone.def.building == building then
        return
    end

    if not building then
        zone.def.error = "NO BUILDING FOUND!"
        return
    end

    local buildingDef = building and building:getDef()
    if not buildingDef then
        zone.def.error = "NO BUILDING DEFINITION FOUND!"
        return
    end

    zone.def.building = building
    zone.def.buildingDef = buildingDef

    local buildingDefW = buildingDef:getW()
    local buildingDefH = buildingDef:getH()

    local centerX = (buildingDef:getX()+(buildingDefW/2))
    local centerY = (buildingDef:getY()+(buildingDefH/2))

    local boundsRadius = math.max(1, math.max(buildingDefW,buildingDefH) + (SandboxVars.LastStandTogether.BufferSize or 4))

    zone.def.radius = boundsRadius
    zone.def.center = {x=centerX, y=centerY}

    zone.initiateLoop = true

    zone.sendZoneDef()
end


return zone