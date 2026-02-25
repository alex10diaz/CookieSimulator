-- FridgeOvenSystem.server.lua
-- Manages fridge stock, tray carry state, and oven deposit flow.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Constants
local MAX_STOCK = 4
local CARRY_OFFSET = CFrame.new(0, 1, -3) -- offset from HRP: forward + slightly up

-- Cookie type → fridge model name
local FRIDGE_NAMES = {
	pink_sugar           = "fridge_pink_sugar",
	chocolate_chip       = "fridge_chocolate_chip",
	birthday_cake        = "fridge_birthday_cake",
	cookies_and_cream    = "fridge_cookies_and_cream",
	snickerdoodle        = "fridge_snickerdoodle",
	lemon_blackraspberry = "fridge_lemon_blackraspberry",
}

-- State
local fridgeStock = {}
for cookieType in pairs(FRIDGE_NAMES) do
	fridgeStock[cookieType] = 0
end

-- carryState[player] = { cookieType = string, panModel = Model }
local carryState = {}

-- References
local fridgesFolder      = Workspace:WaitForChild("Fridges")
local ovensFolder        = Workspace:WaitForChild("Ovens")
local panTemplate        = ServerStorage:WaitForChild("PanTemplate")
local remotes            = ReplicatedStorage:WaitForChild("Remotes")
local grabTrayEvent      = remotes:WaitForChild("GrabTray")
local depositTrayEvent   = remotes:WaitForChild("DepositTray")
local doughBatchComplete = ServerStorage:WaitForChild("Events"):WaitForChild("DoughBatchComplete")

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function getFridgeModel(cookieType)
	return fridgesFolder:FindFirstChild(FRIDGE_NAMES[cookieType])
end

local function updateDisplay(cookieType)
	local fridge = getFridgeModel(cookieType)
	if not fridge then return end
	local stock = fridgeStock[cookieType]
	for _, desc in ipairs(fridge:GetDescendants()) do
		if desc:IsA("BillboardGui") and desc.Name == "FridgeDisplay" then
			local frame = desc:FindFirstChild("Frame")
			if frame then
				local label = frame:FindFirstChildWhichIsA("TextLabel")
				if label then
					label.Text = tostring(stock) .. "/" .. MAX_STOCK
				end
			end
		end
	end
end

local function setPromptEnabled(cookieType, enabled)
	local fridge = getFridgeModel(cookieType)
	if not fridge then return end
	for _, desc in ipairs(fridge:GetDescendants()) do
		if desc:IsA("ProximityPrompt") and desc.Name == "FridgePrompt" then
			desc.Enabled = enabled
		end
	end
end

local function setOvenPromptsEnabled(enabled)
	for _, oven in ipairs(ovensFolder:GetChildren()) do
		local prompt = oven:FindFirstChild("OvenPrompt", true)
		if prompt then prompt.Enabled = enabled end
	end
end

-- ─── Arm Animation ────────────────────────────────────────────────────────────

local function raiseArms(character)
	local torso = character:FindFirstChild("Torso")
	if not torso then return end
	local rs = torso:FindFirstChild("Right Shoulder")
	local ls = torso:FindFirstChild("Left Shoulder")
	if rs then
		rs.C0 = CFrame.new(1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(90), math.rad(-90))
	end
	if ls then
		ls.C0 = CFrame.new(-1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), math.rad(90))
	end
end

local function resetArms(character)
	if not character then return end
	local torso = character:FindFirstChild("Torso")
	if not torso then return end
	local rs = torso:FindFirstChild("Right Shoulder")
	local ls = torso:FindFirstChild("Left Shoulder")
	if rs then
		rs.C0 = CFrame.new(1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(90), 0)
	end
	if ls then
		ls.C0 = CFrame.new(-1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), 0)
	end
end

-- ─── Pan Attach / Detach ──────────────────────────────────────────────────────

local function attachPan(player, cookieType)
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local pan = panTemplate:Clone()
	pan.Name = "CarryPan_" .. cookieType
	pan.Parent = Workspace

	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = hrp
	weld.Part1 = pan.PrimaryPart
	weld.C0 = CARRY_OFFSET
	weld.Parent = hrp

	return pan
end

local function detachPan(pan)
	-- Remove the carry weld from wherever it lives
	if pan and pan.PrimaryPart then
		for _, w in ipairs(pan.PrimaryPart:GetChildren()) do
			if w:IsA("Weld") and w.Name == "CarryWeld" then
				w:Destroy()
			end
		end
	end
	-- Also check HRP of any character (belt-and-suspenders)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				for _, w in ipairs(hrp:GetChildren()) do
					if w:IsA("Weld") and w.Name == "CarryWeld" then
						w:Destroy()
					end
				end
			end
		end
	end
