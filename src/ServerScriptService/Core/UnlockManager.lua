-- ServerScriptService/Core/UnlockManager (ModuleScript)
-- Catalog of purchasable upgrades and cosmetics.
-- Handles PurchaseItem remote, validates purchases, updates PlayerDataManager.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

-- ── CATALOG ────────────────────────────────────────────────────
-- tab: "Upgrades" or "Cosmetics"
-- requires: itemId that must be owned first (or nil)
-- itemType: "station" (bakery-wide stub) or "cosmetic" (player-owned)

local CATALOG = {
    -- UPGRADES (server-side effects stubbed in M6 — StationUnlocked BindableEvent fires on purchase)
    { id = "tip_boost_1",       tab = "Upgrades",  itemType = "station",  name = "Tip Boost I",          price = 3000, desc = "+10% NPC tips each shift",              requires = nil },
    { id = "patience_boost_1",  tab = "Upgrades",  itemType = "station",  name = "Patient Customers I",  price = 2500, desc = "+10s NPC patience",                      requires = nil },
    { id = "tip_boost_2",       tab = "Upgrades",  itemType = "station",  name = "Tip Boost II",         price = 6000, desc = "+20% total NPC tips (requires Boost I)",  requires = "tip_boost_1" },
    { id = "patience_boost_2",  tab = "Upgrades",  itemType = "station",  name = "Patient Customers II", price = 5000, desc = "+20s total patience (requires Boost I)",   requires = "patience_boost_1" },

    -- COSMETICS (owned in profile; equippable via Character Closet in Phase 5)
    { id = "hat_chef",          tab = "Cosmetics", itemType = "cosmetic", name = "Chef Hat",             price = 500,  desc = "A classic tall chef's hat",              requires = nil },
    { id = "hat_beret",         tab = "Cosmetics", itemType = "cosmetic", name = "Baker's Beret",        price = 750,  desc = "A stylish baker's beret",                requires = nil },
    { id = "apron_classic",     tab = "Cosmetics", itemType = "cosmetic", name = "Classic Apron",        price = 600,  desc = "A timeless white baker's apron",         requires = nil },
    { id = "apron_pink",        tab = "Cosmetics", itemType = "cosmetic", name = "Pink Apron",           price = 800,  desc = "Show your sweet side",                   requires = nil },
    { id = "apron_cookie",      tab = "Cosmetics", itemType = "cosmetic", name = "Cookie Print Apron",   price = 1200, desc = "Covered in tiny cookie prints",          requires = nil },
    { id = "hat_cap",           tab = "Cosmetics", itemType = "cosmetic", name = "Baker's Cap",          price = 400,  desc = "Simple and clean baseball-style cap",    requires = nil },
}

-- Fast lookup by id
local catalogById = {}
for _, item in ipairs(CATALOG) do
    catalogById[item.id] = item
end

-- ── STATIONUNLOCKED BINDABLE ────────────────────────────────────
local stationUnlockedEvent = ServerStorage
    :WaitForChild("Events")
    :WaitForChild("StationUnlocked")

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

    -- Afford check
    local success, newCoins = PlayerDataManager.DeductCoins(player, item.price)
    if not success then
        return false, "Not enough coins"
    end

    -- Record ownership
    PlayerDataManager.AddUnlock(player, itemId, item.itemType)

    -- Fire StationUnlocked for upgrade items (station scripts hook this later)
    if item.itemType == "station" then
        stationUnlockedEvent:Fire(player, itemId)
    end

    return true, newCoins
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
        })
    else
        resultRemote:FireClient(player, {
            success = false,
            reason  = result,  -- result is reason string on failure
        })
    end
end)

print("[UnlockManager] Ready — " .. #CATALOG .. " items in catalog.")
return UnlockManager
