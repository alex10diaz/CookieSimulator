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
local OrderManager      = require(ServerScriptService:WaitForChild("Core"):WaitForChild("OrderManager"))
local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

-- ── CONFIG ───────────────────────────────────────────────────────────────────

local HIRE_COST       = 50
local WORKER_QUALITY  = 75
local MAX_WORKERS     = 5
local SHIRT_TEMPLATE  = "rbxassetid://76531325740097"  -- ShirtTemplate from StarterCharacter
local PANTS_TEMPLATE  = "rbxassetid://98693082132232"  -- PantsTemplate from StarterCharacter

-- ── STATE ────────────────────────────────────────────────────────────────────

local workers      = {}  -- workers[stationId] = { rig, proxy, active }
local hirePrompts  = {}  -- hirePrompts[stationId] = { prompt, conn }
local workerCount  = 0
local stagedBoxes  = {}  -- boxId -> Part (box sitting on Dress Table 2)
local stagingTable = nil -- the Dress Table 2 surface Part

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
local function spawnWorkerRig(workerName, spawnCF, _hiringPlayer)
	local rig

	-- M-10: use clean NPCTemplate R6 rig instead of cloning the hiring player's character
	local template = ServerStorage:FindFirstChild("NPCTemplate")
	if template then
		local ok, err2 = pcall(function()
			local clone = template:Clone()
			clone.Name = workerName

			-- Strip customer-NPC-specific elements that don't belong on an AI worker
			for _, name in ipairs({"PatienceGui", "OrderPrompt", "VIPGui"}) do
				local inst = clone:FindFirstChild(name, true)
				if inst then inst:Destroy() end
			end
			-- Remove face decal so workers don't look like customers
			local head = clone:FindFirstChild("Head")
			if head then
				local face = head:FindFirstChildOfClass("Decal")
				if face then face:Destroy() end
			end

			-- Hide health/name bar
			local hum = clone:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DisplayDistanceType   = Enum.HumanoidDisplayDistanceType.None
				hum.HealthDisplayDistance = 0
			end

			-- Parts are all at 0,0,0 in ServerStorage; Motor6D joints only
			-- assemble when in workspace. Parent first, wait a frame, then move.
			local hrp = clone:FindFirstChild("HumanoidRootPart")
			if hrp then
				clone.PrimaryPart = hrp
			end

			-- Parent to workspace so physics assembles the rig
			clone.Parent = workspace
			task.wait()  -- one physics step to resolve Motor6D joints

			-- Now move the assembled model into position
			if clone.PrimaryPart then
				clone:SetPrimaryPartCFrame(spawnCF)
			end

			-- Anchor all parts to hold position
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored   = true
					part.CanCollide = false
				end
			end

			rig = clone
		end)
		if not ok then
			warn("[StaffManager] NPCTemplate clone failed, using block rig:", err2)
		end
	end

	-- Fallback: simple block rig
	if not rig then
		rig = Instance.new("Model")
		rig.Name = workerName
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"; hrp.Size = Vector3.new(2,2,1)
		hrp.Anchored = true; hrp.CanCollide = false
		hrp.BrickColor = BrickColor.new("Pastel brown")
		hrp.TopSurface = Enum.SurfaceType.Smooth; hrp.BottomSurface = Enum.SurfaceType.Smooth
		hrp.CFrame = spawnCF; hrp.Parent = rig
		local head = Instance.new("Part")
		head.Name = "Head"; head.Size = Vector3.new(2,1,1)
		head.Anchored = true; head.CanCollide = false
		head.BrickColor = BrickColor.new("Pastel yellow")
		head.TopSurface = Enum.SurfaceType.Smooth; head.BottomSurface = Enum.SurfaceType.Smooth
		head.CFrame = spawnCF * CFrame.new(0,1.5,0); head.Parent = rig
		local hum = Instance.new("Humanoid")
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.Parent = rig
		rig.PrimaryPart = hrp
		rig.Parent = workspace
	end

	applyBakerUniform(rig)

	-- NameTag + StatusBillboard on HRP
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if hrp then
		local nb = Instance.new("BillboardGui")
		nb.Name="NameTag"; nb.Size=UDim2.new(0,140,0,36)
		nb.StudsOffset=Vector3.new(0,3,0); nb.AlwaysOnTop=true; nb.Parent=hrp
		local nl = Instance.new("TextLabel", nb)
		nl.Name="NameLabel"; nl.Size=UDim2.new(1,0,1,0)
		nl.BackgroundTransparency=1; nl.Text=workerName
		nl.TextColor3=Color3.new(1,1,1); nl.Font=Enum.Font.GothamBold; nl.TextScaled=true

		local sb = Instance.new("BillboardGui")
		sb.Name="StatusBillboard"; sb.Size=UDim2.new(0,120,0,24)
		sb.StudsOffset=Vector3.new(0,2.2,0); sb.AlwaysOnTop=true; sb.Parent=hrp
		local sl = Instance.new("TextLabel", sb)
		sl.Name="StatusLabel"; sl.Size=UDim2.new(1,0,1,0)
		sl.BackgroundTransparency=1; sl.Text="Idle"
		sl.TextColor3=Color3.fromRGB(180,180,180); sl.Font=Enum.Font.Gotham; sl.TextScaled=true
	end

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

