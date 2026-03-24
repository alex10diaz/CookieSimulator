-- BoxCarryServer.server.lua
-- Spawns a physical CookieBox model welded to the carrier's HumanoidRootPart.
-- NPC transfer is triggered by BindableEvent from PersistentNPCSpawner.
-- ForceDropBox cleans up via workspace name lookup.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OrderManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local BOX_TEMPLATE  = "CookieBox"            -- Model in ReplicatedStorage
local ATTACH_PART   = "HumanoidRootPart"     -- Weld anchor on character
local HOLD_OFFSET   = CFrame.new(0, 0.2, -2.2)  -- In front of character at waist
local NPC_ARM       = "Right Arm"            -- NPC arm to transfer to (R6)
local NPC_HOLD_OFFSET = CFrame.new(0, -0.5, -0.6)

-- carryModels[playerName] = Model
local carryModels = {}

-- BindableEvent so PersistentNPCSpawner can trigger NPC transfer with the model ref
local transferEvent = Instance.new("BindableEvent")
transferEvent.Name  = "BoxTransferToNPC"
transferEvent.Parent = ServerScriptService

local function weldModelToPart(model, attachPart, offset)
    local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not primary then return end

    -- Internally weld every sub-part to PrimaryPart (keeps logo + all parts together)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p ~= primary then
            p.Anchored = false
            local iw = Instance.new("WeldConstraint")
            iw.Part0  = primary
            iw.Part1  = p
            iw.Parent = primary
        end
    end
    primary.Anchored = false

    model.Parent = workspace
    model:SetPrimaryPartCFrame(attachPart.CFrame * offset)

    local weld   = Instance.new("WeldConstraint")
    weld.Part0   = attachPart
    weld.Part1   = primary
    weld.Parent  = primary
end

local function spawnCarryModel(playerName, character)
    local template = ReplicatedStorage:FindFirstChild(BOX_TEMPLATE)
    if not template then
        warn("[BoxCarry] CookieBox not found in ReplicatedStorage")
        return
    end
    local hrp = character and character:FindFirstChild(ATTACH_PART)
    if not hrp then return end

    -- Remove any existing carry model for this player
    local existing = carryModels[playerName]
    if existing and existing.Parent then existing:Destroy() end

    local model  = template:Clone()
    model.Name   = "CarriedBox_" .. playerName

    weldModelToPart(model, hrp, HOLD_OFFSET)
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

    local npcArm = npcModel and (
        npcModel:FindFirstChild(NPC_ARM) or npcModel:FindFirstChild("RightHand")
    )

    if npcArm then
        local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if primary then
            -- Remove character weld
            for _, w in ipairs(primary:GetChildren()) do
                if w:IsA("WeldConstraint") and w.Part0 ~= primary then
                    w:Destroy()
                end
            end
            model:SetPrimaryPartCFrame(npcArm.CFrame * NPC_HOLD_OFFSET)
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

-- ── Listeners ─────────────────────────────────────────────────────────────────

OrderManager.On("BoxCreated", function(box)
    if not box or not box.carrier then return end
    local player = Players:FindFirstChild(box.carrier)
    if not player then return end
    spawnCarryModel(box.carrier, player.Character)
end)

-- PersistentNPCSpawner fires this after successful delivery with (playerName, npcModel)
transferEvent.Event:Connect(function(playerName, npcModel)
    transferToNPC(playerName, npcModel)
end)

Players.PlayerRemoving:Connect(function(player)
    destroyCarryModel(player.Name)
end)

print("[BoxCarryServer] Ready.")
