require "ISUI/ISPanel"

if ((not getDebug()) and (not isAdmin()) and (not isCoopHost())) then return end

lastStandTogetherPanel = ISPanel:derive("lastStandTogetherPanel")

function lastStandTogetherPanel:update()
    if MainScreen and MainScreen.instance and MainScreen.instance.mainOptions and MainScreen.instance.mainOptions:isVisible() then
        self:setVisible(false)
    elseif InviteFriends and InviteFriends.instance and InviteFriends.instance:isVisible() then
        self:setVisible(false)
    elseif ISScoreboard and ISScoreboard.instance and ISScoreboard.instance:isVisible() then
        self:setVisible(false)
    else
        self:setVisible(true)
    end
end

function lastStandTogetherPanel:prerender()
    
    ISPanel.prerender(self)

    self.artOffset = self.artOffset or -260+self.StartButton.y+self.StartButton.height+5 or 0

    self:drawTextureScaled(self.panelArt, 0, self.artOffset, self.width, 260, 1, 1, 1, 1)

    self:bringToTop()

    if lastStandTogetherPanel.textEntry and lastStandTogetherPanel.textEntry:isVisible() then
        lastStandTogetherPanel.textEntry:bringToTop()
    end

    local LST_zone = LastStandTogether_Zone
    local zoneDef = LST_zone and LST_zone.def

    local text

    if zoneDef and zoneDef.error then
        text = zoneDef.error
    end

    if zoneDef and (not zoneDef.center) then
        local building = getPlayer():getCurrentBuilding()
        if building then text = (text and text .. "  -  " or "") .. "Inside Valid Building" end
    end

    self.resetButton:setEnable(not not zoneDef.center)

    if zoneDef and text then
        self:drawTextCentre(tostring(text), self.width/2, 0+self.fontMedHeight-260, 0.9, 0.2, 0.2, 1, UIFont.Medium)
    end

    for k,v in pairs(SandboxVars.LastStandTogether) do
        local button = self.sandBoxButtons[k]
        if button then

            self:drawRectStatic(button.x+button.width+10, button.y, self.labelWidth, button.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
            self:drawText(tostring(SandboxVars.LastStandTogether[k]), button.x+button.width+20, button.y+1, 0.9, 0.9, 0.9, 1, UIFont.Medium)
        end
    end
end


function lastStandTogetherPanel:render()
    ISPanel.render(self)
    self:drawRectBorder(0, self.artOffset, self:getWidth(), self:getHeight()-self.artOffset, 1, 0.6, 0.6, 0.6)
end


function lastStandTogetherPanel:instantiate()
    ISPanel.instantiate(self)
    self.javaObject:setConsumeMouseEvents(false)
end


function lastStandTogetherPanel:onTextEntryEntered()
    ---self = text entry
    local value = tonumber(self:getText())
    if value then
        local options = getSandboxOptions()

        local option = options and options:getOptionByName("LastStandTogether."..self.sandBoxOption)
        if option then
            option:setValue(value)
            if isClient() then options:sendToServer() end
            options:toLua()
        end
    end
    lastStandTogetherPanel.instance.textEntry = nil
    self:setVisible(false)
    self:removeFromUIManager()
end


function lastStandTogetherPanel:onButton(button)
    if not button then return end
    if lastStandTogetherPanel.textEntry and lastStandTogetherPanel.textEntry:isVisible() then
        lastStandTogetherPanel.textEntry:bringToTop()
        return
    end
    local textEntry = ISTextEntryBox:new(tostring(SandboxVars.LastStandTogether[button.sandBoxOption]),
            button.x+button.width+10, button.y, lastStandTogetherPanel.instance.labelWidth, button.height)
    textEntry.font = UIFont.Medium
    textEntry:initialise()
    textEntry:instantiate()
    lastStandTogetherPanel.instance:addChild(textEntry)
    textEntry:setOnlyNumbers(true)
    textEntry.sandBoxOption = button.sandBoxOption
    textEntry.onCommandEntered = lastStandTogetherPanel.onTextEntryEntered
    lastStandTogetherPanel.textEntry = textEntry
end


function lastStandTogetherPanel:startWaves(button)
    if not button then return end

    if isClient() then
        sendClientCommand("LastStandTogether", "setZone", {})
    else
        LastStandTogether_Zone.setToCurrentBuilding(getPlayer())
    end
end


function lastStandTogetherPanel:initialise()
    ISPanel.initialise(self)

    local x, y = self.buttonX, self.titleY

    self.StartButton = ISButton:new(self.buttonX, 10, self.width-(self.buttonX*4)+10, self.fontMedHeight*1.5, "Start Last Stand Together", self, lastStandTogetherPanel.startWaves)
    self.StartButton.font = UIFont.Medium
    self.StartButton:initialise()
    self.StartButton:instantiate()
    self:addChild(self.StartButton)

    self.resetButton = ISButton:new(self.StartButton.x+self.StartButton.width+8, 10, self.width-(self.StartButton.width)-30-self.buttonX, self.fontMedHeight*1.5, "Reset", self, LastStandTogether_Zone.resetShopMarkers)
    self.resetButton.font = UIFont.Small
    self.resetButton:setImage(getTexture("media/textures/ui/resetShopButton.png"))
    self.resetButton:initialise()
    self.resetButton:instantiate()
    self:addChild(self.resetButton)

    for k,v in pairs(SandboxVars.LastStandTogether) do
        local title = getText("Sandbox_LastStandTogether_"..k)
        local button = ISButton:new(x, y+5, self.buttonWidth, self.buttonHeight, title, self, lastStandTogetherPanel.onButton)
        button.sandBoxOption = k
        local tooltip = getTextOrNull("Sandbox_LastStandTogether_"..k.."_tooltip")
        if tooltip then button:setTooltip(tooltip) end
        button:initialise()
        button:instantiate()
        self.sandBoxButtons[k] = button
        self:addChild(button)

        y = y + 10 + self.buttonHeight
    end
end


function lastStandTogetherPanel:open()
    if lastStandTogetherPanel.instance then lastStandTogetherPanel.instance:close() end
    local alert = lastStandTogetherPanel:new()
    alert:initialise()
    alert:addToUIManager()
    alert:setVisible(true)
    lastStandTogetherPanel.instance = alert
    return alert
end


function lastStandTogetherPanel:close()
    if lastStandTogetherPanel.instance then
        if lastStandTogetherPanel.instance.textEntry then
            lastStandTogetherPanel.instance.textEntry:setVisible(false)
            lastStandTogetherPanel.instance.textEntry:removeFromUIManager()
            lastStandTogetherPanel.instance.textEntry = nil
        end

        lastStandTogetherPanel.instance:setVisible(false)
        lastStandTogetherPanel.instance:removeFromUIManager()
        lastStandTogetherPanel.instance = nil
    end
end


function lastStandTogetherPanel:new()
    local o = {}

    local fontMedHeight = getTextManager():getFontHeight(UIFont.Medium)
    local titleY = (fontMedHeight*1.5)+20
    local buttonHeight = 24
    local buttonsNeeded = 0
    for k,v in pairs(SandboxVars.LastStandTogether) do buttonsNeeded = buttonsNeeded + 1 end

    local panelHeight = titleY + 10 + (buttonsNeeded * (10+buttonHeight) )

    local width, height = 462, panelHeight
    local x, y = (getCore():getScreenWidth()-width)/2, (getCore():getScreenHeight()-height)/1.5

    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.x = x
    o.y = y
    o.fontMedHeight = fontMedHeight
    o.titleY = titleY
    o.buttonHeight = buttonHeight
    o.buttonWidth = (width/1.5)-20
    o.labelWidth = (o.buttonWidth/3)+10
    o.buttonX = (width-o.buttonWidth-o.labelWidth)/2
    o.background = true
    o.backgroundColor = {r=0.05, g=0.05, b=0.05, a=0.8}
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.width = width
    o.height = height
    o.text = ""
    o.panelArt = getTexture("media/textures/laststandTogetherArt.png")
    o.sandBoxButtons = {}
    o.anchorLeft = true
    o.anchorRight = false
    o.anchorTop = true
    o.anchorBottom = false
    o.moveWithMouse = false
    o.font = UIFont.Large
    return o
end


local MainScreen_onEnterFromGame = MainScreen.onEnterFromGame
function MainScreen:onEnterFromGame()
    MainScreen_onEnterFromGame(self)
    lastStandTogetherPanel:open()
end


local MainScreen_onReturnToGame = MainScreen.onReturnToGame
function MainScreen:onReturnToGame()
    MainScreen_onReturnToGame(self)
    if lastStandTogetherPanel.instance then
        lastStandTogetherPanel.instance:close()
    end
end