-- ── DRESS TABLE 2 — ORDER STAGING ────────────────────────────────────────────

-- createStagingTable()
-- Uses the existing "Dough Table 2" top surface as the staging area.
-- Falls back to a new Part if the model isn't found (so it's always moveable in Studio).
local function createStagingTable()
	-- Try to find the existing Dough Table 2 top Part (highest Y in the model)
	local dt2 = workspace:FindFirstChild("Store") and workspace.Store:FindFirstChild("Dough Table 2")
	local topPart = nil
	if dt2 then
		local highestY = -math.huge
		for _, desc in ipairs(dt2:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Position.Y > highestY then
				highestY = desc.Position.Y
				topPart = desc
			end
		end
	end

	local part
	if topPart then
		part = topPart
		print("[StaffManager] Using Dough Table 2 top surface for staging")
	else
		-- Fallback: create a moveable Part (reposition in Studio as needed)
		part = Instance.new("Part")
		part.Name          = "DressTable2"
		part.Size          = Vector3.new(4, 0.3, 2)
		part.CFrame        = CFrame.new(-15, 4.15, -33)
		part.Anchored      = true
		part.CanCollide    = true
		part.BrickColor    = BrickColor.new("Pastel Blue")
		part.Material      = Enum.Material.SmoothPlastic
		part.TopSurface    = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent        = workspace
		print("[StaffManager] Dough Table 2 not found — created fallback DressTable2 Part")
	end

	-- Add "Ready Orders" label (only if not already present)
	if not part:FindFirstChild("ReadyOrdersBillboard") then
		local billboard = Instance.new("BillboardGui")
		billboard.Name        = "ReadyOrdersBillboard"
		billboard.Size        = UDim2.new(0, 140, 0, 28)
		billboard.StudsOffset = Vector3.new(0, 2, 0)
		billboard.AlwaysOnTop = false
		billboard.Parent      = part

		local lbl = Instance.new("TextLabel")
		lbl.Size                 = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text                 = "Ready Orders"
		lbl.TextColor3           = Color3.fromRGB(60, 60, 60)
		lbl.Font                 = Enum.Font.GothamBold
		lbl.TextScaled           = true
		lbl.Parent               = billboard
	end

	stagingTable = part
end

-- spawnStagedBox(box)
-- Places a labeled box Part on DressTable2 with a pickup ProximityPrompt.
local function spawnStagedBox(box)
	if not stagingTable or not stagingTable.Parent then return end

	local cookie = CookieData.GetById(box.cookieId)
	local label  = cookie and cookie.name or "Cookie Order"

	-- Offset each box so they don't stack (up to 4 across)
	local idx = 0
	for _ in pairs(stagedBoxes) do idx += 1 end
	local offsetX = (idx % 4) * 1.1 - 1.65

	local boxPart = Instance.new("Part")
	boxPart.Name          = "StagedBox_" .. box.boxId
	boxPart.Size          = Vector3.new(0.9, 0.5, 0.9)
	boxPart.CFrame        = stagingTable.CFrame * CFrame.new(offsetX, 0.4, 0)
	boxPart.Anchored      = true
	boxPart.CanCollide    = false
	boxPart.BrickColor    = BrickColor.new("Hot pink")
	boxPart.Material      = Enum.Material.SmoothPlastic
	boxPart.TopSurface    = Enum.SurfaceType.Smooth
	boxPart.BottomSurface = Enum.SurfaceType.Smooth
	boxPart.Parent        = workspace

	-- Label BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Size        = UDim2.new(0, 130, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 1.2, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent      = boxPart

	local bg = Instance.new("Frame")
	bg.Size                 = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3     = Color3.fromRGB(40, 40, 40)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel      = 0
	bg.Parent               = billboard

	local textLabel = Instance.new("TextLabel")
	textLabel.Size                 = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text                 = label
	textLabel.TextColor3           = Color3.new(1, 1, 1)
	textLabel.Font                 = Enum.Font.GothamBold
	textLabel.TextScaled           = true
	textLabel.Parent               = bg

	-- Pickup ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Pick Up"
	prompt.ObjectText            = label
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = boxPart

	stagedBoxes[box.boxId] = boxPart

	local capturedBoxId = box.boxId
	prompt.Triggered:Connect(function(player)
		local p = stagedBoxes[capturedBoxId]
		if not p then return end
		p:Destroy()
		stagedBoxes[capturedBoxId] = nil
		print(string.format("[StaffManager] %s picked up box #%d (%s)", player.Name, capturedBoxId, label))
	end)

	print(string.format("[StaffManager] Box #%d (%s) staged on Dress Table 2", box.boxId, label))
end

-- clearStagedBoxes()
-- Destroys all staged box Parts (called on EndOfDay).
local function clearStagedBoxes()
	for _, part in pairs(stagedBoxes) do
		if part and part.Parent then part:Destroy() end
	end
	stagedBoxes = {}
end

-- setWarmersEnabled(enabled)
-- Enables or disables all WarmerPrompts in Workspace.Warmers.
-- Called false during PreOpen (no customers), true when Open.
local function setWarmersEnabled(enabled)
	local warmersFolder = workspace:FindFirstChild("Warmers")
	if not warmersFolder then return end
	for _, warmer in ipairs(warmersFolder:GetChildren()) do
		-- Only toggle prompts on warmers that have an active cookie assignment
		local cookieId = warmer:GetAttribute("CookieId") or ""
		if cookieId ~= "" then
			-- WarmerPickupPrompt: used by players picking up for KDS orders (Open only)
			local wpp = warmer:FindFirstChild("WarmerPickupPrompt", true)
			if wpp then wpp.Enabled = enabled end
		end
		-- WarmerPrompt is never used by human players — always keep disabled
		local wp = warmer:FindFirstChild("WarmerPrompt", true)
		if wp then wp.Enabled = false end
	end
	print("[StaffManager] Warmer pickup prompts " .. (enabled and "enabled" or "disabled"))
end

-- ── TASK 2: STATIONS + runWorkerLoop ─────────────────────────────────────────

local POLL_INTERVAL = 2

-- Read spawn positions from Tutorial Spawns folder (same spots used for tutorial cinematics)
local function getTutorialSpawnCF(partName, fallback)
	local folder = workspace:FindFirstChild("Tutorial Spawns")
	local part   = folder and folder:FindFirstChild(partName)
	return part and part.CFrame or fallback
end

-- workerSpawnCF: raycasts to find exact floor height, then places HRP 3 studs above it
local function workerSpawnCF(name, fallback, lookDir)
	local base   = getTutorialSpawnCF(name, fallback)
	local origin = base.Position + Vector3.new(0, 10, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -20, 0))
	local floorY = result and result.Position.Y or base.Position.Y
	local pos    = Vector3.new(base.Position.X, floorY + 5, base.Position.Z)
	return CFrame.lookAt(pos, pos + lookDir)
end

local STATIONS = {
	mix = {
		label   = "Mixing",
		spawnCF = workerSpawnCF("TutorialMixerSpawn",     CFrame.new(18, 5, -17),  Vector3.new( 0, 0,-1)),
		work = function(proxy)
			-- Build list of active menu cookies from warmer CookieId attributes
			local warmersFolder = workspace:FindFirstChild("Warmers")
			local menuCookies = {}; local _seen = {}
			if warmersFolder then
				for _, model in ipairs(warmersFolder:GetChildren()) do
					local cId = model:GetAttribute("CookieId")
					if cId and cId ~= "" and not _seen[cId] then
						_seen[cId] = true; table.insert(menuCookies, cId)
					end
				end
			end
			if #menuCookies == 0 then return false end

			-- Balance by combined warmer + fridge stock so no one type piles up.
			-- Cookie with the lowest total gets priority; ties broken by menu order.
			local warmerCounts = OrderManager.GetWarmerCountsByType()
			local fridgeState  = OrderManager.GetFridgeState()
			local cookieId     = menuCookies[1]
			local lowestTotal  = math.huge
			for _, cId in ipairs(menuCookies) do
				local warmerStock = warmerCounts[cId] or 0
				local fridgeStock = fridgeState["fridge_" .. cId] or 0
				local total = warmerStock + fridgeStock
				if total < lowestTotal then
					lowestTotal = total
					cookieId    = cId
				end
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
		spawnCF = workerSpawnCF("TutorialDoughTableSpawn", CFrame.new(0, 5, -34),  Vector3.new(-1, 0, 0)),
		work = function(proxy)
			local batch = OrderManager.GetBatchAtStage("dough")
			if not batch then return false end
			task.wait(6)
			local ok = OrderManager.RecordStationScore(proxy, "dough", WORKER_QUALITY, batch.batchId)
			return ok == true
		end,
	},
	oven = {
		label   = "Baking",
		spawnCF = workerSpawnCF("TutorialOvenSpawn",       CFrame.new(-2, 8, -85),  Vector3.new( 1, 0,-1)),
		work = function(proxy)
			-- Pre-check: any fridge has stock before polling each one
			local fridgeState = OrderManager.GetFridgeState()
			local anyStock = false
			for _, count in pairs(fridgeState) do
				if count > 0 then anyStock = true; break end
			end
			if not anyStock then return false end

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
		spawnCF = workerSpawnCF("TutorialFrostTableSpawn", CFrame.new(20, 6, -36), Vector3.new(-1, 0, 0)),
		work = function(proxy)
			local forFrost = OrderManager.GetWarmerCount()
			if forFrost == 0 then return false end
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
		spawnCF = workerSpawnCF("TutorialDressTableSpawn", CFrame.new(-27, 5, -32), Vector3.new(-1, 0, 0)),
		work = function(_proxy)
			-- Dress packing is handled by human players via the KDS screen.
			-- AI dress worker is intentionally disabled to prevent it from consuming
			-- warmer entries that players are about to pick up for locked orders.
			return false
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
	local rig   = spawnWorkerRig(workerName, stationDef.spawnCF, player)

	workers[stationId] = { rig = rig, proxy = proxy, active = true }
	task.spawn(runWorkerLoop, stationId, rig, proxy)

	local promptEntry = hirePrompts[stationId]
	if promptEntry then
		promptEntry.prompt.ActionText = "Dismiss " .. workerName
		promptEntry.prompt.ObjectText = "AI Worker"
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

	local promptEntry = hirePrompts[stationId]
	local stationDef = STATIONS[stationId]
	if promptEntry and stationDef then
		promptEntry.prompt.ActionText = "Hire Baker (50🪙)"
		promptEntry.prompt.ObjectText = stationDef.label .. " Station"
	end
	print("[StaffManager] Dismissed worker at", stationId)
end

local function dismissAllWorkers()
	for stationId in pairs(STATIONS) do
		dismissWorker(stationId)
	end
	workerCount = 0
	clearStagedBoxes()
	print("[StaffManager] All workers dismissed")
end

-- ── TASK 4: HIRE PROMPTS + GAMESTATE WIRING ──────────────────────────────────

local function spawnHirePrompts()
	if next(hirePrompts) ~= nil then return end  -- guard against double-call
	for stationId, stationDef in pairs(STATIONS) do
		-- m-9: destroy any previous anchor from a prior call to prevent leaking Parts into workspace
		local existing = workspace:FindFirstChild("HireAnchor_" .. stationId)
		if existing then existing:Destroy() end
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

		local capturedId = stationId
		local conn = prompt.Triggered:Connect(function(player)
			local entry = workers[capturedId]
			if entry and entry.active then
				dismissWorker(capturedId)
			else
				hireWorker(player, capturedId)
			end
		end)
		hirePrompts[stationId] = { prompt = prompt, conn = conn }
	end
	print("[StaffManager] Hire prompts spawned for PreOpen")
end

local function destroyHirePrompts()
	for _, entry in pairs(hirePrompts) do
		entry.conn:Disconnect()
		local anchor = entry.prompt.Parent
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
		setWarmersEnabled(false)
	elseif state == "Open" then
		setWarmersEnabled(true)
	elseif state == "Intermission" then
		-- Players are in the back room — disable warmer access and pause AI workers
		dismissAllWorkers()
		setWarmersEnabled(false)
	elseif state == "EndOfDay" or state == "Lobby" then
		destroyHirePrompts()
		dismissAllWorkers()
		setWarmersEnabled(false)
	end
end)

-- Listen for boxes created by AI workers → stage them on Dress Table 2
OrderManager.On("BoxCreated", function(box)
	-- Skip boxes made by real players
	if Players:FindFirstChild(box.carrier) then return end
	spawnStagedBox(box)
end)

-- ── INIT ─────────────────────────────────────────────────────────────────────

createStagingTable()
setWarmersEnabled(false)  -- disabled until GameState == "Open"



print("[StaffManager] Loaded")
