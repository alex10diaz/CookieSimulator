-- ServerScriptService/Core/StaffManager.server.lua
-- Manages AI worker rigs for Solo AI Mode.
-- Task 1: Skeleton + worker rig spawner with baker uniform.

-- ── SERVICES ────────────────────────────────────────────────────────────────

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")

-- ── REQUIRES ────────────────────────────────────────────────────────────────

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

-- ── CONFIG ───────────────────────────────────────────────────────────────────

local HIRE_COST       = 50
local WORKER_QUALITY  = 75
local MAX_WORKERS     = 5
local SHIRT_TEMPLATE  = "rbxassetid://76531325740097"  -- ShirtTemplate from StarterCharacter
local PANTS_TEMPLATE  = "rbxassetid://98693082132232"  -- PantsTemplate from StarterCharacter

-- ── STATE ────────────────────────────────────────────────────────────────────

local workers     = {}  -- workers[stationId] = { rig, proxy, active }
local hirePrompts = {}  -- hirePrompts[stationId] = ProximityPrompt
local workerCount = 0

-- ── HELPERS ──────────────────────────────────────────────────────────────────

-- makeProxy(workerName)
-- Returns a lightweight table that satisfies every OrderManager call,
-- all of which only access the .Name field.
local function makeProxy(workerName)
	return { Name = workerName }
end

-- applyBakerUniform(rig)
-- Applies baker shirt + pants via Shirt/Pants instances with ShirtTemplate/PantsTemplate.
-- This matches how StarterCharacter clothing works — ShirtTemplate is the texture asset ID.
local function applyBakerUniform(rig)
	local shirt = Instance.new("Shirt")
	shirt.ShirtTemplate = SHIRT_TEMPLATE
	shirt.Parent = rig

	local pants = Instance.new("Pants")
	pants.PantsTemplate = PANTS_TEMPLATE
	pants.Parent = rig
end

