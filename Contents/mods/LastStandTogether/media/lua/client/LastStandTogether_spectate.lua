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
    ISPostDeathUI.waitTimeForSpectate = -1
    ISPostDeathUI.spectateDot = getTexture("media/textures/ui/spectateDot.png")

    if player and player:isDead() then

        ISPostDeathUI.spectateOffsets = ISPostDeathUI.spectateOffsets or {x=player:getX(), y=player:getY(), z=player:getZ()}

        local LST_zone = LastStandTogether_Zone
        if not LST_zone then return end

        local zoneDef = LST_zone.def
        if not zoneDef or not zoneDef.center or not zoneDef.dimensions then return end

        local x, y, z = nil, nil, ISPostDeathUI.spectateOffsets.z

        if isKeyDown(Keyboard.KEY_UP) then
            z = (z or ISPostDeathUI.spectateOffsets.z)+0.2
        end
        if isKeyDown(Keyboard.KEY_DOWN) then
            z = math.max(0, ((z or ISPostDeathUI.spectateOffsets.z)-0.2))
        end

        if isKeyDown(Keyboard.KEY_A) then
            x = (x or ISPostDeathUI.spectateOffsets.x)-0.1
            y = (y or ISPostDeathUI.spectateOffsets.y)+0.1
        end
        if isKeyDown(Keyboard.KEY_D) then
            x = (x or ISPostDeathUI.spectateOffsets.x)+0.1
            y = (y or ISPostDeathUI.spectateOffsets.y)-0.1
        end
        if isKeyDown(Keyboard.KEY_W) then
            x = (x or ISPostDeathUI.spectateOffsets.x)-0.1
            y = (y or ISPostDeathUI.spectateOffsets.y)-0.1

        end
        if isKeyDown(Keyboard.KEY_S) then
            x = (x or ISPostDeathUI.spectateOffsets.x)+0.1
            y = (y or ISPostDeathUI.spectateOffsets.y)+0.1
        end


        if x and  x ~= ISPostDeathUI.spectateOffsets.x then
            local minX = zoneDef.center.x - (zoneDef.dimensions.w*0.95)
            local maxX = zoneDef.center.x + (zoneDef.dimensions.w*0.95)
            ISPostDeathUI.spectateOffsets.x = math.max(minX, math.min(x, maxX))
        end

        if y and y ~= ISPostDeathUI.spectateOffsets.y then
            local minY = zoneDef.center.y - (zoneDef.dimensions.h*0.95)
            local maxY = zoneDef.center.y + (zoneDef.dimensions.h*0.95)
            ISPostDeathUI.spectateOffsets.y = math.max(minY, math.min(y, maxY))
        end

        if z and z ~= ISPostDeathUI.spectateOffsets.z then ISPostDeathUI.spectateOffsets.z = z end

        local square = getSquare(ISPostDeathUI.spectateOffsets.x, ISPostDeathUI.spectateOffsets.y, math.floor(ISPostDeathUI.spectateOffsets.z))
        if not square then ISPostDeathUI.spectateOffsets.z = ISPostDeathUI.spectateOffsets.z-0.2 end

        player:setX(ISPostDeathUI.spectateOffsets.x)
        player:setLx(ISPostDeathUI.spectateOffsets.x)
        player:setY(ISPostDeathUI.spectateOffsets.y)
        player:setLy(ISPostDeathUI.spectateOffsets.y)
        player:setZ(math.floor(ISPostDeathUI.spectateOffsets.z))
        player:setJustMoved(true)
        player:setMoveDelta(1)
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
            elseif ISPostDeathUI.waitTimeForSpectate == -1 then
                local pX, pY, pZ = player:getX(), player:getY(), player:getZ()
                local sx1, sy1 = ISCoordConversion.ToScreen(pX, pY, pZ)
                local zoom = getCore():getZoom(0)
                local size = 6
                getRenderer():render(ISPostDeathUI.spectateDot, (sx1-(size/2))/zoom, (sy1-(size/2))/zoom, size, size, 1, 1, 1, 0.7, nil)
            end
        end

        local respawnRule = SandboxVars.LastStandTogether.PlayerRespawn
        local currentScore = LST_zone.highscore.currentPlayers[getPlayer():getUsername()]
        local cannotRespawn = currentScore and ((respawnRule == 1 and currentScore.dead) or (respawnRule == 2 and zoneDef.wave == currentScore.dead))
        local respawnAvailable = (not cannotRespawn) or (respawnRule==3) or (respawnRule == 2 and not zoneDef.wave)

        if not respawnAvailable then
            self:drawTextCentre("Respawn Not Available", self.buttonRespawn.x+(self.buttonRespawn.width/2), self.buttonRespawn.y+(self.buttonRespawn.height/2), 1, 0.2, 0.2, 1, UIFont.Medium)
        end

        self.buttonRespawn:setVisible(respawnAvailable)
    else
        self.buttonRespawn:setVisible(true)
    end
end