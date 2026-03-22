-- MinigameServer
-- Manages all minigame sessions and integrates with OrderManager.
-- Handles ProximityPrompt triggers for game stations.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")

local RemoteManager          = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager           = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local CookieData             = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local MenuManager            = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MenuManager"))
local StationMasteryManager  = require(ServerScriptService:WaitForChild("Core"):WaitForChild("StationMasteryManager"))
local SessionStats           = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))

-- M1: declared early so endSession() closure can capture it as an upvalue
-- Assigned asynchronously below once ServerStorage/Events is ready
local stationCompletedEvent = nil

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
local doughLock      = {}       -- batchId -> true  (prevents two players grabbing same dough batch)

-- ============================================================
-- S-2: STATION OCCUPIED BILLBOARD
-- ============================================================
local STATION_LABELS = { mix="Mixing", dough="Shaping Dough", oven="Baking", frost="Frosting", dress="Packing" }

local function getOrCreateBillboard(part)
    local existing = part:FindFirstChild("OccupiedBillboard")
    if existing then return existing end
    local bg = Instance.new("BillboardGui")
    bg.Name = "OccupiedBillboard"; bg.Size = UDim2.new(0,180,0,36)
    bg.StudsOffset = Vector3.new(0, 4, 0); bg.AlwaysOnTop = false
    bg.Enabled = false; bg.Parent = part
    local frame = Instance.new("Frame", bg)
    frame.Size = UDim2.new(1,0,1,0); frame.BackgroundColor3 = Color3.fromRGB(18,18,32)
    frame.BackgroundTransparency = 0.1; frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(1,0)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(255,200,0); stroke.Thickness = 1.5; stroke.Transparency = 0.3
    local lbl = Instance.new("TextLabel", frame)
    lbl.Name = "OccupiedLabel"; lbl.Size = UDim2.new(1,-6,1,0); lbl.Position = UDim2.new(0,3,0,0)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(255,200,0)
    lbl.Font = Enum.Font.GothamBold; lbl.TextScaled = true
    return bg
end

local function showStationBillboard(model, playerName, stationName)
    if not model then return end
    local part = model:FindFirstChildWhichIsA("BasePart")
    if not part then return end
    local bg = getOrCreateBillboard(part)
    local lbl = bg:FindFirstChild("OccupiedLabel", true)
    if lbl then lbl.Text = playerName .. " — " .. (STATION_LABELS[stationName] or stationName) end
    bg.Enabled = true
end

local function clearStationBillboard(model)
    if not model then return end
    local part = model:FindFirstChildWhichIsA("BasePart")
    if not part then return end
    local bg = part:FindFirstChild("OccupiedBillboard")
    if bg then bg.Enabled = false end
end

-- M-2 + C-3: shared session starter — records startedAt and arms a timeout watchdog
local SESSION_TIMEOUT = 60  -- seconds before a stuck session is auto-cleared
local function startSession(player, sessionData)
    sessionData.startedAt = tick()  -- C-3: used in endSession() to reject too-fast results
    activeSessions[player] = sessionData
    local capturedBatchId   = sessionData.batchId
    local capturedStation   = sessionData.station
    local capturedModel     = sessionData.stationModel
    -- S-2: show occupied billboard
    showStationBillboard(capturedModel, player.Name, capturedStation)
    -- M-2: watchdog clears stuck sessions if client crashes mid-minigame
    task.delay(SESSION_TIMEOUT, function()
        local s = activeSessions[player]
        if s and s.batchId == capturedBatchId then
            warn("[MinigameServer] Session timeout: " .. player.Name .. " @ " .. (capturedStation or "?"))
            if capturedStation == "dough" then
                doughLock[capturedBatchId] = nil
            end
            if (capturedStation == "frost" or capturedStation == "dress") and s.warmerEntry then
                OrderManager.ReturnToWarmers(s.warmerEntry)
                OrderManager.ClearPostOvenScore(capturedBatchId)
            end
            activeSessions[player] = nil
            dressPending[player]   = nil
            -- S-2: clear billboard on watchdog timeout
            clearStationBillboard(capturedModel)
        end
    end)
end

-- ============================================================
-- BROADCAST HELPERS
-- ============================================================
local BatchUpdated   = RemoteManager.Get("BatchUpdated")
local WarmersUpdated = RemoteManager.Get("WarmersUpdated")
local FridgeUpdated  = RemoteManager.Get("FridgeUpdated")
local BoxCreated     = RemoteManager.Get("BoxCreated")
local BoxDelivered   = RemoteManager.Get("BoxDelivered")

