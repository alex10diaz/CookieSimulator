-- src/ServerScriptService/Core/TutorialController.server.lua
-- Drives the 9-step cinematic tutorial for first-time players.
-- Server-authoritative: step state lives here. Client is display-only.
-- Progression: join (new) -> step 1 -> station results -> step 10 (final menu) -> complete
-- Returning players: join -> step 0 (isReturn=true) -> GameSpawn teleport via TutorialCamera

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")
local startGameRemote    = RemoteManager.Get("StartGame")
local replayRemote       = RemoteManager.Get("ReplayTutorial")

-- Station result remotes (advance gates)
local confirmNPCOrderRemote = RemoteManager.Get("ConfirmNPCOrder")
local mixResultRemote       = RemoteManager.Get("MixMinigameResult")
local doughResultRemote     = RemoteManager.Get("DoughMinigameResult")
local depositDoughRemote    = RemoteManager.Get("DepositDough")
local ovenResultRemote      = RemoteManager.Get("OvenMinigameResult")
local frostResultRemote     = RemoteManager.Get("FrostMinigameResult")
local dressResultRemote     = RemoteManager.Get("DressMinigameResult")

-- ─── State ───────────────────────────────────────────────────────────────────
local activeTutorials = {}
local TOTAL_STEPS = 9

-- Step 1 always targets the FOS display machine in workspace.POS
local POS_STEP1_TARGET = "FOS"

local STEPS = {
	[1] = { msg = "Head to the POS and accept a customer order!",           target = "POS",             forceCookieId = nil          },
	[2] = { msg = "Go to a Mixer and press E to start mixing!",             target = "Mixer",           forceCookieId = "pink_sugar" },
	[3] = { msg = "Shape your dough at the Dough Table — press E!",         target = "DoughTable",      forceCookieId = nil          },
	[4] = { msg = "Stock the dough in the Pink Sugar fridge!",              target = "FridgePinkSugar", forceCookieId = nil          },
	[5] = { msg = "Pull the chilled dough out of the fridge!",              target = "FridgePinkSugar", forceCookieId = nil          },
	[6] = { msg = "Slide it into the Oven — watch the timer!",              target = "Oven",            forceCookieId = nil          },
	[7] = { msg = "Apply pink frosting at the Frost Table!",                target = "FrostTable",      forceCookieId = nil          },
	[8] = { msg = "Dress and pack your cookie!",                            target = "DressTable",      forceCookieId = nil          },
	[9] = { msg = "Carry the box to the customer and press E to deliver!",  target = "WaitingArea",     forceCookieId = nil          },
}

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function sendStep(player, step)
	local payload
	if step == 0 then
		payload = { step = 0, total = TOTAL_STEPS, msg = "", isReturn = false }
	elseif step == 10 then
		payload = { step = 10, total = TOTAL_STEPS, msg = "" }
	else
		local data = STEPS[step]
		if not data then
			warn("[TutorialController] sendStep: invalid step " .. tostring(step))
			return
		end
		local session = activeTutorials[player.UserId]
		local target = (step == 1 and session and session.posTarget) or data.target
		payload = {
			step          = step,
			total         = TOTAL_STEPS,
			msg           = data.msg,
			target        = target,
			forceCookieId = data.forceCookieId,
		}
	end
	tutorialStepRemote:FireClient(player, payload)
	print(string.format("[TutorialController] %s -> step %s", player.Name, tostring(step)))
end

local function advance(player)
	local session = activeTutorials[player.UserId]
	if not session then return end
	session.step += 1
	sendStep(player, session.step)
end

local function completeTutorial(player)
	local userId = player.UserId
	if not activeTutorials[userId] then return end
	activeTutorials[userId] = nil
	player:SetAttribute("InTutorial", false)
	PlayerDataManager.SetTutorialCompleted(player)
	sendStep(player, 0)
	print("[TutorialController] " .. player.Name .. " tutorial COMPLETE — saved to DataStore")
end

