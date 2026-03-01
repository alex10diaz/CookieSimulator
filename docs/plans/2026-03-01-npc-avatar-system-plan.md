# NPC Friend Avatar System — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the block NPCTemplate with a pool of 10 real R6 Roblox avatars built from the first player's friends list (falling back to public user IDs), so NPCs look like actual Roblox characters when they walk into the bakery.

**Architecture:** A new `NPCAvatarLoader.server.lua` script fires once when the first player joins, builds 10 avatar models using `Humanoid:ApplyDescription()`, and stores them in `ServerStorage/NPCAvatars/`. NPCSpawner.CreateNPC is updated to pick randomly from that pool; if the pool isn't ready yet it falls back to the existing NPCTemplate (zero regression). A new `R6AvatarTemplate` in ServerStorage provides the base R6 rig structure.

**Tech Stack:** Roblox Lua (server-side), Roblox Players API (`GetFriendsAsync`, `CreateHumanoidDescriptionFromUserId`, `ApplyDescription`), MCP `run_code` for Studio object creation, Rojo file sync for Lua scripts.

---

## Notes for Roblox workflow

- **No unit test framework exists.** Validation is via Studio play-test + Output window prints.
- **MCP `run_code`** creates/modifies Studio objects directly (models, parts, etc.).
- **Rojo is STOPPED.** Write Lua files with the Write tool; apply script bodies in Studio with MCP `run_code` separately if needed. But since Rojo is stopped, writing to `src/` AND updating Studio via MCP are both required.
- All MCP `run_code` calls run in Studio's edit mode command bar context.

---

### Task 1: Create R6AvatarTemplate in Studio

**Files:**
- Studio object only (no src/ file)

**Step 1: Create the R6AvatarTemplate model in ServerStorage via MCP**

```lua
-- MCP run_code
local SS = game:GetService("ServerStorage")

-- Remove old template if exists
local old = SS:FindFirstChild("R6AvatarTemplate")
if old then old:Destroy() end

local model = Instance.new("Model")
model.Name  = "R6AvatarTemplate"

-- ── Parts ──────────────────────────────────────────────────────────────────
local function makePart(name, size, color)
    local p         = Instance.new("Part")
    p.Name          = name
    p.Size          = size
    p.BrickColor    = BrickColor.new(color or "Medium stone grey")
    p.CanCollide    = false
    p.Anchored      = false
    p.Parent        = model
    return p
end

local hrp  = makePart("HumanoidRootPart", Vector3.new(2, 2, 1),  "Medium stone grey")
local tor  = makePart("Torso",            Vector3.new(2, 2, 1),  "Medium stone grey")
local head = makePart("Head",             Vector3.new(1, 1, 1),  "Medium stone grey")
local lArm = makePart("Left Arm",         Vector3.new(1, 2, 1),  "Medium stone grey")
local rArm = makePart("Right Arm",        Vector3.new(1, 2, 1),  "Medium stone grey")
local lLeg = makePart("Left Leg",         Vector3.new(1, 2, 1),  "Medium stone grey")
local rLeg = makePart("Right Leg",        Vector3.new(1, 2, 1),  "Medium stone grey")

hrp.Transparency = 1  -- HRP is invisible
model.PrimaryPart = hrp

-- ── Humanoid ───────────────────────────────────────────────────────────────
local hum    = Instance.new("Humanoid")
hum.RigType  = Enum.HumanoidRigType.R6
hum.Parent   = model

-- ── Motor6D joints ─────────────────────────────────────────────────────────
local function makeJoint(name, parent, p0, p1, c0, c1)
    local j   = Instance.new("Motor6D")
    j.Name    = name
    j.Part0   = p0
    j.Part1   = p1
    j.C0      = c0
    j.C1      = c1
    j.Parent  = parent
    return j
end

makeJoint("RootJoint",
    hrp, hrp, tor,
    CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi/2, 0, math.pi),
    CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi/2, 0, math.pi))

makeJoint("Neck",
    tor, tor, head,
    CFrame.new(0,  1,    0),
    CFrame.new(0, -0.5,  0))

makeJoint("Left Shoulder",
    tor, tor, lArm,
    CFrame.new(-1,  0.5, 0),
    CFrame.new( 0.5, 0.5, 0))

makeJoint("Right Shoulder",
    tor, tor, rArm,
    CFrame.new( 1,  0.5, 0),
    CFrame.new(-0.5, 0.5, 0))

makeJoint("Left Hip",
    tor, tor, lLeg,
    CFrame.new(-1, -1, 0),
    CFrame.new(-0.5, 1, 0))

makeJoint("Right Hip",
    tor, tor, rLeg,
    CFrame.new( 1, -1, 0),
    CFrame.new( 0.5, 1, 0))

model.Parent = SS
print("R6AvatarTemplate created:", model:GetFullName())
print("Parts:", #model:GetChildren(), "children")
```