local function updateWarmerCountLabels()
    local stock = OrderManager.GetWarmerStockByCookieId()
    local folder = Workspace:FindFirstChild("Warmers")
    if not folder then return end
    for _, model in ipairs(folder:GetChildren()) do
        local cookieId = model:GetAttribute("CookieId")
        local doorPanel = model:FindFirstChild("DoorPanel")
        if doorPanel then
            local sg = doorPanel:FindFirstChild("WarmersDisplay")
            if sg then
                local countLbl = sg:FindFirstChild("CountLabel", true)
                if countLbl then
                    local n = cookieId and (stock[cookieId] or 0) or 0
                    countLbl.Text = n > 0 and (n .. " ready") or "0 ready"
                    countLbl.TextColor3 = n > 0
                        and Color3.fromRGB(80, 220, 100)
                        or  Color3.fromRGB(160, 160, 180)
                end
            end
        end
    end
end

-- M-4: debounce so chained BatchUpdated/FridgeUpdated/WarmersUpdated events
-- don't fire 3×N remotes per station step — collapses to one broadcast per frame
local _broadcastPending = false
local function broadcastState()
    if _broadcastPending then return end
    _broadcastPending = true
    task.defer(function()
        _broadcastPending = false
        local batchState  = OrderManager.GetBatchState()
        local fridgeState = OrderManager.GetFridgeState()
        local warmerState = OrderManager.GetWarmerState()
        local stockByType = OrderManager.GetWarmerStockByCookieId()
        for _, p in ipairs(Players:GetPlayers()) do
            BatchUpdated:FireClient(p, batchState)
            FridgeUpdated:FireClient(p, fridgeState)
            WarmersUpdated:FireClient(p, warmerState, stockByType)
        end
        updateWarmerCountLabels()
    end)
end

OrderManager.On("BatchUpdated",   broadcastState)
OrderManager.On("FridgeUpdated",  broadcastState)
OrderManager.On("WarmersUpdated", broadcastState)


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
    -- C-3: reject results submitted too fast — catches instant-perfect-score exploit
    local MIN_DURATION = 3
    local elapsed = tick() - (session.startedAt or 0)
    if elapsed < MIN_DURATION then
        warn(string.format("[AntiExploit] %s submitted %s result in %.2fs (min %ds)",
            player.Name, stationName, elapsed, MIN_DURATION))
        return
    end

    local batchId = session.batchId
    -- S-2: clear occupied billboard
    clearStationBillboard(session.stationModel)
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
        doughLock[batchId] = nil
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

    -- Award station mastery XP and record Employee of the Shift stat
    StationMasteryManager.AwardFromScore(player, stationName, score)
    SessionStats.RecordStationScore(player, stationName, score)

    -- M1: fire server-authoritative event so TutorialController advances only on real completions
    if stationCompletedEvent then
        stationCompletedEvent:Fire(player, stationName)
    end
end

-- ============================================================
-- PROXIMITY PROMPT HANDLERS
-- ============================================================

