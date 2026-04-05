-- src/ServerScriptService/Core/GameStateManager.server.lua
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager      = require(ServerScriptService:WaitForChild("Core"):WaitForChild("OrderManager"))

-- ─── Main Menu Tracking ───────────────────────────────────────────────────────
-- Every joining player starts "on the main menu". PreOpen timer pauses for them
-- until they click Play (fires DismissMainMenu remote) or are force-removed by
-- Open/EndOfDay/Intermission. Also pauses for tutorial players (InTutorial=true).
local dismissMenuRemote = RemoteManager.Get("DismissMainMenu")

Players.PlayerAdded:Connect(function(player)
    player:SetAttribute("OnMainMenu", true)
    player:SetAttribute("SkipPreOpenVoted", false)
    player:SetAttribute("SkipIntermissionVoted", false)
end)

dismissMenuRemote.OnServerEvent:Connect(function(player)
    player:SetAttribute("OnMainMenu", false)
end)

Players.PlayerRemoving:Connect(function(player)
    player:SetAttribute("OnMainMenu", false)
end)

-- Handle players already in game when this module loads (Studio play mode)
for _, p in ipairs(Players:GetPlayers()) do
    if p:GetAttribute("OnMainMenu") == nil then
        p:SetAttribute("OnMainMenu", true)
    end
    if p:GetAttribute("SkipPreOpenVoted") == nil then
        p:SetAttribute("SkipPreOpenVoted", false)
    end
    if p:GetAttribute("SkipIntermissionVoted") == nil then
        p:SetAttribute("SkipIntermissionVoted", false)
    end
end
local SessionStats      = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
local GamepassManager   = require(ServerScriptService:WaitForChild("Core"):WaitForChild("GamepassManager"))

-- C-2: coach tip remote
-- BUG-31: track the last tip so mid-shift joiners can be caught up
local tipRemote = RemoteManager.Get("PlayerTipUpdate")
local function fireTipAll(msg)
    tipRemote:FireAllClients(msg)
    workspace:SetAttribute("LastCoachTip", msg)  -- BUG-31: persists for late joiners
end

-- ─── Constants ────────────────────────────────────────────────────────────────
local DEV_SKIP_PREOPEN    = false     -- PreOpen enabled for live play
local skipPreOpenFlag     = false
local skipPreOpenRemote   = RemoteManager.Get("SkipPreOpen")
local skipIntermissionFlag   = false
local skipIntermissionRemote = RemoteManager.Get("SkipIntermission")
local PREOPEN_DURATION    = 3 * 60   -- 3 minutes: enough time to prep dough before first customers
local OPEN_DURATION       = 5 * 60   -- 5 minutes (playtest)
-- S-1: rush hour fires when 30% of Open remains (= 70% elapsed)
local RUSH_THRESHOLD      = math.floor(OPEN_DURATION * 0.30)
local SUMMARY_DURATION    = 30       -- 30 seconds end-of-day
local INTERMISSION_DURATION = 3 * 60 -- 3 minutes back room break

local BACK_ROOM_CF = CFrame.new(0, 3, -127)
local driveThruUnlocked = false  -- locked until first shift completes

-- Inside-store spawn: near the POS/waiting area (NOT the outside NPC spawn point).
-- NPCSpawnPoint/FrontSpawn Parts are for NPCs only — players must NOT be sent there.
-- Adjust FRONT_SPAWN_CF if a FrontSpawn is moved; use PlayerFrontSpawn Part in workspace
-- to override at runtime without touching code.
local FRONT_SPAWN_CF = CFrame.new(0, 5, 15)

local function getFrontSpawnCF()
    -- Prefer an explicit PlayerFrontSpawn part if placed in workspace.
    local sp = workspace:FindFirstChild("PlayerFrontSpawn")
    if sp then return sp.CFrame + Vector3.new(0, 3, 0) end
    -- Fall back to the GameSpawn SpawnLocation (used by TutorialController).
    local gs = workspace:FindFirstChild("GameSpawn")
    if gs and gs:IsA("BasePart") then
        return CFrame.new(gs.Position + Vector3.new(0, 3.5, 0))
    end
    return FRONT_SPAWN_CF
end

-- ─── State ────────────────────────────────────────────────────────────────────
local currentState   = "Lobby"
local stateListeners = {}
local stateChangedRemote = RemoteManager.Get("GameStateChanged")
local summaryRemote      = RemoteManager.Get("EndOfDaySummary")

-- ─── Internal ─────────────────────────────────────────────────────────────────
local function fireListeners(state)
    if stateListeners[state] then
        for _, cb in ipairs(stateListeners[state]) do
            task.spawn(cb)
        end
    end
end

local function broadcast(state, timeRemaining)
    currentState = state
    -- Expose state server-wide via Workspace attribute (other scripts read this)
    game:GetService("Workspace"):SetAttribute("GameState", state)
    stateChangedRemote:FireAllClients(state, timeRemaining or 0, shiftNumber)
    print("[GameStateManager] → " .. state .. " (" .. (timeRemaining or 0) .. "s)")
    fireListeners(state)
