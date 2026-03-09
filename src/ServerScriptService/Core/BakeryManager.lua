-- ServerScriptService/Core/BakeryManager (Script — auto-runs on server start)
-- Handles bakery name setting and Store Nameplate display.
-- Bakery XP/level math lives in PlayerDataManager.AwardBakeryXP.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Players             = game:GetService("Players")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local setNameRemote      = RemoteManager.Get("SetBakeryName")
local nameResultRemote   = RemoteManager.Get("BakeryNameResult")
local updateNameplateRem = RemoteManager.Get("UpdateNameplate")

-- ── NAMEPLATE ───────────────────────────────────────────────────
local nameplateLabel = nil  -- cached TextLabel on the physical sign
local nameplateSet   = false

local function findNameplateLabel()
    if nameplateLabel then return nameplateLabel end
    local part = workspace:FindFirstChild("Store Nameplate", true)
    if not part then return nil end
    local gui = part:FindFirstChildOfClass("SurfaceGui")
    if not gui then return nil end
    nameplateLabel = gui:FindFirstChildOfClass("TextLabel")
    return nameplateLabel
end

local function trySetNameplate(player)
    if nameplateSet then return end
    local p = PlayerDataManager.GetData(player)
    if not p or p.bakeryName == "" then return end
    local label = findNameplateLabel()
    if not label then return end
    label.Text   = p.bakeryName
    nameplateSet = true
    print("[BakeryManager] Nameplate set to:", p.bakeryName)
end

-- ── NAME VALIDATION ──────────────────────────────────────────────
local function validateName(name)
    if type(name) ~= "string" then return false, "Invalid name" end
    name = name:match("^%s*(.-)%s*$")  -- trim whitespace
    if #name < 2  then return false, "Name must be at least 2 characters" end
    if #name > 24 then return false, "Name must be 24 characters or less" end
    -- Block names that are purely whitespace or special chars
    if not name:match("%a") then return false, "Name must contain letters" end
    return true, name
end

-- ── REMOTE HANDLER ──────────────────────────────────────────────
setNameRemote.OnServerEvent:Connect(function(player, rawName)
    local ok, result = validateName(rawName)
    if not ok then
        nameResultRemote:FireClient(player, false, result)
        return
    end

    local cleanName = result
    PlayerDataManager.SetBakeryName(player, cleanName)
    nameResultRemote:FireClient(player, true, cleanName)
    trySetNameplate(player)
    -- Broadcast to all clients so they update the nameplate on their side too
    updateNameplateRem:FireAllClients(cleanName)
    print("[BakeryManager]", player.Name, "named their bakery:", cleanName)
end)

-- ── PLAYER LIFECYCLE ─────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    -- Defer so PlayerDataManager has time to load the profile first
    task.defer(function()
        task.wait(1)
        trySetNameplate(player)
    end)
end)

print("[BakeryManager] Ready.")
