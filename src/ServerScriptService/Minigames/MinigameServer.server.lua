-- MinigameServer
-- Manages all minigame sessions and integrates with OrderManager.
-- Handles ProximityPrompt triggers for game stations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")

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
local ovenSession    = {}       -- player -> batchId they pulled from fridge, ready for oven
local dressPending   = {}       -- player -> warmerEntry taken for dress

-- ============================================================
-- BROADCAST HELPERS
-- ============================================================
local BatchUpdated   = RemoteManager.Get("BatchUpdated")
local WarmersUpdated = RemoteManager.Get("WarmersUpdated")
local FridgeUpdated  = RemoteManager.Get("FridgeUpdated")
local BoxCreated     = RemoteManager.Get("BoxCreated")
local BoxDelivered   = RemoteManager.Get("BoxDelivered")

local function broadcastState()
    local batchState  = OrderManager.GetBatchState()
    local fridgeState = OrderManager.GetFridgeState()
    local warmerState = OrderManager.GetWarmerState()
    for _, p in ipairs(Players:GetPlayers()) do
        BatchUpdated:FireClient(p, batchState)
        FridgeUpdated:FireClient(p, fridgeState)
        WarmersUpdated:FireClient(p, warmerState)
    end
end

OrderManager.On("BatchUpdated",   broadcastState)
OrderManager.On("FridgeUpdated",  broadcastState)
OrderManager.On("WarmersUpdated", broadcastState)

-- Update physical warmer CountLabels on the Studio models
local function updateWarmerDisplays()
    local counts = OrderManager.GetWarmerCountsByType()
    local warmersFolder = Workspace:FindFirstChild("Warmers")
    if not warmersFolder then return end
    for _, warmerModel in ipairs(warmersFolder:GetChildren()) do
        local cookieId = warmerModel:GetAttribute("CookieId")
        if cookieId then
            local count = counts[cookieId] or 0
            local doorPanel = warmerModel:FindFirstChild("DoorPanel")
            if doorPanel then
                local sg = doorPanel:FindFirstChild("WarmersDisplay")
                if sg then
                    local lbl = sg:FindFirstChild("CountLabel")
                    if lbl then
                        lbl.Text = count > 0 and (count .. " ready") or "empty"
                        lbl.TextColor3 = count > 0
                            and Color3.fromRGB(80, 200, 80)
                            or  Color3.fromRGB(130, 130, 130)
                    end
                end
            end
        end
    end
end

OrderManager.On("WarmersUpdated", updateWarmerDisplays)
updateWarmerDisplays()  -- initialise on load

OrderManager.On("BoxCreated", function(box)
    for _, p in ipairs(Players:GetPlayers()) do BoxCreated:FireClient(p, box) end
end)
OrderManager.On("BoxDelivered", function(data)
    for _, p in ipairs(Players:GetPlayers()) do BoxDelivered:FireClient(p, data) end
end)


-- ============================================================
-- END SESSION / RECORD SCORE
-- ============================================================
local function endSession(player, stationName, score)
    local session = activeSessions[player]
    if not session then
        warn("[AntiExploit] " .. player.Name .. " fired " .. stationName .. " result with no active session")
        return
    end
    if session.station ~= stationName then
        warn("[AntiExploit] " .. player.Name .. " station mismatch (expected=" .. session.station .. " got=" .. stationName .. ")")
        return
    end
    if type(score) ~= "number" then
        warn("[AntiExploit] " .. player.Name .. " sent non-number score: " .. tostring(score))
        return
    end

    local batchId = session.batchId
    activeSessions[player] = nil
    score = math.clamp(score, 0, 100)

    print(string.format("[MinigameServer] %s | %s | score: %d%%", player.Name, stationName, score))

    if stationName == "mix" then
        if not session.cookieId then
            warn("[AntiExploit] " .. player.Name .. " mix session missing server-assigned cookieId")
            return
        end
        OrderManager.RecordStationScore(player, "mix", score, batchId)

    elseif stationName == "dough" then
        OrderManager.RecordStationScore(player, "dough", score, batchId)

    elseif stationName == "oven" then
        OrderManager.RecordOvenScore(player, score, batchId)
        ovenSession[player] = nil

    elseif stationName == "frost" then
        local entry = session.warmerEntry
        local snapshot = entry and entry.snapshot or 0
        local cookieId = entry and entry.cookieId or nil
        OrderManager.RecordFrostScore(player.Name, batchId, score, snapshot, cookieId)

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
-- PROXIMITY PROMPT HANDLERS
-- ============================================================

