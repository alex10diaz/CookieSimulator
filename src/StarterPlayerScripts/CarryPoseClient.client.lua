-- CarryPoseClient.client.lua
-- Sets carry arm pose by disabling Motor6D animation and setting C0 once.
-- Disabling Motor6D.Enabled removes animation system control entirely.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local carryPoseRemote = RemoteManager.Get("CarryPoseUpdate")
local npcPoseRemote   = RemoteManager.Get("NPCCarryPoseUpdate")

local player = Players.LocalPlayer

-- R6 shoulder C0 values
local RS_DEFAULT = CFrame.new(1,  0.5, 0) * CFrame.Angles(0,  math.pi/2, 0)
local LS_DEFAULT = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0)
-- Arms straight forward: Rx(-90°) after default shoulder rotation
local RS_CARRY   = CFrame.new(1,  0.5, 0) * CFrame.Angles(0,  math.pi/2, 0) * CFrame.Angles(-math.pi/2, 0, 0)
local LS_CARRY   = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0) * CFrame.Angles(-math.pi/2, 0, 0)

local function getShoulders(torso)
	if not torso then return nil, nil end
	return torso:FindFirstChild("Right Shoulder"), torso:FindFirstChild("Left Shoulder")
end

-- ── Player carry pose ─────────────────────────────────────────────────────────

local function startPlayerPose()
	local char  = player.Character
	local torso = char and char:FindFirstChild("Torso")
	local rs, ls = getShoulders(torso)
	if rs then rs.Enabled = false; rs.C0 = RS_CARRY end
	if ls then ls.Enabled = false; ls.C0 = LS_CARRY end
end

local function stopPlayerPose()
	local char  = player.Character
	local torso = char and char:FindFirstChild("Torso")
	local rs, ls = getShoulders(torso)
	if rs then rs.C0 = RS_DEFAULT; rs.Enabled = true end
	if ls then ls.C0 = LS_DEFAULT; ls.Enabled = true end
end

carryPoseRemote.OnClientEvent:Connect(function(isCarrying)
	if isCarrying then startPlayerPose() else stopPlayerPose() end
end)

-- Re-apply on character respawn in case they respawn while carrying
player.CharacterAdded:Connect(function()
	-- nothing to do; server will re-fire if still carrying
end)

-- ── NPC carry pose ────────────────────────────────────────────────────────────

local function startNPCPose(npcModel)
	local torso = npcModel:FindFirstChild("Torso")
	local rs, ls = getShoulders(torso)
	if rs then rs.Enabled = false; rs.C0 = RS_CARRY end
	if ls then ls.Enabled = false; ls.C0 = LS_CARRY end
end

local function stopNPCPose(npcModel)
	local torso = npcModel:FindFirstChild("Torso")
	local rs, ls = getShoulders(torso)
	if rs then rs.C0 = RS_DEFAULT; rs.Enabled = true end
	if ls then ls.C0 = LS_DEFAULT; ls.Enabled = true end
end

npcPoseRemote.OnClientEvent:Connect(function(npcModel, isCarrying)
	if not npcModel then return end
	if isCarrying then
		startNPCPose(npcModel)
		-- Auto-restore when NPC is removed
		npcModel.AncestryChanged:Connect(function(_, parent)
			if parent == nil then stopNPCPose(npcModel) end
		end)
	else
		stopNPCPose(npcModel)
	end
end)

print("[CarryPoseClient] Ready.")
