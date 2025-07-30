local highScore = {}

function highScore.reset() highScore.currentPlayers = {} end

highScore.currentPlayers = {}
highScore.currentPlayersSort = {}
highScore.crowned = {}

highScore.textures = {
    blood = getTexture("media/textures/ui/bloodCrown.png"),
    skull = getTexture("media/textures/ui/lastStandSkull.png"),
    metal = {
        getTexture("media/textures/ui/goldCrown.png"),
        getTexture("media/textures/ui/silverCrown.png"),
        getTexture("media/textures/ui/bronzeCrown.png"),
    }
}

--{
--  highScore.crowned.topKills = {
--    { displayName = "Player1", kills = 45 },
--    { displayName = "Player2", kills = 32 },
--    { displayName = "Player3", kills = 30 },
--  },
--  highScore.crowned.topWave = {
--    wave = 12,
--    players = { "Player1", "Player2", "Player3", },
--  },
--}

function highScore.drawTextBoxed(UI, text, x, y, a, right, crossed)
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


function highScore.render(UI, x, y)
    UI.highScoreZone = {x=x, y=y, w=32, h=32}
    UI:drawRect(UI.highScoreZone.x, UI.highScoreZone.y, UI.highScoreZone.w, UI.highScoreZone.h, 0.4, 0, 0, 0)
    UI:drawTextureScaled(highScore.textures.skull, UI.highScoreZone.x, UI.highScoreZone.y, UI.highScoreZone.w, UI.highScoreZone.h, 1, 1, 1, 1)
    ---UI.showHighScore = true
    if not UI.showHighScore then return end

    y = y + 32 + UI.textSmallH*2

    if highScore.crowned.topWave and highScore.crowned.topWave.wave then
        local tooltipZone = highScore.drawTextBoxed(UI, "TOP WAVE: "..highScore.crowned.topWave.wave, x, y)
        UI:drawTextureScaled(highScore.textures.blood, x-32, y-8, 32, 32, 1, 1, 1, 1)
        UI.waveToolTipZone = tooltipZone
        y = y + UI.textSmallH*2

        if UI.showTopWaveTooltip then
            local tempY = y
            for i=1, #highScore.crowned.topWave.players do
                local playerName = highScore.crowned.topWave.players[i]
                highScore.drawTextBoxed(UI, (playerName), x-48, tempY, 1, true)
                tempY = tempY + UI.textSmallH+4
            end
        end
    end

    if highScore.crowned.topKills and (#highScore.crowned.topKills > 0) then
        highScore.drawTextBoxed(UI, "HIGHSCORES: ", x-20, y)
        y = y + UI.textSmallH*1.25+4

        for i=1, #highScore.crowned.topKills do
            local data = highScore.crowned.topKills[i]
            local kills = data.kills or 0
            local displayName = data.displayName
            local shortName = string.sub(displayName, 1, 25)
            if displayName then
                highScore.drawTextBoxed(UI, (shortName.."    kills: "..tostring(kills)), x, y)
                local texture = highScore.textures.metal[i]
                if texture then UI:drawTextureScaled(texture, x-32, y-8, 32, 32, 1, 1, 1, 1) end
                y = y + UI.textSmallH+4
            end
        end
        y = y + UI.textSmallH*2
    end

    if (#highScore.currentPlayersSort > 0) then
        highScore.drawTextBoxed(UI, "KILLS: ", x-20, y)
        y = y + UI.textSmallH*1.25+4

        for i=1, #highScore.currentPlayersSort do
            local data = highScore.currentPlayersSort[i]
            local kills = data.kills or 0
            local displayName = data.displayName
            local dead = data.dead
            if displayName then
                highScore.drawTextBoxed(UI, displayName.."    kills: "..tostring(kills), x, y, (dead and 0.7), false, dead)
                y = y + UI.textSmallH+4
            end
        end
        --y = y + UI.textSmallH*2
    end
end


function highScore.reCrown()
    highScore.currentPlayersSort = {}
    for username, data in pairs(highScore.currentPlayers) do
        local displayName = data.steam and data.steam.profileName or username
        local dead = true
        local playerObj = highScore.fetchPlayerObject(username)
        if playerObj and (not playerObj:isDead()) then
            dead = false
        end
        table.insert(highScore.currentPlayersSort, { displayName = displayName, kills = data.kills, username=username, dead=dead })
    end

    table.sort(highScore.currentPlayersSort, function(a, b) return a.kills > b.kills end)

    local seen = {}

    if highScore.crowned.topKills then
        for i=1, #highScore.crowned.topKills do
            local record = highScore.crowned.topKills[i]
            if record then
                seen[record.displayName] = { displayName = record.displayName, kills = record.kills }
            end
        end
    end

    for i=1, #highScore.currentPlayersSort do
        local record = highScore.currentPlayersSort[i]
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

    highScore.crowned.topKills = blended
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
function highScore.update(player, type)
    if isServer() then
        sendServerCommand("LastStandTogether", "updateHighScore", { player=player, type=type })
        return
    end

    local username = player:getUsername()

    if type == "login" then
        highScore.currentPlayers[username].kills = 0
    end

    if type == "died" then
        highScore.currentPlayers[username].dead = true
    end

    if type == "zombieKill" then
        local kills = highScore.currentPlayers[username].kills or 0
        highScore.currentPlayers[username].kills = kills + 1
    end

    highScore.reCrown()
    highScore.save()
end


function highScore.receiveHighScore(allData)
    if isServer() then return end
    highScore.currentPlayers = allData
end


function highScore.sendHighScore(player)
    if isClient() then return end
    sendServerCommand(player, "LastStandTogether", "receiveHighScore", highScore.currentPlayers)
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject|IsoObject
function highScore.singlePlayerSet(player)
    local username = player:getUsername()
    local steam = {}
    if getSteamModeActive() then
        steam.ID = getCurrentUserSteamID()
        steam.profileName = getCurrentUserProfileName()
    end

    highScore.currentPlayers[username] = {steam=steam}
    highScore.reCrown()
end


---@param usernames ArrayList
---@param displayNames ArrayList
---@param steamIDs ArrayList
function highScore.onlinePlayerSet(usernames, displayNames, steamIDs)
    local numberOfPlayers = usernames:size()
    for i = 0,numberOfPlayers-1 do
        local username = usernames:get(i)
        if not highScore.currentPlayers[username] then
            local steam = {}
            if getSteamModeActive() then
                steam.ID = steamIDs:get(i)
                steam.profileName = getSteamProfileNameFromSteamID(steam.ID)
            end
            highScore.currentPlayers[username] = {steam=steam}
        end
    end
end


function highScore.fetchPlayerObject(username)
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


function highScore.checkTopWave(wave)
    highScore.crowned.topWave = highScore.crowned.topWave or {}
    local currentTopWave = highScore.crowned.topWave.wave or 0
    if wave > currentTopWave then
        highScore.crowned.topWave.wave = wave
        highScore.crowned.topWave.players = {}
        for username,data in pairs(highScore.currentPlayers) do
            local playerObj = highScore.fetchPlayerObject(username)
            if playerObj and (not playerObj:isDead()) and (not playerObj:isInvisible()) then
                local displayName = data.steam and data.steam.profileName or username
                table.insert(highScore.crowned.topWave.players, displayName)
            end
        end
        highScore.save()
    end
end


function highScore.save()
    if isClient() then return end
    if not highScore.crowned then return end

    local lines = {}
    table.insert(lines, "return {")

    -- Save topKills
    if highScore.crowned.topKills then
        table.insert(lines, "  topKills = {")

        for i=1, #highScore.crowned.topKills do
            local record = highScore.crowned.topKills[i]
            table.insert(lines, string.format("    { displayName = %q, kills = %d },", record.displayName, record.kills))
        end
        table.insert(lines, "  },")
    end

    -- Save topWave
    if highScore.crowned.topWave then
        table.insert(lines, "  topWave = {")
        table.insert(lines, string.format("    wave = %d,", highScore.crowned.topWave.wave or 0))
        table.insert(lines, "    players = {")

        for i=1, #highScore.crowned.topWave.players do
            local name = highScore.crowned.topWave.players[i]
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



function highScore.load()
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

    highScore.crowned = highScore.crowned or {}
    highScore.crowned.topKills = data.topKills or {}
    highScore.crowned.topWave = data.topWave or {}
end


return highScore