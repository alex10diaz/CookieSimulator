-- src/ServerScriptService/Core/GameStateManager.server.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local ServerScriptService = game:GetService("ServerScriptService")
local SessionStats = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))

-- ─── Constants ────────────────────────────────────────────────────────────────
local DEV_SKIP_PREOPEN    = true      -- DEV: set false for production
local PREOPEN_DURATION    = 5 * 60   -- 5 min PreOpen for all cycles
local OPEN_DURATION       = 10 * 60  -- 10 minutes (M6)
local SUMMARY_DURATION    = 30       -- 30 seconds end-of-day
local INTERMISSION_DURATION = 5 * 60 -- 5 minutes back room break

local BACK_ROOM_CF  = CFrame.new(0, 3, -127)
local FRONT_SPAWN_CF = CFrame.new(55, 2, 31)

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

local function teleportAllTo(targetCF)
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = targetCF + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
            end
        end
    end
end

local function runPhase(duration, stateName)
    local remaining = duration
    broadcast(stateName, remaining)
    while remaining > 0 do
        task.wait(1)
        remaining -= 1
        stateChangedRemote:FireAllClients(stateName, remaining)
    end
end

local function runCycle()
    while true do
        SessionStats.Reset()
        if not DEV_SKIP_PREOPEN then
            runPhase(PREOPEN_DURATION, "PreOpen")
        end
        runPhase(OPEN_DURATION, "Open")

        -- End of day
        broadcast("EndOfDay", SUMMARY_DURATION)
        summaryRemote:FireAllClients(SessionStats.GetSummary())
        task.wait(SUMMARY_DURATION)

        -- Intermission — teleport to back room
        teleportAllTo(BACK_ROOM_CF)
        runPhase(INTERMISSION_DURATION, "Intermission")

        -- Return players to front for next shift
        teleportAllTo(FRONT_SPAWN_CF)
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
    task.wait(2) -- brief settle for all systems to load
    task.spawn(runCycle)
end

task.spawn(startWhenReady)

print("[GameStateManager] Ready.")
return GameStateManager
