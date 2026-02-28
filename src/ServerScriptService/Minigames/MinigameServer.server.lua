-- MinigameServer
-- Manages all minigame sessions and integrates with OrderManager.
-- Pipeline: Mix → Dough → Fridge → Oven → (Frost? → Warmers) → Dress → Counter

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))

-- ============================================================
-- MINIGAME CONFIG
-- ============================================================
local MINIGAMES = {
    mix   = {
        start  = "StartMixMinigame",
        result = "MixMinigameResult",
        getSettings = function()
            local diff = { speed = 1.2, pathWidth = 60, directionSwitches = 0, duration = 8 }
            return diff, "easy"
        end,
    },
    dough = { start = "StartDoughMinigame", result = "DoughMinigameResult" },
    oven  = { start = "StartOvenMinigame",  result = "OvenMinigameResult"  },
    frost = { start = "StartFrostMinigame", result = "FrostMinigameResult" },
    dress = { start = "StartDressMinigame", result = "DressMinigameResult" },
}

-- ============================================================
-- SESSION STATE
-- activeSessions[player] = { station, batchId, extra }
-- ============================================================
local activeSessions = {}
local playerBatch    = {}       -- player → batchId for mix/dough stage
local ovenSession    = {}       -- player → batchId they pulled from fridge
local dressPending   = {}       -- player → warmerEntry taken for dress

-- ============================================================
-- BROADCAST HELPERS
-- ============================================================
local BatchUpdated   = RemoteManager.Get("BatchUpdated")
local WarmersUpdated = RemoteManager.Get("WarmersUpdated")
local FridgeUpdated  = RemoteManager.Get("FridgeUpdated")
local BoxCreated     = RemoteManager.Get("BoxCreated")
local BoxDelivered   = RemoteManager.Get("BoxDelivered")

local function broadcastAll()
    local batchState  = OrderManager.GetBatchState()
    local fridgeState = OrderManager.GetFridgeState()
    local warmerState = OrderManager.GetWarmerState()
    for _, p in ipairs(Players:GetPlayers()) do
        BatchUpdated:FireClient(p, batchState)
        FridgeUpdated:FireClient(p, fridgeState)
        WarmersUpdated:FireClient(p, warmerState)
    end
end

OrderManager.On("BatchUpdated",   broadcastAll)
OrderManager.On("FridgeUpdated",  broadcastAll)
OrderManager.On("WarmersUpdated", broadcastAll)
OrderManager.On("BoxCreated", function(box)
    for _, p in ipairs(Players:GetPlayers()) do BoxCreated:FireClient(p, box) end
end)
OrderManager.On("BoxDelivered", function(data)
    for _, p in ipairs(Players:GetPlayers()) do BoxDelivered:FireClient(p, data) end
end)

-- ============================================================
-- START SESSION
-- ============================================================
local function startSession(player, stationName, ...)
    if activeSessions[player] then
        warn("[MinigameServer] " .. player.Name .. " already in a session: " .. tostring(activeSessions[player].station))
        return
    end

    local config = MINIGAMES[stationName]
    if not config then return end

    local batchId = nil

    if stationName == "mix" then
        -- cookieId set by RequestMixStart handler before this is called
        local cookieId = activeSessions[player] and activeSessions[player].cookieId
        if not cookieId then
            warn("[MinigameServer] No cookieId for mix session: " .. player.Name)
            return
        end
        local id = OrderManager.TryStartBatch(player, cookieId)
        if not id then return end
        batchId = id
        playerBatch[player] = batchId

    elseif stationName == "dough" then
        local batch = OrderManager.GetBatchAtStage("dough")
        if not batch then
            warn("[MinigameServer] No batch at dough stage for " .. player.Name)
            return
        end
        -- Check no other active player already claimed this batch
        for otherPlayer, pid in pairs(playerBatch) do
            if pid == batch.batchId and otherPlayer ~= player then
                warn("[MinigameServer] Batch #" .. batch.batchId .. " already claimed by " .. otherPlayer.Name)
                return
            end
        end
        batchId = batch.batchId
        playerBatch[player] = batchId

    elseif stationName == "oven" then
        -- batchId comes from fridge pull (handled separately below)
        batchId = ovenSession[player]
        if not batchId then
            warn("[MinigameServer] " .. player.Name .. " has no dough pulled from fridge")
            return
        end

    elseif stationName == "frost" then
        local entry = OrderManager.TakeFromWarmers(true) -- wantsForFrost=true
        if not entry then
            warn("[MinigameServer] No frost-ready cookies in warmers")
            return
        end
        batchId = entry.batchId
        -- Store snapshot for score recording
        activeSessions[player] = { station = stationName, batchId = batchId, warmerEntry = entry }
        local startRemote = RemoteManager.Get(config.start)
        startRemote:FireClient(player)
        return  -- early return, session already set

    elseif stationName == "dress" then
        local entry = OrderManager.TakeFromWarmers(false) -- wantsForFrost=false (ready for dress)
        if not entry then
            warn("[MinigameServer] No dress-ready cookies in warmers")
            return
        end
        batchId = entry.batchId
        dressPending[player] = entry
        activeSessions[player] = { station = stationName, batchId = batchId, warmerEntry = entry }
        local startRemote = RemoteManager.Get(config.start)
        startRemote:FireClient(player, entry.cookieId)
        return
    end

    activeSessions[player] = { station = stationName, batchId = batchId }

    local startRemote = RemoteManager.Get(config.start)
    if config.getSettings then
        local settings, label = config.getSettings()
        startRemote:FireClient(player, settings, label)
    else
        startRemote:FireClient(player)
    end
