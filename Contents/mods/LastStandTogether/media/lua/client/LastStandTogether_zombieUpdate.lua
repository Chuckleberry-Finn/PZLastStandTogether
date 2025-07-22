local onZombieUpdate = {}

---@param zombie IsoZombie
function onZombieUpdate.retarget(zombie)

    local player = getPlayer()
    if zombie:getTarget() ~= player then

        local LST_zone = LastStandTogether_Zone
        if not LST_zone then return end
        local zoneDef = LST_zone.def
        if not zoneDef or not zoneDef.center or not zoneDef.radius then return end

        local zX, zY = zombie:getX(), zombie:getY()
        local dx = math.abs(zoneDef.center.x-zX)
        local dy = math.abs(zoneDef.center.y-zY)

        if ((dx) > zoneDef.radius) or ((dy) > zoneDef.radius) then
            --[[
            local thumped = zombie:getThumpTarget()
            if thumped then zombie:setThumpTarget(nil) end

            zombie:addLineChatElement("!", 1, 1, 1, UIFont.Medium, 1000, "default")
            --]]
            zombie:spotted(player, true)
        end
    end
end


return onZombieUpdate