**Step 2: Verify in Output**

Expected: `R6AvatarTemplate created: ServerStorage.R6AvatarTemplate`
Also verify 8 children: Humanoid + 7 parts.

**Step 3: Copy PatienceGui and OrderPrompt structure check**

Run this to confirm NPCTemplate still has the donor parts:

```lua
local SS = game:GetService("ServerStorage")
local tmpl = SS:FindFirstChild("NPCTemplate")
if tmpl then
    local head = tmpl:FindFirstChild("Head")
    print("PatienceGui:", head:FindFirstChild("PatienceGui") ~= nil)
    print("OrderPrompt:", head:FindFirstChild("OrderPrompt") ~= nil)
    print("FaceGui:",     head:FindFirstChild("FaceGui") ~= nil)
end
```

Expected: all three `true`.

**Step 4: Save Studio file**

Press **Ctrl+S** in Studio to persist R6AvatarTemplate.

---

### Task 2: Write NPCAvatarLoader.server.lua

**Files:**
- Create: `src/ServerScriptService/Core/NPCAvatarLoader.server.lua`

**Step 1: Write the file**

```lua
-- NPCAvatarLoader
-- Builds a pool of 10 R6 NPC avatars from the first player's friends list.
-- Falls back to hardcoded public user IDs to fill any remaining slots.
-- Stores models in ServerStorage/NPCAvatars/.
-- Sets Workspace attribute "NPCAvatarsReady" = true when done.

local Players       = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace     = game:GetService("Workspace")

-- ─── FALLBACK USER IDs ────────────────────────────────────────────────────
-- Used when the first player has fewer than 10 friends.
local FALLBACK_USER_IDS = {
    156,       -- Builderman
    261,       -- ROBLOX
    55492028,  -- EthanGamer
    10792782,  -- Kreekcraft
    1281024,   -- Loleris
    4270282,   -- Dued1
    698870,    -- Stickmasterluke
    90252,     -- theGrefg
    19708579,  -- Coeptus
    2409626,   -- OofQueen
}

local POOL_SIZE = 10

-- ─── HELPERS ──────────────────────────────────────────────────────────────
local function cloneHeadAccessories(srcHead, dstHead)
    -- Copy PatienceGui, OrderPrompt, FaceGui from NPCTemplate head to avatar head
    local names = { "PatienceGui", "OrderPrompt", "FaceGui" }
    for _, name in ipairs(names) do
        local obj = srcHead:FindFirstChild(name)
        if obj then
            local clone = obj:Clone()
            clone.Parent = dstHead
        end
    end
end

local function buildAvatarFromDescription(slot, userId, tmplHead, avatarFolder)
    -- Get HumanoidDescription
    local ok, desc = pcall(function()
        return Players:CreateHumanoidDescriptionFromUserId(userId)
    end)
    if not ok or not desc then
        warn(string.format("[NPCAvatarLoader] Failed to get description for userId %d: %s", userId, tostring(desc)))
        return false
    end

    -- Clone R6AvatarTemplate
    local template = ServerStorage:FindFirstChild("R6AvatarTemplate")
    if not template then
        warn("[NPCAvatarLoader] R6AvatarTemplate not found in ServerStorage")
        return false
    end

    local avatar = template:Clone()
    avatar.Name  = "NPCAvatar_" .. slot

    -- Apply description (face, colors, clothing, accessories)
    local humanoid = avatar:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local applyOk, applyErr = pcall(function()
            humanoid:ApplyDescription(desc)
        end)
        if not applyOk then
            warn(string.format("[NPCAvatarLoader] ApplyDescription failed for slot %d: %s", slot, tostring(applyErr)))
            -- Still usable as a plain grey R6 — don't abort
        end
    end

    -- Copy PatienceGui + OrderPrompt + FaceGui from NPCTemplate head
    local avatarHead = avatar:FindFirstChild("Head")
    if avatarHead and tmplHead then
        cloneHeadAccessories(tmplHead, avatarHead)
    end

    avatar.Parent = avatarFolder
    print(string.format("[NPCAvatarLoader] Slot %d built (userId=%d)", slot, userId))
    return true
end

-- ─── MAIN BUILD ───────────────────────────────────────────────────────────
local function buildAvatarPool(firstPlayer)
    print("[NPCAvatarLoader] Building avatar pool for", firstPlayer.Name)

    -- Create (or clear) the NPCAvatars folder
    local existing = ServerStorage:FindFirstChild("NPCAvatars")
    if existing then existing:Destroy() end
    local avatarFolder   = Instance.new("Folder")
    avatarFolder.Name    = "NPCAvatars"
    avatarFolder.Parent  = ServerStorage

    -- Get NPCTemplate head for copying accessories
    local tmpl     = ServerStorage:FindFirstChild("NPCTemplate")
    local tmplHead = tmpl and tmpl:FindFirstChild("Head") or nil

    -- Collect friend IDs
    local friendIds = {}
    local ok, pages = pcall(function()
        return Players:GetFriendsAsync(firstPlayer.UserId)
    end)
    if ok and pages then
        while #friendIds < POOL_SIZE do
            local pageOk, pageData = pcall(function()
                return pages:GetCurrentPage()
            end)
            if not pageOk or not pageData then break end
            for _, friend in ipairs(pageData) do
                table.insert(friendIds, friend.Id)
                if #friendIds >= POOL_SIZE then break end
            end
            if pages.IsFinished or #friendIds >= POOL_SIZE then break end
            local advOk = pcall(function() pages:AdvanceToNextPageAsync() end)
            if not advOk then break end
        end
    else
        warn("[NPCAvatarLoader] GetFriendsAsync failed:", tostring(pages))
    end

    print(string.format("[NPCAvatarLoader] Found %d friends", #friendIds))

    -- Pad with fallback IDs until we have POOL_SIZE candidates
    local candidates = {}
    for _, id in ipairs(friendIds) do
        table.insert(candidates, id)
    end
    for _, id in ipairs(FALLBACK_USER_IDS) do
        if #candidates >= POOL_SIZE then break end
        table.insert(candidates, id)
    end

    -- Build each avatar
    local built = 0
    for slot, userId in ipairs(candidates) do
        if slot > POOL_SIZE then break end
        local success = buildAvatarFromDescription(slot, userId, tmplHead, avatarFolder)
        if success then built += 1 end
    end

    Workspace:SetAttribute("NPCAvatarsReady", true)
    print(string.format("[NPCAvatarLoader] Pool ready: %d/%d avatars built", built, POOL_SIZE))
end

-- ─── TRIGGER ON FIRST PLAYER JOIN ────────────────────────────────────────
local loaded = false

Players.PlayerAdded:Connect(function(player)
    if loaded then return end
    loaded = true
    -- Small delay so game state is settled
    task.delay(1, function()
        buildAvatarPool(player)
    end)
end)

-- Handle case where player already joined before this script loaded
if #Players:GetPlayers() > 0 and not loaded then
    loaded = true
    task.delay(1, function()
        buildAvatarPool(Players:GetPlayers()[1])
    end)
end

print("[NPCAvatarLoader] Waiting for first player...")
```