end

local function isReadyForPreOpen(player)
    return not player:GetAttribute("OnMainMenu") and not player:GetAttribute("InTutorial")
end

local function resetSkipPreOpenVotes()
    skipPreOpenFlag = false
    for _, player in ipairs(Players:GetPlayers()) do
        player:SetAttribute("SkipPreOpenVoted", false)
    end
end

-- FEAT-8: Intermission skip votes (same pattern as PreOpen)
local function resetSkipIntermissionVotes()
    skipIntermissionFlag = false
    for _, player in ipairs(Players:GetPlayers()) do
        player:SetAttribute("SkipIntermissionVoted", false)
    end
end

local function getSkipIntermissionVoteStatus()
    local total = #Players:GetPlayers()
    local voteCount = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("SkipIntermissionVoted") then voteCount += 1 end
    end
    return voteCount, math.max(1, math.floor(total / 2) + 1), total
end

local function getSkipVoteStatus()
    local readyPlayers = {}
    local voteCount = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if isReadyForPreOpen(player) then
            table.insert(readyPlayers, player)
            if player:GetAttribute("SkipPreOpenVoted") then
                voteCount += 1
            end
        end
    end
    local requiredVotes = #readyPlayers > 0 and (math.floor(#readyPlayers / 2) + 1) or 1
    return voteCount, requiredVotes, #readyPlayers
end

-- BUG-30: use indexed radial spread instead of math.random so 6 players
-- don't all land on the same spot and clip through each other
local function teleportAllTo(targetCF)
    local playerList = Players:GetPlayers()
    local count = #playerList
    for i, player in ipairs(playerList) do
        if player:GetAttribute("InTutorial") then
            continue
        end
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local angle  = (i - 1) / math.max(count, 1) * math.pi * 2
                local radius = count > 1 and 2.5 or 0
                local ox = math.cos(angle) * radius
                local oz = math.sin(angle) * radius
                hrp.CFrame = targetCF + Vector3.new(ox, 0, oz)
            end
        end
    end
end

local function runPhase(duration, stateName)
    local remaining = duration
    if stateName == "PreOpen" then
        resetSkipPreOpenVotes()
    elseif stateName == "Intermission" then
        resetSkipIntermissionVotes()  -- FEAT-8
    end
    broadcast(stateName, remaining)
    while remaining > 0 do
        if stateName == "PreOpen" and skipPreOpenFlag then
            skipPreOpenFlag = false
            stateChangedRemote:FireAllClients(stateName, 0)
            break
        elseif stateName == "Intermission" and skipIntermissionFlag then  -- FEAT-8
            skipIntermissionFlag = false
            stateChangedRemote:FireAllClients(stateName, 0)
            break
        end
        task.wait(1)
        -- Pause PreOpen only if nobody is ready yet. One AFK/menu/tutorial player
        -- should not freeze the whole server for everyone else.
        local paused = false
        if stateName == "PreOpen" then
            local players = Players:GetPlayers()
            paused = #players > 0
            for _, p in ipairs(players) do
                if not p:GetAttribute("OnMainMenu") and not p:GetAttribute("InTutorial") then
                    paused = false
                    break
                end
            end
        end
        if not paused then
            remaining -= 1
        end
        stateChangedRemote:FireAllClients(stateName, remaining)
    end
end

skipPreOpenRemote.OnServerEvent:Connect(function(player)
    if currentState ~= "PreOpen" then
        return
    end
    if not isReadyForPreOpen(player) then
        return
    end
    if player:GetAttribute("SkipPreOpenVoted") then
        local voteCount, requiredVotes = getSkipVoteStatus()
        tipRemote:FireClient(player, string.format("Skip votes: %d/%d", voteCount, requiredVotes))
        return
    end

    player:SetAttribute("SkipPreOpenVoted", true)

    local voteCount, requiredVotes = getSkipVoteStatus()
    fireTipAll(string.format("Skip to Open vote: %d/%d", voteCount, requiredVotes))

    if voteCount >= requiredVotes then
        skipPreOpenFlag = true
        print("[GameStateManager] PreOpen vote passed (" .. voteCount .. "/" .. requiredVotes .. ")")
    else
        print("[GameStateManager] PreOpen vote updated (" .. voteCount .. "/" .. requiredVotes .. ")")
    end
end)

-- FEAT-8: Intermission skip vote handler
skipIntermissionRemote.OnServerEvent:Connect(function(player)
    if currentState ~= "Intermission" then return end
    if player:GetAttribute("SkipIntermissionVoted") then
        local v, r = getSkipIntermissionVoteStatus()
        tipRemote:FireClient(player, string.format("Skip break votes: %d/%d", v, r))
        return
    end
    player:SetAttribute("SkipIntermissionVoted", true)
    local voteCount, requiredVotes = getSkipIntermissionVoteStatus()
    fireTipAll(string.format("Skip break vote: %d/%d", voteCount, requiredVotes))
    if voteCount >= requiredVotes then
        skipIntermissionFlag = true
        print("[GameStateManager] Intermission skip passed (" .. voteCount .. "/" .. requiredVotes .. ")")
    end
end)

