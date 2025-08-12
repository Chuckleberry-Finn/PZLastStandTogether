local spectateKeys = {
    fontHeight = getTextManager():MeasureFont(UIFont.Small)/2,
    keys = {
        { name=Keyboard.getKeyName(Keyboard.KEY_W), x=2, y=0 },
        { name=Keyboard.getKeyName(Keyboard.KEY_A), x=1, y=1 },
        { name=Keyboard.getKeyName(Keyboard.KEY_S), x=2, y=1 },
        { name=Keyboard.getKeyName(Keyboard.KEY_D), x=3, y=1 },
        { name=Keyboard.getKeyName(Keyboard.KEY_UP), x=5, y=0 },
        { name=Keyboard.getKeyName(Keyboard.KEY_DOWN), x=5, y=1 },
    },

}


local orig_CoopCharacterCreation_accept = CoopCharacterCreation.accept
function CoopCharacterCreation:accept()
    local respawnRule = SandboxVars.LastStandTogether.PlayerRespawn

    local LST_zone = LastStandTogether_Zone
    local currentScore = LST_zone.highscore.currentPlayers[getPlayer():getUsername()]

    if currentScore and ((respawnRule == 1 and currentScore.dead) or (respawnRule == 2 and LST_zone.def.wave == currentScore.dead)) then
        self:cancel()
        return
    end

    orig_CoopCharacterCreation_accept(self)
end



local function CameraMove()
    local player = getPlayer()

    if not ISPostDeathUI or not ISPostDeathUI.instance then return end
    if getTimestampMs() < ISPostDeathUI.waitTimeForSpectate then return end

    if player and player:isDead() then

        local LST_zone = LastStandTogether_Zone
        if not LST_zone then return end

        local zoneDef = LST_zone.def
        if not zoneDef or not zoneDef.center or not zoneDef.dimensions then return end

        local x, y, z = nil, nil, player:getZ()

        local building = player:getBuilding()
        if building then
            if isKeyDown(Keyboard.KEY_UP) then
                local newZ = z+1
                if getSquare(player:getX(), player:getY(), newZ) then
                    z = newZ
                end
            end

            if isKeyDown(Keyboard.KEY_DOWN) then
                local newZ = math.max(0, (z-1))
                if newZ~=z and getSquare(player:getX(), player:getY(), newZ) then
                    z = newZ
                end
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


local orig_ISPostDeathUI_prerender = ISPostDeathUI.prerender
function ISPostDeathUI:prerender()
    orig_ISPostDeathUI_prerender(self)

    local LST_zone = LastStandTogether_Zone
    local zoneDef = LST_zone and LST_zone.def
    local isZone = (zoneDef and zoneDef.center and zoneDef.center ~= nil) or false

    local player = getPlayer()
    if isZone then
        if player:isDead() then
            local kX, kY = -self.x+getCore():getScreenWidth()-(6.5*48), -self.y+(getCore():getScreenHeight()-(2.5*48))

            self:drawText("Movement", kX+(3*48)+8, kY+9+spectateKeys.fontHeight, 0.9, 0.9, 0.9, 0.6, UIFont.AutoNormSmall)

            self:drawTextCentre("Z Level ("..getPlayer():getZ()..")", kX+(5*48)+21, kY-8-(spectateKeys.fontHeight*2), 0.9, 0.9, 0.9, 0.6, UIFont.AutoNormSmall)

            for i=1, #spectateKeys.keys do
                local k = spectateKeys.keys[i]
                if k then
                    if not k.w then k.w = getTextManager():MeasureStringX(UIFont.Small, k.name) end
                    self:drawRectBorder(kX+(k.x*48), kY+(k.y*48), 43, 43, 0.9, 0.9, 0.9, 1)
                    self:drawTextCentre(k.name, kX+(k.x*48)+21, kY+(k.y*48)+9+spectateKeys.fontHeight, 0.9, 0.9, 0.9, 1, UIFont.AutoNormSmall)
                end
            end

            if not ISPostDeathUI.waitTimeForSpectate then
                ISPostDeathUI.waitTimeForSpectate = getTimestampMs() + 500
                player:setCanSeeAll(true)
                player:setCanHearAll(true)
                IsoCamera.setCamCharacter(getPlayer())
                Events.OnTick.Add(CameraMove)
            end
        end


        local respawnRule = SandboxVars.LastStandTogether.PlayerRespawn
        local currentScore = LST_zone.highscore.currentPlayers[getPlayer():getUsername()]
        local cannotRespawn = currentScore and ((respawnRule == 1 and currentScore.dead) or (respawnRule == 2 and LST_zone.def.wave == currentScore.dead))
        local respawnAvailable = (not cannotRespawn)

        if not respawnAvailable then
            self:drawTextCentre("Respawn Not Available", self.buttonRespawn.x+(self.buttonRespawn.width/2), self.buttonRespawn.y+(self.buttonRespawn.height/2), 1, 0.2, 0.2, 1, UIFont.Medium)
        end

        self.buttonRespawn:setVisible(respawnAvailable)
    end
end