require "ISUI/ISPanel"

lastStandTogetherWaveAlert = ISPanel:derive("lastStandTogetherWaveAlert")


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

    local tens = math.floor(n / 10) * 10
    local ones = n % 10

    if tens > 0 then
        table.insert(parts, tostring(tens))
    end
    if ones > 0 then
        table.insert(parts, tostring(ones))
    end

    return parts
end


function lastStandTogetherWaveAlert:prerender()
    local LST_zone = LastStandTogether_Zone
    if not LST_zone then self:setVisible(false) return end

    local zoneDef = LST_zone.def
    if not zoneDef or not zoneDef.center or not zoneDef.radius or not zoneDef.wave then self:setVisible(false) return end

    ISPanel.prerender(self)

    --- def = {}
    --zoneDef.wave = false
    --zoneDef.nextWaveTime = false
    --zoneDef.popMulti = false

    self.textLine1 = (zoneDef.wave > 0) and ("Wave " .. zoneDef.wave) or ""
    local nextWaveMs = zoneDef.nextWaveTime - getTimestampMs()
    local nextText
    if nextWaveMs > 0 then
        local totalSeconds = math.floor(nextWaveMs / 1000)
        local hours = math.floor(totalSeconds / 3600)
        local minutes = math.floor((totalSeconds % 3600) / 60)
        local seconds = totalSeconds % 60

        if hours > 0 then
            nextText = string.format("%d:%02d:%02d", hours, minutes, seconds)
        elseif minutes > 0 then
            nextText = string.format("%d:%02d", minutes, seconds)
        else
            nextText = string.format("%d", seconds)
        end

        if nextWaveMs <= 10000 then

            if self.waveAnnounceParts and #self.waveAnnounceParts > 0 then
                local noLongerPlaying = (self.playWaveAnnouncePart and not self.emitter:isPlaying(self.playWaveAnnouncePart))
                if (not self.playWaveAnnouncePart) or noLongerPlaying then
                    if noLongerPlaying then table.remove(self.waveAnnounceParts) end
                    self.playWaveAnnouncePart = self.emitter:playSound("LastStandTogether/" .. self.waveAnnounceParts[#self.waveAnnounceParts])
                end
            end

            if self.announced == 0 then
                self.emitter:playSound("LastStandTogether/countdown")
                self.announced = 1
                self.waveAnnounceParts = lastStandTogetherWaveAlert.getWaveNumberParts(zoneDef.wave)
            end
            if self.announced == 1 and nextWaveMs <= 1000 then
                self.announced = 2
            end
        else
            self.waveAnnounceParts = nil
            self.announced = false
        end
    end

    self.textLine2 = nextText and ("Next wave: " .. nextText) or ""

    self:setVisible(true)
end


function lastStandTogetherWaveAlert:render()
    ISPanel.render(self)
    self:drawTextCentre(self.textLine1, self.width/2, self.textY, 0.9, 0.2, 0.2, 0.8, UIFont.Title)
    self:drawTextCentre(self.textLine2, self.width/2, self.textY+self.textLine2Hgt, 0.9, 0.2, 0.2, 0.7, UIFont.Large)
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
    o.background = true
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0.9, g=0.2, b=0.2, a=1}
    o.width = width
    o.height = height
    o.emitter = getPlayer():getEmitter()
    o.textLine1 = ""
    o.textLine2 = ""
    o.textY = getCore():getScreenHeight()/8
    o.textLine2Hgt = getTextManager():getFontHeight(UIFont.Title)
    o.anchorLeft = true
    o.anchorRight = false
    o.anchorTop = true
    o.anchorBottom = false
    o.moveWithMouse = false
    return o
end