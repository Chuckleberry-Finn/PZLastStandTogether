LastStandTogether_Zone = LastStandTogether_Zone or require "LastStandTogether_zoneHandler.lua"

if not isClient() then --SP and Server Only
    if LastStandTogether_Zone then
        Events.OnTick.Add(LastStandTogether_Zone.schedulerLoop)
    end
end

Events.OnZombieDead.Add(LastStandTogether_Zone.onDead)

if isServer() then
    local function onClientCommand(_module, _command, _player, _data)
        if _module ~= "LastStandTogether" then return end
        if _command == "setZone" then LastStandTogether_Zone.setToCurrentBuilding(_player) end
        if _command == "requestZone" then
            print("ZONE DEF REQUESTED!")
            LastStandTogether_Zone.sendZoneDef(_player)
        end
    end
    Events.OnClientCommand.Add(onClientCommand)--what the server gets from the client
end


if isClient() then

    Events.OnPlayerUpdate.Add(LastStandTogether_Zone.onLogin)

    local function onServerCommand(_module, _command, _data)
        if _module ~= "LastStandTogether" then return end
        if _command == "updateZone" then
            LastStandTogether_Zone.def = _data
            LastStandTogether_Zone.sendZoneDef()--this called on clientside sets the wave UI
        end
    end
    Events.OnServerCommand.Add(onServerCommand)--what clients gets from the server
end