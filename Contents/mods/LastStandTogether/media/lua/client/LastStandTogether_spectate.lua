---CREDIT: TchernoLib B41: https://steamcommunity.com/sharedfiles/filedetails/?id=2986578314
-- and Battle Royal also by Tchernobill https://steamcommunity.com/sharedfiles/filedetails/?id=2970134188

--[[
if not getActivatedMods():contains("TchernoLib") then return end

require "Spectate/Spectate.lua"

function lastStandTogetherSpectate(targetFunc, button, userName)

    if not userName then return end

    local player = getPlayer()
    if not player then return end

    if userName == player:getUsername() then
        if not Spectate.isSpectating(player) and getDebug() then
            player:Kill(nil)
        end
    else
        if not (Spectate.isSpectating(player) or player:isAccessLevel("Admin")) then return end
        local onlineUsers = getOnlinePlayers()
        if onlineUsers then

            for i=0, onlineUsers:size()-1 do
                local targetPlayer = onlineUsers:get(i)
                if targetPlayer and targetPlayer:getUsername() == userName then

                    local x = targetPlayer:getX()
                    local y = targetPlayer:getY()
                    local z = targetPlayer:getZ()

                    if isClient() then
                        SendCommandToServer("/teleportto " .. x .. "," .. y .. "," .. z)
                    else
                        player:setX(x)
                        player:setY(y)
                        player:setZ(z)
                        player:setLx(x)
                        player:setLy(y)
                        player:setLz(z)
                    end
                end
            end
        end
    end
end

local orig_ISPostDeathUI_createChildren = ISPostDeathUI.createChildren
function ISPostDeathUI:createChildren()
    orig_ISPostDeathUI_createChildren(self)

    local buttonWid = 250
    local buttonHgt = 40
    local buttonGapY = 12
    local buttonX = 0
    if not self.bottomButtonY then self.bottomButtonY = self.buttonQuit:getY() end
    if not self.totalHgt then self.totalHgt = (buttonHgt * 3) + (buttonGapY * 2) end

    self.bottomButtonY = self.bottomButtonY + buttonHgt + buttonGapY
    local button = ISButton:new(buttonX, self.bottomButtonY, buttonWid, buttonHgt, getText("IGUI_PostDeath_Spectate"), self, ISPostDeathUI.onClickSpectate)
    self:configButton(button)
    self:addChild(button)
    self.buttonSpectate = button
    self.totalHgt = self.totalHgt + buttonGapY + buttonHgt

    --self:setWidth(buttonWid)
    self:setHeight(self.totalHgt)
    -- must set these after setWidth/setHeight or getKeepOnScreen will mess them up
    self:setX(self.screenX + (self.screenWidth - buttonWid) / 2)
    self:setY(self.screenY + (self.screenHeight - 40 - self.totalHgt))
end
--]]


--[[
local orig_ISPostDeathUI_prerender = ISPostDeathUI.prerender
function ISPostDeathUI:prerender()
    orig_ISPostDeathUI_prerender(self)

    local LST_zone = LastStandTogether_Zone
    local zoneDef = LST_zone and LST_zone.def
    local isZone = (zoneDef and zoneDef.center and zoneDef.center ~= nil) or false
    --self.buttonSpectate:setVisible(isZone)
    self.buttonRespawn:setVisible(not isZone)
    self.buttonQuit:setVisible(true)
    self.buttonExit:setVisible(true)
end
--]]


--[[
function ISPostDeathUI:onClickSpectate()
    --removes post death UI

    --if ISPostDeathUI.instance[0] then
    --    ISPostDeathUI.instance[0]:removeFromUIManager()
    --    ISPostDeathUI.instance[0] = nil
    --end
    Spectate.onSpectateStart()
end
--]]


local function CameraMove()
    local player = getPlayer()

    if player and player:isDead() then

        local LST_zone = LastStandTogether_Zone
        if not LST_zone then return end

        local zoneDef = LST_zone.def
        if not zoneDef or not zoneDef.center or not zoneDef.dimensions then return end

        player:setCanSeeAll(true)
        player:setCanHearAll(true)

        local x, y, z = nil, nil, player:getZ()

        local building = player:getBuilding()
        if building then
            if isKeyDown(Keyboard.KEY_UP) then
                z = (z+1)
            end

            if isKeyDown(Keyboard.KEY_DOWN) then
                z = math.max(0, (z-1))
            end
        else
            z = 0
        end

        if isKeyDown(Keyboard.KEY_A) then
            x = (x or player:getX())-0.2
            y = (y or player:getY())+0.2
        end
        if isKeyDown(Keyboard.KEY_D) then
            x = (x or player:getX())+0.2
            y = (y or player:getY())-0.2
        end
        if isKeyDown(Keyboard.KEY_W) then
            x = (x or player:getX())-0.2
            y = (y or player:getY())-0.2

        end
        if isKeyDown(Keyboard.KEY_S) then
            x = (x or player:getX())+0.2
            y = (y or player:getY())+0.2
        end

        if x and y then

            local minX = zoneDef.center.x - (zoneDef.dimensions.w*0.95)
            local maxX = zoneDef.center.x + (zoneDef.dimensions.w*0.95)
            local minY = zoneDef.center.y - (zoneDef.dimensions.h*0.95)
            local maxY = zoneDef.center.y + (zoneDef.dimensions.h*0.95)

            local clampedX = math.max(minX, math.min(x, maxX))
            local clampedY = math.max(minY, math.min(y, maxY))

            player:setX(clampedX)
            player:setLx(clampedX)

            player:setY(clampedY)
            player:setLy(clampedY)

            player:setZ(z)

            player:setJustMoved(true)
            player:setMoveDelta(1)
        end
    end
end
Events.OnTick.Add(CameraMove)