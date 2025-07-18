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
zone.def.zombies = 0

zone.players = {}
zone.schedulingProcess = false
zone.initiateLoop = false


function zone.onDead(zombie)
    zone.def.zombies = (zone.def.zombies or 0) - 1
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
        waveGen.spawnZombies(numberOf)
        zone.def.nextWaveTime = nil
    end

    zone.schedulingProcess = false
    zone.sendZoneDef()
end


function zone.schedulerLoop()
    if not zone.initiateLoop or not zone.def then return end

    local zombiesLeft = zone.def.zombies or 0--getWorld():getCell():getZombieList():size()

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


function zone.requestZoneDef()
    if isClient() then
        sendClientCommand(getPlayer(),"LastStandTogether", "requestZone", {})
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


---@param buildingDef BuildingDef
function zone.establishShopFront(buildingDef)

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


    local shops = (isServer() and GLOBAL_STORES) or CLIENT_STORES

    local allContainers = {}
    for _, roomData in ipairs(sortedRooms) do
        for _, container in ipairs(roomData.containers) do
            table.insert(allContainers, container)
        end
    end

    local assignedShops = 0
    for shopID,shopData in pairs(shops) do

        local storeObj = STORE_HANDLER.getStoreByID(shopID)
        storeObj.locations = {}

        assignedShops = assignedShops + 1
        ---@type IsoObject
        local container = allContainers[assignedShops]
        if container then
            container:setOutlineHighlightCol(1,1,1,1)
            STORE_HANDLER.connectStoreByID(container, shopID)
        else
            zone.def.error = "ERROR: Not enough containers to assign all shops!"
        end

        STORE_HANDLER.updateStore(storeObj)
    end

end


---@param player IsoObject|IsoMovingObject|IsoGameCharacter|IsoPlayer
function zone.setToCurrentBuilding(player)

    zone.def = {}

    local building = player:getCurrentBuilding()
    if building and zone.def.building and zone.def.building == building then
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

    local boundsRadius = math.max(1, math.max(buildingDefW,buildingDefH) + (SandboxVars.LastStandTogether.BufferSize or 4))

    zone.def.radius = boundsRadius
    zone.def.center = {x=centerX, y=centerY}

    zone.initiateLoop = true

    getWorld():ForceKillAllZombies()

    zone.sendZoneDef()
    zone.establishShopFront(buildingDef)
end


return zone