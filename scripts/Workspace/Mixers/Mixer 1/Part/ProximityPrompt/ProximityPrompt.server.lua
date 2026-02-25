local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShowSkillCheck = ReplicatedStorage:FindFirstChild("ShowSkillCheck")
local SkillCheckCompleted = ReplicatedStorage:FindFirstChild("SkillCheckCompleted")
local SetMixCamera = ReplicatedStorage:FindFirstChild("SetMixCamera")

local ProximityPrompt = script.Parent

if ShowSkillCheck and ProximityPrompt and SetMixCamera then
    ProximityPrompt.Triggered:Connect(function(player)
        ProximityPrompt.Enabled = false
        -- Tell client to set camera to MixCamera
        SetMixCamera:FireClient(player, true)
        ShowSkillCheck:FireClient(player)
    end)
end

if SkillCheckCompleted and ProximityPrompt and SetMixCamera then
    SkillCheckCompleted.OnServerEvent:Connect(function(player)
        ProximityPrompt.Enabled = true
        -- Tell client to restore camera
        SetMixCamera:FireClient(player, false)
    end)
end
