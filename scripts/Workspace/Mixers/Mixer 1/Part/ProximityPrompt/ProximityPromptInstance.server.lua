local part = Instance.new("Part")
part.Name = "MixerPromptPart"
part.Size = Vector3.new(2,2,2)
part.Anchored = true
part.CanCollide = true
part.Position = Vector3.new(0, 5, 0)
part.Parent = script.Parent

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "ProximityPrompt"
prompt.ActionText = "Start Skill Check"
prompt.ObjectText = "Mixer"
prompt.MaxActivationDistance = 10
prompt.Parent = part

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShowSkillCheck = ReplicatedStorage:FindFirstChild("ShowSkillCheck")
if ShowSkillCheck and prompt then
    prompt.Triggered:Connect(function(player)
        ShowSkillCheck:FireClient(player)
    end)
end
