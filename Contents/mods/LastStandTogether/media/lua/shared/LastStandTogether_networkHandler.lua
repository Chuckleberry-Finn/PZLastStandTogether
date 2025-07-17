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
    LastStandTogether_Zone.def = data
    if not lastStandTogetherWaveAlert.instance then
        lastStandTogetherWaveAlert:setToScreen()
    end
end

return networkHandler