-- CarryPoseClient.client.lua
-- Listens for CarryPoseUpdate / NPCCarryPoseUpdate remotes.
-- Arms are left in default pose while carrying (no animation override).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local carryPoseRemote = RemoteManager.Get("CarryPoseUpdate")
local npcPoseRemote   = RemoteManager.Get("NPCCarryPoseUpdate")

-- Arms stay in default position while carrying — no pose changes needed.
carryPoseRemote.OnClientEvent:Connect(function(_isCarrying)
	-- intentionally no-op: arms hang naturally
end)

npcPoseRemote.OnClientEvent:Connect(function(_npcModel, _isCarrying)
	-- intentionally no-op: NPC arms hang naturally
end)

print("[CarryPoseClient] Ready.")