-- ─── Player Join ─────────────────────────────────────────────────────────────
local function handlePlayerJoin(player)
	task.wait(3)
	if not player or not player.Parent then return end

	local data = PlayerDataManager.GetData(player)
	if not data then return end

	if data.tutorialCompleted then
		local payload = { step = 0, total = TOTAL_STEPS, msg = "", isReturn = true }
		tutorialStepRemote:FireClient(player, payload)
		print("[TutorialController] " .. player.Name .. " returning player -> GameSpawn")
		return
	end

	local chosen = POS_DISPLAY_TARGETS[math.random(1, #POS_DISPLAY_TARGETS)]
	activeTutorials[player.UserId] = { step = 1, posTarget = chosen }
	player:SetAttribute("InTutorial", true)
	sendStep(player, 1)

	-- Signal TestNPCSpawner which display POS was chosen
	task.spawn(function()
		local evts = ServerStorage:WaitForChild("Events", 10)
		local posChosenEvt = evts and evts:FindFirstChild("TutorialPOSChosen")
		if posChosenEvt then posChosenEvt:Fire(player, chosen) end
	end)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(handlePlayerJoin, player)
end)

Players.PlayerRemoving:Connect(function(player)
	activeTutorials[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(handlePlayerJoin, player)
end

-- ─── Skip / Start Day / Replay ───────────────────────────────────────────────
tutorialDoneRemote.OnServerEvent:Connect(function(player)
	completeTutorial(player)
end)

startGameRemote.OnServerEvent:Connect(function(player)
	completeTutorial(player)
end)

replayRemote.OnServerEvent:Connect(function(player)
	local session = activeTutorials[player.UserId]
	if not session or session.step ~= 10 then return end
	session.step = 1
	sendStep(player, 1)
	print("[TutorialController] " .. player.Name .. " replaying tutorial from step 1")
end)

-- ─── Station Advance Gates ────────────────────────────────────────────────────
local function makeGate(expectedStep)
	return function(player, ...)
		local session = activeTutorials[player.UserId]
		if session and session.step == expectedStep then
			advance(player)
		end
	end
end

confirmNPCOrderRemote.OnServerEvent:Connect(makeGate(1))
mixResultRemote.OnServerEvent:Connect(makeGate(2))

-- Step 3: dough complete → skip step 4 (auto-deposit) → jump to step 5 (pull from fridge)
-- Skipping step 4 prevents the fridge camera transition from playing twice.
doughResultRemote.OnServerEvent:Connect(function(player, ...)
	local session = activeTutorials[player.UserId]
	if not session or session.step ~= 3 then return end
	session.step = 5
	sendStep(player, 5)
end)

-- Step 4 kept for safety but will not fire in normal tutorial flow (skipped above)
depositDoughRemote.OnServerEvent:Connect(makeGate(4))

-- Step 5 gate: FridgePulled BindableEvent (fired by MinigameServer after fridge pull)
-- PullFromFridgeResult is server→client only — OnServerEvent would never fire.
task.spawn(function()
	local evts = ServerStorage:WaitForChild("Events", 10)
	local fe   = evts and evts:WaitForChild("FridgePulled", 10)
	if not fe then warn("[TutorialController] FridgePulled event not found"); return end
	fe.Event:Connect(function(player)
		local session = activeTutorials[player.UserId]
		if session and session.step == 5 then
			advance(player)
		end
	end)
	print("[TutorialController] FridgePulled gate wired for step 5")
end)

ovenResultRemote.OnServerEvent:Connect(makeGate(6))
frostResultRemote.OnServerEvent:Connect(makeGate(7))
dressResultRemote.OnServerEvent:Connect(makeGate(8))

-- Step 9 gate: TutorialDelivered BindableEvent (fired by TestNPCSpawner after delivery)
-- DeliveryResult is server→client only — OnServerEvent would never fire here.
task.spawn(function()
	local evts = ServerStorage:WaitForChild("Events", 10)
	local fe   = evts and evts:WaitForChild("TutorialDelivered", 10)
	if not fe then warn("[TutorialController] TutorialDelivered BindableEvent not found"); return end
	fe.Event:Connect(function(player)
		local session = activeTutorials[player.UserId]
		if session and session.step == 9 then
			advance(player)  -- 9→10: Final Menu
		end
	end)
	print("[TutorialController] TutorialDelivered gate wired for step 9")
end)

print("[TutorialController] Ready — 9-step cinematic tutorial active.")
