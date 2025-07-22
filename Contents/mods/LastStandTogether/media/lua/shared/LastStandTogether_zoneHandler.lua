local waveGen = require "LastStandTogether_waveGenerator.lua"
local _internal = require "shop-shared"

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

zone.def.currentZombies = 0
zone.def.zombiesToSpawn = 0
zone.def.zombiesSpawned = 0
zone.def.spawnTickTimer = 0

zone.def.buildingID = false
zone.def.shopMarkers = {}
zone.def.shopMarkersRooms = {}

zone.playerDeaths = {}

zone.players = {}
zone.schedulingProcess = false
zone.initiateLoop = false
zone.deathLogFade = 5000

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
    if (not isClient() and not isServer()) then
        table.insert(zone.playerDeaths, {username=player:getUsername(), expire=getTimestampMs()+zone.deathLogFade} )
    end
    if isClient() then sendClientCommand("LastStandTogether", "updateZoneDefPlayerDeaths", {}) end
    if isServer() then sendServerCommand("LastStandTogether", "updateZoneDefPlayerDeaths", { username=player:getUsername() }) end
end


function zone.sendZombieCount(data)
    if isClient() and data then
        if data.spawnTickTimer then zone.def.spawnTickTimer = data.spawnTickTimer end
        if data.zombiesToSpawn then zone.def.zombiesToSpawn = data.zombiesToSpawn end
        if data.zombiesSpawned then zone.def.zombiesSpawned = data.zombiesSpawned end
        if data.currentZombies then zone.def.currentZombies = data.currentZombies end
    end

    if isServer() then
        sendServerCommand("LastStandTogether", "updateZoneDefZombies", data or {
            spawnTickTimer = zone.def.spawnTickTimer,
            zombiesToSpawn = zone.def.zombiesToSpawn,
            zombiesSpawned = zone.def.zombiesSpawned,
            currentZombies = zone.def.currentZombies,
        })
    end
end


function zone.onZombieDead(zombie)
    if not zone.def.center then return end

    if (not isClient()) then zone.def.currentZombies = math.max(0, (zone.def.currentZombies or 0) - 1) end
    zone.sendZombieCount({ currentZombies = zone.def.currentZombies })

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

    local currentTime = getTimestampMs()

    if not zone.def.wave then
        zone.def.wave = 0
        local setupTime = 60000 * (SandboxVars.LastStandTogether.SetUpGracePeriod or 3)
        zone.def.nextWaveTime = currentTime + setupTime
    else
        if not zone.def.popMulti then
            zone.def.popMulti = 1
        else
            zone.def.popMulti = zone.def.popMulti * (SandboxVars.LastStandTogether.WavePopMultiplier or 1.2)
        end

        zone.def.wave = zone.def.wave + 1
        zone.def.zombiesToSpawn = math.floor(zone.def.popMulti * (SandboxVars.LastStandTogether.NumberOfZombiesPerWave or 10))
        zone.def.zombiesSpawned = 0
        zone.def.spawnTickTimer = 0
        zone.def.nextWaveTime = false
    end

    zone.schedulingProcess = false
    zone.sendZoneDef()
end


function zone.schedulerLoop()
    if not (zone.initiateLoop and zone.def and zone.def.center) then return end

    local currentTime = getTimestampMs()

    if not zone.def.wave and not zone.def.nextWaveTime then
        local zombiesInCell = getWorld():getCell():getZombieList()
        for z=0, zombiesInCell:size()-1 do
            local zombie = zombiesInCell:get(z)
            if zombie then
                zombie:getEmitter():unregister()
                zombie:removeFromWorld()
                zombie:removeFromSquare()
            end
        end

        local meta = getWorld():getMetaGrid()
        for x = 0, meta:getMaxX() do
            for y = 0, meta:getMaxY() do
                zpopClearZombies(x, y)
            end
        end
        zone.scheduleWave()
        return
    end

    if not zone.def.wave then return end
    local zombiesLeft = zone.def.currentZombies or 0
    if zone.def.zombiesToSpawn and zone.def.zombiesToSpawn > 0 then
        if not zone.def.spawnTickTimer or currentTime > zone.def.spawnTickTimer then
            local batchSize = math.min(100, zone.def.zombiesToSpawn)
            local spawned = waveGen.spawnZombies(batchSize)
            zone.def.zombiesToSpawn = math.max(0,zone.def.zombiesToSpawn - spawned)
            zone.def.spawnTickTimer = currentTime + ((SandboxVars.LastStandTogether.InWaveSpawnInterval or 2) * 60000)
            zone.def.zombiesSpawned = (zone.def.zombiesSpawned or 0) + spawned
            zone.def.currentZombies = (zone.def.currentZombies or 0) + spawned
            if isServer() then zone.sendZombieCount() end
        end
        return
    end

    if not zone.def.nextWaveTime then
        if zombiesLeft <= 0 and (zone.def.zombiesSpawned or 0) > 0 then
            local base = 60000 * (SandboxVars.LastStandTogether.CoolDownBetweenWave or 2)
            local multi = (SandboxVars.LastStandTogether.CoolDownMulti or 1.01)
            local max = (SandboxVars.LastStandTogether.CoolDownMax or 10) * 60000

            zone.def.waveCooldown = math.min(max, (zone.def.waveCooldown or base) * multi)
            zone.def.nextWaveTime = currentTime + zone.def.waveCooldown
            zone.sendZoneDef()
        end
        return
    end

    if currentTime > zone.def.nextWaveTime and zombiesLeft <= 0 then zone.scheduleWave() return end

    local zombiesInCell = getWorld():getCell():getZombieList():size()
    if zombiesLeft > 0 and zombiesInCell <= 0 then
        local need = math.max(0, zombiesLeft - zombiesInCell)
        local spawned = (need>0) and waveGen.spawnZombies(need)
        print("WARNING: Spawned fallback zombies. spawned:", spawned, "  needed:",need)
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
                    avgX = avgX + (shop.x)
                    avgY = avgY + (shop.y)
                    avgZ = avgZ + (shop.z)
                end
            end
            avgX = math.floor(avgX/#shopLocations)
            avgY = math.floor(avgY/#shopLocations)
            avgZ = math.floor(avgZ/#shopLocations)
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
                local roomID = sq and sq:getRoomID()
                if roomID then
                    local objects = sq:getObjects()
                    for o=0, objects:size()-1 do
                        ---@type IsoObject
                        local container = objects:get(o)
                        local objModData = container and container:getModData()
                        if objModData and objModData.storeObjID then
                            zone.def.shopMarkersInRoom[roomID] = zone.def.shopMarkersInRoom[roomID] or {}
                            local zOffset = container:isTableTopObject() and 0.25 or 0
                            table.insert(zone.def.shopMarkersInRoom[roomID],{ x=sq:getX(), y=sq:getY(), z=(sq:getZ()+zOffset) })
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
                            local objectName = _internal.getWorldObjectDisplayName(obj)
                            if objectName then
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
                    local roomID = sq:getRoomID()
                    if roomID then
                        assignedShops = assignedShops + 1
                        zone.def.shopMarkersInRoom[roomID] = zone.def.shopMarkersInRoom[roomID] or {}
                        local zOffset = container:isTableTopObject() and 0.25 or 0
                        table.insert(zone.def.shopMarkersInRoom[roomID],{ x=sq:getX(), y=sq:getY(), z=(sq:getZ()+zOffset) })
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