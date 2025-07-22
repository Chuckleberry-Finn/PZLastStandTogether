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
zone.def.buildingID = false
zone.def.shopMarkers = {}
zone.def.shopMarkersRooms = {}

zone.playerDeaths = {}

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


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
function zone.onPlayerDeath(player)
    if (not isClient() and not isServer()) then table.insert(zone.playerDeaths, player:getUsername()) end
    if isClient() then sendClientCommand("LastStandTogether", "updateZoneDefPlayerDeaths", {}) end
    if isServer() then sendServerCommand("LastStandTogether", "updateZoneDefPlayerDeaths", { username=player:getUsername() }) end
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
    for _,_ in pairs(shops) do empty = false break end
    return empty, shops
end


function zone.setRoomsWithShopsMarkers()
    for roomID, shopLocations in pairs(zone.def.shopMarkersInRoom) do
        if #shopLocations > 0 then
            local avgX, avgY, avgZ = 0, 0, 0
            for s=1, #shopLocations do
                local shop = shopLocations[s]
                if shop then
                    avgX = avgX + shop.x
                    avgY = avgY + shop.y
                    avgZ = avgZ + shop.z
                end
            end
            avgX = avgX/#shopLocations
            avgY = avgY/#shopLocations
            zone.def.shopMarkersRooms[roomID] = {x=avgX, y=avgY, z=avgZ}
        end
    end
end


function zone.resetShopMarkers()
    if isClient() then sendClientCommand("LastStandTogether", "resetShopMarkers", {}) end

    if not zone.def or not zone.def.center then
        zone.def.error = "Warning: No building set for Last Stand Together!"
        return
    end

    zone.def.shopMarkersInRoom = {}
    zone.def.shopMarkersRooms = {}

    local empty, shops = zone.checkIfShopsEmpty()
    if empty then
        zone.def.error = "Warning: Default Shops Enabled!"
        local defaultShops = require "LastStandTogether_defaultShops.lua"
        for shopID,shopData in pairs(defaultShops) do shops[shopID] = copyTable(shopData) end
    end

    for shopID,_ in pairs(shops) do
        ---@type IsoObject
        local storeObj = STORE_HANDLER.getStoreByID(shopID)
        if storeObj then
            for _,locData in pairs(storeObj.locations) do
                local sq = getSquare(locData.x, locData.y, locData.z)
                local roomID = sq and tostring(sq:getRoomID())
                if roomID then
                    local objects = sq:getObjects()
                    for o=0, objects:size()-1 do
                        ---@type IsoObject
                        local container = objects:get(o)
                        local objModData = container and container:getModData()
                        if objModData and objModData.storeObjID then
                            zone.def.shopMarkersInRoom[roomID] = zone.def.shopMarkersInRoom[roomID] or {}
                            local zOffset = container:isTableTopObject() and 0.25 or 0
                            table.insert(zone.def.shopMarkersInRoom[roomID],{ x=sq:getX(), y=sq:getY(), z=sq:getZ()+zOffset })
                        end
                    end
                end
            end
        end
    end

    zone.setRoomsWithShopsMarkers()
    zone.sendZoneDef()
end


---@param buildingDef BuildingDef
function zone.establishShopFront(buildingDef)

    zone.def.shopMarkersInRoom = {}
    zone.def.shopMarkersRooms = {}

    local buildingX, buildingX2 = buildingDef:getX(), buildingDef:getX2()
    local buildingY, buildingY2 = buildingDef:getY(), buildingDef:getY2()

    local roomContainers = {} -- Maps roomID -> list of containers
    local totalContainers = 0

    for z=0, 8 do --B41's max level is 8 I think
        local validZ = false
        for x=buildingX, buildingX2 do
            for y=buildingY, buildingY2 do
                local sq = getSquare(x, y, z)
                if sq then
                    validZ = true
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

                            local roomID = sq:getRoomID()
                            if roomID >= 0 then
                                roomContainers[roomID] = roomContainers[roomID] or {}
                                table.insert(roomContainers[roomID], obj)
                                totalContainers = totalContainers + 1
                            end
                        end
                    end
                end
            end
        end
        if not validZ then break end
    end

    if totalContainers == 0 then
        zone.def.error = "ERROR: UNABLE TO ESTABLISH SHOPS!"
        return
    end

    local empty, shops = zone.checkIfShopsEmpty()
    if empty then
        zone.def.error = "Warning: Default Shops Enabled!"
        local defaultShops = require "LastStandTogether_defaultShops.lua"
        for shopID,shopData in pairs(defaultShops) do shops[shopID] = copyTable(shopData) end
    end

    local sortedRooms = {}
    for roomID, containers in pairs(roomContainers) do table.insert(sortedRooms, { id = roomID, containers = containers }) end
    table.sort(sortedRooms, function(a, b) return #a.containers > #b.containers end)

    local allContainers = {}
    for _, roomData in ipairs(sortedRooms) do
        for _, container in ipairs(roomData.containers) do
            table.insert(allContainers, container)
        end
    end

    local assignedShops = 1
    for shopID,_ in pairs(shops) do
        ---@type IsoObject
        local storeObj = STORE_HANDLER.getStoreByID(shopID)
        if storeObj then
            storeObj.locations = {}
            ---@type IsoObject
            local container = allContainers[assignedShops]
            if container then
                STORE_HANDLER.connectStoreByID(container, shopID)
                local sq = container:getSquare()
                if sq then
                    local roomID = tostring(sq:getRoomID())
                    if roomID then
                        assignedShops = assignedShops + 1
                        zone.def.shopMarkersInRoom[roomID] = zone.def.shopMarkersInRoom[roomID] or {}
                        local zOffset = container:isTableTopObject() and 0.25 or 0
                        table.insert(zone.def.shopMarkersInRoom[roomID],{ x=sq:getX(), y=sq:getY(), z=zOffset })
                        STORE_HANDLER.updateStore(storeObj)
                    end
                end
            end
        end
    end

    zone.setRoomsWithShopsMarkers()
end


---@param player IsoObject|IsoMovingObject|IsoGameCharacter|IsoPlayer
function zone.setToCurrentBuilding(player)

    zone.def = {}

    local building = player:getCurrentBuilding()
    if not building then
        zone.def.error = "NO BUILDING FOUND!"
        zone.sendZoneDef()
        return
    end

    local buildingDef = building and building:getDef()
    if not buildingDef then
        zone.def.error = "NO BUILDING DEFINITION FOUND!?"
        zone.sendZoneDef()
        return
    end

    local buildingID = buildingDef and buildingDef:getID()
    if building and zone.def.buildingID and zone.def.buildingID == buildingID then
        zone.def.buildingID = nil
        zone.def.error = "CLEARED BUILDING"
        zone.sendZoneDef()
        return
    end

    zone.def.buildingID = buildingID

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

    zone.establishShopFront(buildingDef)

    zone.sendZoneDef()
end


return zone