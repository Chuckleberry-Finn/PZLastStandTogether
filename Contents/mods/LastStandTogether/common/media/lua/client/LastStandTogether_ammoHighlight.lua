local Ammo = require "WeaponSystems/Utils/Ammo"

local ammoHighlight = {}

ammoHighlight.color = {r=0.35, g=0.95, b=0.35}

---@param gunFullType string
---@return table|nil set (keys = ammo item type strings), or nil if this isn't a ranged weapon
ammoHighlight.compatibleAmmoCache = {}

function ammoHighlight.getCompatibleAmmoTypes(gunFullType)
    local cached = ammoHighlight.compatibleAmmoCache[gunFullType]
    if cached ~= nil then
        return cached or nil
    end

    local set = nil

    if Ammo and Ammo.ItemAmmoFamily then
        local family = Ammo.ItemAmmoFamily[gunFullType]
        if family then
            local bulletTypes = Ammo.GetBulletTypesForFamily(family)
            if bulletTypes then
                set = set or {}
                for i=1, #bulletTypes do
                    set[bulletTypes[i]] = true
                end
            end
        end
    end

    local script = getScriptManager():getItem(gunFullType)
    local scriptAmmoType = script and script:getAmmoType()
    local scriptAmmoKey = scriptAmmoType and scriptAmmoType:getItemKey()
    if scriptAmmoKey then
        set = set or {}
        set[scriptAmmoKey] = true
    end

    if script and (set or scriptAmmoKey) then
        local tempWeapon = script:InstanceItem(nil)
        if tempWeapon and instanceof(tempWeapon, "HandWeapon") then
            local ammoBox = tempWeapon:getAmmoBox()
            if ammoBox and ammoBox ~= "" then
                set = set or {}
                set[ammoBox] = true
            end

            local magType = tempWeapon:getMagazineType()
            if magType and magType ~= "" then
                set = set or {}
                set[magType] = true
            end
        end
    end

    ammoHighlight.compatibleAmmoCache[gunFullType] = set or false
    return set
end


---@param container ItemContainer
---@param results InventoryItem[] accumulator
local function collectGunsRecurse(container, results)
    if not container then return end
    local items = container:getItems()
    for i=0, items:size()-1 do
        local item = items:get(i)
        if item then
            if instanceof(item, "HandWeapon") and item:isRanged() then
                table.insert(results, item)
            end
            if item.getInventory and item:getInventory() then
                collectGunsRecurse(item:getInventory(), results)
            end
        end
    end
end


function ammoHighlight.playerHasAmmoForGun(player, gunFullType)
    local ammoTypes = ammoHighlight.getCompatibleAmmoTypes(gunFullType)
    if not ammoTypes then return false end

    local inventory = player:getInventory()
    if not inventory then return false end

    for ammoType,_ in pairs(ammoTypes) do
        if inventory:getCountTypeRecurse(ammoType) > 0 then return true end
    end
    return false
end


ammoHighlight.gunsCacheRefreshMs = 500
ammoHighlight.cachedGunTypes = nil
ammoHighlight.gunsCacheTime = 0

function ammoHighlight.playerHasGunForAmmo(player, ammoFullType)
    local now = getTimestampMs()
    if not ammoHighlight.cachedGunTypes or ammoHighlight.gunsCacheTime <= now then
        ammoHighlight.gunsCacheTime = now + ammoHighlight.gunsCacheRefreshMs
        local inventory = player:getInventory()
        local guns = {}
        if inventory then collectGunsRecurse(inventory, guns) end
        ammoHighlight.cachedGunTypes = {}
        for i=1, #guns do
            ammoHighlight.cachedGunTypes[i] = guns[i]:getFullType()
        end
    end

    for i=1, #ammoHighlight.cachedGunTypes do
        local ammoTypes = ammoHighlight.getCompatibleAmmoTypes(ammoHighlight.cachedGunTypes[i])
        if ammoTypes and ammoTypes[ammoFullType] then return true end
    end
    return false
end


storeWindow.getListingHighlight = function(itemFullType, listing, player)
    if type(itemFullType) ~= "string" then return nil end
    if string.match(itemFullType, "category:") then return nil end
    if not player then return nil end

    local ammoTypes = ammoHighlight.getCompatibleAmmoTypes(itemFullType)
    if ammoTypes then
        if ammoHighlight.playerHasAmmoForGun(player, itemFullType) then
            return ammoHighlight.color, "You're carrying compatible ammo"
        end
        return nil
    end

    if ammoHighlight.playerHasGunForAmmo(player, itemFullType) then
        return ammoHighlight.color, "You're carrying a compatible weapon"
    end

    return nil
end


return ammoHighlight
