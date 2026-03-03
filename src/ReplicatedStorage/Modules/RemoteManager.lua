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
    "TutorialStep",
    "ReplayTutorial",
    "StartGame",
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
