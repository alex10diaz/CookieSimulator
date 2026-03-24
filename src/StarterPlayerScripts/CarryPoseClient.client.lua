-- CarryPoseClient.client.lua
-- Enforces zombie carry arm pose via RenderStepped (overrides animation each frame).
-- Correct C0 values derived from Rx(-90°) after default shoulder rotation.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local carryPoseRemote = RemoteManager.Get("CarryPoseUpdate")
local npcPoseRemote   = RemoteManager.Get("NPCCarryPoseUpdate")

local player = Players.LocalPlayer

-- R6 shoulder C0 values
-- Rx(-90°) after the default shoulder rotation makes arms point straight forward
local RS_DEFAULT = CFrame.new(1,  0.5, 0) * CFrame.Angles(0,  math.pi/2, 0)
local LS_DEFAULT = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0)
local RS_CARRY   = CFrame.new(1,  0.5, 0) * CFrame.Angles(0,  math.pi/2, 0) * CFrame.Angles(-math.pi/2, 0, 0)
local LS_CARRY   = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0) * CFrame.Angles(-math.pi/2, 0, 0)

local playerPoseConn = nil
local npcPoseConns   = {}  -- [npcModel] = RenderStepped connection

local function getShoulders(torso)
    if not torso then return nil, nil end
    return torso:FindFirstChild("Right Shoulder"), torso:FindFirstChild("Left Shoulder")
end

-- ── Player carry pose ─────────────────────────────────────────────────────────

local function startPlayerPose()
    if playerPoseConn then return end
    playerPoseConn = RunService.RenderStepped:Connect(function()
        local char  = player.Character
        local torso = char and char:FindFirstChild("Torso")
        local rs, ls = getShoulders(torso)
        if rs then rs.C0 = RS_CARRY;  rs.Transform = CFrame.identity end
        if ls then ls.C0 = LS_CARRY;  ls.Transform = CFrame.identity end
    end)
end

local function stopPlayerPose()
    if playerPoseConn then playerPoseConn:Disconnect(); playerPoseConn = nil end
    local char  = player.Character
    local torso = char and char:FindFirstChild("Torso")
    local rs, ls = getShoulders(torso)
    if rs then rs.C0 = RS_DEFAULT; rs.Transform = CFrame.identity end
    if ls then ls.C0 = LS_DEFAULT; ls.Transform = CFrame.identity end
end

carryPoseRemote.OnClientEvent:Connect(function(isCarrying)
    if isCarrying then startPlayerPose() else stopPlayerPose() end
end)

-- ── NPC carry pose ────────────────────────────────────────────────────────────

local function startNPCPose(npcModel)
    if npcPoseConns[npcModel] then return end
    npcPoseConns[npcModel] = RunService.RenderStepped:Connect(function()
        local torso = npcModel:FindFirstChild("Torso")
        local rs, ls = getShoulders(torso)
        if rs then rs.C0 = RS_CARRY;  rs.Transform = CFrame.identity end
        if ls then ls.C0 = LS_CARRY;  ls.Transform = CFrame.identity end
    end)
end

local function stopNPCPose(npcModel)
    local conn = npcPoseConns[npcModel]
    if conn then conn:Disconnect(); npcPoseConns[npcModel] = nil end
end

npcPoseRemote.OnClientEvent:Connect(function(npcModel, isCarrying)
    if not npcModel then return end
    if isCarrying then
        startNPCPose(npcModel)
        -- Auto-clean when NPC is removed
        npcModel.AncestryChanged:Connect(function(_, parent)
            if parent == nil then stopNPCPose(npcModel) end
        end)
    else
        stopNPCPose(npcModel)
    end
end)

print("[CarryPoseClient] Ready.")
