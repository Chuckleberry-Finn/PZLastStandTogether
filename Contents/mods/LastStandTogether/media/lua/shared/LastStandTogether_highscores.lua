local highscore = {}

highscore.currentPlayers = {}
highscore.currentPlayersSort = {}
highscore.crowned = {}

highscore.textures = {
    blood = getTexture("media/textures/ui/bloodCrown.png"),
    skull = getTexture("media/textures/ui/lastStandSkull.png"),
    metal = {
        getTexture("media/textures/ui/goldCrown.png"),
        getTexture("media/textures/ui/silverCrown.png"),
        getTexture("media/textures/ui/bronzeCrown.png"),
    }
}

--{
--  highscore.crowned.topKills = {
--    { displayName = "Player1", kills = 45 },
--    { displayName = "Player2", kills = 32 },
--    { displayName = "Player3", kills = 30 },
--  },
--  highscore.crowned.topWave = {
--    wave = 12,
--    players = { "Player1", "Player2", "Player3", },
--  },
--}

function highscore.drawTextBoxed(UI, text, x, y, a, right, crossed)
    local r, g, b, font, height = 0.9, 0.2, 0.2, UIFont.Small, UI.textSmallH
    local w = getTextManager():MeasureStringX(font, text)
    UI:drawRect(x-4, y-1, w+8, height+1, 0.4, 0, 0, 0)

    local style = right and "drawTextRight" or "drawText"
    UI[style](UI, text, x, y, r, g, b, (a or 1), font)

    if crossed then
        UI:drawRectBorder(x, y+(height/2)-2, w, 1, 1, 0.9, 0.2, 0.2)
    end

    return {x=x-4, y=y-1, w=w+8, h=height+1}
end


