require "ISUI/ISPanel"
local _internal = require "shop-shared"

lastStandTogetherWaveAlert = ISPanel:derive("lastStandTogetherWaveAlert")

function lastStandTogetherWaveAlert.walletBalance(player)
    local wallet = getWallet(player)

    if wallet then
        local walletBalance = wallet and wallet.amount
        local walletBalanceLine = _internal.numToCurrency(walletBalance)
        return walletBalanceLine
    else
        getOrSetWalletID(player)
    end
end


function lastStandTogetherWaveAlert.getWaveNumberParts(n)
    local parts = {"wave"}

    if n == 100 then
        table.insert(parts, "100")
        return parts
    end

    if n >= 11 and n <= 15 then
        table.insert(parts, tostring(n))
        return parts
    end

    if n >= 16 and n <= 19 then
        local ones = n % 10
        table.insert(parts, tostring(ones))
        table.insert(parts, "teen")
        return parts
    end

    local hundreds = math.floor(n / 100) * 100
    local remainder = n % 100
    local tens = math.floor(remainder / 10) * 10
    local ones = remainder % 10

    if hundreds > 0 then
        table.insert(parts, tostring(hundreds))
    end
    if tens > 0 then
        table.insert(parts, tostring(tens))
    end
    if ones > 0 then
        table.insert(parts, tostring(ones))
    end

    return parts
end


function lastStandTogetherWaveAlert.timeToText(time)
    if time < 0 then return "0" end
    local text
    local totalSeconds = math.floor(time / 1000)
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60

    if hours > 0 then
        text = string.format("%d:%02d:%02d", hours, minutes, seconds)
    elseif minutes > 0 then
        text = string.format("%d:%02d", minutes, seconds)
    else
        text = string.format("%d", seconds)
    end
    return text
end


function lastStandTogetherWaveAlert:prerender()
    ISPanel.prerender(self)
    local LST_zone = LastStandTogether_Zone
    local zoneDef = LST_zone and LST_zone.def

    if not zoneDef or not zoneDef.center then
        self.textLine1 = ""
        self.textLine2 = ""
        self.textLine3 = ""
        return
    end

    --- WAVE
    self.textLine1 = (zoneDef and zoneDef.wave and (zoneDef.wave > 0) and ("Wave " .. zoneDef.wave)) or ""

    --- Announcer handler
    if self.waveAnnounceParts and self.waveAnnouncePartsSaid <= #self.waveAnnounceParts then
        local noLongerPlaying = (self.playWaveAnnouncePart and not self.player:getEmitter():isPlaying(self.playWaveAnnouncePart))
        if (not self.playWaveAnnouncePart) or noLongerPlaying then
            local sound = self.waveAnnounceParts[self.waveAnnouncePartsSaid]
            if sound then
                self.playWaveAnnouncePart = self.player:playSoundLocal("lastStandTogether_" .. sound)
                self.waveAnnouncePartsSaid = self.waveAnnouncePartsSaid + 1
            end
        end
    end

    local currentTime = getTimestampMs()

    --- NEXT WAVE TIMER
    local nextText
    if zoneDef.wave and zoneDef.nextWaveTime then
        local nextWaveMs = zoneDef.nextWaveTime - currentTime
        if nextWaveMs > 0 then
            nextText = lastStandTogetherWaveAlert.timeToText(nextWaveMs)
            if nextWaveMs <= 11000 then
                if self.announced == 0 then
                    self.player:playSoundLocal("lastStandTogether_countDown")
                    self.announced = 1
                end
                if self.announced == 1 and nextWaveMs <= 200 then
                    self.announced = 2
                    self.waveAnnounceParts = lastStandTogetherWaveAlert.getWaveNumberParts(zoneDef.wave+1)
                    self.waveAnnouncePartsSaid = 1
                end
            else
                self.announced = 0
            end
        end
    end
    self.textLine2 = nextText and ("Next wave: " .. nextText) or ""

    --- ZOMBIES
    self.currentZombies = (zoneDef.currentZombies or 0)
    self.zombiesToSpawn = (zoneDef.zombiesToSpawn or 0)
    self.spawnTickTimer = (zoneDef.spawnTickTimer or 0)
    self.zombiesSpawned = (zoneDef.zombiesSpawned or 0)

    if self.currentZombies > 0 and (not self.player:isDead() and not self.player:isInvisible()) then
        if (not self.lastYellOut) or (currentTime > self.lastYellOut) then
            self.lastYellOut = currentTime+10000
            AddWorldSound(self.player, 600, 600)
        end
    end

    local fraction = self.zombiesToSpawn and (self.zombiesToSpawn > 0) and " / "..self.zombiesToSpawn+self.zombiesSpawned or ""
    self.textLine3 = (self.currentZombies>0 or self.zombiesToSpawn>0) and (self.currentZombies .. fraction .. " zombies left.") or ""

    --- ADDITIONAL ZOMBIE INFO
    local needMoreSpawns = self.zombiesToSpawn and (self.zombiesToSpawn > 0)
    local timer = self.spawnTickTimer and " ("..lastStandTogetherWaveAlert.timeToText((self.spawnTickTimer-currentTime))..")" or ""
    local zombiesIncoming = math.min(100, self.zombiesToSpawn)

    self.textLine4 = needMoreSpawns and zombiesIncoming.." incoming "..timer or ""
