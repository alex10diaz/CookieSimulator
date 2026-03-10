-- CookieUnlockManager (ModuleScript, ServerScriptService/Core)
-- Server-side cookie ownership and purchase logic.
-- Required by MenuServer. Call GrantStarters on PlayerAdded.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local CookieUnlockManager = {}

-- Returns the array of owned cookie IDs for this player.
function CookieUnlockManager.GetOwned(player)
    return PlayerDataManager.GetOwnedCookies(player)
end

function CookieUnlockManager.IsOwned(player, cookieId)
    for _, id in ipairs(CookieUnlockManager.GetOwned(player)) do
        if id == cookieId then return true end
    end
    return false
end

-- Ensures all starter cookies are in the player's owned list.
-- Safe to call multiple times (AddOwnedCookie is idempotent).
function CookieUnlockManager.GrantStarters(player)
    for _, id in ipairs(CookieData.StarterIds) do
        PlayerDataManager.AddOwnedCookie(player, id)
    end
end

-- Attempts to purchase a cookie for the player.
-- Returns ok (bool), message/newCoins.
function CookieUnlockManager.PurchaseCookie(player, cookieId)
    local cookie = CookieData.GetById(cookieId)
    if not cookie then
        return false, "Unknown cookie"
    end
    if CookieUnlockManager.IsOwned(player, cookieId) then
        return false, "Already owned"
    end
    local cost = CookieData.GetUnlockCost(cookieId)
    local ok, newCoins = PlayerDataManager.DeductCoins(player, cost)
    if not ok then
        return false, "Not enough coins"
    end
    PlayerDataManager.AddOwnedCookie(player, cookieId)
    return true, newCoins
end

return CookieUnlockManager
