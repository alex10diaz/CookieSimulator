-- src/ServerScriptService/Core/TestNPCSpawner.server.lua
-- TEMPORARY TEST SCRIPT — remove before shipping.
-- Spawns 1 static NPC at the POS counter so you can test the order cutscene flow
-- without needing the full NPC lifecycle system running.
--
-- Controls:
--   Press E on the NPC to trigger the cutscene modal.
--   Dismiss the modal (X / Escape / 5s) to confirm the order.
--   The NPC prompt re-enables after 2s so you can test again.
--
-- Change TEST_IS_VIP = true to test the gold VIP earnings card.
-- Does NOT interfere with PersistentNPCSpawner (uses npcId 9999 which that
-- script ignores).  You may see a harmless warning in output: that's expected.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local RemoteManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startCutsceneRemote = RemoteManager.Get("StartOrderCutscene")
local confirmRemote       = RemoteManager.Get("ConfirmNPCOrder")

-- ─── CONFIG ───────────────────────────────────────────────────────────────────
local TEST_NPC_ID   = 9999          -- must not match any real NPC id
local TEST_NPC_NAME = "Test Customer"
local TEST_COOKIE   = { id = "chocolate_chip", name = "Chocolate Chip" }
local TEST_PACK     = 4
local TEST_PRICE    = 60            -- baseCoins shown in the earnings card
local TEST_IS_VIP   = false         -- set true to test gold VIP card

-- Spawn position: 3 units in front of the POS tablet (adjust in Studio if needed)
local SPAWN_CF = CFrame.new(-0.25, 3, -4)  -- QueueSpot1, in front of the POS Tablet

-- ─── BUILD NPC ────────────────────────────────────────────────────────────────
local npc

-- Try to clone the NPCTemplate from ServerStorage first
local template = ServerStorage:FindFirstChild("NPCTemplate")
if template then
    npc = template:Clone()
    npc.Name = "TestNPC"
    if npc.PrimaryPart then
        npc:SetPrimaryPartCFrame(SPAWN_CF)
    end
else
    -- Fallback: minimal block humanoid
    npc = Instance.new("Model")
    npc.Name = "TestNPC"

    local hrp = Instance.new("Part")
    hrp.Name             = "HumanoidRootPart"
    hrp.Size             = Vector3.new(2, 2, 1)
    hrp.Anchored         = true
    hrp.BrickColor       = BrickColor.new("Bright blue")
    hrp.CFrame           = SPAWN_CF
    hrp.Parent           = npc

    local head = Instance.new("Part")
    head.Name    = "Head"
    head.Size    = Vector3.new(2, 1, 1)
    head.Anchored = true
    head.BrickColor = BrickColor.new("Bright yellow")
    head.CFrame  = SPAWN_CF * CFrame.new(0, 1.5, 0)
    head.Parent  = npc

    local hum = Instance.new("Humanoid")
    hum.Parent = npc

    npc.PrimaryPart = hrp
end

-- Billboard name tag
local bb = Instance.new("BillboardGui")
bb.Name          = "NameTag"
bb.Size          = UDim2.new(0, 120, 0, 30)
bb.StudsOffset   = Vector3.new(0, 3, 0)
bb.AlwaysOnTop   = true
bb.Parent        = npc.PrimaryPart

local nameLabel = Instance.new("TextLabel")
nameLabel.Size              = UDim2.new(1, 0, 1, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.TextColor3        = Color3.fromRGB(255, 255, 255)
nameLabel.TextScaled        = true
nameLabel.Font              = Enum.Font.GothamBold
nameLabel.Text              = TEST_NPC_NAME .. (TEST_IS_VIP and " ⭐" or "")
nameLabel.Parent            = bb

-- Proximity prompt
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText              = "Take Order"
prompt.ObjectText              = TEST_NPC_NAME
prompt.KeyboardKeyCode         = Enum.KeyCode.E
prompt.MaxActivationDistance   = 10
prompt.Parent                  = npc.PrimaryPart

npc.Parent = workspace

-- ─── CUTSCENE TRIGGER ────────────────────────────────────────────────────────
prompt.Triggered:Connect(function(player)
    prompt.Enabled = false  -- prevent double-trigger while modal is open

    startCutsceneRemote:FireClient(player, {
        npcId      = TEST_NPC_ID,
        npcName    = TEST_NPC_NAME,
        cookieId   = TEST_COOKIE.id,
        cookieName = TEST_COOKIE.name,
        packSize   = TEST_PACK,
        baseCoins  = TEST_PRICE,
        isVIP      = TEST_IS_VIP,
    })
end)

-- ─── CONFIRM HANDLER ─────────────────────────────────────────────────────────
-- PersistentNPCSpawner will also receive this event but will silently skip
-- npcId 9999 (not in its npcs table).
confirmRemote.OnServerEvent:Connect(function(player, npcId)
    if npcId ~= TEST_NPC_ID then return end

    print(string.format("[TestNPC] Order confirmed by %s — cookie: %s x%d (%d coins%s)",
        player.Name, TEST_COOKIE.name, TEST_PACK, TEST_PRICE,
        TEST_IS_VIP and ", VIP" or ""))

    -- Re-enable prompt after a short delay so you can test again
    task.delay(2, function()
        if prompt and prompt.Parent then
            prompt.Enabled = true
        end
    end)
end)

print("[TestNPCSpawner] Test NPC spawned at", tostring(SPAWN_CF.Position),
    "— press E to trigger cutscene.")
