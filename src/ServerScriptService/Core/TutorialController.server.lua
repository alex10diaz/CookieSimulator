-- src/ServerScriptService/Core/TutorialController.server.lua
-- Drives the 3-step first-time-player tutorial.
-- Fires TutorialStep to the client; listens for TutorialComplete (skip).
-- Progression: join → step 1 → MixMinigameResult → step 2 → DoughMinigameResult → step 3 (auto-complete after 4s)

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")
local mixResultRemote    = RemoteManager.Get("MixMinigameResult")
local doughResultRemote  = RemoteManager.Get("DoughMinigameResult")

-- ─── State ───────────────────────────────────────────────────────────────────
-- Maps userId → current tutorial step (1, 2, or 3). Nil = not in tutorial.
local activeTutorials = {}

local STEPS = {
    [1] = "Go to a Mixer and press E to start mixing!",
    [2] = "Great mix! Go to the Dough Table and press E to shape the dough.",
    [3] = "Perfect! Stock a Fridge with dough — then wait for the store to open!",
}
local TOTAL_STEPS = 3

local function sendStep(player, step)
    tutorialStepRemote:FireClient(player, {
        step  = step,
        total = TOTAL_STEPS,
        msg   = STEPS[step] or "",
    })
    print(string.format("[TutorialController] %s → step %d/%d", player.Name, step, TOTAL_STEPS))
end

local function completeTutorial(player)
    local userId = player.UserId
    if not activeTutorials[userId] then return end
    activeTutorials[userId] = nil
    PlayerDataManager.SetTutorialCompleted(player)
    -- step=0 signals client to dismiss overlay
    tutorialStepRemote:FireClient(player, { step = 0, total = TOTAL_STEPS, msg = "" })
    print("[TutorialController] " .. player.Name .. " tutorial complete.")
end

-- ─── Player join ─────────────────────────────────────────────────────────────
local function startTutorialForPlayer(player)
    task.wait(3)   -- allow PlayerDataManager to finish loading profile
    if not player or not player.Parent then return end
    local data = PlayerDataManager.GetData(player)
    if not data then return end
    if data.tutorialCompleted then
        print("[TutorialController] " .. player.Name .. " already completed tutorial, skipping.")
        return
    end
    activeTutorials[player.UserId] = 1
    sendStep(player, 1)
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(startTutorialForPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
    activeTutorials[player.UserId] = nil
end)

-- Handle players already in-game when this script loads
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(startTutorialForPlayer, player)
end

-- ─── Step progression ────────────────────────────────────────────────────────
mixResultRemote.OnServerEvent:Connect(function(player, ...)
    if activeTutorials[player.UserId] == 1 then
        activeTutorials[player.UserId] = 2
        sendStep(player, 2)
    end
end)

doughResultRemote.OnServerEvent:Connect(function(player, ...)
    if activeTutorials[player.UserId] == 2 then
        activeTutorials[player.UserId] = 3
        sendStep(player, 3)
        -- Auto-complete after 4 seconds (step 3 is informational, no action gate)
        local userId = player.UserId
        task.delay(4, function()
            if activeTutorials[userId] == 3 then
                completeTutorial(player)
            end
        end)
    end
end)

-- ─── Skip button ─────────────────────────────────────────────────────────────
tutorialDoneRemote.OnServerEvent:Connect(function(player)
    completeTutorial(player)
end)

print("[TutorialController] Ready.")
