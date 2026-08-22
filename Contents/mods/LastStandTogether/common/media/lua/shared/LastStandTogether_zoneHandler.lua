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
zone.def.zombieCountSafety = {}

zone.def.resetCooldown = false
zone.def.warningNoPlayers = false

zone.def.buildingID = false
zone.def.shopMarkers = {}
zone.def.shopMarkersRooms = {}

zone.resetCooldown = isServer() and 80000 or 20000
zone.confirmRequestCooldownMs = 10000
zone.confirmRequestGraceMs = 2000
zone.confirmRequest = {}
zone.playerDeaths = {}

zone.players = {}
zone.schedulingProcess = false
zone.initiateLoop = false
zone.deathLogFade = 20000

zone.highscore = require "LastStandTogether_highscores.lua"

zone.stateFile = "LastStandTogether_State.json"
zone.restoreAttempted = false
zone.restoring = false


function zone.saveState()
    if isClient() and not isServer() then return nil end
    if not zone.def or not zone.def.buildingID then return end

    local now = getTimestampMs()

    local state = {
        buildingID = zone.def.buildingID,
        wave = zone.def.wave,
        popMulti = zone.def.popMulti,
        waveCooldown = zone.def.waveCooldown,
        zombiesSpawned = zone.def.zombiesSpawned or 0,
        currentZombies = zone.def.currentZombies or 0,
        zombiesToSpawn = zone.def.zombiesToSpawn or 0,
        currentPlayers = zone.highscore.currentPlayers,
        spawnTickTimerRemaining = (zone.def.spawnTickTimer and zone.def.spawnTickTimer > 0) and math.max(0, zone.def.spawnTickTimer - now) or 0,
        nextWaveTimeRemaining = (zone.def.nextWaveTime and type(zone.def.nextWaveTime) == "number") and math.max(0, zone.def.nextWaveTime - now) or false,
        resetCooldownRemaining = (zone.def.resetCooldown and type(zone.def.resetCooldown) == "number") and math.max(0, zone.def.resetCooldown - now) or false,
    }

    local path = _internal.getSavePath("lastStandTogether", zone.stateFile)
    local writer = getFileWriter(path, true, false)
    if not writer then print("[LastStandTogether] ERROR: Could not write "..path) return end
    writer:write(_internal.jsonEncode(state))
    writer:close()
end


function zone.deleteStateFile()
    local path = _internal.getSavePath("lastStandTogether", zone.stateFile)
    local writer = getFileWriter(path, true, false)
    if writer then
        writer:write("")
        writer:close()
    end
end


function zone.loadState()
    if isClient() and not isServer() then return nil end

    local path = _internal.getSavePath("lastStandTogether", zone.stateFile)
    local reader = getFileReader(path, false)
    if not reader then return nil end

    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()

    local content = table.concat(lines, "\n")
    if content == "" then return nil end

    local data, err = _internal.jsonDecode(content)
    if not data then
        print("[LastStandTogether] Failed to load state: "..(err or ""))
        return nil
    end

    zone.deleteStateFile()
    return data
end


function zone.findBuildingByID(buildingID)
    local meta = getWorld():getMetaGrid()
    if not meta then return nil end
    local buildings = meta:getBuildings()
    if not buildings then return nil end
    for i = 0, buildings:size() - 1 do
        local bDef = buildings:get(i)
        if bDef and bDef:getID() == buildingID then
            return bDef
        end
    end
    return nil
end


function zone.tryRestore()
    if zone.restoreAttempted then return false end

    local saveName = getCurrentSaveName()
    if not saveName or saveName == "" then return false end

    zone.restoreAttempted = true

    local state = zone.loadState()
    if not state or not state.buildingID then return false end

    local buildingDef = zone.findBuildingByID(state.buildingID)
    if not buildingDef then
        print("[LastStandTogether] Restore failed: building ID "..tostring(state.buildingID).." not found")
        return false
    end

    zone.def.wave = state.wave
    zone.def.popMulti = state.popMulti
    zone.def.waveCooldown = state.waveCooldown
    zone.def.zombiesSpawned = state.zombiesSpawned or 0
    zone.def.currentZombies = state.currentZombies or 0
    zone.def.zombiesToSpawn = state.zombiesToSpawn or 0

    local now = getTimestampMs()
    if state.spawnTickTimerRemaining and state.spawnTickTimerRemaining > 0 then
        zone.def.spawnTickTimer = now + state.spawnTickTimerRemaining
    end
    if state.nextWaveTimeRemaining and type(state.nextWaveTimeRemaining) == "number" then
        zone.def.nextWaveTime = now + state.nextWaveTimeRemaining
    end
    if state.resetCooldownRemaining and type(state.resetCooldownRemaining) == "number" then
        zone.def.resetCooldown = now + state.resetCooldownRemaining
    end

    if state.currentPlayers then
        zone.highscore.currentPlayers = state.currentPlayers
    end

    zone.restoring = true
    zone.setToBuilding(buildingDef)

    print("[LastStandTogether] Restored state: building "..state.buildingID..", wave "..tostring(state.wave))
    return true
