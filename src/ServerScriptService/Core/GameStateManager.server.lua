-- src/ServerScriptService/Core/GameStateManager.server.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local ServerScriptService = game:GetService("ServerScriptService")
local SessionStats = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))

-- ─── Constants ────────────────────────────────────────────────────────────────
local PREOPEN_FIRST     = 7 * 60 + 30  -- 7:30 first day — gives tutorial players ~5 min of real PreOpen
local PREOPEN_REPEAT    = 3 * 60   -- 3 minutes subsequent days
local OPEN_DURATION     = 10 * 60  -- 10 minutes (M6)
local SUMMARY_DURATION  = 30       -- 30 seconds end-of-day

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
    stateChangedRemote:FireAllClients(state, timeRemaining or 0)
    print("[GameStateManager] → " .. state .. " (" .. (timeRemaining or 0) .. "s)")
    fireListeners(state)
end

local function runPhase(duration, stateName)
    local remaining = duration
    broadcast(stateName, remaining)
    while remaining > 0 do
        task.wait(1)
        remaining -= 1
        if remaining % 5 == 0 or remaining <= 10 then
            stateChangedRemote:FireAllClients(stateName, remaining)
        end
    end
end

local function runCycle(isFirstDay)
    SessionStats.Reset()
    runPhase(isFirstDay and PREOPEN_FIRST or PREOPEN_REPEAT, "PreOpen")
    runPhase(OPEN_DURATION, "Open")

    -- End of day
    broadcast("EndOfDay", SUMMARY_DURATION)
    summaryRemote:FireAllClients(SessionStats.GetSummary())
    task.wait(SUMMARY_DURATION)

    runCycle(false)
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
    task.wait(2) -- brief settle for all systems to load
    task.spawn(runCycle, true)
end

task.spawn(startWhenReady)

print("[GameStateManager] Ready.")
return GameStateManager
