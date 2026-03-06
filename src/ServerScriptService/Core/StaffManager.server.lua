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
-- Applies baker shirt + pants via HumanoidDescription.
-- Wrapped in pcall — fails silently if rig lacks a full character setup.
local function applyBakerUniform(rig)
	local ok, err = pcall(function()
		local hum = rig:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		local desc = Instance.new("HumanoidDescription")
		desc.Shirt = SHIRT_ASSET_ID
		desc.Pants = PANTS_ASSET_ID
		hum:ApplyDescription(desc)
	end)

	if not ok then
		warn("[StaffManager] applyBakerUniform failed:", err)
	end
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

-- ── INIT ─────────────────────────────────────────────────────────────────────

print("[StaffManager] Loaded")