end

function zone.setSandboxForLastStand()
    local options = getSandboxOptions()
    local optionsToValues = {
        ["ZombieConfig.PopulationMultiplier"] = 0.01,
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

    if isClient() then options:sendToServer() end
    options:toLua()
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
function zone.onPlayerDeath(player)
    if not zone.def.center then return end

    local pUsername = player:getUsername()

    local currentScore = zone.highscore.currentPlayers[pUsername]
    if currentScore and currentScore.dead then return end

    if (not isClient() and not isServer()) then
        table.insert(zone.playerDeaths, {username=pUsername, expire=getTimestampMs()+zone.deathLogFade} )
    end
    if not isClient() then zone.highscore.update(player, "died") end

    if isClient() then sendClientCommand("LastStandTogether", "updateZoneDefPlayerDeaths", {}) end
    if isServer() then sendServerCommand("LastStandTogether", "updateZoneDefPlayerDeaths", { username=pUsername }) end
    if not isClient() and zone.def.wave then
        local players = zone.getAllPlayers()
        if players and zone.allPlayersDead(players) then
            zone.allPlayersHaveDied()
        end
    end
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


function zone.getNearestPlayer(players, x, y)
    local nearest, nearestDistSq
    for i=0, players:size()-1 do
        ---@type IsoPlayer
        local player = players:get(i)
        if player and not player:isDead() and not player:isInvisible() then
            local dx = player:getX()-x
            local dy = player:getY()-y
            local distSq = dx*dx + dy*dy
            if not nearestDistSq or distSq < nearestDistSq then
                nearestDistSq = distSq
                nearest = player
            end
        end
    end
    return nearest
end


function zone.enforceZoneBoundaries()
    if not isServer() then return end
    if not zone.def or not zone.def.center or not zone.def.dimensions then return end

    local cell = getCell()
    local zombiesInCell = cell:getZombieList()
    local players = zone.getAllPlayers()
    local hasPlayers = players and players:size() > 0

    local luringRadius = math.max(zone.def.dimensions.w, zone.def.dimensions.h) + 20

    for i=0, zombiesInCell:size()-1 do
        ---@type IsoZombie
        local zombie = zombiesInCell:get(i)
        if zombie and not zombie:isDead() then
            local zX, zY = zombie:getX(), zombie:getY()
            local dx = zone.def.center.x - zX
            local dy = zone.def.center.y - zY
            local distFromCenter = math.sqrt(dx*dx + dy*dy)

            if distFromCenter <= luringRadius then
                local nearestPlayer = hasPlayers and zone.getNearestPlayer(players, zX, zY)

                if nearestPlayer then
                    if zombie:getTarget() ~= nearestPlayer then
                        zombie:setTarget(nearestPlayer)
                    end
                    if zombie:getThumpTarget() then zombie:setThumpTarget(nil) end
                end

                local outOfBounds = (math.abs(dx) > zone.def.dimensions.w) or (math.abs(dy) > zone.def.dimensions.h)
                if (outOfBounds or not nearestPlayer) and distFromCenter > 0 then
                    local step = math.max(2, math.min(6, distFromCenter))
                    local newX = zX + (dx/distFromCenter)*step
                    local newY = zY + (dy/distFromCenter)*step
                    zone.teleportEntity(zombie, newX, newY, zombie:getZ())
                end
            end
        end
    end
end


function zone.getAllPlayers()
    if (not zone.def or not zone.def.center) then return end
    local players = (isClient() or isServer()) and getOnlinePlayers() or IsoPlayer.getPlayers()
    if players:size() <= 0 then return false end
    return players
end


function zone.allPlayersDead(players)
    if (not zone.def or not zone.def.center) then return end
    if not players then return false end
    local hasVisiblePlayer = false
    for i=0, players:size()-1 do
        ---@type IsoPlayer|IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
        local player = players:get(i)
        if player and not player:isInvisible() then
            hasVisiblePlayer = true
            if not player:isDead() then
                return false
            end
        end
    end
    if not hasVisiblePlayer then return false end
    return true
end


function zone.hasActivePlayers(players)
    if not players then return false end
    for i=0, players:size()-1 do
        local player = players:get(i)
        if player and not player:isDead() and not player:isInvisible() then
            return true
        end
    end
    return false
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
                zone.teleportEntity(player, zone.def.center.x, zone.def.center.y, 0)
            end

        end
    end
    return true
end


function zone.onZombieDead(zombie)
    if not zone.def.center then return end

    local attacker = zombie:getAttackedBy()
    ---@type IsoPlayer|IsoGameCharacter
    local attackerPlayer = attacker and instanceof(attacker,"IsoPlayer") and attacker or false

    if (not isClient()) then
        if attackerPlayer then
            zone.highscore.update(attackerPlayer, "zombieKill")

            local value = SandboxVars.LastStandTogether.MoneyPerKill or 2
            local walletID = _internal.getWalletID(attackerPlayer)
            if walletID then
                local playerWallet = WALLET_HANDLER.getOrSetWallet(walletID)
                if playerWallet then
                    WALLET_HANDLER.validateMoneyOrWallet(playerWallet, attackerPlayer, value)
                end
            end
        end

        zone.def.currentZombies = math.max(0, (zone.def.currentZombies or 0) - 1)
    end

    if isServer() then
        zone.sendZombieCount({ currentZombies = zone.def.currentZombies })
    end
end


function zone.handleTeleportEntity(data)

    if not data or not data.onlineID then return end

    local typeOf = data.entityType --zombie --player
    local x, y, z = data.x, data.y, data.z or 0
    local onlineID = data.onlineID

    local entity
    
    if typeOf == "player" then
        entity = getPlayerByOnlineID(onlineID)

    elseif typeOf == "zombie" then
        local cell = getCell()
        if not cell then return end
        for i = 0, cell:getZombieList():size() - 1 do
            local zombie = cell:getZombieList():get(i)
            if zombie:getOnlineID() == data.onlineID then
                entity = zombie
            end
        end
    else
        print("ERROR: Unrecognized entity teleport. typeOf:", typeOf, " (ID:",onlineID,")")
    end

    if entity then
        zone.teleportEntity(entity, x, y, z)
    end
end


---@param entity IsoZombie|IsoPlayer
function zone.teleportEntity(entity, x, y, z)

    if instanceof(entity, "IsoPlayer") and isServer() then
        sendServerCommand(entity, "LastStandTogether", "teleportEntity", {entityType="player", onlineID=entity:getOnlineID(), x=x, y=y, z=z})
        return
    end

    --if instanceof(entity, "IsoZombie") and isClient() then
    --    sendClientCommand(getPlayer(), "LastStandTogether", "teleportEntity", {entityType="zombie", onlineID=entity:getOnlineID(), x=x, y=y, z=z})
    --    return
    --end

    entity:setX(x)
    entity:setY(y)
    entity:setLastX(x)
    entity:setLastY(y)
    entity:setZ(z)
end


function zone.scheduleWave()
    if zone.schedulingProcess then return end
    zone.schedulingProcess = true

    local currentTime = getTimestampMs()

    zone.clearZombies()

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


function zone.forceZombieSpawns(expectedCount)
    local inCell = zone.def.currentZombies
    if expectedCount > 0 and inCell > expectedCount then
        local need = inCell-expectedCount
        waveGen.spawnZombies(need, false)
    end
end


function zone.requestZombieCountConfirmation()
    if not isServer() then return end

    local now = getTimestampMs()
    if zone.confirmRequest.nextAllowed and now < zone.confirmRequest.nextAllowed then return end

    zone.confirmRequest.nextAllowed = now + zone.confirmRequestCooldownMs
    zone.confirmRequest.pendingTime = now + zone.confirmRequestGraceMs
end


function zone.sendZombieCountConfirmationRequest()
    local players = getOnlinePlayers()
    if players:size() <= 0 then return end

    local random = ZombRand(players:size())
    local player = players:get(random)
    sendServerCommand(player, "LastStandTogether", "confirmZombieCountWithClient", {})
end


function zone.checkZombieCountSafety()
    local now = getTimestampMs()

    zone.def.zombieCountSafety = zone.def.zombieCountSafety or {}

    if zone.def.zombieCountSafety.time and zone.def.zombieCountSafety.time > now then return end
    zone.def.zombieCountSafety.time = now + 15000

    local tracked = zone.def.currentZombies or 0
    local inCell = zone.getTrueZombieCount()

    if tracked > 0 and inCell < tracked then
        local need = tracked - inCell
        waveGen.spawnZombies(need, true)
        if isServer() then zone.sendZombieCount() end
        zone.def.zombieCountSafety.zombieCount = tracked
        return
    end

    local prev = zone.def.zombieCountSafety.zombieCount
    if prev and prev == tracked and tracked > 0 and inCell == 0 then
        waveGen.spawnZombies(1, true)
        if isServer() then zone.sendZombieCount() end
    end

    zone.def.zombieCountSafety.zombieCount = tracked
end


function zone.getTrueZombieCount()
    local zombiesRaw = getCell():getZombieList()
    local zombiesInCell = 0
    for i=0, zombiesRaw:size()-1 do
        ---@type IsoPlayer|IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
        local zombie = zombiesRaw:get(i)
        if zombie then
            zombiesInCell = zombiesInCell + 1
        end
    end
    return zombiesInCell
end


function zone.schedulerLoop()
    if not zone.restoreAttempted then
        zone.tryRestore()
    end

    if not (zone.initiateLoop and zone.def and zone.def.center) then
        local random = (SandboxVars.LastStandTogether.AutoSelectRandomBuilding or false)
        if random then zone.setToBuildingRandom() end
        return
    end

    --- Pause detection: if tick gap exceeds 2 seconds, shift all active timestamps forward
    local now = getTimestampMs()
    if zone.lastTickTime then
        local delta = now - zone.lastTickTime
        if delta > 2000 then
            local adjust = delta - 33
            if zone.def.nextWaveTime and type(zone.def.nextWaveTime) == "number" then
                zone.def.nextWaveTime = zone.def.nextWaveTime + adjust
            end
            if zone.def.spawnTickTimer and zone.def.spawnTickTimer > 0 then
                zone.def.spawnTickTimer = zone.def.spawnTickTimer + adjust
            end
            if zone.def.resetCooldown and type(zone.def.resetCooldown) == "number" then
                zone.def.resetCooldown = zone.def.resetCooldown + adjust
            end
            if zone.clearingZombies then
                zone.clearingZombies = zone.clearingZombies + adjust
            end
            if zone.confirmRequest.pendingTime then
                zone.confirmRequest.pendingTime = zone.confirmRequest.pendingTime + adjust
            end
            if zone.confirmRequest.nextAllowed then
                zone.confirmRequest.nextAllowed = zone.confirmRequest.nextAllowed + adjust
            end
        end
    end
    zone.lastTickTime = now

    if isServer() and zone.confirmRequest.pendingTime and now > zone.confirmRequest.pendingTime then
        zone.confirmRequest.pendingTime = nil
        zone.sendZombieCountConfirmationRequest()
    end

    local players = zone.getAllPlayers()
    local activePlayers = zone.hasActivePlayers(players)

    if (not zone.def.wave) and (not activePlayers) then
        if not zone.def.warningNoPlayers then
            zone.def.warningNoPlayers = true
            zone.clearZombies()
            zone.def.error = "Waiting for a living player to enter the zone."
            zone.sendZoneDef()
        end
        return
    end

    zone.def.error = ""
    zone.def.warningNoPlayers = false

    local currentTime = getTimestampMs()

    if isServer() and (not zone.boundaryEnforceTimer or currentTime > zone.boundaryEnforceTimer) then
        zone.boundaryEnforceTimer = currentTime + 1000
        zone.enforceZoneBoundaries()
    end

    if not zone.def.wave and not zone.def.nextWaveTime then
        zone.scheduleWave()
        return
    end

    if zone.def.resetCooldown then
        if currentTime > zone.def.resetCooldown then
            zone.setToBuildingRandom()
        end
        return
    end

    --- zombies left to spawn
    if zone.def.zombiesToSpawn and zone.def.zombiesToSpawn > 0 then
        if not zone.def.spawnTickTimer or currentTime > zone.def.spawnTickTimer then
            local batchSize = math.min(100, zone.def.zombiesToSpawn)
            local spawned = waveGen.spawnZombies(batchSize, false)
            zone.def.zombiesToSpawn = math.max(0, zone.def.zombiesToSpawn - spawned)
            zone.def.spawnTickTimer = currentTime + ((SandboxVars.LastStandTogether.InWaveSpawnInterval or 2) * 60000)
            zone.def.zombiesSpawned = (zone.def.zombiesSpawned or 0) + spawned
            zone.def.currentZombies = (zone.def.currentZombies or 0) + spawned
            if isServer() then zone.sendZombieCount() end
        end
        return
    end

    local zombiesLeft = (zone.def.currentZombies or 0) + (zone.def.zombiesToSpawn or 0)

    local zombiesInCell = zone.getTrueZombieCount()

    if zone.def.wave == 0 and zombiesInCell > 0 then
        if not zone.clearingZombies or currentTime > zone.clearingZombies then
            zone.clearZombies()
        end
    end

    if zombiesLeft > 0 and (zone.def.zombiesSpawned or 0) > 0 and (zombiesLeft / zone.def.zombiesSpawned <= 0.15 or zombiesLeft <= 5) then
        zone.checkZombieCountSafety()
    end

    --[[
    print("zombiesLeft: ", zombiesLeft, " zombiesInCell: ", zombiesInCell)
    local cellZombies = getCell():getZombieList()
    for z=0, cellZombies:size()-1 do
        ---@type IsoZombie
        local zombie = cellZombies:get(z)
        print(z, " ", zombie:getOnlineID(), " ", zombie)
    end
    --]]

    if zombiesLeft > 0 and zombiesLeft > zombiesInCell then
        local need = math.max(0, zombiesLeft - zombiesInCell)
        if not zone.missingZombieTimer or currentTime > zone.missingZombieTimer then
            zone.missingZombieTimer = currentTime + 5000
            local spawned = waveGen.spawnZombies(need, true)
            print("WARNING: Zombies In Cell: ", zombiesInCell, " tracked: ", zombiesLeft, "  wanted: ", need, "  spawned: ", spawned)
            zone.def.error = "Zombies went missing - respawning " .. (spawned or 0) .. " to compensate."
            if isServer() then zone.sendZombieCount() end
            zone.sendZoneDef()
        end
        return
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
            zone.saveState()
        end
        return
    end

    if currentTime > zone.def.nextWaveTime and zombiesLeft <= 0 then
        zone.scheduleWave()
        return
    end

end


function zone.validationFailed(playerObj)
    playerObj:setX(zone.def.center.x)
    playerObj:setY(zone.def.center.y)
    playerObj:setLx(zone.def.center.x)
    playerObj:setLy(zone.def.center.y)
    playerObj:setZ(0)
    playerObj:Kill(nil)
end


function zone.validateLogin(playerObj)
    if not zone.def or not zone.def.center then print(" x NO ZONE") return end
    local respawnRule = SandboxVars.LastStandTogether.PlayerRespawn
    if respawnRule ~= 3 then
        local currentScore = zone.highscore.currentPlayers[playerObj:getUsername()]
        local cannotRespawn = currentScore and ((respawnRule == 1 and currentScore.dead) or (respawnRule == 2 and zone.def.wave == currentScore.dead))
        local isDead = currentScore and currentScore.dead
        if isDead and cannotRespawn then
            sendServerCommand(playerObj, "LastStandTogether", "validationFailed", {})
        end
    end
end


function zone.onPlayerCreate() Events.OnPlayerUpdate.Add(LastStandTogether_Zone.onLogin) end
function zone.onLogin()
    zone.clientSideLoginCheck = (zone.clientSideLoginCheck or 2) - 1
    if zone.clientSideLoginCheck <=0 then
        lastStandTogetherWaveAlert:setToScreen()
        if isClient() then
            sendClientCommand(getPlayer(),"LastStandTogether", "requestZone", {})
            sendClientCommand(getPlayer(),"LastStandTogether", "requestHighscores", {login=true})
        end
        Events.OnPlayerUpdate.Remove(LastStandTogether_Zone.onLogin)
    end
end


zone.serverOnlyFields = {
    zombieCountSafety = true,
    popMulti = true,
    waveCooldown = true,
    zombiesSpawned = true,
}

function zone.getClientDef()
    local filtered = {}
    for k, v in pairs(zone.def) do
        if not zone.serverOnlyFields[k] then filtered[k] = v end
    end
    return filtered
end

function zone.sendZoneDef(player)
    if isServer() then
        local data = zone.getClientDef()
        if player then
            sendServerCommand(player, "LastStandTogether", "updateZone", data)
        else
            sendServerCommand("LastStandTogether", "updateZone", data)
        end
    end
end


function zone.checkIfShopsEmpty()
    local shops = (isServer() and GLOBAL_STORES) or CLIENT_STORES
    local empty = true
    for _,_ in pairs(shops) do empty = false break end
    return empty, shops
end


function zone.loadOrCreateShops()
    local empty, shops = zone.checkIfShopsEmpty()

    if empty then
        local tbl, err = zone.loadShopsFromServer()
        if err then
            zone.def.error = "Shop data failed to load - check server logs."
            print("ERROR: shops failed to load from server! \n"..err)
        elseif tbl then
            empty = false
            zone.def.error = "Shops loaded from saved data."
            print("Shops Loaded From Server Files!")
            for shopID,shopData in pairs(tbl) do shops[shopID] = copyTable(shopData) end
        end
    end

    if empty then
        zone.def.error = zone.def.error .. " Using default shops."
        print("Warning: Default Shops Enabled!")
        local defaultShops = require "LastStandTogether_defaultShops.lua"
        for shopID,shopData in pairs(defaultShops) do
            local shop = copyTable(shopData)
            if shop.listings then
                for listingKey,listing in pairs(shop.listings) do
                    if not listing.id then listing.id = listingKey end
                end
            end
            shops[shopID] = shop
        end
        --- Persist defaults into the JSON file so they survive restarts
        if not isClient() or isServer() then
            for shopID,shopData in pairs(shops) do GLOBAL_STORES[shopID] = shops[shopID] end
            STORE_HANDLER.saveToFile()
        end
    end

    if not shops then
        zone.def.error = zone.def.error .. " Shop generation failed - no items available."
        print("ERROR: Shops failed to generate!")
    end

    return shops
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
        zone.def.error = "No active game to reset markers for."
        return
    end

    zone.def.shopMarkersInRoom = {}
    zone.def.shopMarkersRooms = {}

    local shops = zone.loadOrCreateShops()
    if not shops then return end

    STORE_HANDLER.restocking()

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
                            table.insert(zone.def.shopMarkersInRoom[roomID],{ x=sq:getX(), y=sq:getY(), z=(sq:getZ()+zOffset), shopID=shopID })
                        end
                    end
                end
            end
        end
    end

    zone.setRoomsWithShopsMarkers()
    zone.sendZoneDef()
end


function zone.loadShopsFromServer()
    return STORE_HANDLER.loadFromFile()
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
        zone.def.error = "No valid containers found in this building for shops."
        return
    end

    local shops = zone.loadOrCreateShops()
    if not shops then return end

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
    print("Lasts Stand Together: available containers for shops: ", #allContainers)

    STORE_HANDLER.restocking()

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
                        table.insert(zone.def.shopMarkersInRoom[roomID],{ x=sq:getX(), y=sq:getY(), z=(sq:getZ()+zOffset), shopID=shopID })
                        STORE_HANDLER.updateStore(storeObj, shopID)
                    end
                end
            end
        end
    end
    print("Lasts Stand Together: assigned shops: ", assignedShops)

    zone.setRoomsWithShopsMarkers()
    zone.sendZoneDef()
end


---@param player IsoObject|IsoMovingObject|IsoGameCharacter|IsoPlayer
function zone.setToCurrentBuilding(player)

    local building = player:getCurrentBuilding()
    if not building then
        zone.def = {}
        zone.def.error = "You must be inside a building to start the game."
        zone.sendZoneDef()
        return
    end

    local buildingDef = building and building:getDef()
    if not buildingDef then
        zone.def = {}
        zone.def.error = "This building could not be read. Try a different one."
        zone.sendZoneDef()
        return
    end

    local buildingID = buildingDef and buildingDef:getID()
    if building and zone.def.buildingID and zone.def.buildingID == buildingID then
        zone.def = {}
        zone.def.error = "Game ended. Select a new building or press Start again to restart."
        zone.sendZoneDef()
        return
    end

    zone.setToBuilding(buildingDef)
end


function zone.clearZombies()
    local now = getTimestampMs()
    if zone then
        if zone.clearingZombies and zone.clearingZombies > now then return end
        zone.clearingZombies = now + 1000
    end

    local cell = getCell()
    ---@type ArrayList
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


function zone.trimZombies()

    local cell = getCell()
    local zombieList = cell:getZombieList()
    local inCell = zombieList:size()
    local target = zone and zone.def and zone.def.currentZombies or 0
    local toRemove = math.max(0, inCell - target)

    if toRemove > 0 then
        for z = inCell - 1, math.max(0, inCell - toRemove), -1 do
            local zombie = zombieList:get(z)
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

    if not zone.restoring then
        zone.def = {}
    end

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
    if not zone.restoring then
        zone.highscore.reset()
    else
        zone.highscore.setAllPlayers()
    end
    zone.finalSteps = false
    Events.OnTick.Add(zone.scheduledFinalSetup)
    zone.saveState()
end


function zone.scheduledFinalSetup()

    local players = zone.getAllPlayers()
    if not players then return end

    if not zone.finalSteps then
        if zone.restoring then
            zone.finalSteps = { "establishShops", "sendScores", "teleport", "sendDef", "trimZombies"}
        else
            zone.finalSteps = { "clearZombies", "establishShops", "sendScores", "teleport", "sendDef"}
        end
        zone.finalStepsTime = getTimestampMs() + 100
        return
    end

    if zone.finalStepsTime > getTimestampMs() then return end

    if #zone.finalSteps > 0 then
        local step = zone.finalSteps[#zone.finalSteps]

        if step == "sendDef" then
            zone.sendZoneDef()
            zone.finalSteps[#zone.finalSteps] = nil
            zone.finalStepsTime = getTimestampMs() + 100

        elseif step == "teleport" then
            local tpPlayers = zone.getAllPlayers()
            zone.teleportPlayersToZone(tpPlayers)
            zone.finalSteps[#zone.finalSteps] = nil
            zone.finalStepsTime = getTimestampMs() + 400

        elseif step == "sendScores" then
            zone.highscore.sendHighScore()
            zone.finalSteps[#zone.finalSteps] = nil
            zone.finalStepsTime = getTimestampMs() + 100

        elseif step == "establishShops" then
            local x = zone.def.center.x
            local y = zone.def.center.y
            local sq = getSquare(x, y, 0)
            local buildingDef = getWorld():getMetaGrid():getBuildingAtRelax(x, y)
            if sq and  buildingDef then
                zone.establishShopFront(buildingDef)
                zone.finalSteps[#zone.finalSteps] = nil
            end
            zone.finalStepsTime = getTimestampMs() + 300

        elseif step == "clearZombies" or step == "trimZombies" then
            local x = zone.def.center.x
            local y = zone.def.center.y

            local sq = getSquare(x, y, 0)
            if sq then
                zone[step]()
                zone.finalSteps[#zone.finalSteps] = nil
            end
            zone.finalStepsTime = getTimestampMs() + 300
        end
        return
    end

    if #zone.finalSteps <= 0 then
        if zone.restoring then
            zone.restoring = false
            zone.def.currentZombies = zone.getTrueZombieCount()
        end
        Events.OnTick.Remove(zone.scheduledFinalSetup)
    end
end


function zone.allPlayersHaveDied()
    if zone.def.resetCooldown then return end
    zone.def.resetCooldown = getTimestampMs() + zone.resetCooldown
    zone.sendZoneDef()
end


function zone.setToBuildingRandom()
    ---@type BuildingDef
    local buildingDef = zone.seekNewBuilding()
    zone.setToBuilding(buildingDef)
end


function zone.seekNewBuilding()
    local metaGrid = getWorld():getMetaGrid()
    if not metaGrid then print("Last Stand Together: No Meta Grid Found") return end

    local buildings = metaGrid and metaGrid:getBuildings()
    if not buildings then print("Last Stand Together: No Buildings Found") return end

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