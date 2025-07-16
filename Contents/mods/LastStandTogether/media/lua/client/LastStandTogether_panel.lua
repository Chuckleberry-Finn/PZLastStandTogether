require "ISUI/ISPanel"

lastStandTogetherPanel = ISPanel:derive("lastStandTogetherPanel")

function lastStandTogetherPanel:prerender()
    ISPanel.prerender(self)
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

    if zoneDef and not zoneDef.building then
        local building = getPlayer():getCurrentBuilding()
        if building then
            text = "Valid Building"
        end
    end

    if zoneDef and text then
        self:drawTextCentre(tostring(text), self.width/2, 0-self.fontMedHeight, 0.9, 0.2, 0.2, 1, UIFont.Medium)
    end

    for k,v in pairs(SandboxVars.LastStandTogether) do
        local button = self.sandBoxButtons[k]
        if button then

            self:drawRectStatic(button.x+button.width+10, button.y, self.labelWidth, button.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
            self:drawText(tostring(SandboxVars.LastStandTogether[k]), button.x+button.width+20, button.y+1, 0.9, 0.9, 0.9, 1, UIFont.Medium)
        end
    end
end

function lastStandTogetherPanel:render() ISPanel.render(self) end


function lastStandTogetherPanel:instantiate()
    ISPanel.instantiate(self)
    self.javaObject:setConsumeMouseEvents(false)
end


function lastStandTogetherPanel:onTextEntryEntered()

    print("self:getText(): ", self:getText())

    ---self = text entry
    local value = tonumber(self:getText())
    if value then
        local options = getSandboxOptions()
        print("option: checking for: ", self.sandBoxOption)
        local option = options and options:getOptionByName("LastStandTogether."..self.sandBoxOption)
        if option then
            print("SETTING: ", self.sandBoxOption)
            option:setValue(value)

            if isClient then
                options:sendToServer()
            end
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
    LastStandTogether_Zone.setToCurrentBuilding(getPlayer())
end


function lastStandTogetherPanel:initialise()
    ISPanel.initialise(self)

    local x, y = self.buttonX, self.titleY

    self.StartButton = ISButton:new(10, 10, self.width-20, self.fontMedHeight*1.5, "Last Stand Together", self, lastStandTogetherPanel.startWaves)
    self.StartButton.font = UIFont.Medium
    self.StartButton:initialise()
    self.StartButton:instantiate()
    self:addChild(self.StartButton)

    for k,v in pairs(SandboxVars.LastStandTogether) do
        local title = getText("Sandbox_LastStandTogether_"..k)
        local button = ISButton:new(x, y, self.buttonWidth, self.buttonHeight, title, self, lastStandTogetherPanel.onButton)
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

    local width, height = getCore():getScreenWidth()/5, panelHeight
    local x, y = (getCore():getScreenWidth()-width)/2, (getCore():getScreenHeight()-height)/2

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
    o.backgroundColor = {r=0, g=0, b=0, a=0.4}
    o.borderColor = {r=0.2, g=0.2, b=0.2, a=0.9}
    o.width = width
    o.height = height
    o.text = ""
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