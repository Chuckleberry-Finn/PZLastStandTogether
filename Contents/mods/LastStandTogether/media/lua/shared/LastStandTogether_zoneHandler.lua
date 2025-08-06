local waveGen = require "LastStandTogether_waveGenerator.lua"
local _internal = require "shop-shared"

local zone = {}

zone.def = {}
zone.def.center = false
zone.def.dimensions = false

zone.def.error = false

zone.def.waveCooldown = false
zone.def.wave = false
zone.def.nextWaveTime = false

zone.def.popMulti = false

zone.def.currentZombies = 0
zone.def.zombiesToSpawn = 0
zone.def.zombiesSpawned = 0
zone.def.spawnTickTimer = 0

zone.def.resetCooldown = false
zone.def.warningNoPlayers = false

zone.def.buildingID = false
zone.def.shopMarkers = {}
zone.def.shopMarkersRooms = {}

zone.resetCooldown = 35000
zone.playerDeaths = {}

zone.players = {}
zone.schedulingProcess = false
zone.initiateLoop = false
zone.deathLogFade = 20000

zone.highscore = require "LastStandTogether_highscores.lua"

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
    if not zone.def.center then return end

    if (not isClient() and not isServer()) then
        table.insert(zone.playerDeaths, {username=player:getUsername(), expire=getTimestampMs()+zone.deathLogFade} )
    end
    if not isClient() then zone.highscore.update(player, "died") end

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


function zone.getAllPlayers()
    if (not zone.def or not zone.def.center) then return end
    local players = (isClient() or isServer()) and getOnlinePlayers() or IsoPlayer.getPlayers()
    if players:size() <= 0 then return false end
    return players
end


function zone.killSpectators(players)
    if not players then return false end
    if not Spectate then return end
    for i=0, players:size()-1 do
        ---@type IsoPlayer|IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
        local player = players:get(i)
        if player and Spectate.isSpectating(player) then
            player:Kill()
        end
    end
    return true
end


function zone.allPlayersDead(players)
    if (not zone.def or not zone.def.center) then return end
    if not players then return false end
    for i=0, players:size()-1 do
        ---@type IsoPlayer|IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
        local player = players:get(i)
        if player and (not player:isDead()) and (not player:isInvisible()) then
            return false
        end
    end
    return true
end


function zone.teleportPlayersToZone(players)
    if (not zone.def or not zone.def.center) then return end
    if not players then return false end
    for i=0, players:size()-1 do
        ---@type IsoPlayer|IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
        local player = players:get(i)
        if player then
            local pX, pY, pZ = player:getX(), player:getY(), player:getZ()
            local dx = math.abs(zone.def.center.x-pX)
            local dy = math.abs(zone.def.center.y-pY)

            if ((dx) > zone.def.dimensions.w*2.5) or ((dy) > zone.def.dimensions.h*2.5) then
                player:setX(zone.def.center.x)
                player:setY(zone.def.center.y)
                player:setLx(zone.def.center.x)
                player:setLy(zone.def.center.y)
                player:setZ(0)
            end
        end
    end
    return true
end


