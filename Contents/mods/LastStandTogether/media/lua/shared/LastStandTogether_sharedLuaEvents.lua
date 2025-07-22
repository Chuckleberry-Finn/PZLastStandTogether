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
        if _command == "requestZone" then LastStandTogether_Zone.sendZoneDef(_player) end
        if _command == "resetShopMarkers" then LastStandTogether_Zone.resetShopMarkers() end
        if _command == "updateZoneDefPlayerDeaths" then LastStandTogether_Zone.onPlayerDeath(_player) end
    end
    Events.OnClientCommand.Add(onClientCommand)--what the server gets from the client
end

Events.OnInitWorld.Add(LastStandTogether_Zone.setSandboxForLastStand)


if isClient() then

    Events.OnPlayerUpdate.Add(LastStandTogether_Zone.onLogin)

    local function onServerCommand(_module, _command, _data)
        if _module ~= "LastStandTogether" then return end
        if _command == "updateZoneDefPlayerDeaths" then
            table.insert(LastStandTogether_Zone.playerDeaths, {username=_data.username, expire=getTimestampMs()+LastStandTogether_Zone.deathLogFade} )
        end
        if _command == "updateZoneDefZombies" then LastStandTogether_Zone.def.zombies = _data.zombies end
        if _command == "updateZone" then
            LastStandTogether_Zone.def = _data
            LastStandTogether_Zone.sendZoneDef()--this called on clientside sets the wave UI
        end
    end
    Events.OnServerCommand.Add(onServerCommand)--what clients gets from the server
end