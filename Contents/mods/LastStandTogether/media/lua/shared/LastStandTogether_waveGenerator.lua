local waveGenerator = {}

function waveGenerator.spawnZombies(numberOf)

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then return end

    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.radius then return end

    local x1 = zoneDef.center.x-(zoneDef.radius*2)
    local y1 = zoneDef.center.y-(zoneDef.radius*2)
    local x2 = zoneDef.center.x+(zoneDef.radius*2)
    local y2 = zoneDef.center.y+(zoneDef.radius*2)

    numberOf = math.floor(numberOf)

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
            if zombie then
                zombie:pathToLocationF(zoneDef.center.x,zoneDef.center.y,0)
            end
        else
            print("ERROR: NO ZOMBIES SPAWNED, EXPECTED: ", numberOf)
        end
    end

    if isServer() then
        sendClientCommand("LastStandTogether", "callZombies", {x=zoneDef.center.x, y=zoneDef.center.y})
    else
        addSound(nil, zoneDef.center.x, zoneDef.center.y, 0, 301, 1000)
    end
end

return waveGenerator