-- DOUGH, FROST, DRESS prompts
local function handleSimpleStart(player, stationName, stationModel)
    local gameState = Workspace:GetAttribute("GameState")
    if gameState ~= "Open" and gameState ~= "PreOpen" then return end  -- lock during Intermission/EndOfDay/Lobby
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
        if doughLock[batch.batchId] then
            warn("[MinigameServer] Batch #" .. batch.batchId .. " already claimed by another player")
            return
        end
        doughLock[batch.batchId] = true
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

    startSession(player, { station = stationName, batchId = batchId, warmerEntry = extraData and extraData.warmerEntry, stationModel = stationModel })
    
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
        local model = desc:FindFirstAncestorOfClass("Model")
        desc.Triggered:Connect(function(player) handleSimpleStart(player, "dough", model) end)
    elseif desc.Name == "FrostPrompt" then
        local model = desc:FindFirstAncestorOfClass("Model")
        desc.Triggered:Connect(function(player) handleSimpleStart(player, "frost", model) end)
    -- DressPrompt is handled by DressStationServer (KDS system)
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
                local gameState = Workspace:GetAttribute("GameState")
                if gameState ~= "Open" and gameState ~= "PreOpen" then return end
                if activeSessions[player] then return end
                ShowMixPicker:FireClient(player, MenuManager.GetActiveMenu())
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
    local gameState = Workspace:GetAttribute("GameState")
    if gameState ~= "Open" and gameState ~= "PreOpen" then return end  -- lock during Intermission/EndOfDay
    if activeSessions[player] then return end
    if not cookieId or cookieId == "" then return end

    -- C5: Validate cookieId is in the active menu (prevent spoofing unowned/invalid recipes)
    local activeMenu = MenuManager.GetActiveMenu()
    local inMenu = false
    for _, id in ipairs(activeMenu) do
        if id == cookieId then inMenu = true; break end
    end
    if not inMenu then
        warn("[AntiExploit] " .. player.Name .. " sent cookieId not in active menu: " .. tostring(cookieId))
        return
    end

    local batchId = OrderManager.TryStartBatch(player, cookieId)
    if not batchId then
        warn("[MinigameServer] Could not start batch for " .. player.Name)
        return
    end

    -- S-2: track which mixer the player is nearest to for the billboard
    local mixerModel = nil
    if Workspace:FindFirstChild("Mixers") then
        local nearest, nearestDist = nil, math.huge
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        for _, m in ipairs(Workspace.Mixers:GetChildren()) do
            if m:IsA("Model") then
                local p = m:FindFirstChildWhichIsA("BasePart")
                if p and hrp then
                    local d = (p.Position - hrp.Position).Magnitude
                    if d < nearestDist then nearestDist = d; nearest = m end
                end
            end
        end
        mixerModel = nearest
    end
    startSession(player, { station = "mix", batchId = batchId, cookieId = cookieId, stationModel = mixerModel })

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
            -- Label prompt with cookie name so players know which fridge they're at
            for _, cookie in ipairs(CookieData.Cookies) do
                if cookie.fridgeId == fridgeId then
                    prompt.ActionText = "Pull " .. cookie.name .. " Dough"
                    break
                end
            end
            prompt.Triggered:Connect(function(player)
                local gameState = Workspace:GetAttribute("GameState")
                if gameState ~= "Open" and gameState ~= "PreOpen" then return end
                if ovenSession[player] or activeSessions[player] then return end
                -- Read FridgeId dynamically so StationRemap changes are respected (Bug 1 fix)
                local currentFridgeId = fridge:GetAttribute("FridgeId")
                if not currentFridgeId then return end
                local batchId = OrderManager.PullFromFridge(player, currentFridgeId)
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
                local gameState = Workspace:GetAttribute("GameState")
                if gameState ~= "Open" and gameState ~= "PreOpen" then return end
                local batchId = ovenSession[player]
                if not batchId or activeSessions[player] then return end
                
                print(string.format("[MinigameServer] %s deposited batch #%d into %s", player.Name, batchId, oven.Name))
                
                startSession(player, { station = "oven", batchId = batchId, stationModel = oven })
                
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

-- m7: Player pressed Exit button — cancel session, return warmer entry if applicable
RemoteManager.Get("CancelMinigame").OnServerEvent:Connect(function(player)
    local session = activeSessions[player]
    if not session then return end
    if (session.station == "frost" or session.station == "dress") and session.warmerEntry then
        OrderManager.ReturnToWarmers(session.warmerEntry)
        OrderManager.ClearPostOvenScore(session.batchId)
    end
    if session.station == "dough" and session.batchId then
        doughLock[session.batchId] = nil
    end
    activeSessions[player] = nil
    dressPending[player]   = nil
    print("[MinigameServer] " .. player.Name .. " cancelled " .. tostring(session.station))
end)

Players.PlayerRemoving:Connect(function(player)
    -- Release any dough lock this player held
    local session = activeSessions[player]
    if session and session.station == "dough" and session.batchId then
        doughLock[session.batchId] = nil
    end
    -- m2: clear postOvenScores for abandoned frost/dress sessions
    if session and (session.station == "frost" or session.station == "dress") and session.batchId then
        OrderManager.ClearPostOvenScore(session.batchId)
    end
    activeSessions[player] = nil
    ovenSession[player]    = nil
    dressPending[player]   = nil
end)


-- M1: StationCompleted BindableEvent setup (variable declared at top of file)
task.spawn(function()
    local evts = ServerStorage:WaitForChild("Events", 10)
    if not evts then warn("[MinigameServer] ServerStorage/Events not found"); return end
    local existing = evts:FindFirstChild("StationCompleted")
    if existing then
        stationCompletedEvent = existing
    else
        local be = Instance.new("BindableEvent")
        be.Name   = "StationCompleted"
        be.Parent = evts
        stationCompletedEvent = be
    end
    print("[MinigameServer] StationCompleted BindableEvent ready")
end)

print("[MinigameServer] Ready")
