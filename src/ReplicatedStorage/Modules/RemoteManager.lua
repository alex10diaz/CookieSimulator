-- RemoteManager
-- Single source of truth for all RemoteEvents.
-- No system should create or find remotes outside this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

-- Server creates the folder; client waits for it.
local GameEvents
if RunService:IsServer() then
    GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
    if not GameEvents then
        GameEvents = Instance.new("Folder")
        GameEvents.Name = "GameEvents"
        GameEvents.Parent = ReplicatedStorage
    end
else
    GameEvents = ReplicatedStorage:WaitForChild("GameEvents", 30)
end

local RemoteManager = {}

-- Registry of all valid remote names
local REMOTES = {
    -- Mix
    "ShowMixPicker",
    "RequestMixStart",
    "StartMixMinigame",
    "MixMinigameResult",
    "MixProgress",
    -- Dough
    "StartDoughMinigame",
    "DoughMinigameResult",
    -- Fridge / Carry
    "PullFromFridge",
    "PullFromFridgeResult",
    "DepositDough",
    -- Oven
    "StartOvenMinigame",
    "OvenMinigameResult",
    -- Frost
    "StartFrostMinigame",
    "FrostMinigameResult",
    -- Dress
    "StartDressMinigame",
    "DressMinigameResult",
    -- NPC cutscene flow
    "StartOrderCutscene",
    "ConfirmNPCOrder",
    -- Dress KDS
    "DressKDSUpdate",
    "DressLockOrder",
    "DressOrderLocked",
    "DressCancelOrder",
    -- Orders & state
    "BatchUpdated",
    "FridgeUpdated",
    "WarmersUpdated",
    "NPCOrderReady",
    -- Boxes
    "BoxCarried",
    "BoxDelivered",
    "BoxCreated",
    "ForceDropBox",
    -- M1: Game state & session
    "GameStateChanged",
    "AcceptOrder",
    "OrderAccepted",
    "OrderFailed",
    "HUDUpdate",
    "DeliverBox",
    "DeliveryResult",
    "EndOfDaySummary",
    "TutorialComplete",
    "TutorialStep",
    "ReplayTutorial",
    "StartGame",
    -- M6: Meta systems
    "RushHour",
    "LeaderboardUpdate",
    "PurchaseItem",
    "PurchaseResult",
    "SetCosmetic",          -- Client->Server: equip (cosmeticId) or unequip (nil, slot)
    "SlotSelect",
    "SlotSelectResult",
    "PlayerDataInit",   -- Server→Client: sends coins/level/unlocks on profile load
    -- Phase 2: Bakery identity
    "SetBakeryName",    -- Client→Server: player submits chosen bakery name
    "BakeryNameResult", -- Server→Client: success/failure + final name
    "BakeryLevelUp",    -- Server→Client: new bakery level on level-up
    "UpdateNameplate",  -- Server→All clients: broadcast the active bakery name
    -- Phase 2: Menu selection
    "OpenMenuBoard",       -- Server→Client: open menu selection UI (fires on PreOpen)
    "SetMenuSelection",    -- Client→Server: array of cookieIds player selected
    "MenuSelectionResult", -- Server→All: success/fail + updated menu list
    "MenuLocked",          -- Server→All: menu is now locked (Open phase started)
    -- Cookie unlock shop
    "PurchaseCookie",       -- Client→Server: buy a cookie by id
    "PurchaseCookieResult", -- Server→Client: ok/fail + newCoins + cookieId
    "StationRemapped",  -- Server->All: slot->cookieId map after menu locks
    "SkipPreOpen",      -- Client->Server: skip remaining PreOpen time
    -- Daily challenges
    "DailyChallengesInit",    -- Server->Client: send today's challenges + progress on join
    "DailyChallengeProgress", -- Server->Client: incremental progress update after each delivery
    -- Topping minigame
    "StartToppingMinigame",   -- Server->Client: begin topping minigame session
    "ToppingComplete",        -- Client->Server: player finished topping minigame
    -- Warmer stock HUD
    "WarmersStockUpdate",     -- Server->All: per-type warmer counts after any delivery or remap
    -- Station Mastery
    "MasteryLevelUp",         -- Server->Client: player leveled up a role
    -- Weekly challenges
    "WeeklyChallengesInit",   -- Server->Client: send this week's challenges + progress on join
    "WeeklyChallengeProgress",-- Server->Client: incremental progress update after each delivery
    -- Lifetime milestones
    "LifetimeChallengesInit",  -- Server->Client: full milestone list on join
    "LifetimeChallengeComplete",-- Server->Client: a milestone was just completed
    -- NPC order cancellation (patience/leave)
    "NPCOrderCancelledClient", -- Server->All clients: orderId that was cancelled (for HUD update)
    -- Minigame cancel (player presses Exit button)
    "CancelMinigame",          -- Client->Server: player chose to exit minigame early
    -- S-3: Drive-thru car arrival alert
    "DriveThruCarArrived",     -- Server->All: car arrived at window; clients show HUD pill
    -- S-4: NPC left without delivery (order failed)
    "NPCOrderFailed",          -- Server->All: NPC name + orderId; clients flash fail state
    -- Station status lights
    "StationStatusUpdate",     -- Server->All: model, "occupied"/"free", playerName
    -- S-9: Combo streak update
    "ComboUpdate",             -- Server->Client: current combo streak count
    -- S-6: NPC patience replication
    "NPCPatienceUpdate",       -- Server->All: orderId, currentPatience, maxPatience
    "DeliveryFeedback",        -- Server->All: npcHeadPos, stars, carrierName
    "WorkerFeedback",          -- Server->All: player, stationName, score, hrpPos
}

-- Server creates all remotes; client waits for server-created ones.
-- This prevents client-side ghost RemoteEvents that FireServer silently drops.
if RunService:IsServer() then
    for _, name in ipairs(REMOTES) do
        if not GameEvents:FindFirstChild(name) then
            local r = Instance.new("RemoteEvent")
            r.Name   = name
            r.Parent = GameEvents
        end
    end
end

-- Get a remote by name (errors loudly if invalid)
function RemoteManager.Get(name)
    local remote
    if RunService:IsServer() then
        remote = GameEvents:FindFirstChild(name)
    else
        remote = GameEvents:WaitForChild(name, 10)
    end
    if not remote then
        error("[RemoteManager] Unknown remote: " .. tostring(name), 2)
    end
    return remote
end

return RemoteManager