**Step 2: Push the script body into Studio via MCP**

```lua
-- MCP run_code: create the Script object in Studio
local SSS  = game:GetService("ServerScriptService")
local core = SSS:WaitForChild("Core", 5)
if not core then
    core      = Instance.new("Folder")
    core.Name = "Core"
    core.Parent = SSS
end

-- Remove old if exists
local old = core:FindFirstChild("NPCAvatarLoader")
if old then old:Destroy() end

local s        = Instance.new("Script")
s.Name         = "NPCAvatarLoader"
s.Parent       = core
-- Body will be synced from src/ via file — for now confirm it exists
print("NPCAvatarLoader Script created at:", s:GetFullName())
```

**Step 3: Paste the script source into Studio**

Since Rojo is stopped, open Studio's Script editor for `NPCAvatarLoader`, paste the full source from `src/ServerScriptService/Core/NPCAvatarLoader.server.lua`, and save. (Or use the MCP set-source approach if available.)

**Step 4: Commit the file**

```bash
cd /c/Users/alex1/Documents/CookieSimulator
git add src/ServerScriptService/Core/NPCAvatarLoader.server.lua
git commit -m "feat: add NPCAvatarLoader - builds R6 avatar pool from friends list"
```

---

### Task 3: Update NPCSpawner.CreateNPC to use the avatar pool

