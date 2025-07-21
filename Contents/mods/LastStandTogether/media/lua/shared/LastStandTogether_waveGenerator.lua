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

    local spawnedZombies = 0
    local attempts = 0
    local maxAttempts = 1000

    while spawnedZombies < numberOf and attempts < maxAttempts do

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

        attempts = attempts + 1

        local square = getSquare(x, y, 0)
        if square and not square:isSolidTrans() then
            local spawned = addZombiesInOutfit(x, y, 0, 1, nil, nil)
            if spawned and spawned:size() > 0 then
                ---@type IsoObject|IsoMovingObject|IsoGameCharacter|IsoZombie
                local zombie = spawned:get(0)
                spawnedZombies = spawnedZombies + 1
            else
                print("ERROR: WAVE-GEN: spawnZombie FAILED!")
            end

            if isServer() then
                ---@type IsoPlayer|IsoObject|IsoGameCharacter
                local playerObj = players:get(player)
                if not playerObj:isDead() and not playerObj:isInvisible() then
                    AddWorldSound(players:get(player), 600, 600)
                end
                player = player + 1
                if player >= players:size() then player = 0 end
            else
                local playerObj = getPlayer()
                if not playerObj:isDead() and not playerObj:isInvisible() then
                    AddWorldSound(playerObj, 600, 600)
                end
            end
        end

    end

    if attempts >= maxAttempts then
        print("WARNING: Max attempts reached when spawning zombies, consider a different location.   spawnedZombies:",spawnedZombies, "  expected: ",numberOf)
    end

    return spawnedZombies
end

return waveGenerator