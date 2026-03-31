-- src/ServerScriptService/Core/TutorialController.server.lua
-- Routes new players to TutorialKitchen; returning players to GameSpawn.
-- All step logic lives in TutorialKitchen (SSS/TutorialKitchen ModuleScript).

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
local TutorialKitchen   = require(ServerScriptService:WaitForChild("TutorialKitchen"))

local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local TOTAL_STEPS = 5

local function handlePlayerJoin(player)
	local data
	local deadline = tick() + 10
	repeat
		task.wait(0.5)
		if not player or not player.Parent then return end
		data = PlayerDataManager.GetData(player)
	until data or tick() >= deadline

	if not player or not player.Parent then return end
	if not data then
		warn("[TutorialController] DataStore timed out for " .. player.Name)
		return
	end

	if data.tutorialCompleted then
		tutorialStepRemote:FireClient(player, { step = 0, total = TOTAL_STEPS, msg = "", isReturn = true })
		print("[TutorialController] " .. player.Name .. " returning player -> GameSpawn")
		return
	end

	player:SetAttribute("InTutorial", true)
	TutorialKitchen.StartForPlayer(player)
	print("[TutorialController] " .. player.Name .. " new player -> TutorialKitchen")
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(handlePlayerJoin, player)
end)

Players.PlayerRemoving:Connect(function(player)
	player:SetAttribute("InTutorial", false)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(handlePlayerJoin, player)
end

print("[TutorialController] Ready.")