**Files:**
- Modify: `src/ReplicatedStorage/Modules/NPCSpawner.lua` (lines 14–45, CreateNPC function only)

**Step 1: Read NPCSpawner.lua** (already read — see lines 17–45)

**Step 2: Edit CreateNPC**

Replace the existing `CreateNPC` function body with the version below. Everything else in NPCSpawner stays untouched.

```lua
-- ─── CreateNPC ────────────────────────────────────────────────────────────────
-- config: { name, isVIP, spawnCFrame }
-- Returns the NPC Model, or nil on failure.
function NPCSpawner.CreateNPC(config)
    local npc

    -- Prefer the avatar pool if it's ready
    local avatarsReady  = Workspace:GetAttribute("NPCAvatarsReady")
    local avatarFolder  = ServerStorage:FindFirstChild("NPCAvatars")
    if avatarsReady and avatarFolder then
        local pool = avatarFolder:GetChildren()
        if #pool > 0 then
            local pick = pool[math.random(1, #pool)]
            npc = pick:Clone()
        end
    end

    -- Fallback: use the original block NPCTemplate
    if not npc then
        local template = ServerStorage:FindFirstChild(TEMPLATE_NAME)
        if not template then
            warn("[NPCSpawner] NPCTemplate not found in ServerStorage")
            return nil
        end
        npc = template:Clone()
    end

    npc.Name = config.name or "Customer"

    -- VIP: add a gold BillboardGui label above the head
    if config.isVIP then
        local head = npc:FindFirstChild("Head")
        if head then
            local existing = head:FindFirstChild("VIPGui")
            if not existing then
                local bb       = Instance.new("BillboardGui")
                bb.Name        = "VIPGui"
                bb.Size        = UDim2.new(0, 60, 0, 24)
                bb.StudsOffset = Vector3.new(0, 2.5, 0)
                bb.AlwaysOnTop = false
                bb.Parent      = head

                local lbl           = Instance.new("TextLabel")
                lbl.Size            = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
                lbl.BackgroundTransparency = 0.1
                lbl.TextColor3      = Color3.fromRGB(0, 0, 0)
                lbl.Font            = Enum.Font.GothamBold
                lbl.TextScaled      = true
                lbl.Text            = "⭐ VIP"
                lbl.Parent          = bb
            end
        end
    end

    local spawnCF = config.spawnCFrame or CFrame.new(Vector3.new(-5, 2, 30))
    npc:SetPrimaryPartCFrame(spawnCF)

    local npcFolder = Workspace:FindFirstChild(NPC_FOLDER)
    if not npcFolder then
        npcFolder        = Instance.new("Folder")
        npcFolder.Name   = NPC_FOLDER
        npcFolder.Parent = Workspace
    end
    npc.Parent = npcFolder
    return npc
end
```

**Step 3: Apply the updated function in Studio via MCP**

Since Rojo is stopped, open NPCSpawner in the Studio Script editor, replace the `CreateNPC` function (lines 14–45) with the new version above, and save.

