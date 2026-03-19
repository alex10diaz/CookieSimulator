-- ServerScriptService/Core/LifetimeChallengeServer (Script)
-- Wires player join into LifetimeChallengeManager.

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local LifetimeChallengeManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("LifetimeChallengeManager"))

Players.PlayerAdded:Connect(function(player)
    task.defer(function()
        task.wait(2) -- wait for PlayerDataManager profile to load
        LifetimeChallengeManager.CheckAll(player)
        LifetimeChallengeManager.SendToPlayer(player)
    end)
end)

print("[LifetimeChallengeServer] Ready.")
