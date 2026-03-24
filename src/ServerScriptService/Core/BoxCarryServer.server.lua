-- BoxCarryServer.server.lua
-- Spawns a physical CookieBox model welded to the carrier's Right Arm when a box
-- is created. On delivery, transfers it to the NPC's arm for 1.5s then destroys.
-- On ForceDropBox (NPC leaves), destroys immediately via workspace name lookup.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local BOX_TEMPLATE  = "CookieBox"   -- Model name in ReplicatedStorage
local HAND_PART     = "Right Arm"   -- R6 rig
local HOLD_OFFSET   = CFrame.new(0, -0.8, -0.6)  -- relative to hand part

-- carryModels[playerName] = Model in Workspace
local carryModels = {}

local function getTemplate()
    return ReplicatedStorage:FindFirstChild(BOX_TEMPLATE)
end

local function getHand(character)
    return character and character:FindFirstChild(HAND_PART)
end

local function spawnCarryModel(playerName, hand)
    local template = getTemplate()
    if not template then
        warn("[BoxCarry] No CookieBox template found in ReplicatedStorage")
        return
    end

    local model = template:Clone()
    local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not primary then
        model:Destroy()
        warn("[BoxCarry] CookieBox has no PrimaryPart")
        return
    end

    model.Name = "CarriedBox_" .. playerName

    -- Unanchor all parts so the weld can move them with the character
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then p.Anchored = false end
    end

    model.Parent = workspace
    model:SetPrimaryPartCFrame(hand.CFrame * HOLD_OFFSET)

    local weld   = Instance.new("WeldConstraint")
    weld.Part0   = hand
    weld.Part1   = primary
    weld.Parent  = primary

    carryModels[playerName] = model
end

local function destroyCarryModel(playerName)
    local m = carryModels[playerName]
    if m and m.Parent then m:Destroy() end
    carryModels[playerName] = nil
end

local function transferToNPC(playerName, npcModel)
    local model = carryModels[playerName]
    carryModels[playerName] = nil

    if not model or not model.Parent then return end

    local npcArm = npcModel
        and (npcModel:FindFirstChild(HAND_PART) or npcModel:FindFirstChild("RightHand"))

    if npcArm then
        local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if primary then
            -- Remove old weld
            for _, w in ipairs(primary:GetChildren()) do
                if w:IsA("WeldConstraint") then w:Destroy() end
            end
            model:SetPrimaryPartCFrame(npcArm.CFrame * HOLD_OFFSET)
            local weld  = Instance.new("WeldConstraint")
            weld.Part0  = npcArm
            weld.Part1  = primary
            weld.Parent = primary
        end
    end

    task.delay(1.5, function()
        if model and model.Parent then model:Destroy() end
    end)
end

-- ── Box created → attach to player's hand ────────────────────────────────────
OrderManager.On("BoxCreated", function(box)
    if not box or not box.carrier then return end
    local player = Players:FindFirstChild(box.carrier)
    if not player then return end
    local char = player.Character
    local hand = getHand(char)
    if not hand then return end
    spawnCarryModel(box.carrier, hand)
end)

-- ── Box delivered → transfer to NPC then destroy ─────────────────────────────
OrderManager.On("BoxDelivered", function(payload)
    if not payload then return end
    local box      = payload.box
    local npcOrder = payload.npcOrder
    if not box or not box.carrier then return end

    -- Try to find the NPC model for the transfer visual
    local npcModel = nil
    if npcOrder then
        -- NPC model is in workspace; find by npcOrder.npcName or search for it
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj:FindFirstChild("Head") then
                local nameTag = obj:FindFirstChild("NameTag", true)
                if nameTag and nameTag.Text == npcOrder.npcName then
                    npcModel = obj; break
                end
            end
        end
    end

    transferToNPC(box.carrier, npcModel)
end)

-- ── Player leaves → clean up ─────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    destroyCarryModel(player.Name)
end)

print("[BoxCarryServer] Ready.")
