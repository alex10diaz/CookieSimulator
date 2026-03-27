-- ServerScriptService/Core/GamepassManager (ModuleScript)
-- M-12: Gamepass scaffold — grants benefits when players own a gamepass.
-- NOTE: In Studio this is a ModuleScript (not Script) so it can be required.
-- Replace PLACEHOLDER IDs with real Roblox Gamepass IDs before launch.
--
-- SPEED_PASS  (ID: set below) — skips the PreOpen phase on join
-- VIP_PASS    (ID: set below) — 1.5× coin multiplier on all deliveries
-- BOOST_TOKEN (Dev Product)   — 2× coins for one shift (consumable)

local Players           = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

-- ── GAMEPASS IDs (replace 0 with real IDs before launch) ─────────────────────
local SPEED_PASS_ID  = 0   -- Skip PreOpen phase
local VIP_PASS_ID    = 0   -- 1.5× coin multiplier

-- ── DEV PRODUCT IDs ───────────────────────────────────────────────────────────
local BOOST_TOKEN_ID = 0   -- 2× coins for one shift (consumable)

-- ── PLAYER BENEFIT STATE ─────────────────────────────────────────────────────
-- These are checked by other systems via GamepassManager.HasBenefit(player, id)
local benefits = {}  -- userId -> { speedPass=bool, vipPass=bool, boostActive=bool }

local function getBenefits(player)
    local uid = player.UserId
    if not benefits[uid] then benefits[uid] = {} end
    return benefits[uid]
end

-- ── MODULE API ────────────────────────────────────────────────────────────────
local GamepassManager = {}

function GamepassManager.HasSpeedPass(player)
    return getBenefits(player).speedPass == true
end

function GamepassManager.HasVIPPass(player)
    return getBenefits(player).vipPass == true
end

function GamepassManager.HasBoostActive(player)
    return getBenefits(player).boostActive == true
end

-- Call to activate Boost Token for this player's current shift
function GamepassManager.ActivateBoost(player)
    getBenefits(player).boostActive = true
    print("[GamepassManager] Boost Token activated for " .. player.Name)
end

-- Called each shift end to clear consumable boost
function GamepassManager.ClearBoost(player)
    getBenefits(player).boostActive = false
end

-- ── OWNERSHIP CHECK ON JOIN ───────────────────────────────────────────────────
local function checkGamepasses(player)
    local b = getBenefits(player)

    -- Speed Pass
    if SPEED_PASS_ID ~= 0 then
        local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync,
            MarketplaceService, player.UserId, SPEED_PASS_ID)
        b.speedPass = ok and owns or false
    end

    -- VIP Pass
    if VIP_PASS_ID ~= 0 then
        local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync,
            MarketplaceService, player.UserId, VIP_PASS_ID)
        b.vipPass = ok and owns or false
    end

    if b.speedPass or b.vipPass then
        print(string.format("[GamepassManager] %s: SpeedPass=%s VIPPass=%s",
            player.Name, tostring(b.speedPass), tostring(b.vipPass)))
    end
end

Players.PlayerAdded:Connect(function(player)
    checkGamepasses(player)
end)

Players.PlayerRemoving:Connect(function(player)
    benefits[player.UserId] = nil
end)

-- ── DEV PRODUCT HANDLER ───────────────────────────────────────────────────────
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

    if receiptInfo.ProductId == BOOST_TOKEN_ID then
        GamepassManager.ActivateBoost(player)
        -- Notify client
        local ok, rm = pcall(require, ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
        if ok then
            rm.Get("ShowAlert"):FireClient(player, "Boost Token active! 2x coins this shift.")
        end
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Handle existing players (required if module loads after some players joined)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(checkGamepasses, p)
end

print("[GamepassManager] Ready — SpeedPass=" .. SPEED_PASS_ID .. " VIPPass=" .. VIP_PASS_ID)
return GamepassManager
