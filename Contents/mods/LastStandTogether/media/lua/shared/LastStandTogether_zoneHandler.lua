local waveGen = require "LastStandTogether_waveGenerator.lua"

local zone = {}

zone.def = {}
zone.def.center = false
zone.def.center = false
zone.def.radius = false
zone.def.error = false
zone.def.waveCooldown = false
zone.def.wave = false
zone.def.nextWaveTime = false
zone.def.popMulti = false
zone.def.zombies = 0

zone.def.shopMarkers = {}

zone.building = false

zone.players = {}
zone.schedulingProcess = false
zone.initiateLoop = false

function zone.setSandboxForLastStand()
    local options = getSandboxOptions()
    local optionsToValues = {
        ["ZombieConfig.PopulationMultiplier"] = 0.0001,
        ["ZombieConfig.PopulationStartMultiplier"] = 0.0,
        ["ZombieConfig.PopulationPeakMultiplier"] = 0.0,
        ["ZombieConfig.RespawnHours"] = 0.0,
        ["ZombieConfig.RespawnUnseenHours"] = 0.0,
        ["ZombieConfig.RespawnMultiplier"] = 0.0,
        ["ZombieConfig.RedistributeHours"] = 0.0,
    }
    for o,value in pairs(optionsToValues) do
        local option = options:getOptionByName(o)
        if option then option:setValue(value) end
    end
    if isClient then options:sendToServer() end
    options:toLua()
end


function zone.onZombieDead(zombie)
    --- To future Chuck, I'm sorry
    --This is not client so it works in SP and Server only
    if not isClient() then zone.def.zombies = (zone.def.zombies or 0) - 1 end
    --updates the players if server
    if isServer() then sendServerCommand("LastStandTogether", "updateZoneDefZombies", { zombies=zone.def.zombies }) end
    --sends money handling for clients
    if not isServer() then
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
        numberOf = math.floor(numberOf)
        local spawnedZ = waveGen.spawnZombies(numberOf)
        zone.def.zombies = spawnedZ
        zone.def.nextWaveTime = nil
    end

    zone.schedulingProcess = false
    zone.sendZoneDef()
end


function zone.schedulerLoop()
    if not zone.initiateLoop or not zone.def or not zone.def.center then return end

    local zombiesLeft = zone.def.zombies or 0--getWorld():getCell():getZombieList():size()

    local sanityCheck = getWorld():getCell():getZombieList():size()
    if zone.def.wave and zombiesLeft > 0 and sanityCheck <= 0 then
        local spawnedZ = waveGen.spawnZombies(1)
        print("WARNING: HAD TO SPAWN EXTRA ZOMBIE", (spawnedZ <=0) and " - FAILED" or "")
    end

    if not zone.def.wave and (not zone.def.nextWaveTime or getTimestampMs() > zone.def.nextWaveTime) then
        zone.scheduleWave()
        return
    end

    if zone.def.wave and not zone.def.nextWaveTime and zombiesLeft <= 0 then
        local coolDown = (SandboxVars.LastStandTogether.CoolDownBetweenWave or 5)
        zone.def.waveCooldown = (zone.def.waveCooldown or (60000 * coolDown))
        local coolDownMulti = (SandboxVars.LastStandTogether.CoolDownMulti or 1.01)
        local coolDownMax = ((SandboxVars.LastStandTogether.CoolDownMax or 10) * 60000)
        zone.def.waveCooldown = math.min(coolDownMax, zone.def.waveCooldown * coolDownMulti)
        zone.def.nextWaveTime = getTimestampMs() + zone.def.waveCooldown
        zone.sendZoneDef()
        return
    end

    if zone.def.wave and zone.def.nextWaveTime and getTimestampMs() > zone.def.nextWaveTime and zombiesLeft <= 0 then
        zone.scheduleWave()
        return
    end
end


zone.clientSideLoginCheck = 2
function zone.onLogin()
    zone.clientSideLoginCheck = zone.clientSideLoginCheck - 1
    if zone.clientSideLoginCheck <= 0 then
        sendClientCommand(getPlayer(),"LastStandTogether", "requestZone", {})
        Events.OnPlayerUpdate.Remove(LastStandTogether_Zone.onLogin)
    end
end


function zone.sendZoneDef(player)
    if isServer() then
        if player then
            sendServerCommand(player, "LastStandTogether", "updateZone", zone.def)
        else
            sendServerCommand("LastStandTogether", "updateZone", zone.def)
        end
    else
        if not lastStandTogetherWaveAlert.instance then
            lastStandTogetherWaveAlert:setToScreen()
        end
    end
