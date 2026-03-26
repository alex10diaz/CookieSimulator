-- ServerScriptService/Core/UnlockManager (Script — auto-runs on server start)
-- Catalog of purchasable upgrades and cosmetics.
-- Handles PurchaseItem remote, validates purchases, updates PlayerDataManager.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

-- ── CATALOG ────────────────────────────────────────────────────
-- tab: "Upgrades" or "Cosmetics"
-- source: "shop" (buy with coins) | "station" (earn via mastery)
-- itemType: "station" (bakery-wide stub) or "cosmetic" (player-owned)
-- stationReq/levelReq: only for source="station" cosmetics

local CATALOG = {
    -- UPGRADES
    { id = "tip_boost_1",       tab = "Upgrades",  itemType = "station",  source = "shop",    name = "Tip Boost I",            price = 3000, desc = "+10% NPC tips each shift",              requires = nil, bakeryLevelReq = 3 },
    { id = "patience_boost_1",  tab = "Upgrades",  itemType = "station",  source = "shop",    name = "Patient Customers I",    price = 2500, desc = "+10s NPC patience",                      requires = nil },
    { id = "tip_boost_2",       tab = "Upgrades",  itemType = "station",  source = "shop",    name = "Tip Boost II",           price = 6000, desc = "+20% total NPC tips (requires Boost I)",  requires = "tip_boost_1" },
    { id = "patience_boost_2",  tab = "Upgrades",  itemType = "station",  source = "shop",    name = "Patient Customers II",   price = 5000, desc = "+20s total patience (requires Boost I)",   requires = "patience_boost_1" },

    -- SHOP COSMETICS (buy with coins)
    { id = "hat_chef",          tab = "Cosmetics", itemType = "cosmetic", source = "shop",    name = "Chef Hat",               price = 500,  desc = "A classic tall chef's hat" },
    { id = "hat_beret",         tab = "Cosmetics", itemType = "cosmetic", source = "shop",    name = "Baker's Beret",          price = 750,  desc = "A stylish baker's beret" },
    { id = "hat_cap",           tab = "Cosmetics", itemType = "cosmetic", source = "shop",    name = "Baker's Cap",            price = 400,  desc = "Simple and clean baseball-style cap" },
    { id = "apron_classic",     tab = "Cosmetics", itemType = "cosmetic", source = "shop",    name = "Classic Apron",          price = 600,  desc = "A timeless white baker's apron" },
    { id = "apron_pink",        tab = "Cosmetics", itemType = "cosmetic", source = "shop",    name = "Pink Apron",             price = 800,  desc = "Show your sweet side" },
    { id = "apron_cookie",      tab = "Cosmetics", itemType = "cosmetic", source = "shop",    name = "Cookie Print Apron",     price = 1200, desc = "Covered in tiny cookie prints" },

    -- STATION COSMETICS (earned via mastery — cannot be purchased)
    { id = "hat_station_mix",   tab = "Cosmetics", itemType = "cosmetic", source = "station", name = "Flour Dusted Cap",       stationReq = "Mixer",     levelReq = 3, desc = "Earned by reaching Mixer level 3" },
    { id = "apron_station_bake",tab = "Cosmetics", itemType = "cosmetic", source = "station", name = "Oven Master Apron",      stationReq = "Baker",     levelReq = 3, desc = "Earned by reaching Baker level 3" },
    { id = "hat_station_dec",   tab = "Cosmetics", itemType = "cosmetic", source = "station", name = "Decorator's Crown",      stationReq = "Decorator", levelReq = 5, desc = "Earned by reaching Decorator level 5" },
    { id = "apron_station_frost",tab= "Cosmetics", itemType = "cosmetic", source = "station", name = "Glazer's Apron",         stationReq = "Glazer",    levelReq = 3, desc = "Earned by reaching Glazer level 3" },
}

-- Fast lookup by id
local catalogById = {}
for _, item in ipairs(CATALOG) do
    catalogById[item.id] = item
end

-- ── BINDABLE EVENTS ─────────────────────────────────────────────
local eventsFolder = ServerStorage:WaitForChild("Events")
local stationUnlockedEvent  = eventsFolder:WaitForChild("StationUnlocked")
local cosmeticEquippedEvent = eventsFolder:WaitForChild("CosmeticEquipped")

-- ── MODULE API ──────────────────────────────────────────────────
local UnlockManager = {}

function UnlockManager.GetCatalog()
    return CATALOG
end

function UnlockManager.GetItem(itemId)
    return catalogById[itemId]
end

function UnlockManager.Owns(player, itemId)
    local item = catalogById[itemId]
    if not item then return false end
    local stations, cosmetics = PlayerDataManager.GetUnlocks(player)
    local list = item.itemType == "cosmetic" and cosmetics or stations
    for _, id in ipairs(list) do
        if id == itemId then return true end
    end
    return false
