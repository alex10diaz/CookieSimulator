local module = {}

function module.SpawnRig()
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local workspace = game:GetService("Workspace")
	local rigTemplate = replicatedStorage:FindFirstChild("Rig")
	if rigTemplate then
		local Rig = rigTemplate:Clone()
		Rig.Parent = workspace
		local movementScript = replicatedStorage:FindFirstChild("WorkingAdvancedMovement")
		if movementScript then
			local newScript = movementScript:Clone()
			newScript.Parent = Rig
		end
		return Rig
	end
	return
end

return module