end


function zone.checkIfShopsEmpty()
    local shops = (isServer() and GLOBAL_STORES) or CLIENT_STORES
    local empty = true
    for k,v in pairs(shops) do empty = false break end
    return empty, shops
end


---@param buildingDef BuildingDef
function zone.establishShopFront(buildingDef)

    zone.def.shopMarkers = {}

    local rooms = buildingDef:getRooms()
    local roomContainers = {} -- Maps roomID -> list of containers
    local totalContainers = 0

    for i = 0, rooms:size() - 1 do
        ---@type RoomDef
        local roomDef = rooms:get(i)
        if roomDef then
            local ID = roomDef:getID()

            local roomX, roomX2 = roomDef:getX(), roomDef:getX2()
            local roomY, roomY2 = roomDef:getY(), roomDef:getY2()
            local roomZ = roomDef:getZ()

            for x=roomX, roomX2 do
                for y=roomY, roomY2 do
                    local sq = getSquare(x, y, roomZ)
                    if sq then
                        local objects = sq:getObjects()
                        for o=0, objects:size()-1 do
                            ---@type IsoObject
                            local obj = objects:get(o)

                            if obj and obj:getContainer() then

                                local objModData = obj:getModData()
                                if objModData then
                                    objModData.storeObjID = nil
                                    obj:transmitModData()
                                end

                                roomContainers[ID] = roomContainers[ID] or {}
                                table.insert(roomContainers[ID], obj)
                                totalContainers = totalContainers + 1
                            end
                        end
                    end
                end
            end
        end
    end

    if totalContainers == 0 then
        zone.def.error = "ERROR: UNABLE TO ESTABLISH SHOP!"
        return
    end

    local sortedRooms = {}
    for roomID, containers in pairs(roomContainers) do
        table.insert(sortedRooms, { id = roomID, containers = containers })
    end
    table.sort(sortedRooms, function(a, b) return #a.containers > #b.containers end)

    local empty, shops = zone.checkIfShopsEmpty()
    if empty then
        zone.def.error = "Warning: Default Shops Enabled!"
        local defaultShops = require "LastStandTogether_defaultShops.lua"
        for shopID,shopData in pairs(defaultShops) do shops[shopID] = copyTable(shopData) end
    end

    local allContainers = {}
    for _, roomData in ipairs(sortedRooms) do
        for _, container in ipairs(roomData.containers) do
            table.insert(allContainers, container)
        end
    end

    local assignedShops = 0
    for shopID,shopData in pairs(shops) do
        ---@type IsoObject
        local storeObj = STORE_HANDLER.getStoreByID(shopID)
        if storeObj then
            storeObj.locations = {}
            assignedShops = assignedShops + 1
            ---@type IsoObject
            local container = allContainers[assignedShops]
            if container then
                STORE_HANDLER.connectStoreByID(container, shopID)

                local sq = container:getSquare()
                if sq then
                    table.insert(zone.def.shopMarkers, { x=sq:getX(), y=sq:getY() })
                end

            else
                zone.def.error = "ERROR: Not enough containers to assign all shops!"
            end

            STORE_HANDLER.updateStore(storeObj)
        end
    end

end


---@param player IsoObject|IsoMovingObject|IsoGameCharacter|IsoPlayer
function zone.setToCurrentBuilding(player)

    zone.def = {}

    local building = player:getCurrentBuilding()
    if building and zone.building and zone.building == building then
        zone.building = nil
        zone.sendZoneDef()
        return
    end

    if not building then
        zone.def.error = "NO BUILDING FOUND!"
        zone.sendZoneDef()
        return
    end

    local buildingDef = building and building:getDef()
    if not buildingDef then
        zone.def.error = "NO BUILDING DEFINITION FOUND!"
        zone.sendZoneDef()
        return
    end

    zone.def.building = building

    local buildingDefW = buildingDef:getW()
    local buildingDefH = buildingDef:getH()

    local centerX = (buildingDef:getX()+(buildingDefW/2))
    local centerY = (buildingDef:getY()+(buildingDefH/2))

    local largestSize = math.max(buildingDefW,buildingDefH)
    local bufferSize = (SandboxVars.LastStandTogether.BufferSize or 4)

    local finalRadius = math.min(50, math.max(1, largestSize+bufferSize))
    
    zone.def.radius = finalRadius
    zone.def.center = {x=centerX, y=centerY}

    zone.initiateLoop = true

    zone.sendZoneDef()
    zone.establishShopFront(buildingDef)
end


return zone