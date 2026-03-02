-- src/ServerScriptService/Core/TestNPCSpawner.server.lua
-- TEMPORARY TEST SCRIPT — remove before shipping.
-- Spawns 1 static NPC at the POS counter so you can test the order cutscene flow
-- without needing the full NPC lifecycle system running.
--
-- Controls:
--   Press E on the NPC to trigger the cutscene modal.
--   Dismiss the modal (X / Escape / 5s) to confirm the order.
--   Bake the requested cookie, pack it into a box, then press E on the NPC again to deliver.
--   The NPC prompt re-enables after delivery so you can test again.
--
-- Change TEST_IS_VIP = true to test the gold VIP earnings card.
-- Does NOT interfere with PersistentNPCSpawner (uses npcId 9999 which that
-- script ignores).  You may see a harmless warning in output: that's expected.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager       = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local EconomyManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EconomyManager"))
local PlayerDataManager   = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local startCutsceneRemote = RemoteManager.Get("StartOrderCutscene")
local confirmRemote       = RemoteManager.Get("ConfirmNPCOrder")
local deliveryResult      = RemoteManager.Get("DeliveryResult")
local hudUpdate           = RemoteManager.Get("HUDUpdate")

-- ─── CONFIG ───────────────────────────────────────────────────────────────────
local TEST_NPC_ID   = 9999          -- must not match any real NPC id
local TEST_NPC_NAME = "Test Customer"
local TEST_COOKIE   = { id = "chocolate_chip", name = "Chocolate Chip" }
local TEST_PACK     = 4
local TEST_PRICE    = 60            -- baseCoins shown in the earnings card
local TEST_IS_VIP   = true          -- set true to test gold VIP card

local SPAWN_CF = CFrame.new(-0.25, 3, -4)  -- QueueSpot1

-- ─── LOCAL STATE ──────────────────────────────────────────────────────────────
local pendingOrder  = nil   -- OrderManager NPC order record after confirm
local pendingBox    = nil   -- { boxId, carrier } once a matching box is created
local deliverPrompt = nil   -- ProximityPrompt added to head when box is ready

-- ─── BUILD NPC ────────────────────────────────────────────────────────────────
local npc = Instance.new("Model")
npc.Name = "TestNPC"

local hrp = Instance.new("Part")
hrp.Name       = "HumanoidRootPart"
hrp.Size       = Vector3.new(2, 2, 1)
hrp.Anchored   = true
hrp.BrickColor = BrickColor.new("Bright blue")
hrp.CFrame     = SPAWN_CF
hrp.Parent     = npc

local head = Instance.new("Part")
head.Name      = "Head"
head.Size      = Vector3.new(2, 1, 1)
head.Anchored  = true
head.BrickColor = BrickColor.new("Bright yellow")
head.CFrame    = SPAWN_CF * CFrame.new(0, 1.5, 0)
head.Parent    = npc

Instance.new("Humanoid").Parent = npc
npc.PrimaryPart = hrp

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
prompt.RequiresLineOfSight     = false
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

    -- Register the order so BoxCreated can match it
    pendingOrder = OrderManager.AddNPCOrder(TEST_NPC_NAME, TEST_COOKIE.id, {
        packSize = TEST_PACK,
        price    = TEST_PRICE,
        isVIP    = TEST_IS_VIP,
        npcId    = TEST_NPC_ID,
    })

    print("[TestNPC] Waiting for a", TEST_COOKIE.name, "box to be created...")
end)

-- ─── BOX READY → ADD DELIVER PROMPT ──────────────────────────────────────────
OrderManager.On("BoxCreated", function(box)
    if not box.cookieId or box.cookieId ~= TEST_COOKIE.id then return end
    if not pendingOrder then return end
    if pendingBox then return end  -- already waiting for delivery

    pendingBox = { boxId = box.boxId, carrier = box.carrier }

    -- Add a DeliverPrompt to the TestNPC's head
    local npcHead = npc:FindFirstChild("Head")
    if not npcHead then return end

    if deliverPrompt then deliverPrompt:Destroy() end
    deliverPrompt = Instance.new("ProximityPrompt")
    deliverPrompt.Name                  = "DeliverPrompt"
    deliverPrompt.ActionText            = "Deliver Box"
    deliverPrompt.ObjectText            = TEST_NPC_NAME
    deliverPrompt.MaxActivationDistance = 10
    deliverPrompt.HoldDuration          = 0
    deliverPrompt.Parent                = npcHead

    deliverPrompt.Triggered:Connect(function(player)
        if not pendingBox then return end

        if pendingBox.carrier ~= player.Name then
            warn("[TestNPC] Wrong carrier:", player.Name, "expected", pendingBox.carrier)
            return
        end

        local ok, quality = OrderManager.DeliverBox(player, pendingBox.boxId, pendingOrder.orderId)
        if not ok then return end

        -- Clear state
        pendingBox    = nil
        pendingOrder  = nil
        if deliverPrompt then
            deliverPrompt:Destroy()
            deliverPrompt = nil
        end

        -- Stars from quality (0-100 → 1-5)
        local stars = math.clamp(math.floor(1 + (quality / 100) * 4), 1, 5)

        -- Combo tracking
        local comboStreak
        if stars >= 3 then
            comboStreak = PlayerDataManager.IncrementCombo(player)
        else
            PlayerDataManager.ResetCombo(player)
            comboStreak = 0
        end

        -- Full economy payout
        local payout = EconomyManager.CalculatePayout(
            TEST_COOKIE.id, TEST_PACK, stars,
            0, 1, comboStreak, TEST_IS_VIP
        )

        PlayerDataManager.RecordOrderComplete(player, stars == 5)
        PlayerDataManager.AddCoins(player, payout.coins)
        PlayerDataManager.AddXP(player, payout.xp)

        local profile = PlayerDataManager.GetData(player)
        deliveryResult:FireClient(player, stars, payout.coins, payout.xp)
        hudUpdate:FireClient(player,
            profile and profile.coins or 0,
            profile and profile.xp    or 0,
            nil)

        print(string.format("[TestNPC] Delivery complete | q=%d%% stars=%d coins=%d xp=%d",
            quality, stars, payout.coins, payout.xp))

        -- Re-enable the order prompt so you can test again
        task.delay(2, function()
            if prompt and prompt.Parent then
                prompt.Enabled = true
            end
        end)
    end)

    print(string.format("[TestNPC] Box #%d ready — walk to %s and press E to deliver",
        box.boxId, TEST_NPC_NAME))
end)

print("[TestNPCSpawner] Test NPC spawned at", tostring(SPAWN_CF.Position),
    "— press E to trigger cutscene.")