function highscore.render(UI, x, y)
    UI.highscoreZone = {x=x, y=y, w=32, h=32}

    if UI.showHighScore then
        UI:drawTextureScaled(highscore.textures.skullOpen, UI.highscoreZone.x, UI.highscoreZone.y, UI.highscoreZone.w, UI.highscoreZone.h, 1, 1, 1, 1)
    else
        UI:drawTextureScaled(highscore.textures.skull, UI.highscoreZone.x, UI.highscoreZone.y, UI.highscoreZone.w, UI.highscoreZone.h, 1, 1, 1, 1)
        return
    end

    y = y + 32 + UI.textSmallH*2

    if highscore.crowned.topWave and highscore.crowned.topWave.wave then
        local tooltipZone = highscore.drawTextBoxed(UI, "TOP WAVE: "..highscore.crowned.topWave.wave, x, y)
        UI:drawTextureScaled(highscore.textures.blood, x-32, y-8, 32, 32, 1, 1, 1, 1)
        UI.waveToolTipZone = tooltipZone
        y = y + UI.textSmallH*2

        if UI.showTopWaveTooltip then
            local tempY = y
            for i=1, #highscore.crowned.topWave.players do
                local playerName = highscore.crowned.topWave.players[i]
                highscore.drawTextBoxed(UI, (playerName), x-48, tempY, 1, true)
                tempY = tempY + UI.textSmallH+4
            end
        end
    end

    if highscore.crowned.topKills and (#highscore.crowned.topKills > 0) then
        highscore.drawTextBoxed(UI, "HIGHSCORES: ", x-20, y)
        y = y + UI.textSmallH*1.25+4

        for i=1, #highscore.crowned.topKills do
            local data = highscore.crowned.topKills[i]
            local kills = data.kills or 0
            local displayName = data.displayName
            local shortName = string.sub(displayName, 1, 25)
            if displayName then
                highscore.drawTextBoxed(UI, (shortName.."    kills: "..tostring(kills)), x, y)
                local texture = highscore.textures.metal[i]
                if texture then UI:drawTextureScaled(texture, x-32, y-8, 32, 32, 1, 1, 1, 1) end
                y = y + UI.textSmallH+4
            end
        end
        y = y + UI.textSmallH*2
    end

    if (#highscore.currentPlayersSort > 0) then
        highscore.drawTextBoxed(UI, "KILLS: ", x-20, y)
        y = y + UI.textSmallH*1.25+4

        for i=1, #highscore.currentPlayersSort do
            local data = highscore.currentPlayersSort[i]
            local kills = data.kills or 0
            local displayName = data.displayName
            local dead = data.dead
            if displayName then
                highscore.drawTextBoxed(UI, displayName.."    kills: "..tostring(kills), x, y, (dead and 0.7), false, dead)
                y = y + UI.textSmallH+4
            end
        end
        --y = y + UI.textSmallH*2
    end
end


function highscore.reCrown()
    highscore.currentPlayersSort = {}
    for username, data in pairs(highscore.currentPlayers) do
        local displayName = data.steam and data.steam.profileName or username
        local dead = true
        local playerObj = highscore.fetchPlayerObject(username)
        if playerObj and (not playerObj:isDead()) then
            dead = false
        end
        table.insert(highscore.currentPlayersSort, { displayName = displayName, kills = data.kills, username=username, dead=dead })
    end

    table.sort(highscore.currentPlayersSort, function(a, b) return a.kills > b.kills end)

    local seen = {}

    if highscore.crowned.topKills then
        for i=1, #highscore.crowned.topKills do
            local record = highscore.crowned.topKills[i]
            if record then
                seen[record.displayName] = { displayName = record.displayName, kills = record.kills }
            end
        end
    end

    for i=1, #highscore.currentPlayersSort do
        local record = highscore.currentPlayersSort[i]
        if record and record.kills and record.kills > 0 then
            local name = record.displayName
            local existing = seen[name]
            if not existing or record.kills > existing.kills then
                seen[name] = { displayName = name, kills = record.kills }
            end
        end
    end

    local blended = {}
    for _, record in pairs(seen) do table.insert(blended, record) end

    table.sort(blended, function(a, b) return a.kills > b.kills end)
    for i = 4, #blended do blended[i] = nil end

    highscore.crowned.topKills = blended
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
function highscore.update(player, type, username)
    username = username or player:getUsername()
    if type == "died" then
        highscore.currentPlayers[username].dead = true
    end

    if type == "zombieKill" then
        local kills = highscore.currentPlayers[username].kills or 0
        highscore.currentPlayers[username].kills = kills + 1
    end

    if not isClient() then
        highscore.reCrown()
        highscore.save()
    end
    if isServer() then highscore.sendHighScore() end
end


function highscore.receiveHighScore(data)
    highscore.currentPlayers = (data.currentPlayers)
    highscore.crowned = (data.crowned)
    highscore.reCrown()
end


function highscore.sendHighScore(player)
    if not isClient() then highscore.setAllPlayers() end
    if isServer() then
        local data = {
            currentPlayers = highscore.currentPlayers,
            crowned = highscore.crowned,
        }

        if player then
            sendServerCommand(player, "LastStandTogether", "receiveHighScore", data)
        else
            sendServerCommand("LastStandTogether", "receiveHighScore", data)
        end
    end
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
function highscore.setIntoCurrentPlayers(player)
    local username = player:getUsername()
    if highscore.currentPlayers[username] then return end
    local steam = {}
    if getSteamModeActive() then
        steam.ID = isClient() and player:getSteamID() or getCurrentUserSteamID()
        steam.profileName = isClient() and getSteamProfileNameFromSteamID(steam.ID) or getCurrentUserProfileName()
    end
    highscore.currentPlayers[username] = {steam=steam, kills=0}
end


function highscore.setAllPlayers()
    local players = (isClient() or isServer()) and getOnlinePlayers() or IsoPlayer.getPlayers()
    for i=0, players:size()-1 do
        ---@type IsoPlayer|IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
        local player = players:get(i)
        if player then
            highscore.setIntoCurrentPlayers(player)
        end
    end
    highscore.reCrown()
end


function highscore.fetchPlayerObject(username)
    if isClient() or isServer() then
        return getPlayerFromUsername(username)
    else
        local players = IsoPlayer.getPlayers()
        for i=0, players:size()-1 do
            ---@type IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
            local player = players:get(i)
            if player and player:getUsername()==username then
                return player
            end
        end
    end
end


function highscore.checkTopWave(wave)
    highscore.crowned.topWave = highscore.crowned.topWave or {}
    local currentTopWave = highscore.crowned.topWave.wave or 0
    if wave > currentTopWave then
        highscore.crowned.topWave.wave = wave
        highscore.crowned.topWave.players = {}
        for username,data in pairs(highscore.currentPlayers) do
            local playerObj = highscore.fetchPlayerObject(username)
            if playerObj and (not playerObj:isDead()) and (not playerObj:isInvisible()) then
                local displayName = data.steam and data.steam.profileName or username
                table.insert(highscore.crowned.topWave.players, displayName)
            end
        end
        highscore.save()
    end
end


function highscore.save()
    if isClient() then return end
    if not highscore.crowned then return end

    local lines = {}
    table.insert(lines, "return {")

    -- Save topKills
    if highscore.crowned.topKills then
        table.insert(lines, "  topKills = {")

        for i=1, #highscore.crowned.topKills do
            local record = highscore.crowned.topKills[i]
            table.insert(lines, string.format("    { displayName = %q, kills = %d },", record.displayName, record.kills))
        end
        table.insert(lines, "  },")
    end

    -- Save topWave
    if highscore.crowned.topWave then
        table.insert(lines, "  topWave = {")
        table.insert(lines, string.format("    wave = %d,", highscore.crowned.topWave.wave or 0))
        table.insert(lines, "    players = {")

        for i=1, #highscore.crowned.topWave.players do
            local name = highscore.crowned.topWave.players[i]
            table.insert(lines, string.format("      %q,", name))
        end

        table.insert(lines, "    },")
        table.insert(lines, "  },")
    end

    table.insert(lines, "}")

    local compiled = table.concat(lines, "\n")
    local writer = getFileWriter("LastStandTogether_HighScores.txt", true, false)
    writer:write(compiled)
    writer:close()
end



function highscore.load()
    if isClient() then return end

    local reader = getFileReader("LastStandTogether_HighScores.txt", false)
    if not reader then return end

    local content = ""
    local line = reader:readLine()
    while line do
        content = content .. line .. "\n"
        line = reader:readLine()
    end
    reader:close()

    local chunk, err = loadstring(content)
    if not chunk then print("Failed to load high scores:", err) return end

    local ok, data = pcall(chunk)
    if not ok then print("Error loading high score table:", data) return end

    highscore.crowned = highscore.crowned or {}
    highscore.crowned.topKills = data.topKills or {}
    highscore.crowned.topWave = data.topWave or {}
end


return highscore