-- RemoteManager
-- Single source of truth for all RemoteEvents.
-- No system should create or find remotes outside this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents        = ReplicatedStorage:WaitForChild("GameEvents")

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
    -- Orders & state
    "BatchUpdated",
    "FridgeUpdated",
    "WarmersUpdated",
    "NPCOrderReady",
    -- Boxes
    "BoxCarried",
    "BoxDelivered",
    "BoxCreated",
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
}

-- Ensure all remotes exist
for _, name in ipairs(REMOTES) do
    if not GameEvents:FindFirstChild(name) then
        local r = Instance.new("RemoteEvent")
        r.Name   = name
        r.Parent = GameEvents
    end
end

-- Get a remote by name (errors loudly if invalid)
function RemoteManager.Get(name)
    local remote = GameEvents:FindFirstChild(name)
    if not remote then
        error("[RemoteManager] Unknown remote: " .. tostring(name), 2)
    end
    return remote
end

return RemoteManager