-- spawnWorkerRig(workerName, spawnCF)
-- Builds a minimal NPC model and parents it to workspace.
-- Returns the Model instance.
local function spawnWorkerRig(workerName, spawnCF)
	local rig = Instance.new("Model")
	rig.Name = workerName

	-- HumanoidRootPart ─────────────────────────────────────────────────────
	local hrp = Instance.new("Part")
	hrp.Name        = "HumanoidRootPart"
	hrp.Size        = Vector3.new(2, 2, 1)
	hrp.Anchored    = true
	hrp.BrickColor  = BrickColor.new("Pastel brown")
	hrp.TopSurface  = Enum.SurfaceType.Smooth
	hrp.BottomSurface = Enum.SurfaceType.Smooth
	hrp.CFrame      = spawnCF
	hrp.Parent      = rig

	-- Head ─────────────────────────────────────────────────────────────────
	local head = Instance.new("Part")
	head.Name        = "Head"
	head.Size        = Vector3.new(2, 1, 1)
	head.Anchored    = true
	head.BrickColor  = BrickColor.new("Pastel yellow")
	head.TopSurface  = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.CFrame      = spawnCF * CFrame.new(0, 1.5, 0)
	head.Parent      = rig

	-- Humanoid ─────────────────────────────────────────────────────────────
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = rig

	-- PrimaryPart must be set before parenting to workspace
	rig.PrimaryPart = hrp

	-- NameTag BillboardGui ─────────────────────────────────────────────────
	local nameBillboard = Instance.new("BillboardGui")
	nameBillboard.Name          = "NameTag"
	nameBillboard.Size          = UDim2.new(0, 140, 0, 36)
	nameBillboard.StudsOffset   = Vector3.new(0, 3, 0)
	nameBillboard.AlwaysOnTop   = true
	nameBillboard.Parent        = hrp

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name            = "NameLabel"
	nameLabel.Size            = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text            = workerName
	nameLabel.TextColor3      = Color3.new(1, 1, 1)
	nameLabel.Font            = Enum.Font.GothamBold
	nameLabel.TextScaled      = true
	nameLabel.Parent          = nameBillboard

	-- StatusBillboard BillboardGui ─────────────────────────────────────────
	local statusBillboard = Instance.new("BillboardGui")
	statusBillboard.Name        = "StatusBillboard"
	statusBillboard.Size        = UDim2.new(0, 120, 0, 24)
	statusBillboard.StudsOffset = Vector3.new(0, 2.2, 0)
	statusBillboard.AlwaysOnTop = true
	statusBillboard.Parent      = hrp

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name            = "StatusLabel"
	statusLabel.Size            = UDim2.new(1, 0, 1, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text            = "Idle"
	statusLabel.TextColor3      = Color3.fromRGB(180, 180, 180)
	statusLabel.Font            = Enum.Font.Gotham
	statusLabel.TextScaled      = true
	statusLabel.Parent          = statusBillboard

	-- Parent rig to workspace, then apply uniform ──────────────────────────
	rig.Parent = workspace
	applyBakerUniform(rig)

	return rig
end

-- setStatus(rig, text, color)
-- Updates the StatusLabel on the rig's StatusBillboard.
-- Guards against nil at every navigation step.
local function setStatus(rig, text, color)
	if not rig then return end

	local primaryPart = rig.PrimaryPart
	if not primaryPart then return end

	local billboard = primaryPart:FindFirstChild("StatusBillboard")
	if not billboard then return end

	local label = billboard:FindFirstChild("StatusLabel")
	if not label then return end

	label.Text       = text
	label.TextColor3 = color or Color3.fromRGB(180, 180, 180)
end

-- ── TASK 2: STATIONS + runWorkerLoop ─────────────────────────────────────────

local POLL_INTERVAL = 2

local STATIONS = {
	mix = {
		label   = "Mixing",
		spawnCF = CFrame.new(18, 5, -17),
		work = function(proxy)
			local orders = OrderManager.GetNPCOrders and OrderManager.GetNPCOrders() or {}
			local cookieId = "chocolate_chip"
			for _, o in ipairs(orders) do
				if o.cookieId then cookieId = o.cookieId; break end
			end
			local batchId = OrderManager.TryStartBatch(proxy, cookieId)
			if not batchId then return false end
			task.wait(8)
			OrderManager.RecordStationScore(proxy, "mix", WORKER_QUALITY, batchId)
			return true
		end,
	},
	dough = {
		label   = "Shaping",
		spawnCF = CFrame.new(0, 5, -34),
		work = function(proxy)
			local batch = OrderManager.GetBatchAtStage("dough")
			if not batch then return false end
			task.wait(6)
			OrderManager.RecordStationScore(proxy, "dough", WORKER_QUALITY, batch.batchId)
			return true
		end,
	},
	oven = {
		label   = "Baking",
		spawnCF = CFrame.new(-2, 8, -85),
		work = function(proxy)
			local fridges = workspace:FindFirstChild("Fridges")
			if not fridges then return false end
			local batchId
			for _, fridge in ipairs(fridges:GetChildren()) do
				local fridgeId = fridge:GetAttribute("FridgeId")
				if fridgeId then
					batchId = OrderManager.PullFromFridge(proxy, fridgeId)
					if batchId then break end
				end
			end
			if not batchId then return false end
			task.wait(12)
			OrderManager.RecordOvenScore(proxy, WORKER_QUALITY, batchId)
			return true
		end,
	},
	frost = {
		label   = "Frosting",
		spawnCF = CFrame.new(20, 6, -36),
		work = function(proxy)
			local entry = OrderManager.TakeFromWarmers(true)
			if not entry then return false end
			task.wait(8)
			OrderManager.RecordFrostScore(
				proxy.Name, entry.batchId, WORKER_QUALITY,
				entry.snapshot or 0, entry.cookieId
			)
			return true
		end,
	},
	dress = {
		label   = "Packing",
		spawnCF = CFrame.new(-27, 5, -32),
		work = function(proxy)
			local entry = OrderManager.TakeFromWarmers(false)
			if not entry then return false end
			task.wait(6)
			OrderManager.CreateBox(proxy, entry.batchId, WORKER_QUALITY, entry)
			return true
		end,
	},
}

local function runWorkerLoop(stationId, rig, proxy)
	local stationDef = STATIONS[stationId]
	while workers[stationId] and workers[stationId].active do
		local didWork = false
		local success, err = pcall(function()
			didWork = stationDef.work(proxy)
		end)
		if not success then
			warn("[StaffManager] Worker error at", stationId, ":", err)
		end
		if success and didWork then
			setStatus(rig, "Done ✓", Color3.fromRGB(80, 200, 80))
			task.wait(1)
		else
			setStatus(rig, "Idle", Color3.fromRGB(160, 160, 160))
			task.wait(POLL_INTERVAL)
		end
	end
	setStatus(rig, "Off duty", Color3.fromRGB(120, 120, 120))
end

-- ── TASK 3: HIRE + DISMISS ────────────────────────────────────────────────────

local function hireWorker(player, stationId)
	if workers[stationId] and workers[stationId].active then
		warn("[StaffManager]", stationId, "already staffed")
		return false
	end
	if workerCount >= MAX_WORKERS then
		warn("[StaffManager] Max workers reached for", player.Name)
		return false
	end
	local profile = PlayerDataManager.GetData(player)
	if not profile or (profile.coins or 0) < HIRE_COST then
		warn("[StaffManager]", player.Name, "cannot afford worker (need", HIRE_COST, "coins)")
		return false
	end

	PlayerDataManager.AddCoins(player, -HIRE_COST)
	workerCount += 1

	local workerName = "Baker #" .. workerCount
	local stationDef = STATIONS[stationId]
	local proxy = makeProxy(workerName)
	local rig   = spawnWorkerRig(workerName, stationDef.spawnCF)

	workers[stationId] = { rig = rig, proxy = proxy, active = true }
	task.spawn(runWorkerLoop, stationId, rig, proxy)

	local prompt = hirePrompts[stationId]
	if prompt then
		prompt.ActionText = "Dismiss " .. workerName
		prompt.ObjectText = "AI Worker"
	end

	print(string.format("[StaffManager] %s hired %s at %s (-%d coins)", player.Name, workerName, stationId, HIRE_COST))
	return true
end

local function dismissWorker(stationId)
	local entry = workers[stationId]
	if not entry then return end
	entry.active = false
	if entry.rig and entry.rig.Parent then
		entry.rig:Destroy()
	end
	workers[stationId] = nil
	workerCount = math.max(0, workerCount - 1)

	local prompt = hirePrompts[stationId]
	local stationDef = STATIONS[stationId]
	if prompt and stationDef then
		prompt.ActionText = "Hire Baker (50🪙)"
		prompt.ObjectText = stationDef.label .. " Station"
	end
	print("[StaffManager] Dismissed worker at", stationId)
end

local function dismissAllWorkers()
	for stationId in pairs(STATIONS) do
		dismissWorker(stationId)
	end
	workerCount = 0
	print("[StaffManager] All workers dismissed")
end

-- ── TASK 4: HIRE PROMPTS + GAMESTATE WIRING ──────────────────────────────────

local function spawnHirePrompts()
	for stationId, stationDef in pairs(STATIONS) do
		local anchor = Instance.new("Part")
		anchor.Name         = "HireAnchor_" .. stationId
		anchor.Anchored     = true
		anchor.CanCollide   = false
		anchor.Transparency = 1
		anchor.Size         = Vector3.new(1, 1, 1)
		anchor.CFrame       = stationDef.spawnCF
		anchor.Parent       = workspace

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText            = "Hire Baker (50🪙)"
		prompt.ObjectText            = stationDef.label .. " Station"
		prompt.KeyboardKeyCode       = Enum.KeyCode.H
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight   = false
		prompt.Parent                = anchor

		hirePrompts[stationId] = prompt

		local capturedId = stationId
		prompt.Triggered:Connect(function(player)
			local entry = workers[capturedId]
			if entry and entry.active then
				dismissWorker(capturedId)
			else
				hireWorker(player, capturedId)
			end
		end)
	end
	print("[StaffManager] Hire prompts spawned for PreOpen")
end

local function destroyHirePrompts()
	for stationId, prompt in pairs(hirePrompts) do
		local anchor = prompt.Parent
		if anchor and anchor.Parent then
			anchor:Destroy()
		end
	end
	hirePrompts = {}
	print("[StaffManager] Hire prompts removed")
end

-- Wire to GameStateManager via workspace attribute signal
workspace:GetAttributeChangedSignal("GameState"):Connect(function()
	local state = workspace:GetAttribute("GameState")
	if state == "PreOpen" then
		spawnHirePrompts()
	elseif state == "EndOfDay" or state == "Lobby" then
		destroyHirePrompts()
		dismissAllWorkers()
	end
end)

-- ── INIT ─────────────────────────────────────────────────────────────────────

print("[StaffManager] Loaded")
