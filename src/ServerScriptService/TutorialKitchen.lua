-- src/ServerScriptService/TutorialKitchen.lua
-- ModuleScript. Required by TutorialController.
-- Drives the 5-step tutorial in isolation — no MinigameServer/OrderManager dependency.
-- Reuses Start*/Result remotes so existing client minigame UIs work unchanged.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local startMixRemote     = RemoteManager.Get("StartMixMinigame")
local mixResultRemote    = RemoteManager.Get("MixMinigameResult")
local startDoughRemote   = RemoteManager.Get("StartDoughMinigame")
local doughResultRemote  = RemoteManager.Get("DoughMinigameResult")
local startOvenRemote    = RemoteManager.Get("StartOvenMinigame")
local ovenResultRemote   = RemoteManager.Get("OvenMinigameResult")
local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")
local startGameRemote    = RemoteManager.Get("StartGame")
local replayRemote       = RemoteManager.Get("ReplayTutorial")

local TUTORIAL_COOKIE = "chocolate_chip"
local TUTORIAL_REWARD = 200
local TOTAL_STEPS     = 5
local FINAL_MENU_STEP = TOTAL_STEPS + 1

local STEPS = {
	[1] = { msg = "Go to the Mixer and press E to start mixing!" },
	[2] = { msg = "Shape your dough at the Dough Table!" },
	[3] = { msg = "Pull your dough from the Fridge, then bake it in the Oven!" },
	[4] = { msg = "Pack your cookies at the Dress Station!" },
	[5] = { msg = "Carry the box to the customer and press E to deliver!" },
}

-- sessions[userId] = { step, waitingForMix, waitingForDough, fridgeDone, waitingForOven }
local sessions = {}

-- ─── Kitchen folder ──────────────────────────────────────────────────────────
local kitchenFolder = workspace:WaitForChild("TutorialKitchen", 30)
if not kitchenFolder then
	warn("[TutorialKitchen] 'TutorialKitchen' folder not found in Workspace — disabled.")
	return {}
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function sendStep(player, step, overrideMsg)
	local payload
	if step == 0 then
		payload = { step = 0, total = TOTAL_STEPS, msg = "", isReturn = false }
	elseif step == FINAL_MENU_STEP then
		payload = { step = FINAL_MENU_STEP, total = TOTAL_STEPS, msg = "", reward = TUTORIAL_REWARD }
	else
		local data = STEPS[step]
		payload = {
			step          = step,
			total         = TOTAL_STEPS,
			msg           = overrideMsg or (data and data.msg) or "",
			forceCookieId = (step == 1) and TUTORIAL_COOKIE or nil,
		}
	end
	tutorialStepRemote:FireClient(player, payload)
end

local function teleportToKitchen(player)
	local char = player.Character
	if not char then
		player.CharacterAdded:Wait()
		char = player.Character
	end
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local sp  = kitchenFolder:FindFirstChild("TutorialKitchenSpawn")
	if hrp and sp and sp:IsA("BasePart") then
		hrp.CFrame = CFrame.new(sp.Position + Vector3.new(0, 3.5, 0))
	end
end

local function teleportToMainBakery(player)
	task.wait(0.5)
	local char = player.Character
	if not char then return end
	local hrp   = char:FindFirstChild("HumanoidRootPart")
	local spawn = workspace:FindFirstChild("GameSpawn")
	if hrp and spawn and spawn:IsA("BasePart") then
		hrp.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 3.5, 0))
	end
end

local function completeTutorial(player, natural)
	sessions[player.UserId] = nil
	player:SetAttribute("InTutorial", false)
	if natural then
		pcall(function() PlayerDataManager.AddCoins(player, TUTORIAL_REWARD) end)
		print("[TutorialKitchen]", player.Name, "tutorial COMPLETE (+$" .. TUTORIAL_REWARD .. ")")
	else
		print("[TutorialKitchen]", player.Name, "tutorial SKIPPED")
	end
	PlayerDataManager.SetTutorialCompleted(player)
	sendStep(player, 0)
	teleportToMainBakery(player)
end