end

function UnlockManager.CanAfford(player, itemId)
    local item = catalogById[itemId]
    if not item then return false end
    local data = PlayerDataManager.GetData(player)
    if not data then return false end
    return data.coins >= item.price
end

-- Returns: success (bool), reason (string)
function UnlockManager.Purchase(player, itemId)
    local item = catalogById[itemId]
    if not item then
        return false, "Item does not exist"
    end

    -- Already owned?
    if UnlockManager.Owns(player, itemId) then
        return false, "Already owned"
    end

    -- Prerequisite check
    if item.requires and not UnlockManager.Owns(player, item.requires) then
        local req = catalogById[item.requires]
        local reqName = req and req.name or item.requires
        return false, "Requires " .. reqName .. " first"
    end

    -- H-5: Bakery level requirement
    if item.bakeryLevelReq then
        local data = PlayerDataManager.GetData(player)
        local lvl = data and data.bakeryLevel or 1
        if lvl < item.bakeryLevelReq then
            return false, "Requires Bakery Level " .. item.bakeryLevelReq
        end
    end

    -- Afford check
    local success, newCoins = PlayerDataManager.DeductCoins(player, item.price)
    if not success then
        return false, "Not enough coins"
    end

    -- Record ownership
    PlayerDataManager.AddUnlock(player, itemId, item.itemType)

    -- Auto-equip cosmetics on purchase and notify CosmeticService
    if item.itemType == "cosmetic" then
        PlayerDataManager.EquipCosmetic(player, itemId)
        cosmeticEquippedEvent:Fire(player, itemId)
    end

    -- Fire StationUnlocked for upgrade items (station scripts hook this later)
    if item.itemType == "station" then
        stationUnlockedEvent:Fire(player, itemId)
    end

    return true, newCoins
end

-- Checks if any station-earned cosmetics are now unlocked for this player
-- Call this after every mastery level-up
function UnlockManager.CheckMasteryGrants(player)
    local data = PlayerDataManager.GetData(player)
    if not data or not data.mastery then return end
    for _, item in ipairs(CATALOG) do
        if item.source == "station" and item.itemType == "cosmetic" then
            if not UnlockManager.Owns(player, item.id) then
                local currentLevel = data.mastery[(item.stationReq .. "Level")] or 1
                if currentLevel >= item.levelReq then
                    PlayerDataManager.AddUnlock(player, item.id, "cosmetic")
                    PlayerDataManager.EquipCosmetic(player, item.id)
                    cosmeticEquippedEvent:Fire(player, item.id)
                    print(string.format("[UnlockManager] %s earned station cosmetic: %s", player.Name, item.id))
                end
            end
        end
    end
end

-- ── REMOTE HANDLER ──────────────────────────────────────────────
local purchaseRemote = RemoteManager.Get("PurchaseItem")
local resultRemote   = RemoteManager.Get("PurchaseResult")

purchaseRemote.OnServerEvent:Connect(function(player, itemId)
    if type(itemId) ~= "string" then
        resultRemote:FireClient(player, { success = false, reason = "Invalid request" })
        return
    end

    local ok, result = UnlockManager.Purchase(player, itemId)
    if ok then
        local newCoins = result  -- result is newCoins on success
        local stations, cosmetics = PlayerDataManager.GetUnlocks(player)
        resultRemote:FireClient(player, {
            success           = true,
            itemId            = itemId,
            newCoins          = newCoins,
            unlockedStations  = stations,
            unlockedCosmetics = cosmetics,
            equippedCosmetics = PlayerDataManager.GetEquipped(player),
        })
    else
        resultRemote:FireClient(player, {
            success = false,
            reason  = result,
        })
    end
end)

-- SetCosmetic: equip (cosmeticId) or unequip (nil, slot)
local setCosmeticRemote = RemoteManager.Get("SetCosmetic")
local cosmeticEquippedEvent2 = ServerStorage:WaitForChild("Events"):WaitForChild("CosmeticEquipped")

setCosmeticRemote.OnServerEvent:Connect(function(player, cosmeticId, slot)
    if cosmeticId ~= nil then
        -- Equip: validate ownership first
        if type(cosmeticId) ~= "string" then return end
        if not UnlockManager.Owns(player, cosmeticId) then return end
        PlayerDataManager.EquipCosmetic(player, cosmeticId)
        cosmeticEquippedEvent2:Fire(player, cosmeticId)
    else
        -- Unequip: clear the slot
        if slot ~= "hat" and slot ~= "apron" then return end
        local p = PlayerDataManager.GetData(player)
        if not p then return end
        if p.equippedCosmetics then p.equippedCosmetics[slot] = nil end
        cosmeticEquippedEvent2:Fire(player, nil, slot)
    end
end)

print("[UnlockManager] Ready — " .. #CATALOG .. " items in catalog.")