end

local function placePanInOven(pan, oven)
	local rack = oven:FindFirstChild("InsideRack")
	detachPan(pan)
	if rack then
		pan.Parent = rack
		pan:PivotTo(rack:GetPivot())
	else
		warn("[FridgeOvenSystem] No InsideRack in " .. oven.Name .. " — destroying pan")
		pan:Destroy()
		return
	end
	for _, part in ipairs(pan:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

-- ─── Grab Tray ────────────────────────────────────────────────────────────────

local function handleGrabTray(player, cookieType)
	if not FRIDGE_NAMES[cookieType] then return end
	if carryState[player] then return end
	if fridgeStock[cookieType] <= 0 then return end

	local pan = attachPan(player, cookieType)
	if not pan then return end

	carryState[player] = { cookieType = cookieType, panModel = pan }
	fridgeStock[cookieType] -= 1
	updateDisplay(cookieType)

	if fridgeStock[cookieType] == 0 then
		setPromptEnabled(cookieType, false)
	end

	raiseArms(player.Character)
	setOvenPromptsEnabled(true)

	print("[FridgeOvenSystem] " .. player.Name .. " grabbed: " .. cookieType)
end

-- Connect FridgePrompts (ProximityPrompt.Triggered fires server-side)
for cookieType, fridgeName in pairs(FRIDGE_NAMES) do
	local fridge = fridgesFolder:WaitForChild(fridgeName)
	for _, desc in ipairs(fridge:GetDescendants()) do
		if desc:IsA("ProximityPrompt") and desc.Name == "FridgePrompt" then
			desc.Triggered:Connect(function(player)
				handleGrabTray(player, cookieType)
			end)
		end
	end
end

grabTrayEvent.OnServerEvent:Connect(function(player, cookieType)
	handleGrabTray(player, cookieType)
end)

-- ─── Deposit Tray ─────────────────────────────────────────────────────────────

local function handleDepositTray(player, ovenName)
	local state = carryState[player]
	if not state then return end

	local oven = ovensFolder:FindFirstChild(ovenName or "Oven1")
	if not oven then
		warn("[FridgeOvenSystem] Oven not found: " .. tostring(ovenName))
		return
	end

	placePanInOven(state.panModel, oven)
	resetArms(player.Character)
	carryState[player] = nil
	setOvenPromptsEnabled(false)

	if fridgeStock[state.cookieType] > 0 then
		setPromptEnabled(state.cookieType, true)
	end

	print("[FridgeOvenSystem] " .. player.Name .. " deposited tray in " .. oven.Name)

	-- TODO: trigger oven minigame
	-- OvenMinigame.Start(player, oven, state.cookieType)
end

-- Connect OvenPrompts
for _, oven in ipairs(ovensFolder:GetChildren()) do
	local prompt = oven:FindFirstChild("OvenPrompt", true)
	if prompt then
		prompt.Enabled = false -- disabled until player is carrying
		prompt.Triggered:Connect(function(player)
			handleDepositTray(player, oven.Name)
		end)
	end
end

depositTrayEvent.OnServerEvent:Connect(function(player, ovenName)
	handleDepositTray(player, ovenName)
end)

-- ─── Dough → Fridge Stock ─────────────────────────────────────────────────────

doughBatchComplete.Event:Connect(function(cookieType)
	if not fridgeStock[cookieType] then
		warn("[FridgeOvenSystem] Unknown cookieType: " .. tostring(cookieType))
		return
	end
	if fridgeStock[cookieType] >= MAX_STOCK then
		warn("[FridgeOvenSystem] Fridge full for: " .. cookieType)
		return
	end

	fridgeStock[cookieType] += 1
	updateDisplay(cookieType)

	if fridgeStock[cookieType] == 1 then
		setPromptEnabled(cookieType, true)
	end

	print("[FridgeOvenSystem] Stocked " .. cookieType .. ": " .. fridgeStock[cookieType] .. "/" .. MAX_STOCK)
end)

-- ─── Disconnect Cleanup ───────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player)
	local state = carryState[player]
	if state then
		if state.panModel and state.panModel.Parent then
			state.panModel:Destroy()
		end
		carryState[player] = nil
		print("[FridgeOvenSystem] Cleaned up carry state for " .. player.Name)
	end
end)

-- ─── Init ─────────────────────────────────────────────────────────────────────

for cookieType in pairs(FRIDGE_NAMES) do
	updateDisplay(cookieType)
	setPromptEnabled(cookieType, false)
end

print("[FridgeOvenSystem] Initialized. All fridges at 0/" .. MAX_STOCK)