function zone.onZombieDead(zombie)
    if not zone.def.center then return end

    local attacker = zombie:getAttackedBy()
    local attackerPlayer = attacker and instanceof(attacker,"IsoPlayer") and attacker or false

    if (not isClient()) then
        if attackerPlayer then
            zone.highscore.update(attackerPlayer, "zombieKill")
        end

        zone.def.currentZombies = math.max(0, (zone.def.currentZombies or 0) - 1)
    end

    if isServer() then
        zone.sendZombieCount({ currentZombies = zone.def.currentZombies })
    end

    --sends money handling for clients
    if not isServer() then
        if attackerPlayer then
            local value = SandboxVars.LastStandTogether.MoneyPerKill
            local walletID = getOrSetWalletID(attackerPlayer)
            if not walletID then
                local moneyTypes = _internal.getMoneyTypes()
                local type = moneyTypes[ZombRand(#moneyTypes)+1]
                local money = InventoryItemFactory.CreateItem(type)
                if money then
                    generateMoneyValue(money, value, true)
                    attackerPlayer:getInventory():AddItem(money)
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
        zone.clearZombies()
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

    local players = zone.getAllPlayers()
    if (not zone.def.wave) and ((not players) or zone.allPlayersDead(players)) then
        if not zone.def.warningNoPlayers then
            zone.def.warningNoPlayers = true
            zone.clearZombies()
            zone.def.error = "WAITING FOR PLAYERS"
            zone.sendZoneDef()
        end
        return
    end

    zone.def.error = ""
    zone.def.warningNoPlayers = false

    local currentTime = getTimestampMs()

    if not zone.def.wave and not zone.def.nextWaveTime then
        zone.scheduleWave()
        return
    end

    if zone.def.wave and ((not players) or zone.allPlayersDead(players)) then
        zone.allPlayersHaveDied()
        return
    end

    --- zombies left to spawn
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

    local zombiesLeft = (zone.def.currentZombies or 0) + (zone.def.zombiesToSpawn or 0)

    local zombiesInCell = getWorld():getCell():getZombieList():size()
    if zombiesLeft > 0 and zombiesInCell <= 0 then
        local need = math.max(0, zombiesLeft - zombiesInCell)
        local spawned = (need>0) and waveGen.spawnZombies(need)
        print("WARNING: Spawned fallback zombies. spawned:", spawned, "  needed:",need)
        zone.def.error = "WARNING: Fall-back spawner spawned "..spawned.." zombies."
        zone.sendZoneDef()
    end

    if not zone.def.nextWaveTime then --- set wave timer for next wave when all zombies are dead
        if zombiesLeft <= 0 and (zone.def.zombiesSpawned or 0) > 0 then
            local base = 60000 * (SandboxVars.LastStandTogether.CoolDownBetweenWave or 2)
            local multi = (SandboxVars.LastStandTogether.CoolDownMulti or 1.01)
            local max = (SandboxVars.LastStandTogether.CoolDownMax or 10) * 60000

            zone.def.waveCooldown = math.min(max, (zone.def.waveCooldown or base) * multi)
            zone.def.nextWaveTime = currentTime + zone.def.waveCooldown

            if zone.def.wave > 0 then zone.highscore.checkTopWave(zone.def.wave) end

            zone.sendZoneDef()
        end
        return
    end

    if currentTime > zone.def.nextWaveTime and zombiesLeft <= 0 then zone.scheduleWave() return end

end


zone.clientSideLoginCheck = 2
function zone.onPlayerCreate(playerID)
    if Spectate and Spectate.isSpectating(getSpecificPlayer(playerID)) then return end
    zone.clientSideLoginCheck = 2
    Events.OnPlayerUpdate.Add(LastStandTogether_Zone.onLogin)
end


function zone.onLogin(playerObj)
    zone.clientSideLoginCheck = zone.clientSideLoginCheck - 1
    if zone.clientSideLoginCheck <= 0 then

        if Spectate then
            local record = zone.highscore.currentPlayers and zone.highscore.currentPlayers[playerObj:getUsername()]
            if not record and Spectate.isSpectating(playerObj) then
                Events.OnPlayerUpdate.Remove(LastStandTogether_Zone.onLogin)
                playerObj:Kill()
                return
            end
        end

        lastStandTogetherWaveAlert:setToScreen()
        if isClient() then
            sendClientCommand(playerObj,"LastStandTogether", "requestZone", {})
            sendClientCommand(playerObj,"LastStandTogether", "requestHighscores", {login=true})
        else
            zone.highscore.setAllPlayers()
        end
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
    for r=1, #sortedRooms do
        local roomData = sortedRooms[r]
        for c=1, #roomData.containers do
            local container = roomData.containers[c]
            table.insert(allContainers, container)
        end
    end

    local assignedShops = 0
    print("Lasts Stand Together: allContainers for shops: ", #allContainers)
    for shopID,_ in pairs(shops) do
        ---@type IsoObject
        local storeObj = STORE_HANDLER.getStoreByID(shopID)
        if storeObj then
            storeObj.locations = {}
            ---@type IsoObject
            local container = allContainers[assignedShops+1]
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
    print("Lasts Stand Together: assigned shops: ", assignedShops)

    zone.setRoomsWithShopsMarkers()
end


---@param player IsoObject|IsoMovingObject|IsoGameCharacter|IsoPlayer
function zone.setToCurrentBuilding(player)

    local building = player:getCurrentBuilding()
    if not building then
        zone.def = {}
        zone.def.error = "NO BUILDING FOUND!"
        zone.sendZoneDef()
        return
    end

    local buildingDef = building and building:getDef()
    if not buildingDef then
        zone.def = {}
        zone.def.error = "NO BUILDING DEFINITION FOUND!?"
        zone.sendZoneDef()
        return
    end

    local buildingID = buildingDef and buildingDef:getID()
    if building and zone.def.buildingID and zone.def.buildingID == buildingID then
        zone.def = {}
        zone.def.error = "CLEARED BUILDING"
        zone.sendZoneDef()
        return
    end

    zone.setToBuilding(buildingDef)
end


function zone.clearZombies()
    local cell = getCell()
    local zombiesInCell = cell:getZombieList()
    local zombiesInCellSize = zombiesInCell:size()

    if zombiesInCellSize > 0 then
        for z=zombiesInCellSize-1, 0, -1 do
            local zombie = zombiesInCell:get(z)
            if zombie then
                zombie:getEmitter():unregister()
                zombie:removeFromWorld()
                zombie:removeFromSquare()
            end
        end
    end

    local meta = getWorld():getMetaGrid()
    for x = 0, meta:getMaxX() do
        for y = 0, meta:getMaxY() do
            zpopClearZombies(x, y)
        end
    end

end


---@param buildingDef BuildingDef
function zone.setToBuilding(buildingDef)
    if not buildingDef then print("ERROR: setToBuilding has invalid buildingDef!") return end

    zone.def = {}

    buildingDef:setAlarmed(false) ---lol

    local buildingID = buildingDef and buildingDef:getID()
    zone.def.buildingID = buildingID

    local buildingDefW = buildingDef:getW()
    local buildingDefH = buildingDef:getH()

    local centerX = (buildingDef:getX()+(buildingDefW/2))
    local centerY = (buildingDef:getY()+(buildingDefH/2))

    local bufferSize = (SandboxVars.LastStandTogether.BufferSize or 4)
    local zoneWidth = math.min(50, math.max(1, buildingDefW + bufferSize))
    local zoneHeight = math.min(50, math.max(1, buildingDefH + bufferSize))

    zone.def.dimensions = {w=zoneWidth, h=zoneHeight}
    zone.def.center = {x=centerX, y=centerY}
    zone.initiateLoop = true
    zone.highscore.load()

    if LivesToLive then
        ---Workshop ID: 3296856214
        ---Mod ID: BB_LivesToLiveRedux
        ---Compat Patch
        for i=1, #LivesToLive.playerList do
            local playerData = LivesToLive.playerList[i]
            if playerData then playerData.currentLives = SandboxVars.LivesToLive.StartAmount end
        end
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size()-1 do
            local player = onlinePlayers:get(i)
            if player then sendServerCommand(player, "LivesToLive", "Refresh", {}) end
        end
    end

    zone.highscore.reset()
    zone.finalSteps = false
    Events.OnTick.Add(zone.scheduledFinalSetup)
end


function zone.scheduledFinalSetup()

    local players = zone.getAllPlayers()
    if not players then return end

    if not zone.finalSteps then
        zone.finalSteps = { "clearZombies", "establishShops", "teleport", "sendDefAndScores", "killSpectators"}
        zone.finalStepsTime = getTimestampMs() + 100
        return
    end

    if zone.finalStepsTime > getTimestampMs() then return end

    if #zone.finalSteps > 0 then
        local step = zone.finalSteps[#zone.finalSteps]

        if step == "killSpectators" then
            if Spectate then zone.killSpectators(players) end
            zone.finalSteps[#zone.finalSteps] = nil
            zone.finalStepsTime = getTimestampMs() + 50

        elseif step == "sendDefAndScores" then
            zone.sendZoneDef()
            zone.highscore.sendHighScore()
            zone.finalSteps[#zone.finalSteps] = nil
            zone.finalStepsTime = getTimestampMs() + 100

        elseif step == "teleport" then
            zone.teleportPlayersToZone(players)
            zone.finalSteps[#zone.finalSteps] = nil
            zone.finalStepsTime = getTimestampMs() + 400

        elseif step == "establishShops" then
            local x = zone.def.center.x
            local y = zone.def.center.y
            local sq = getSquare(x, y, 0)
            local buildingDef = getWorld():getMetaGrid():getBuildingAtRelax(x, y)
            if sq and  buildingDef then
                zone.establishShopFront(buildingDef)
                zone.finalSteps[#zone.finalSteps] = nil
            end
            zone.finalStepsTime = getTimestampMs() + 200

        elseif step == "clearZombies" then
            local x = zone.def.center.x
            local y = zone.def.center.y

            local sq = getSquare(x, y, 0)
            if sq then
                zone.clearZombies()
                zone.finalSteps[#zone.finalSteps] = nil
            end
            zone.finalStepsTime = getTimestampMs() + 500
        end
        return
    end

    if #zone.finalSteps <= 0 then
        Events.OnTick.Remove(zone.scheduledFinalSetup)
    end
end


function zone.allPlayersHaveDied()

    local now = getTimestampMs()
    if not zone.def.resetCooldown then
        zone.def.resetCooldown = now+zone.resetCooldown
        zone.sendZoneDef()
    else
        if now > zone.def.resetCooldown then
            zone.setToBuildingRandom()
        end
    end
end


function zone.setToBuildingRandom()
    ---@type BuildingDef
    local buildingDef = zone.seekNewBuilding()
    zone.setToBuilding(buildingDef)
end


zone.IsoMetaGridBuildingsField = false
---@return ArrayList BuildingDef
---`getBuildings` is now a thing in B42.
function zone.IsoMetaGridGetBuildings(metaGrid)
    if not metaGrid then return false end

    if zone.IsoMetaGridBuildingsField then
        return getClassFieldVal(metaGrid, zone.IsoMetaGridBuildingsField)
    end

    local fieldStr = "public final java.util.ArrayList zombie.iso.IsoMetaGrid.Buildings"
    local fieldCount = getNumClassFields(metaGrid)
    for i = 0, fieldCount - 1 do
        local field = getClassField(metaGrid, i)
        if field and tostring(field) == fieldStr then
            zone.IsoMetaGridBuildingsField = field
            return getClassFieldVal(metaGrid, field)
        end
    end

    return false
end


function zone.seekNewBuilding()
    local metaGrid = getWorld():getMetaGrid()
    local buildings = metaGrid and zone.IsoMetaGridGetBuildings(metaGrid)
    if not buildings then return end
    local buildingPool = {}
    local buildingSizeMinimum = SandboxVars.LastStandTogether.AutoSelectBuildingSizeMinimum or 20

    for i=0, buildings:size()-1 do
        ---@type BuildingDef
        local building = buildings:get(i)
        if building then
            if (building:getW() > buildingSizeMinimum) and (building:getH() > buildingSizeMinimum) then
                table.insert(buildingPool, building)
            end
        end
    end

    local buildingSelection = buildingPool[ZombRand(#buildingPool)+1]
    return buildingSelection
end


return zone