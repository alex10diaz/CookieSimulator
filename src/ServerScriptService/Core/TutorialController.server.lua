-- src/ServerScriptService/Core/TutorialController.server.lua
-- Drives the 5-step tutorial for first-time players.
-- Server-authoritative: step state lives here. Client is display-only.
-- Steps: Mix(1) -> Dough(2) -> Oven(3) -> Dress(4) -> Deliver(5) -> FinalMenu(6) -> complete(0)
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

-- ─── Constants ────────────────────────────────────────────────────────────────
local TOTAL_STEPS        = 5
local FINAL_MENU_STEP    = TOTAL_STEPS + 1   -- 6: shown after step 5 delivery gate
local TUTORIAL_REWARD    = 200               -- coins granted on tutorial completion

-- Use chocolate_chip (no frost needed) so the tutorial skips the frost station.
local TUTORIAL_COOKIE = "chocolate_chip"

local STEPS = {
	[1] = { msg = "Go to a Mixer and press E to start mixing!",                 target = "Mixer",       forceCookieId = TUTORIAL_COOKIE },
	[2] = { msg = "Shape your dough at the Dough Table!",                       target = "DoughTable",  forceCookieId = nil             },
	[3] = { msg = "Pull your dough from the fridge, then bake it in the Oven!", target = "Oven",        forceCookieId = nil             },
	[4] = { msg = "Dress and pack your cookies at the Dress Station!",          target = "DressTable",  forceCookieId = nil             },
	[5] = { msg = "Carry the box to the customer and press E to deliver!",      target = "WaitingArea", forceCookieId = nil             },
}

-- ─── State ────────────────────────────────────────────────────────────────────
local activeTutorials = {}

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function sendStep(player, step)
	local payload
	if step == 0 then
		payload = { step = 0, total = TOTAL_STEPS, msg = "", isReturn = false }
	elseif step == FINAL_MENU_STEP then
		payload = { step = FINAL_MENU_STEP, total = TOTAL_STEPS, msg = "", reward = TUTORIAL_REWARD }
	else
		local data = STEPS[step]
		if not data then
			warn("[TutorialController] sendStep: invalid step " .. tostring(step))
			return
		end
		payload = {
			step          = step,
			total         = TOTAL_STEPS,
			msg           = data.msg,
			target        = data.target,
			forceCookieId = data.forceCookieId,
		}
	end
	tutorialStepRemote:FireClient(player, payload)
	print(string.format("[TutorialController] %s -> step %s", player.Name, tostring(step)))
end

local function advance(player)
	local session = activeTutorials[player.UserId]
	if not session then return end
	if session.step >= FINAL_MENU_STEP then return end
	session.step += 1
	sendStep(player, session.step)
end

local function completeTutorial(player)
	local userId = player.UserId
	if not activeTutorials[userId] then return end
	activeTutorials[userId] = nil
	player:SetAttribute("InTutorial", false)
	-- Grant tutorial completion reward
	pcall(function()
		PlayerDataManager.AddCoins(player, TUTORIAL_REWARD)
	end)
	PlayerDataManager.SetTutorialCompleted(player)
	sendStep(player, 0)
	print("[TutorialController] " .. player.Name .. " tutorial COMPLETE (+$" .. TUTORIAL_REWARD .. " coins) — saved to DataStore")
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

	activeTutorials[player.UserId] = { step = 1 }
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

-- ─── Skip ────────────────────────────────────────────────────────────────────
-- Allow skip from ANY step — no step restriction.
tutorialDoneRemote.OnServerEvent:Connect(function(player)
	if not activeTutorials[player.UserId] then return end
	completeTutorial(player)
end)

-- ─── Start Day / Replay ──────────────────────────────────────────────────────
startGameRemote.OnServerEvent:Connect(function(player)
	local session = activeTutorials[player.UserId]
	if session and session.step ~= FINAL_MENU_STEP then return end
	completeTutorial(player)
end)

replayRemote.OnServerEvent:Connect(function(player)
	local session = activeTutorials[player.UserId]
	if not session or session.step ~= FINAL_MENU_STEP then return end
	session.step = 1
	sendStep(player, 1)
	print("[TutorialController] " .. player.Name .. " replaying tutorial from step 1")
end)

-- ─── Station Advance Gates ────────────────────────────────────────────────────
-- Steps 1,2,3,4: gated by StationCompleted BindableEvent (server-authoritative)
task.spawn(function()
	local evts = ServerStorage:WaitForChild("Events", 10)
	local sc   = evts and evts:WaitForChild("StationCompleted", 15)
	if not sc then warn("[TutorialController] StationCompleted event not found"); return end
	sc.Event:Connect(function(player, stationName)
		local session = activeTutorials[player.UserId]
		if not session then return end
		if     stationName == "mix"   and session.step == 1 then advance(player)  -- 1→2
		elseif stationName == "dough" and session.step == 2 then advance(player)  -- 2→3
		elseif stationName == "oven"  and session.step == 3 then advance(player)  -- 3→4
		elseif stationName == "dress" and session.step == 4 then advance(player)  -- 4→5
		end
	end)
	print("[TutorialController] StationCompleted gate wired for steps 1-4")
end)

-- Step 5 gate: TutorialDelivered BindableEvent (fired by TestNPCSpawner after delivery)
task.spawn(function()
	local evts = ServerStorage:WaitForChild("Events", 10)
	local fe   = evts and evts:WaitForChild("TutorialDelivered", 10)
	if not fe then warn("[TutorialController] TutorialDelivered BindableEvent not found"); return end
	fe.Event:Connect(function(player)
		local session = activeTutorials[player.UserId]
		if session and session.step == 5 then
			advance(player)  -- 5→6: Final Menu
		end
	end)
	print("[TutorialController] TutorialDelivered gate wired for step 5")
end)

print("[TutorialController] Ready — 5-step tutorial active.")
