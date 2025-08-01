require "ISUI/ISPanel"

if (isClient()) and ((not getDebug()) and (not isAdmin()) and (not isCoopHost())) then return end

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
    self:drawTextureScaled(self.panelArt.texture, 2, 2, self.panelArt.w, self.panelArt.h, 1, 1, 1, 1)
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
        self:drawTextCentre(tostring(text), self.width/2, 0-(self.fontMedHeight*1.25), 0.9, 0.2, 0.2, 1, UIFont.Medium)
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
end


function lastStandTogetherPanel:instantiate()
    ISPanel.instantiate(self)
    self.javaObject:setConsumeMouseEvents(false)
end


function lastStandTogetherPanel:setSandBoxValue(optionName, value)
    local options = getSandboxOptions()
    local option = options and options:getOptionByName("LastStandTogether."..optionName)
    if option then
        option:setValue(value)
        options:toLua()
        if isClient() then options:sendToServer() end
    end
end


function lastStandTogetherPanel:onTextEntryEntered()
    ---self = text entry
    local value = tonumber(self:getText())
    if value then
        self.parent:setSandBoxValue(self.sandBoxOption, value)
    end
    lastStandTogetherPanel.instance.textEntry = nil
    self:setVisible(false)
    self:removeFromUIManager()
end


function lastStandTogetherPanel:onButton(button)
    if not button then return end

    if button.boolean then
        local value = not SandboxVars.LastStandTogether[button.sandBoxOption]
        SandboxVars.LastStandTogether[button.sandBoxOption] = value
        self:setSandBoxValue(button.sandBoxOption, value)
        return
    end

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


function lastStandTogetherPanel:startGame(button, random)
    if not button then return end

    if isClient() then
        local command = "LastStandTogether" .. (random and "Random" or "")
        sendClientCommand(command, "setZone", {})
    else
        local func = random and "setToBuildingRandom" or "setToCurrentBuilding"
        LastStandTogether_Zone[func](getPlayer())
    end
end


function lastStandTogetherPanel:startGameRandom(button)
    if not button then return end
    lastStandTogetherPanel:startGame(button, true)
end


function lastStandTogetherPanel:initialise()
    ISPanel.initialise(self)

    local x, y = self.buttonX, self.titleY

    self.StartButton = ISButton:new(self.buttonX, y, (self.width*0.5)-27, self.fontMedHeight*1.5, "Start Last Stand Together", self, lastStandTogetherPanel.startGame)
    self.StartButton.font = UIFont.Medium
    self.StartButton:initialise()
    self.StartButton:instantiate()
    self:addChild(self.StartButton)

    self.StartButtonRandom = ISButton:new(self.StartButton.x+self.StartButton.width+8, y, (self.width*0.3)-27, self.fontMedHeight*1.5, "Random", self, lastStandTogetherPanel.startGameRandom)
    self.StartButtonRandom.font = UIFont.Medium
    self.StartButtonRandom:initialise()
    self.StartButtonRandom:instantiate()
    self:addChild(self.StartButtonRandom)

    self.resetButton = ISButton:new(self.StartButtonRandom.x+self.StartButtonRandom.width+8, y, (self.width*0.2)-27, self.fontMedHeight*1.5, "Reset", self, LastStandTogether_Zone.resetShopMarkers)
    self.resetButton.font = UIFont.Small
    self.resetButton:setImage(getTexture("media/textures/ui/resetShopButton.png"))
    self.resetButton:initialise()
    self.resetButton:instantiate()
    self:addChild(self.resetButton)

    for k,v in pairs(SandboxVars.LastStandTogether) do
        local title = getText("Sandbox_LastStandTogether_"..k)
        local button = ISButton:new(x, y+20+self.StartButton.height, self.buttonWidth, self.buttonHeight, title, self, lastStandTogetherPanel.onButton)
        button.sandBoxOption = k
        button.boolean = (v == true or v == false)
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

    local buttonHeight = 24
    local buttonsNeeded = 0

    local panelArt = getTexture("media/textures/laststandTogetherArt.png")
    local artW, artH = panelArt:getWidth()-4, panelArt:getHeight()-4

    local titleY = artH - (fontMedHeight)/2

    for k,v in pairs(SandboxVars.LastStandTogether) do buttonsNeeded = buttonsNeeded + 1 end

    local panelHeight = titleY + 40 + (fontMedHeight) + (buttonsNeeded * (10+buttonHeight) )
    local width, height = artW+4, panelHeight+4

    local menu = MainScreen and MainScreen.instance and MainScreen.instance.bottomPanel
    local menuX = menu and menu:getX()+(menu:getWidth()*1.75) or (getCore():getScreenWidth()-width)/2
    local finalX = math.min(getCore():getScreenWidth()-width-50, menuX)
    local x, y = finalX, (getCore():getScreenHeight()-height)/1.5

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
    o.borderColor = {r=0.6, g=0.6, b=0.6, a=1}
    o.width = width
    o.height = height
    o.text = ""
    o.panelArt = {texture=panelArt, w=artW, h=artH }
    o.sandBoxButtons = {}
    o.anchorLeft = false
    o.anchorRight = false
    o.anchorTop = false
    o.anchorBottom = false
    o.moveWithMouse = true
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