-- DOUGH, FROST, DRESS prompts
local function handleSimpleStart(player, stationName)
    if activeSessions[player] then
        warn("[MinigameServer] " .. player.Name .. " already in a session.")
        return
    end

    local config = MINIGAMES[stationName]
    if not config then return end

    local batchId, extraData
    
    if stationName == "dough" then
        local batch = OrderManager.GetBatchAtStage("dough")
        if not batch then
            warn("[MinigameServer] No batch at dough stage for " .. player.Name)
            return
        end
        batchId = batch.batchId
    elseif stationName == "frost" then
        local entry = OrderManager.TakeFromWarmers(true) -- wantsForFrost=true
        if not entry then
            warn("[MinigameServer] No frost-ready cookies in warmers")
            return
        end
        batchId = entry.batchId
        extraData = { warmerEntry = entry }
    elseif stationName == "dress" then
        local entry = OrderManager.TakeFromWarmers(false) -- wantsForFrost=false
        if not entry then
            warn("[MinigameServer] No dress-ready cookies in warmers")
            return
        end
        batchId = entry.batchId
        extraData = { warmerEntry = entry }
        dressPending[player] = entry
    end

    activeSessions[player] = { station = stationName, batchId = batchId, warmerEntry = extraData and extraData.warmerEntry }
    
    local startRemote = RemoteManager.Get(config.start)
    if stationName == "dress" and extraData and extraData.warmerEntry then
         startRemote:FireClient(player, extraData.warmerEntry.cookieId)
    else
         startRemote:FireClient(player)
    end
end

-- HOOK UP PROMPTS (Dough, Frost, Dress stations)
local function hookPromptIfNamed(desc)
    if not desc:IsA("ProximityPrompt") then return end
    if desc.Name == "DoughPrompt" then
        desc.Triggered:Connect(function(player) handleSimpleStart(player, "dough") end)
    elseif desc.Name == "FrostPrompt" then
        desc.Triggered:Connect(function(player) handleSimpleStart(player, "frost") end)
    elseif desc.Name == "DressPrompt" then
        desc.Triggered:Connect(function(player) handleSimpleStart(player, "dress") end)
    end
end

for _, desc in ipairs(Workspace:GetDescendants()) do
    hookPromptIfNamed(desc)
end
Workspace.DescendantAdded:Connect(hookPromptIfNamed)


-- MIXER PROMPTS -> Show Client Picker
local ShowMixPicker = RemoteManager.Get("ShowMixPicker")
local function hookMixerPrompts(model)
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Name == "MixerPrompt" then
            obj.Triggered:Connect(function(player)
                if activeSessions[player] then return end
                ShowMixPicker:FireClient(player)
            end)
        end
    end
end

local mixersFolder = Workspace:WaitForChild("Mixers", 10)
if mixersFolder then
    for _, mixer in ipairs(mixersFolder:GetChildren()) do hookMixerPrompts(mixer) end
    mixersFolder.ChildAdded:Connect(hookMixerPrompts)
else
    warn("[MinigameServer] Workspace.Mixers not found")
end

-- MIX COOKIE SELECTION (from client via FireServer)
local RequestMixStart = RemoteManager.Get("RequestMixStart")
RequestMixStart.OnServerEvent:Connect(function(player, cookieId)
    if activeSessions[player] then return end
    if not cookieId or cookieId == "" then return end

    local batchId = OrderManager.TryStartBatch(player, cookieId)
    if not batchId then
        warn("[MinigameServer] Could not start batch for " .. player.Name)
        return
    end

    activeSessions[player] = { station = "mix", batchId = batchId, cookieId = cookieId }

    local settings, label = MINIGAMES.mix.getSettings()
    RemoteManager.Get("StartMixMinigame"):FireClient(player, settings, label)
    print("[MinigameServer] Mix started for " .. player.Name .. " cookie=" .. cookieId)
end)


-- FRIDGE & OVEN PROMPTS
local PullResultRemote = RemoteManager.Get("PullFromFridgeResult")

local function hookFridgeOvenPrompts()
    -- Fridges
    local fridges = Workspace:WaitForChild("Fridges")
    for _, fridge in ipairs(fridges:GetChildren()) do
        local prompt = fridge:FindFirstChild("FridgePrompt", true)
        local fridgeId = fridge:GetAttribute("FridgeId")
        if prompt and fridgeId then
            prompt.Triggered:Connect(function(player)
                if ovenSession[player] or activeSessions[player] then return end
                
                local batchId = OrderManager.PullFromFridge(player, fridgeId)
                if batchId then
                    ovenSession[player] = batchId
                    PullResultRemote:FireClient(player, batchId, true)
                else
                    PullResultRemote:FireClient(player, nil, false)
                end
            end)
        end
    end

    -- Ovens
    local ovens = Workspace:WaitForChild("Ovens")
    for _, oven in ipairs(ovens:GetChildren()) do
        local prompt = oven:FindFirstChild("OvenPrompt", true)
        if prompt then
            prompt.Triggered:Connect(function(player)
                local batchId = ovenSession[player]
                if not batchId or activeSessions[player] then return end
                
                print(string.format("[MinigameServer] %s deposited batch #%d into %s", player.Name, batchId, oven.Name))
                
                activeSessions[player] = { station = "oven", batchId = batchId }
                
                local startRemote = RemoteManager.Get("StartOvenMinigame")
                startRemote:FireClient(player)
            end)
        end
    end
end

hookFridgeOvenPrompts()


-- ============================================================
-- WIRE UP RESULT & CLEANUP
-- ============================================================
for name, config in pairs(MINIGAMES) do
    local resultRemote = RemoteManager.Get(config.result)
    resultRemote.OnServerEvent:Connect(function(player, score)
        endSession(player, name, score)
    end)
end

Players.PlayerRemoving:Connect(function(player)
    activeSessions[player] = nil
    ovenSession[player]    = nil
    dressPending[player]   = nil
end)


print("[MinigameServer] Ready")
