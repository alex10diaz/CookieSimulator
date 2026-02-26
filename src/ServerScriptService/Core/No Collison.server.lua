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
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		HandleCharacterAdded(character)

		character.ChildAdded:Connect(function(object)
			ChangeGroup(object)
		end)
	end)
end)