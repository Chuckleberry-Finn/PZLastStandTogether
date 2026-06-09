LastStandTogether_Zone = LastStandTogether_Zone or require "LastStandTogether_zoneHandler.lua"

if not isClient() then --SP and Server Only
    if LastStandTogether_Zone then
        Events.OnTick.Add(LastStandTogether_Zone.schedulerLoop)
    end
end

Events.OnZombieDead.Add(LastStandTogether_Zone.onZombieDead)
Events.OnPlayerDeath.Add(LastStandTogether_Zone.onPlayerDeath)

if isServer() then
    local function onClientCommand(_module, _command, _player, _data)
        if _module ~= "LastStandTogether" then return end
        if _command == "setZone" then LastStandTogether_Zone.setToCurrentBuilding(_player) end
        if _command == "setZoneRandom" then LastStandTogether_Zone.setToBuildingRandom() end
        if _command == "requestZone" then LastStandTogether_Zone.sendZoneDef(_player) end
        if _command == "requestHighscores" then
            local player = not _data.login and _player or nil
            LastStandTogether_Zone.highscore.sendHighScore(player)
            if _data.login then LastStandTogether_Zone.validateLogin(_player) end
        end
        if _command == "resetShopMarkers" then LastStandTogether_Zone.resetShopMarkers() end
        if _command == "updateZoneDefPlayerDeaths" then LastStandTogether_Zone.onPlayerDeath(_player) end

        if _command == "teleportEntity" then
            LastStandTogether_Zone.handleTeleportEntity(_data)
        end
        if _command == "applyOutOfBoundsDamage" then
            if _player and _data.dmg then _player:getBodyDamage():ReduceGeneralHealth(_data.dmg) end
        end

        if _command == "spawnZombieTest" then
            addZombiesInOutfit(_player:getX()+5, _player:getY()+5, 0, 1, nil, nil)
            --sendClientCommand("LastStandTogether", "spawnZombieTest", { })
        end
    end
    Events.OnClientCommand.Add(onClientCommand)--what the server gets from the client
end

if not isClient() then --SP and Server
    ---NOTE: THIS DOESNT SEEM TO FIRE ON SERVER IT IS UNCLEAR WHY
    Events.OnSave.Add(LastStandTogether_Zone.highscore.save)
    Events.OnSave.Add(LastStandTogether_Zone.saveState)
end

Events.OnInitWorld.Add(LastStandTogether_Zone.setSandboxForLastStand)


if isClient() then
    local function onServerCommand(_module, _command, _data)
        if _module ~= "LastStandTogether" then return end
        if _command == "validationFailed" then LastStandTogether_Zone.validationFailed(getPlayer()) end
        if _command == "receiveHighScore" then LastStandTogether_Zone.highscore.receiveHighScore(_data) end
        if _command == "updateZoneDefPlayerDeaths" then
            table.insert(LastStandTogether_Zone.playerDeaths, {username=_data.username, expire=getTimestampMs()+LastStandTogether_Zone.deathLogFade} )
        end
        if _command == "updateZoneDefZombies" then LastStandTogether_Zone.sendZombieCount(_data) end
        if _command == "updateZone" then LastStandTogether_Zone.def = _data end

        if _command == "teleportEntity" then
            LastStandTogether_Zone.handleTeleportEntity(_data)
        end
    end
    Events.OnServerCommand.Add(onServerCommand)--what clients gets from the server
end


if not isServer() then
    Events.OnCreatePlayer.Add(LastStandTogether_Zone.onPlayerCreate)
end