local shiftNumber = 0  -- FEAT-2: increments each loop so clients can display "Shift N"

local function runCycle()
    while true do
        shiftNumber += 1  -- FEAT-2
        OrderManager.Reset()   -- wipe pipeline state before every new shift
        SessionStats.Reset()
        -- BUG-23: comboStreak is per-shift — reset for all players at shift boundary
        PlayerDataManager.ResetAllCombos()
        if not DEV_SKIP_PREOPEN then
            fireTipAll("Pick today's cookie menu from the board!")
            -- BUG-25: SpeedPass skips PreOpen for the whole server (co-op game)
            local anySpeedPass = false
            for _, p in ipairs(Players:GetPlayers()) do
                if GamepassManager.HasSpeedPass(p) then anySpeedPass = true; break end
            end
            if not anySpeedPass then
                runPhase(PREOPEN_DURATION, "PreOpen")
            else
                broadcast("PreOpen", 0)
                print("[GameStateManager] PreOpen skipped — SpeedPass holder present")
            end
        end
        -- S-1: Open phase with rush hour at 70% elapsed
        do
            local ssEvents  = game:GetService("ServerStorage"):FindFirstChild("Events")
            local rushStart = ssEvents and ssEvents:FindFirstChild("RushHourStart")
            local rushEnd   = ssEvents and ssEvents:FindFirstChild("RushHourEnd")
            local remaining = OPEN_DURATION
            local rushFired = false
            broadcast("Open", remaining)
            fireTipAll("Head to a Mix Station to start baking!")
            -- BUG-28: explain drive-thru is locked if first shift
            if not driveThruUnlocked then
                task.delay(3, function()
                    tipRemote:FireAllClients("Complete this shift to unlock the Drive-Thru!")
                end)
            end
            while remaining > 0 do
                task.wait(1)
                remaining -= 1
                stateChangedRemote:FireAllClients("Open", remaining)
                if not rushFired and remaining <= RUSH_THRESHOLD then
                    rushFired = true
                    if rushStart then rushStart:Fire() end
                    print("[GameStateManager] Rush Hour started! (" .. remaining .. "s remain)")
                end
            end
            if rushEnd then rushEnd:Fire() end
        end

        -- Unlock drive-thru after first completed shift
        if not driveThruUnlocked then
            driveThruUnlocked = true
            workspace:SetAttribute("DriveThruUnlocked", true)
            print("[GameStateManager] Drive-thru unlocked after first shift.")
        end

        -- End of day
        fireTipAll("Shift over! Check your results.")
        broadcast("EndOfDay", SUMMARY_DURATION)
        local summary = SessionStats.GetSummary()
        summary.employees = SessionStats.GetEmployeeOfShift()
        summary.shiftGrade = SessionStats.GetShiftGrade(summary)
        -- BUG-88: fire per-player so each gets their own station breakdown
        for _, p in ipairs(Players:GetPlayers()) do
            local personalSummary = {}
            for k, v in pairs(summary) do personalSummary[k] = v end
            personalSummary.stationBreakdown = SessionStats.GetPlayerBreakdown(p.UserId)
            summaryRemote:FireClient(p, personalSummary)
        end
        do  -- BUG-79: tick EndOfDay countdown so client timer actually counts down
            local _eod = SUMMARY_DURATION
            while _eod > 0 do
                task.wait(1)
                _eod -= 1
                stateChangedRemote:FireAllClients("EndOfDay", _eod)
            end
        end

        -- BUG-63: clear fridge/warmer displays before Intermission so they don't
        -- show stale shift data during the break
        OrderManager.Reset()
        -- Intermission — teleport to back room
        teleportAllTo(BACK_ROOM_CF)
        fireTipAll("Break time! Next shift starts soon.")
        runPhase(INTERMISSION_DURATION, "Intermission")

        -- Return players to front for next shift
        teleportAllTo(getFrontSpawnCF())
    end
end

-- ─── Public API ───────────────────────────────────────────────────────────────
local GameStateManager = {}

function GameStateManager.GetState()
    return currentState
end

function GameStateManager.OnState(stateName, callback)
    if not stateListeners[stateName] then
        stateListeners[stateName] = {}
    end
    table.insert(stateListeners[stateName], callback)
end

-- ─── Init ─────────────────────────────────────────────────────────────────────
broadcast("Lobby", 0)

-- Wait for a player then start
local function startWhenReady()
    if #Players:GetPlayers() == 0 then
        Players.PlayerAdded:Wait()
    end
    -- m-10: poll until GameEvents folder exists (confirms RemoteManager bootstrapped)
    local _rs, _w = game:GetService("ReplicatedStorage"), 0
    while not _rs:FindFirstChild("GameEvents") and _w < 10 do
        task.wait(0.5); _w += 0.5
    end
    task.spawn(runCycle)
end

task.spawn(startWhenReady)

print("[GameStateManager] Ready.")
return GameStateManager
