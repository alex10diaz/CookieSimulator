-- src/ServerScriptService/Core/GameStateManager.server.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local ServerScriptService = game:GetService("ServerScriptService")
local SessionStats = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))

-- ─── Constants ────────────────────────────────────────────────────────────────
local DEV_SKIP_PREOPEN    = false     -- false = always run PreOpen (production)
local skipPreOpenFlag     = false
local skipPreOpenRemote   = RemoteManager.Get("SkipPreOpen")
local PREOPEN_DURATION    = 3 * 60   -- 3 minutes: enough time to prep dough before first customers
local OPEN_DURATION       = 15 * 60  -- M-7: 15 minutes (was 10)
local SUMMARY_DURATION    = 30       -- 30 seconds end-of-day
local INTERMISSION_DURATION = 3 * 60 -- 3 minutes back room break

local BACK_ROOM_CF = CFrame.new(0, 3, -127)

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
                hrp.CFrame = targetCF + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
            end
        end
    end
end

local function runPhase(duration, stateName)
    local remaining = duration
    broadcast(stateName, remaining)
    while remaining > 0 do
        if stateName == "PreOpen" and skipPreOpenFlag then
            skipPreOpenFlag = false
            stateChangedRemote:FireAllClients(stateName, 0)
            break
        end
        task.wait(1)
        remaining -= 1
        stateChangedRemote:FireAllClients(stateName, remaining)
    end
end

skipPreOpenRemote.OnServerEvent:Connect(function()
    if not game:GetService("RunService"):IsStudio() then return end
    skipPreOpenFlag = true
end)

local function runCycle()
    while true do
        SessionStats.Reset()
        if not DEV_SKIP_PREOPEN then
            runPhase(PREOPEN_DURATION, "PreOpen")
        end
        runPhase(OPEN_DURATION, "Open")

        -- End of day
        broadcast("EndOfDay", SUMMARY_DURATION)
        local summary = SessionStats.GetSummary()
        summary.employees = SessionStats.GetEmployeeOfShift()
        summaryRemote:FireAllClients(summary)
        task.wait(SUMMARY_DURATION)

        -- Intermission — teleport to back room
        teleportAllTo(BACK_ROOM_CF)
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
    task.wait(2) -- brief settle for all systems to load
    task.spawn(runCycle)
end

task.spawn(startWhenReady)

print("[GameStateManager] Ready.")
return GameStateManager
