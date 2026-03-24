-- BoxCarryServer.server.lua
-- Physical box carry: spawns CookieBox welded to HumanoidRootPart, raises arms
-- zombie-style. On delivery transfers to NPC. Box destroys when NPC leaves.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OrderManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local BOX_TEMPLATE    = "CookieBox"
local ATTACH_PART     = "HumanoidRootPart"
local HOLD_OFFSET     = CFrame.new(0, 0.2, -2.2)
local NPC_ARM         = "Right Arm"
local NPC_HOLD_OFFSET = CFrame.new(0, -0.5, -0.6)

-- R6 shoulder defaults + zombie pose (arms raised forward)
local RS_DEFAULT = CFrame.new(1,  0.5, 0) * CFrame.Angles(0,  math.pi/2, 0)
local LS_DEFAULT = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0)
local RS_ZOMBIE  = CFrame.new(1,  0.5, 0) * CFrame.Angles(0,  math.pi/2, 0) * CFrame.Angles(0, 0, -math.pi/2)
local LS_ZOMBIE  = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0) * CFrame.Angles(0, 0,  math.pi/2)

local carryModels = {}  -- [playerName] = model

-- BindableEvent so PersistentNPCSpawner can pass the actual NPC model on delivery
local transferEvent        = Instance.new("BindableEvent")
transferEvent.Name         = "BoxTransferToNPC"
transferEvent.Parent       = ServerScriptService

local function setArms(torso, rs, ls)
    if not torso then return end
    local rShoulder = torso:FindFirstChild("Right Shoulder")
    local lShoulder = torso:FindFirstChild("Left Shoulder")
    if rShoulder then rShoulder.C0 = rs end
    if lShoulder then lShoulder.C0 = ls end
end

local function weldAllParts(model, attachPart, offset)
    local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not primary then return end
    -- Weld every sub-part to PrimaryPart so logo + all pieces follow
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p ~= primary then
            p.Anchored = false
            local w   = Instance.new("WeldConstraint")
            w.Part0   = primary
            w.Part1   = p
            w.Parent  = primary
        end
    end
    primary.Anchored = false
    model.Parent = workspace
    model:SetPrimaryPartCFrame(attachPart.CFrame * offset)
    local w   = Instance.new("WeldConstraint")
    w.Part0   = attachPart
    w.Part1   = primary
    w.Parent  = primary
end

local function spawnCarryModel(playerName, character)
    local template = ReplicatedStorage:FindFirstChild(BOX_TEMPLATE)
    if not template then warn("[BoxCarry] CookieBox not in ReplicatedStorage"); return end
    local hrp   = character:FindFirstChild(ATTACH_PART)
    local torso = character:FindFirstChild("Torso")
    if not hrp then return end

    local existing = carryModels[playerName]
    if existing and existing.Parent then existing:Destroy() end

    local model  = template:Clone()
    model.Name   = "CarriedBox_" .. playerName
    weldAllParts(model, hrp, HOLD_OFFSET)
    carryModels[playerName] = model

    -- Raise player arms (zombie carry pose)
    setArms(torso, RS_ZOMBIE, LS_ZOMBIE)
end

local function dropCarryModel(playerName, character)
    local m = carryModels[playerName]
    if m and m.Parent then m:Destroy() end
    carryModels[playerName] = nil
    -- Restore arms
    if character then
        setArms(character:FindFirstChild("Torso"), RS_DEFAULT, LS_DEFAULT)
    end
end

local function transferToNPC(playerName, npcModel)
    local model     = carryModels[playerName]
    local character = (Players:FindFirstChild(playerName) or {}).Character
    carryModels[playerName] = nil

    -- Restore player arms immediately
    if character then
        setArms(character:FindFirstChild("Torso"), RS_DEFAULT, LS_DEFAULT)
    end

    if not model or not model.Parent then return end
    if not npcModel then
        model:Destroy(); return
    end

    local npcArm   = npcModel:FindFirstChild(NPC_ARM) or npcModel:FindFirstChild("RightHand")
    local npcTorso = npcModel:FindFirstChild("Torso")
    local primary  = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")

    if npcArm and primary then
        -- Remove character weld (the outer one connecting HRP → primary)
        for _, w in ipairs(primary:GetChildren()) do
            if w:IsA("WeldConstraint") and w.Part0 ~= primary then w:Destroy() end
        end
        model:SetPrimaryPartCFrame(npcArm.CFrame * NPC_HOLD_OFFSET)
        local weld  = Instance.new("WeldConstraint")
        weld.Part0  = npcArm
        weld.Part1  = primary
        weld.Parent = primary
    end

    -- Raise NPC arms
    setArms(npcTorso, RS_ZOMBIE, LS_ZOMBIE)

    -- Destroy box when the NPC model leaves workspace (not on a timer)
    npcModel.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            if model and model.Parent then model:Destroy() end
        end
    end)
end

-- ── Listeners ─────────────────────────────────────────────────────────────────

OrderManager.On("BoxCreated", function(box)
    if not box or not box.carrier then return end
    local player = Players:FindFirstChild(box.carrier)
    if not player or not player.Character then return end
    spawnCarryModel(box.carrier, player.Character)
end)

-- Fired by PersistentNPCSpawner after successful delivery with (playerName, npcModel)
transferEvent.Event:Connect(function(playerName, npcModel)
    transferToNPC(playerName, npcModel)
end)

-- NPC leaves without delivery (ForceDropBox path) — workspace cleanup already
-- handled in PersistentNPCSpawner, but also restore player arms here
OrderManager.On("BoxDelivered", function() end)  -- handled via transferEvent above

Players.PlayerRemoving:Connect(function(player)
    dropCarryModel(player.Name, player.Character)
end)

print("[BoxCarryServer] Ready.")
