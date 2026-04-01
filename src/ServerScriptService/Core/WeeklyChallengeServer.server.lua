-- ServerScriptService/Core/WeeklyChallengeServer (Script)
-- Wires player lifecycle and game state into WeeklyChallengeManager.

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local WeeklyChallengeManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("WeeklyChallengeManager"))

Players.PlayerAdded:Connect(function(player)
    task.defer(function()
        WeeklyChallengeManager.ResetIfNeeded(player)
        task.wait(1.5) -- wait for PlayerDataManager profile to load
        WeeklyChallengeManager.SendToPlayer(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    WeeklyChallengeManager.Cleanup(player)
end)

-- BUG-57: re-send weekly challenge data when Open fires so widget shows for existing players
workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    if workspace:GetAttribute("GameState") == "Open" then
        for _, p in ipairs(Players:GetPlayers()) do
            task.defer(function() WeeklyChallengeManager.SendToPlayer(p) end)
        end
    end
end)

print("[WeeklyChallengeServer] Ready.")
