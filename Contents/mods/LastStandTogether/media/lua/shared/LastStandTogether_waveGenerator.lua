local waveGenerator = {}

function waveGenerator.spawnZombies(numberOf)

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then print("ERROR: spawnZombies FAILED! - NO LST_zone!") return end

    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.radius then print("ERROR: spawnZombies FAILED! - zoneDef invalid!") return end

    local x1 = zoneDef.center.x-50
    local y1 = zoneDef.center.y-50
    local x2 = zoneDef.center.x+50
    local y2 = zoneDef.center.y+50

    numberOf = math.floor(numberOf)

    local player = 0
    local players = (isServer() and getOnlinePlayers())

    zoneDef.zombies = numberOf

    for i=1, numberOf do

        local side = ZombRand(4)+1

        local x, y = x1, y1

        if side == 1 then
            x = x1
            y = ZombRand(y1,y2)+1
        elseif side == 2 then
            x = x2
            y = ZombRand(y1,y2)+1

        elseif side == 3 then
            x = ZombRand(x1,x2)+1
            y = y1
        else --4
            x = ZombRand(x1,x2)+1
            y = y2
        end


        local spawned = addZombiesInOutfit(x, y, 0, 1, nil, nil)
        if spawned and spawned:size() > 0 then
            ---@type IsoObject|IsoMovingObject|IsoGameCharacter|IsoZombie
            local zombie = spawned:get(0)
        else
            print("ERROR: WAVE-GEN: spawnZombie FAILED!")
        end

        if isServer() then
            AddWorldSound(players:get(player), 600, 600)
            player = player + 1
            if player >= players:size() then player = 0 end
        else
            AddWorldSound(getPlayer(), 600, 600)
        end
    end
end

return waveGenerator