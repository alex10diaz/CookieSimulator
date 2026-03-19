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

print("[WeeklyChallengeServer] Ready.")