end

-- ============================================================
-- END SESSION / RECORD SCORE
-- ============================================================
local function endSession(player, stationName, score)
    local session = activeSessions[player]
    if not session or session.station ~= stationName then
        warn("[MinigameServer] Session mismatch for " .. player.Name)
        return
    end

    local batchId = session.batchId
    activeSessions[player] = nil
    score = math.clamp(score or 0, 0, 100)

    print(string.format("[MinigameServer] %s | %s | score: %d%%", player.Name, stationName, score))

    if stationName == "mix" then
        OrderManager.RecordStationScore(player, "mix", score, batchId)

    elseif stationName == "dough" then
        OrderManager.RecordStationScore(player, "dough", score, batchId)
        playerBatch[player] = nil

    elseif stationName == "oven" then
        OrderManager.RecordOvenScore(player, score, batchId)
        ovenSession[player] = nil

    elseif stationName == "frost" then
        local entry = session.warmerEntry
        OrderManager.RecordFrostScore(player.Name, batchId, score, entry and entry.snapshot or 0)

    elseif stationName == "dress" then
        local entry = dressPending[player]
        local box = OrderManager.CreateBox(player, batchId, score, entry)
        dressPending[player] = nil
        if box then
            print("[MinigameServer] Box #" .. box.boxId .. " ready | Quality: " .. box.quality .. "%")
        end
    end
end

-- ============================================================
-- FRIDGE PULL → player receives tray, must carry to oven
-- DepositDough fires when they interact with a specific oven
-- ============================================================
local PullRemote       = RemoteManager.Get("PullFromFridge")
local PullResultRemote = RemoteManager.Get("PullFromFridgeResult")
local DepositDough     = RemoteManager.Get("DepositDough")

PullRemote.OnServerEvent:Connect(function(player, fridgeId)
    if ovenSession[player] then
        warn("[MinigameServer] " .. player.Name .. " already carrying dough")
        PullResultRemote:FireClient(player, nil, false)
        return
    end
    local batchId = OrderManager.PullFromFridge(player, fridgeId)
    if batchId then
        ovenSession[player] = batchId  -- reserve slot, oven session starts on deposit
        PullResultRemote:FireClient(player, batchId, true)
    else
        PullResultRemote:FireClient(player, nil, false)
    end
end)

DepositDough.OnServerEvent:Connect(function(player, batchId, ovenName)
    if ovenSession[player] ~= batchId then
        warn("[MinigameServer] " .. player.Name .. " deposit mismatch")
        return
    end
    print(string.format("[MinigameServer] %s deposited batch #%d into %s", player.Name, batchId, ovenName))
    -- Oven minigame session starts now — client OvenPrompt triggered it,
    -- StartOvenMinigame fires to client to begin the minigame
    local startRemote = RemoteManager.Get("StartOvenMinigame")
    startRemote:FireClient(player)
end)

-- ============================================================
-- BOX CARRY & DELIVER
-- ============================================================
local BoxCarriedRemote   = RemoteManager.Get("BoxCarried")
local BoxDeliveredRemote = RemoteManager.Get("BoxDelivered")

BoxCarriedRemote.OnServerEvent:Connect(function(player, boxId)
    OrderManager.PickupBox(player, boxId)
end)

BoxDeliveredRemote.OnServerEvent:Connect(function(player, boxId, npcOrderId)
    local ok, quality = OrderManager.DeliverBox(player, boxId, npcOrderId)
    if ok then
        print(string.format("[MinigameServer] %s delivered box #%d | Quality: %d%%", player.Name, boxId, quality))
        -- TODO: reward player currency/xp
    end
end)