-- ─── Station wiring ──────────────────────────────────────────────────────────
local function wirePrompt(partName, actionText, onTriggered)
	local part = kitchenFolder:FindFirstChild(partName, true)
	if not part then warn("[TutorialKitchen] Part not found:", partName); return end
	local base = part:IsA("BasePart") and part or part:FindFirstChildWhichIsA("BasePart")
	if not base then warn("[TutorialKitchen] No BasePart in:", partName); return end
	local prompt = base:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText      = actionText
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent          = base
	end
	prompt.Triggered:Connect(onTriggered)
end

wirePrompt("TutorialMixer", "Mix", function(player)
	local s = sessions[player.UserId]
	if not s or s.step ~= 1 or s.waitingForMix then return end
	s.waitingForMix = true
	startMixRemote:FireClient(player, {
		batchId     = "TUT_MIX",
		cookieId    = TUTORIAL_COOKIE,
		stationName = "TutorialMixer",
	})
end)

wirePrompt("TutorialDoughTable", "Shape Dough", function(player)
	local s = sessions[player.UserId]
	if not s or s.step ~= 2 or s.waitingForDough then return end
	s.waitingForDough = true
	startDoughRemote:FireClient(player, {
		batchId  = "TUT_DOUGH",
		cookieId = TUTORIAL_COOKIE,
	})
end)

wirePrompt("TutorialFridge", "Pull Dough", function(player)
	local s = sessions[player.UserId]
	if not s or s.step ~= 3 or s.fridgeDone then return end
	s.fridgeDone = true
	sendStep(player, 3, "Nice! Now bake it in the Oven.")
end)

wirePrompt("TutorialOven", "Bake", function(player)
	local s = sessions[player.UserId]
	if not s or s.step ~= 3 or not s.fridgeDone or s.waitingForOven then return end
	s.waitingForOven = true
	startOvenRemote:FireClient(player, {
		batchId  = "TUT_OVEN",
		cookieId = TUTORIAL_COOKIE,
	})
end)

wirePrompt("TutorialDressStation", "Pack Cookies", function(player)
	local s = sessions[player.UserId]
	if not s or s.step ~= 4 then return end
	s.step = 5
	sendStep(player, 5)
end)

wirePrompt("TutorialCustomer", "Deliver", function(player)
	local s = sessions[player.UserId]
	if not s or s.step ~= 5 then return end
	s.step = FINAL_MENU_STEP
	sendStep(player, FINAL_MENU_STEP)
end)

-- ─── Minigame result listeners (gated to tutorial sessions only) ──────────────
mixResultRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player.UserId]
	if not s or not s.waitingForMix then return end
	s.waitingForMix = nil
	s.step = 2
	sendStep(player, 2)
end)

doughResultRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player.UserId]
	if not s or not s.waitingForDough then return end
	s.waitingForDough = nil
	s.step = 3
	sendStep(player, 3)
end)

ovenResultRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player.UserId]
	if not s or not s.waitingForOven then return end
	s.waitingForOven = nil
	s.step = 4
	sendStep(player, 4)
end)

-- ─── Skip / Complete / Replay ────────────────────────────────────────────────
tutorialDoneRemote.OnServerEvent:Connect(function(player)
	if not sessions[player.UserId] then return end
	completeTutorial(player, false)
end)

startGameRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player.UserId]
	if not s or s.step ~= FINAL_MENU_STEP then return end
	completeTutorial(player, true)
end)

replayRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player.UserId]
	if not s or s.step ~= FINAL_MENU_STEP then return end
	s.step         = 1
	s.fridgeDone   = nil
	s.waitingForMix   = nil
	s.waitingForDough = nil
	s.waitingForOven  = nil
	sendStep(player, 1)
	teleportToKitchen(player)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player.UserId] = nil
end)

print("[TutorialKitchen] Ready.")

-- ─── Public API ───────────────────────────────────────────────────────────────
local TutorialKitchen = {}

function TutorialKitchen.StartForPlayer(player)
	sessions[player.UserId] = { step = 1 }
	sendStep(player, 1)
	task.spawn(teleportToKitchen, player)
end

return TutorialKitchen
