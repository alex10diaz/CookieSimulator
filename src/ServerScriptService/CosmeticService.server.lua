-- ServerScriptService/CosmeticService.server.lua
-- Applies equipped hat + apron cosmetics to player characters on spawn.
-- Listens to CosmeticEquipped BindableEvent for live re-apply mid-session.

local Players         = game:GetService("Players")
local ServerStorage   = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PDM = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local cosmeticsFolder   = ServerStorage:WaitForChild("Cosmetics")
local cosmeticEquipped  = ServerStorage:WaitForChild("Events"):WaitForChild("CosmeticEquipped")

-- ── HELPERS ────────────────────────────────────────────────────────────────────

-- Determines cosmetic slot from id prefix
local function getSlot(id)
    return id:sub(1, 5) == "apron" and "apron" or "hat"
end

-- CFrame offsets relative to the body part (R6)
local OFFSETS = {
    hat   = CFrame.new(0, 0.85, 0),   -- above Head center
    apron = CFrame.new(0, 0, -0.6),   -- front face of Torso
}

-- Body part each slot attaches to
local ATTACH_TO = {
    hat   = "Head",
    apron = "Torso",
}

local function removeCosmetic(character, slot)
    local tag = "Cosmetic_" .. slot
    local existing = character:FindFirstChild(tag)
    if existing then existing:Destroy() end
end

local function applyCosmetic(character, slot, cosmeticId)
    removeCosmetic(character, slot)
    if not cosmeticId then return end

    local model = cosmeticsFolder:FindFirstChild(cosmeticId)
    if not model then
        warn("[CosmeticService] Model not found:", cosmeticId)
        return
    end

    local clone = model:Clone()
    clone.Name = "Cosmetic_" .. slot

    local bodyPart = character:FindFirstChild(ATTACH_TO[slot])
    if not bodyPart then clone:Destroy(); return end

    local part = clone:IsA("BasePart") and clone or clone.PrimaryPart
        or clone:FindFirstChildWhichIsA("BasePart")
    if not part then clone:Destroy(); return end

    part.Anchored = false
    clone.Parent = character

    local weld = Instance.new("Weld")
    weld.Part0  = bodyPart
    weld.Part1  = part
    weld.C0     = OFFSETS[slot]
    weld.C1     = CFrame.new()
    weld.Parent = part
end

local function applyAll(player, character)
    -- Wait for character to be fully loaded
    if not character:FindFirstChild("HumanoidRootPart") then
        character:WaitForChild("HumanoidRootPart", 10)
    end

    local equipped = PDM.GetEquipped(player)
    applyCosmetic(character, "hat",   equipped.hat)
    applyCosmetic(character, "apron", equipped.apron)
end

-- ── PLAYER LIFECYCLE ───────────────────────────────────────────────────────────

local function onCharacterAdded(player, character)
    task.defer(function()
        applyAll(player, character)
    end)
end

local function onPlayerAdded(player)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- ── LIVE EQUIP (fires when cosmetic is purchased or station grant unlocks one) ─

cosmeticEquipped.Event:Connect(function(player, cosmeticId)
    local character = player.Character
    if not character then return end
    local slot = getSlot(cosmeticId)
    applyCosmetic(character, slot, cosmeticId)
end)

print("[CosmeticService] Ready.")
