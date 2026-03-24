-- BoxCarryServer.server.lua
-- Spawns CookieBox model on carry. Fires CarryPoseUpdate/NPCCarryPoseUpdate so
-- clients enforce the arm pose via RenderStepped. Box destroys when NPC leaves.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager  = require(ServerScriptService:WaitForChild("Core"):WaitForChild("OrderManager"))

local carryPoseRemote    = RemoteManager.Get("CarryPoseUpdate")
local npcPoseRemote      = RemoteManager.Get("NPCCarryPoseUpdate")

local BOX_TEMPLATE    = "CookieBox"
local ATTACH_PART     = "HumanoidRootPart"
local HOLD_OFFSET     = CFrame.new(0, 0.2, -2.2)
local NPC_ARM         = "Right Arm"
local NPC_HOLD_OFFSET = CFrame.new(0, -0.5, -0.6)

local carryModels = {}

-- BindableEvent for PersistentNPCSpawner to pass the actual npcModel ref on delivery
local transferEvent        = Instance.new("BindableEvent")
transferEvent.Name         = "BoxTransferToNPC"
transferEvent.Parent       = ServerScriptService

local function weldAllParts(model, attachPart, offset)
    local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not primary then return end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p ~= primary then
            p.Anchored = false
            local w = Instance.new("WeldConstraint")
            w.Part0 = primary; w.Part1 = p; w.Parent = primary
        end
    end
    primary.Anchored = false
    model.Parent = workspace
    model:SetPrimaryPartCFrame(attachPart.CFrame * offset)
    local w = Instance.new("WeldConstraint")
    w.Part0 = attachPart; w.Part1 = primary; w.Parent = primary
end

local function spawnCarryModel(playerName, character)
    local template = ReplicatedStorage:FindFirstChild(BOX_TEMPLATE)
    if not template then warn("[BoxCarry] CookieBox not in ReplicatedStorage"); return end
    local hrp = character:FindFirstChild(ATTACH_PART)
    if not hrp then return end
    local existing = carryModels[playerName]
    if existing and existing.Parent then existing:Destroy() end
    local model = template:Clone()
    model.Name  = "CarriedBox_" .. playerName
    weldAllParts(model, hrp, HOLD_OFFSET)
    carryModels[playerName] = model
    -- Tell client to start arm pose loop
    local player = Players:FindFirstChild(playerName)
    if player then carryPoseRemote:FireClient(player, true) end
end

local function dropCarryModel(playerName, character)
    local m = carryModels[playerName]
    if m and m.Parent then m:Destroy() end
    carryModels[playerName] = nil
    local player = Players:FindFirstChild(playerName)
    if player then carryPoseRemote:FireClient(player, false) end
end

local function transferToNPC(playerName, npcModel)
    local model   = carryModels[playerName]
    carryModels[playerName] = nil
    -- Restore player arms
    local player = Players:FindFirstChild(playerName)
    if player then carryPoseRemote:FireClient(player, false) end
    if not model or not model.Parent then return end
    if not npcModel then model:Destroy(); return end

    local npcArm  = npcModel:FindFirstChild(NPC_ARM) or npcModel:FindFirstChild("RightHand")
    local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")

    if npcArm and primary then
        for _, w in ipairs(primary:GetChildren()) do
            if w:IsA("WeldConstraint") and w.Part0 ~= primary then w:Destroy() end
        end
        model:SetPrimaryPartCFrame(npcArm.CFrame * NPC_HOLD_OFFSET)
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = npcArm; weld.Part1 = primary; weld.Parent = primary
    end

    -- Tell all clients to raise NPC arms
    npcPoseRemote:FireAllClients(npcModel, true)

    -- Box destroys when NPC model leaves workspace
    npcModel.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            if model and model.Parent then model:Destroy() end
            npcPoseRemote:FireAllClients(npcModel, false)
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

transferEvent.Event:Connect(function(playerName, npcModel)
    transferToNPC(playerName, npcModel)
end)

Players.PlayerRemoving:Connect(function(player)
    dropCarryModel(player.Name, player.Character)
end)

print("[BoxCarryServer] Ready.")
