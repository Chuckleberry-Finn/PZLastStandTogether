local networkHandler = {}

--[[
---@param player IsoPlayer|IsoGameCharacter
function networkHandler.sendUpdate(player)
    if not player then return end

    if isClient() then
        sendClientCommand(player, "LastStandTogether", "updateZone", dataToSend)
    else
        networkHandler.receiveUpdate(dataToSend)
    end
end
--]]

function networkHandler.receiveUpdate(data)--x, y, z
    if isServer() then return end
    LastStandTogether_Zone.def = data
    if lastStandTogetherWaveAlert and (not lastStandTogetherWaveAlert.instance) then
        lastStandTogetherWaveAlert:setToScreen()
    end
end

return networkHandler