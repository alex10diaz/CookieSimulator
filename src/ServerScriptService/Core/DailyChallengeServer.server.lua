-- ServerScriptService/Core/DailyChallengeServer (Script)
-- Wires player lifecycle and game state events into DailyChallengeManager.

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DailyChallengeManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("DailyChallengeManager"))

-- On join: reset if new day, then send current state to client
Players.PlayerAdded:Connect(function(player)
    task.defer(function()
        DailyChallengeManager.ResetIfNeeded(player)
        -- Brief wait for PlayerDataManager to fully load profile
        task.wait(1)
        DailyChallengeManager.SendToPlayer(player)
    end)
end)

-- On leave: clean up in-memory stats
Players.PlayerRemoving:Connect(function(player)
    DailyChallengeManager.Cleanup(player)
end)

-- On Open phase: invalidate cookieType cache (menu is now locked) + reset shift coins
workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    local state = workspace:GetAttribute("GameState")
    if state == "Open" then
        DailyChallengeManager.InvalidateChallengeCache()
        for _, p in ipairs(Players:GetPlayers()) do
            DailyChallengeManager.ResetShiftCounters(p)
        end
    end
end)

print("[DailyChallengeServer] Ready.")
