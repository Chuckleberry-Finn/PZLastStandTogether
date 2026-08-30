local modOptions = {}

modOptions.defaultZoneColor = {r=0.854901961, g=0.64705882352, b=0.125490196, a=0.5}

modOptions.zoneColorOption = nil

local function createModOptionsUI()
    if not PZAPI or not PZAPI.ModOptions then return end

    local options = PZAPI.ModOptions:create("LastStandTogether", getText("UI_ConfigMODID_LastStandTogether"))

    modOptions.zoneColorOption = options:addColorPicker(
        "lst_ZoneColor",
        getText("UI_LST_ZoneColor"),
        modOptions.defaultZoneColor.r,
        modOptions.defaultZoneColor.g,
        modOptions.defaultZoneColor.b,
        modOptions.defaultZoneColor.a,
        getText("UI_LST_ZoneColorToolTip")
    )

    PZAPI.ModOptions:load()
end


function modOptions.getZoneColor()
    if modOptions.zoneColorOption then
        return modOptions.zoneColorOption:getValue()
    end
    return modOptions.defaultZoneColor
end


Events.OnGameBoot.Add(createModOptionsUI)

return modOptions
