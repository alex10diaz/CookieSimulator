# NPC Friend Avatar System — Design Doc
**Date:** 2026-03-01
**Milestone:** M3 (pre-Step 2)
**Status:** Approved

---

## Goal

Replace the block NPCTemplate with real Roblox R6 avatars pulled from the first player's friends list. Fall back to 10 hardcoded public user IDs if the player has fewer than 10 friends. Pool is built once at game start — zero API overhead per NPC spawn.

---

## Architecture

```
ServerStorage/
  R6AvatarTemplate     ← base R6 rig (all parts + Motor6Ds), created via MCP
  NPCAvatars/          ← created at runtime by NPCAvatarLoader
    NPCAvatar_1        ← full R6 model with HumanoidDescription applied
    NPCAvatar_2
    ... up to NPCAvatar_10
  NPCTemplate          ← unchanged (fallback + donor for PatienceGui / OrderPrompt)
```

**New file:** `src/ServerScriptService/Core/NPCAvatarLoader.server.lua`
**Modified file:** `src/ReplicatedStorage/Modules/NPCSpawner.lua` (CreateNPC only)

---

## NPCAvatarLoader Flow

1. `Players.PlayerAdded` → grab first arriving player's `UserId`
2. `Players:GetFriendsAsync(userId)` → iterate pages, collect up to 10 friend IDs
3. Pad remaining slots with hardcoded `FALLBACK_USER_IDS` (10 known public Roblox users)
4. For each slot (up to 10):
   - Clone `R6AvatarTemplate` from ServerStorage
   - `pcall(Players.CreateHumanoidDescriptionFromUserId, Players, id)` → HumanoidDescription
   - If pcall succeeds: `Humanoid:ApplyDescription(desc)` — sets face, colors, clothing, accessories
   - If pcall fails: skip slot silently (pool may have < 10 entries, that's fine)
   - Copy `PatienceGui` and `OrderPrompt` from `NPCTemplate.Head` onto avatar's Head
   - Name model `"NPCAvatar_" .. slot`
   - Parent to `ServerStorage/NPCAvatars`
5. `Workspace:SetAttribute("NPCAvatarsReady", true)` when loop finishes

All `GetFriendsAsync` and `CreateHumanoidDescriptionFromUserId` calls are wrapped in `pcall`.

---

## NPCSpawner.CreateNPC Change

```lua
-- Before cloning NPCTemplate, check for avatar pool
local pool = SS:FindFirstChild("NPCAvatars")
local ready = Workspace:GetAttribute("NPCAvatarsReady")
if ready and pool then
    local avatars = pool:GetChildren()
    if #avatars > 0 then
        local pick = avatars[math.random(1, #avatars)]
        -- clone pick, set PrimaryPart, position, parent → return
    end
end
-- fallback: existing NPCTemplate clone logic unchanged
```

VIP NPCs: add a gold `BillboardGui` label ("⭐ VIP") above the head instead of recoloring the torso (since avatar appearance is locked).

---

## R6AvatarTemplate Structure

Created in Studio via MCP `run_code`. All parts: `CanCollide = false`, `Anchored = false`.
`HumanoidRootPart` is the `PrimaryPart`.

| Part | Size |
|------|------|
| HumanoidRootPart | 2, 2, 1 |
| Torso | 2, 2, 1 |
| Head | 1, 1, 1 |
| Left Arm | 1, 2, 1 |
| Right Arm | 1, 2, 1 |
| Left Leg | 1, 2, 1 |
| Right Leg | 1, 2, 1 |

Motor6D joints (all parented to Torso except RootJoint which goes in HumanoidRootPart):

| Joint | Part0 | Part1 | Location |
|-------|-------|-------|----------|
| RootJoint | HumanoidRootPart | Torso | HumanoidRootPart |
| Neck | Torso | Head | Torso |
| Left Shoulder | Torso | Left Arm | Torso |
| Right Shoulder | Torso | Right Arm | Torso |
| Left Hip | Torso | Left Leg | Torso |
| Right Hip | Torso | Right Leg | Torso |

---

## Fallback User IDs

10 known public Roblox accounts used when player has < 10 friends:

```lua
local FALLBACK_USER_IDS = {
    156,       -- Builderman
    261,       -- ROBLOX
    55492028,  -- EthanGamer
    10792782,  -- Kreekcraft
    1281024,   -- Loleris
    4270282,   -- Dued1
    2409626,   -- OofQueen
    698870,    -- Stickmasterluke
    90252,     -- theGrefg
    19708579,  -- Coeptus
}
```

---

## Error Handling

- `pcall` around every async API call — one bad ID never breaks the batch
- Pool may end up with fewer than 10 avatars if multiple IDs fail — NPCSpawner picks from whatever is available
- If `NPCAvatarsReady` is false when first NPC spawns, NPCTemplate is used (block humanoid, zero regression)

---

## What Does NOT Change

- NPCController (PersistentNPCSpawner) — no changes
- OrderManager — no changes
- CookieData — no changes
- NPCTemplate — stays in ServerStorage as fallback
- All queue/patience/delivery logic — untouched

---

## Test Plan (3 minutes)

1. Play test → watch Output for `[NPCAvatarLoader] Pool ready: N avatars`
2. Wait for NPC to spawn → confirm it looks like a Roblox character (face, colors)
3. Confirm PatienceGui timer shows above head
4. Confirm OrderPrompt (E key) still works
5. Confirm a VIP NPC shows the gold BillboardGui label
