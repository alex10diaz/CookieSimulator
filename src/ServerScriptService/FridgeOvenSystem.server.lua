-- FridgeOvenSystem.server.lua
-- Visual-only carry layer: pan attach/detach + arm raise/reset.
-- Fridge stock is managed entirely by OrderManager (via MinigameServer).
-- Connects to FridgePrompt and OvenPrompt ProximityPrompts server-side.
-- Bridges to MinigameServer via FridgePulled / OvenDeposited BindableEvents.

local Players           = game:GetService("Players")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local OrderManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

-- Constants
local CARRY_OFFSET = CFrame.new(0, 1, -3) -- offset from HRP: forward + slightly up

-- State
local carryState = {}  -- [player] = { panModel = Model, batchId = number }

-- References
local panTemplate      = ServerStorage:WaitForChild("PanTemplate")
local gameEvents       = ReplicatedStorage:WaitForChild("GameEvents")
local fridgesFolder    = Workspace:WaitForChild("Fridges")
local ovensFolder      = Workspace:WaitForChild("Ovens")
local eventsFolder     = ServerStorage:WaitForChild("Events")

-- Server→Server bridge events
local fridgePulledBE   = eventsFolder:WaitForChild("FridgePulled")
local ovenDepositedBE  = eventsFolder:WaitForChild("OvenDeposited")

-- Client notification
local pullResultRemote = gameEvents:WaitForChild("PullFromFridgeResult")

-- ─── Oven Prompt Helpers ───────────────────────────────────────────────────────

local function setOvenPromptsEnabled(enabled)
	for _, oven in ipairs(ovensFolder:GetChildren()) do
		local prompt = oven:FindFirstChild("OvenPrompt", true)
		if prompt then prompt.Enabled = enabled end
	end
end

local function countCarrying()
	local n = 0
	for _ in pairs(carryState) do n += 1 end
	return n
end

-- ─── Arm Animation ────────────────────────────────────────────────────────────

local function raiseArms(character)
	local torso = character and character:FindFirstChild("Torso")
	if not torso then return end
	local rs = torso:FindFirstChild("Right Shoulder")
	local ls = torso:FindFirstChild("Left Shoulder")
	if rs then rs.C0 = CFrame.new(1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(90), math.rad(-90)) end
	if ls then ls.C0 = CFrame.new(-1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), math.rad(90)) end
end

local function resetArms(character)
	local torso = character and character:FindFirstChild("Torso")
	if not torso then return end
	local rs = torso:FindFirstChild("Right Shoulder")
	local ls = torso:FindFirstChild("Left Shoulder")
	if rs then rs.C0 = CFrame.new(1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(90), 0) end
	if ls then ls.C0 = CFrame.new(-1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), 0) end
end

-- ─── Pan Attach / Detach ──────────────────────────────────────────────────────

local function attachPan(player)
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local pan = panTemplate:Clone()
	pan.Name   = "CarryPan"
	pan.Parent = Workspace

	local weld  = Instance.new("Weld")
	weld.Name   = "CarryWeld"
	weld.Part0  = hrp
	weld.Part1  = pan.PrimaryPart
	weld.C0     = CARRY_OFFSET
	weld.Parent = hrp

	return pan
end

local function detachPan(pan)
	if pan and pan.PrimaryPart then
		for _, w in ipairs(pan.PrimaryPart:GetChildren()) do
			if w:IsA("Weld") and w.Name == "CarryWeld" then w:Destroy() end
		end
	end
	-- Belt-and-suspenders: remove stray welds from any player's HRP
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				for _, w in ipairs(hrp:GetChildren()) do
					if w:IsA("Weld") and w.Name == "CarryWeld" then w:Destroy() end
				end
			end
		end
	end
end

local function placePanInOven(pan, oven)
	detachPan(pan)
	if not oven then
		warn("[FridgeOvenSystem] Oven is nil — destroying pan")
		pan:Destroy()
		return
	end
	local rack = oven:FindFirstChild("InsideRack")
	if rack then
		pan.Parent = rack
		pan:PivotTo(rack:GetPivot())
		for _, part in ipairs(pan:GetDescendants()) do
			if part:IsA("BasePart") then part.Anchored = true end
		end
	else
		warn("[FridgeOvenSystem] No InsideRack in " .. oven.Name .. " — destroying pan")
		pan:Destroy()
	end
end

-- ─── Fridge Proximity Prompts ─────────────────────────────────────────────────
-- ProximityPrompt.Triggered fires server-side with the triggering player.
-- We call OrderManager directly — no client RemoteEvent needed for fridge pull.

for _, fridge in ipairs(fridgesFolder:GetChildren()) do
	local fridgeId = fridge:GetAttribute("FridgeId")
	if not fridgeId then continue end

	for _, desc in ipairs(fridge:GetDescendants()) do
		if desc:IsA("ProximityPrompt") and desc.Name == "FridgePrompt" then
			desc.Triggered:Connect(function(player)
				if carryState[player] then return end -- already carrying

				local batchId = OrderManager.PullFromFridge(player, fridgeId)
				if not batchId then
					pullResultRemote:FireClient(player, nil, false)
					return
				end

				local pan = attachPan(player)
				if not pan then
					pullResultRemote:FireClient(player, nil, false)
					return
				end

				carryState[player] = { panModel = pan, batchId = batchId }
				raiseArms(player.Character)
				setOvenPromptsEnabled(true)
				pullResultRemote:FireClient(player, batchId, true)
				fridgePulledBE:Fire(player, batchId)

				print(string.format("[FridgeOvenSystem] %s pulled batch #%d from %s", player.Name, batchId, fridgeId))
			end)
		end
	end
end

-- ─── Oven Proximity Prompts ───────────────────────────────────────────────────

for _, oven in ipairs(ovensFolder:GetChildren()) do
	local prompt = oven:FindFirstChild("OvenPrompt", true)
	if not prompt then continue end

	prompt.Enabled = false -- disabled until a player is carrying

	prompt.Triggered:Connect(function(player)
		local state = carryState[player]
		if not state then return end

		placePanInOven(state.panModel, oven)
		resetArms(player.Character)
		carryState[player] = nil

		if countCarrying() == 0 then
			setOvenPromptsEnabled(false)
		end

		ovenDepositedBE:Fire(player, oven.Name)
		print(string.format("[FridgeOvenSystem] %s deposited tray in %s", player.Name, oven.Name))
	end)
end

-- ─── Cleanup ──────────────────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player)
	local state = carryState[player]
	if state then
		if state.panModel and state.panModel.Parent then
			state.panModel:Destroy()
		end
		carryState[player] = nil
		if countCarrying() == 0 then
			setOvenPromptsEnabled(false)
		end
	end
end)

-- ─── Init ─────────────────────────────────────────────────────────────────────

setOvenPromptsEnabled(false)
print("[FridgeOvenSystem] Visual carry system ready.")
