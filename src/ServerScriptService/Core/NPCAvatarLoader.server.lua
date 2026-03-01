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

local function buildAvatarFromDescription(slot, userId, tmplHead, avatarFolder, template)
    -- Get HumanoidDescription
    local ok, desc = pcall(function()
        return Players:CreateHumanoidDescriptionFromUserId(userId)
    end)
    if not ok or not desc then
        warn(string.format("[NPCAvatarLoader] Failed to get description for userId %d: %s", userId, tostring(desc)))
        return false
    end

    -- Clone R6AvatarTemplate
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
    if not tmplHead then
        warn("[NPCAvatarLoader] NPCTemplate or its Head is missing — avatars will lack PatienceGui/OrderPrompt/FaceGui")
    end

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
    local candidates = table.clone(friendIds)
    for _, id in ipairs(FALLBACK_USER_IDS) do
        if #candidates >= POOL_SIZE then break end
        table.insert(candidates, id)
    end

    -- Look up R6AvatarTemplate once (fail fast if missing)
    local template = ServerStorage:FindFirstChild("R6AvatarTemplate")
    if not template then
        warn("[NPCAvatarLoader] R6AvatarTemplate not found in ServerStorage — aborting pool build")
        return
    end

    -- Build each avatar
    local built = 0
    for slot, userId in ipairs(candidates) do
        if slot > POOL_SIZE then break end
        local success = buildAvatarFromDescription(slot, userId, tmplHead, avatarFolder, template)
        if success then built += 1 end
    end

    if built > 0 then
        Workspace:SetAttribute("NPCAvatarsReady", true)
    end
    print(string.format("[NPCAvatarLoader] Pool ready: %d/%d avatars built", built, POOL_SIZE))
end

-- ─── TRIGGER ON FIRST PLAYER JOIN ────────────────────────────────────────
local loaded = false

Players.PlayerAdded:Connect(function(player)
    if loaded then return end
    loaded = true
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