end


function lastStandTogetherWaveAlert:render()
    ISPanel.render(self)
    self:backMost()
    local waveAlpha = (self.currentZombies and self.currentZombies > 0 and 0.8) or 0.5

    local tempTextY = self.textY

    local currentTime = getTimestampMs()

    if self.textLine1 ~= "" then
        self:drawTextCentre(self.textLine1, self.width/2, tempTextY, 0.9, 0.2, 0.2, waveAlpha, UIFont.Title)
        tempTextY = tempTextY + self.textTitleH
    end

    if self.textLine2 ~= "" then
        self:drawTextCentre(self.textLine2, self.width/2, tempTextY, 0.9, 0.2, 0.2, 0.8, UIFont.Large)
        tempTextY = tempTextY + self.textLargeH
    end

    if self.textLine3 ~= "" then
        self:drawTextCentre(self.textLine3, self.width/2, tempTextY, 0.9, 0.2, 0.2, 0.7, UIFont.Medium)
        tempTextY = tempTextY + self.textMediumH
    end

    if self.textLine4 ~= "" then
        self:drawTextCentre(self.textLine4, self.width/2, tempTextY, 0.8, 0.2, 0.2, 0.7, UIFont.Medium)
        tempTextY = tempTextY + self.textMediumH
    end

    if #LastStandTogether_Zone.playerDeaths > 0 then tempTextY = tempTextY + self.textMediumH*0.25 end

    for n=1, #LastStandTogether_Zone.playerDeaths do
        local data = LastStandTogether_Zone.playerDeaths[n]
        if data then
            local expire = data.expire
            if expire < currentTime then
                LastStandTogether_Zone.playerDeaths[n] = nil
                self.playerDeaths[data.username] = nil
            else
                local t = math.max(0.4, math.min(1, (expire - currentTime) / LastStandTogether_Zone.deathLogFade))
                local alpha = t * t
                local name = data.username
                local text = name.." has died."

                if not self.playerDeaths[name] then
                    self.playerDeaths[name] = true
                    self.player:playSoundLocal("lastStandTogether_survivorDied")
                end

                self:drawTextCentre(text, self.width/2, tempTextY, 0.9, 0.2, 0.2, 1 * alpha, UIFont.Large)
                tempTextY = tempTextY + self.textLargeH
            end
        end
    end

    local walletBalance = lastStandTogetherWaveAlert.walletBalance(self.player)
    if walletBalance then
        local speedControls = UIManager.getSpeedControls()
        local x = speedControls:getX() - 15 - self:getX()
        local y = speedControls:getY() - 5 - self:getY()
        local w = getTextManager():MeasureStringX(UIFont.Medium, walletBalance)
        self:drawRect(x-(w*1.125), y, w*1.25, self.textMediumH, 0.4, 0, 0, 0)
        self:drawTextRight(walletBalance, x, y, 0.9, 0.9, 0.9, 1, UIFont.Medium)
    end
end


function lastStandTogetherWaveAlert:instantiate()
    ISPanel.instantiate(self)
    self.javaObject:setConsumeMouseEvents(false)
end


function lastStandTogetherWaveAlert:setToScreen()

    if lastStandTogetherWaveAlert.instance then
        lastStandTogetherWaveAlert.instance:setVisible(false)
        lastStandTogetherWaveAlert.instance:removeFromUIManager()
    end

    local alert = lastStandTogetherWaveAlert:new()
    alert:initialise()
    alert:addToUIManager()
    lastStandTogetherWaveAlert.instance = alert

    return alert
end


function lastStandTogetherWaveAlert:new()
    local o = {}

    local width, height = 1, 1
    local x, y = getCore():getScreenWidth()/2, -1

    o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.x = x
    o.y = y
    o.announced = 0
    o.lastYellOut = false
    o.background = true
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0.9, g=0.2, b=0.2, a=1}
    o.width = width
    o.height = height
    o.player = getPlayer()
    o.textLine1 = ""
    o.textLine2 = ""
    o.textLine3 = ""
    o.textLine4 = ""
    o.playerDeaths = {}
    o.textY = (getCore():getScreenHeight()/8)-10
    o.textTitleH = getTextManager():getFontHeight(UIFont.Title)*1.25
    o.textLargeH = getTextManager():getFontHeight(UIFont.Large)*1.25
    o.textMediumH = getTextManager():getFontHeight(UIFont.Medium)*1.25
    o.textSmallH = getTextManager():getFontHeight(UIFont.Small)*1.25
    o.anchorLeft = true
    o.anchorRight = false
    o.anchorTop = true
    o.anchorBottom = false
    o.moveWithMouse = false
    return o
end