local waveGenerator = {}

function waveGenerator.spawnZombieRing(numberOf, x1, y1, x2, y2)

    numberOf = math.floor(numberOf)

    local spawnedZombies = 0
    local attempts = 0
    local maxAttempts = 1000

    while spawnedZombies < numberOf and attempts <= maxAttempts do

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
            --addZombieSitting(x, y, 0)
            if spawned and spawned:size() > 0 then
                spawnedZombies = spawnedZombies + 1
            else
                print("ERROR: WAVE-GEN: spawnZombie FAILED!")
            end
        end
    end

    if attempts >= maxAttempts then
        print("WARNING: Max attempts reached when spawning zombies, consider a different location.   spawnedZombies:",spawnedZombies, "  expected: ",numberOf)
    end

    return spawnedZombies
end


function waveGenerator.spawnZombies(numberOf, isCorrective)

    local LST_zone = LastStandTogether_Zone
    if not LST_zone then print("ERROR: spawnZombies FAILED! - NO LST_zone!") return end

    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.dimensions then print("ERROR: spawnZombies FAILED! - zoneDef invalid!") return end

    local ringPadding = 12
    local maxLoadedTileRadius = 60
    local wOffset = math.min(maxLoadedTileRadius, (zoneDef.dimensions.w/2) + ringPadding)
    local hOffset = math.min(maxLoadedTileRadius, (zoneDef.dimensions.h/2) + ringPadding)

    local x1 = zoneDef.center.x-wOffset
    local y1 = zoneDef.center.y-hOffset
    local x2 = zoneDef.center.x+wOffset
    local y2 = zoneDef.center.y+hOffset

    numberOf = math.floor(numberOf)

    local trueCountBefore = LST_zone.getTrueZombieCount()
    local spawnedZombies = waveGenerator.spawnZombieRing(numberOf, x1, y1, x2, y2)

    local verifyRetries = 0
    local maxVerifyRetries = 3
    while verifyRetries < maxVerifyRetries do
        local actualGained = LST_zone.getTrueZombieCount() - trueCountBefore
        local shortfall = spawnedZombies - actualGained
        if shortfall <= 0 then break end
        spawnedZombies = spawnedZombies + waveGenerator.spawnZombieRing(shortfall, x1, y1, x2, y2)
        verifyRetries = verifyRetries + 1
    end

    getWorldSoundManager():addSound(nil, zoneDef.center.x, zoneDef.center.y, 0, 600, 100, false, 1000, 100)

    if isServer() and isCorrective then
        LST_zone.requestZombieCountConfirmation()
    end

    return spawnedZombies
end

return waveGenerator