**Step 4: Commit**

```bash
cd /c/Users/alex1/Documents/CookieSimulator
git add src/ReplicatedStorage/Modules/NPCSpawner.lua
git commit -m "feat: NPCSpawner picks from R6 avatar pool; fallback to NPCTemplate"
```

---

### Task 4: Sync script sources into Studio via MCP

**Step 1: Set NPCAvatarLoader source in Studio**

```lua
-- MCP run_code: set script source
local SSS    = game:GetService("ServerScriptService")
local loader = SSS.Core:FindFirstChild("NPCAvatarLoader")
if not loader then
    print("NPCAvatarLoader not found — create it first (Task 2)")
    return
end

loader.Source = [==[
-- paste full content of NPCAvatarLoader.server.lua here
]==]
print("NPCAvatarLoader source updated")
```

> Note: Due to string length, open the script editor manually in Studio and paste content from `src/ServerScriptService/Core/NPCAvatarLoader.server.lua` if MCP source-setting truncates.

**Step 2: Update NPCSpawner source in Studio**

Open `ReplicatedStorage > Modules > NPCSpawner` in Studio script editor, replace `CreateNPC` function body with new version from Task 3.

---

### Task 5: Play-test and validate

**Step 1: Enter Play mode in Studio**

Open Output window before pressing Play.

**Step 2: Watch for these prints in order**

```
[NPCAvatarLoader] Waiting for first player...
[NPCAvatarLoader] Building avatar pool for [YourUsername]
[NPCAvatarLoader] Found N friends
[NPCAvatarLoader] Slot 1 built (userId=XXXXXX)
[NPCAvatarLoader] Slot 2 built (userId=XXXXXX)
...
[NPCAvatarLoader] Pool ready: 10/10 avatars built
[NPCController] Ready
```

**Step 3: Wait for NPC to spawn (~2–8 seconds)**

Expected:
- An R6-shaped NPC walks to the queue spot
- If your avatar has a face texture, it appears on the Head
- Body colors match the user's avatar colors
- PatienceGui timer shows above the head
- OrderPrompt (E key) appears when NPC is at slot 1

**Step 4: Test VIP NPC**

VIP chance is 10% — may need several spawns. When a VIP spawns:
- Gold "⭐ VIP" BillboardGui appears above the head
- NPC still walks to queue and accepts orders normally

**Step 5: Test fallback (optional)**

In NPCAvatarLoader, temporarily set `POOL_SIZE = 0` and play-test → NPCs should spawn as block NPCTemplate (grey blocks). Revert after confirming.

**Step 6: Confirm order flow still works end-to-end**

- Press E on the front-of-queue NPC → order shows on Tablet
- NPC walks to waiting area
- Trigger a box creation (via mix/dough/oven pipeline or MCP)
- NPC walks to counter
- Deliver prompt appears → deliver box → coins awarded

---

### Task 6: Save and push

**Step 1: Save Studio file**

Ctrl+S in Studio to persist all changes.

**Step 2: Git push**

```bash
cd /c/Users/alex1/Documents/CookieSimulator
git push origin main
```

**Step 3: Update MEMORY.md**

Add to Current Status:
- NPC avatar system complete: R6 pool from friends list, 10 fallback IDs, VIP gold label
- SPAWN_STATES still includes "Lobby" for testing — revert to `{ "Open" }` after visual test passes
- Next: revert spawn states, then M3 Step 2 (order display / HUD)

---

## Risk / Regression Notes

| Risk | Mitigation |
|------|-----------|
| `CreateHumanoidDescriptionFromUserId` throttled | `pcall` per slot, pool still builds with partial results |
| Player has 0 friends | All 10 slots use FALLBACK_USER_IDS — pool always builds |
| R6AvatarTemplate missing from Studio | NPCSpawner falls back to NPCTemplate (block), game continues |
| ApplyDescription adds accessories that break hitbox | Accessories are cosmetic only, don't affect Humanoid physics |
| NPCAvatarsReady set before pool parent is finalized | Attribute set at end of loop, after all avatars parented |
