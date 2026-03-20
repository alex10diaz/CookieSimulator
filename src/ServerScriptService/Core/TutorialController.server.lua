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

-- Step 1 gate: NPC order confirm (client remote — lower risk, NPC system validates state server-side)
local confirmNPCOrderRemote = RemoteManager.Get("ConfirmNPCOrder")

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
	if session.step >= TOTAL_STEPS then return end  -- m10: prevent overrun
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
	-- Poll for PlayerDataManager to finish loading (up to 10s before giving up)
	local data
	local deadline = tick() + 10
	repeat
		task.wait(0.5)
		if not player or not player.Parent then return end
		data = PlayerDataManager.GetData(player)
	until data or tick() >= deadline

	if not player or not player.Parent then return end
	if not data then
		warn("[TutorialController] DataStore load timed out for " .. player.Name)
		return
	end

	if data.tutorialCompleted then
		local payload = { step = 0, total = TOTAL_STEPS, msg = "", isReturn = true }
		tutorialStepRemote:FireClient(player, payload)
		print("[TutorialController] " .. player.Name .. " returning player -> GameSpawn")
		return
	end

	local chosen = POS_STEP1_TARGET
	activeTutorials[player.UserId] = { step = 1, posTarget = chosen }
	player:SetAttribute("InTutorial", true)
	sendStep(player, 1)


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
	-- M1: only allow completion from the final summary screen (step 10)
	local session = activeTutorials[player.UserId]
	if session and session.step ~= 10 then return end
	completeTutorial(player)
end)

startGameRemote.OnServerEvent:Connect(function(player)
	-- M1: only allow starting day from the final summary screen (step 10)
	local session = activeTutorials[player.UserId]
	if session and session.step ~= 10 then return end
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
-- Step 1: NPC order confirmed at POS (client remote; NPC system validates state separately)
confirmNPCOrderRemote.OnServerEvent:Connect(function(player)
	local session = activeTutorials[player.UserId]
	if session and session.step == 1 then advance(player) end
end)

-- Steps 2, 3, 6, 7, 8: M1 — listen to StationCompleted BindableEvent fired by MinigameServer
-- after validated endSession(), NOT raw client remotes (which can be spoofed).
task.spawn(function()
	local evts = ServerStorage:WaitForChild("Events", 10)
	local sc   = evts and evts:WaitForChild("StationCompleted", 15)
	if not sc then warn("[TutorialController] StationCompleted event not found"); return end
	sc.Event:Connect(function(player, stationName)
		local session = activeTutorials[player.UserId]
		if not session then return end
		if stationName == "mix" and session.step == 2 then
			advance(player)                          -- 2 → 3
		elseif stationName == "dough" and session.step == 3 then
			-- Skip step 4 (auto-deposit already done); jump straight to step 5 (pull fridge)
			session.step = 5
			sendStep(player, 5)
		elseif stationName == "oven"  and session.step == 6 then
			advance(player)                          -- 6 → 7
		elseif stationName == "frost" and session.step == 7 then
			advance(player)                          -- 7 → 8
		elseif stationName == "dress" and session.step == 8 then
			advance(player)                          -- 8 → 9
		end
	end)
	print("[TutorialController] StationCompleted gate wired for steps 2,3,6,7,8")
end)

-- Step 5 gate: FridgePulled BindableEvent (server-authoritative — cannot be spoofed)
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
