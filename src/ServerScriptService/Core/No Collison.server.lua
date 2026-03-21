local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local GroupName = "Players"
PhysicsService:RegisterCollisionGroup(GroupName)
PhysicsService:CollisionGroupSetCollidable(GroupName, GroupName, false)

local function ChangeGroup(part)
	if part:IsA("BasePart") then
		part.CollisionGroup = GroupName
	end
end

local function HandleCharacterAdded(character)
	for _, part in ipairs(character:GetDescendants()) do
		ChangeGroup(part)
	end
	-- P3-3: block jumping globally
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.JumpHeight = 0
	else
		character.ChildAdded:Connect(function(obj)
			if obj:IsA("Humanoid") then obj.JumpHeight = 0 end
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		HandleCharacterAdded(character)

		character.ChildAdded:Connect(function(object)
			ChangeGroup(object)
		end)
	end)
end)