-- ============================================================
-- REQUEST MIX START — via Player attribute (bypasses RemoteEvent)
-- Client sets PendingMixCookie attribute; server detects change here.
-- ============================================================
local function handleMixCookieSelection(player)
    local cookieId = player:GetAttribute("PendingMixCookie")
    if not cookieId or cookieId == "" then return end
    player:SetAttribute("PendingMixCookie", "")  -- clear immediately
    if activeSessions[player] then
        warn("[MinigameServer] " .. player.Name .. " already in a session")
        return
    end
    local cookie = CookieData.GetById(cookieId)
    if not cookie then
        warn("[MinigameServer] Invalid cookieId: " .. tostring(cookieId))
        return
    end
    local batchId = OrderManager.TryStartBatch(player, cookieId)
    if not batchId then
        warn("[MinigameServer] Could not start batch for " .. player.Name)
        return
    end
    playerBatch[player] = batchId
    activeSessions[player] = { station = "mix", batchId = batchId, cookieId = cookieId }
    local settings, label = MINIGAMES.mix.getSettings()
    RemoteManager.Get("StartMixMinigame"):FireClient(player, settings, label)
    print("[MinigameServer] Mix started for " .. player.Name .. " cookie=" .. cookieId)
end

-- Poll every frame — client SetAttribute does not cross Solo Play boundary via signals
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        local cookieId = player:GetAttribute("PendingMixCookie")
        if cookieId and cookieId ~= "" then
            handleMixCookieSelection(player)
        end
    end
end)

-- ============================================================
-- WIRE UP MINIGAME START/RESULT REMOTES
-- ============================================================
for name, config in pairs(MINIGAMES) do
    local startRemote  = RemoteManager.Get(config.start)
    local resultRemote = RemoteManager.Get(config.result)

    -- Mix start is handled exclusively by RequestMixStart above
    if name ~= "mix" then
        startRemote.OnServerEvent:Connect(function(player, ...)
            startSession(player, name, ...)
        end)
    end

    resultRemote.OnServerEvent:Connect(function(player, score)
        endSession(player, name, score)
    end)
end

-- ============================================================
-- CLEANUP
-- ============================================================

-- ============================================================
-- BRIDGE: FridgeOvenSystem → MinigameServer (server BindableEvents)
-- FridgeOvenSystem handles ProximityPrompt triggers server-side.
-- It fires these BindableEvents to keep MinigameServer session state in sync.
-- ============================================================
local ServerStorage2 = game:GetService("ServerStorage")
local bridgeEvents   = ServerStorage2:WaitForChild("Events")
local fridgePulledBE  = bridgeEvents:WaitForChild("FridgePulled")
local ovenDepositedBE = bridgeEvents:WaitForChild("OvenDeposited")

fridgePulledBE.Event:Connect(function(player, batchId)
    -- Player pulled a batch from the fridge; track for oven session
    ovenSession[player] = batchId
    print(string.format("[MinigameServer] ovenSession set for %s: batch #%d", player.Name, batchId))
end)

ovenDepositedBE.Event:Connect(function(player, ovenName)
    -- Player deposited at oven; fire client to start oven minigame
    if not ovenSession[player] then
        warn("[MinigameServer] OvenDeposited with no ovenSession for " .. player.Name)
        return
    end
    print(string.format("[MinigameServer] %s deposited at %s — starting oven minigame", player.Name, ovenName))
    local startRemote = RemoteManager.Get("StartOvenMinigame")
    startRemote:FireClient(player)
end)

Players.PlayerRemoving:Connect(function(player)
    activeSessions[player] = nil
    playerBatch[player]    = nil
    ovenSession[player]    = nil
    dressPending[player]   = nil
end)

-- ============================================================
-- MIXER PROXIMITY PROMPTS → ShowMixPicker (server-side trigger)
-- Client-side Triggered is unreliable; server hooks the prompts
-- and fires ShowMixPicker back to the triggering player.
-- ============================================================
local ShowMixPicker = RemoteManager.Get("ShowMixPicker")

local function hookMixerPrompts(model)
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            obj.Triggered:Connect(function(player)
                ShowMixPicker:FireClient(player)
            end)
        end
    end
end

local mixersFolder = workspace:WaitForChild("Mixers", 10)
if mixersFolder then
    for _, mixer in ipairs(mixersFolder:GetChildren()) do
        hookMixerPrompts(mixer)
    end
    mixersFolder.ChildAdded:Connect(hookMixerPrompts)
else
    warn("[MinigameServer] Workspace.Mixers not found")
end

print("[MinigameServer] Ready")
