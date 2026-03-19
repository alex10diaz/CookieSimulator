-- StarterPlayerScripts/LifetimeChallengeClient (LocalScript)
-- Renders the Lifetime Milestones back-room board and shows a completion flash.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local initRemote     = RemoteManager.Get("LifetimeChallengesInit")
local completeRemote = RemoteManager.Get("LifetimeChallengeComplete")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("HUD")

-- ─── State ────────────────────────────────────────────────────────────────────
local milestones = {}  -- list of { id, label, goal, reward, progress, claimed }

-- ─── Board ────────────────────────────────────────────────────────────────────
local function getBoardGui()
    local part = workspace:FindFirstChild("LifetimeBoard")
    return part and part:FindFirstChild("LifetimeBoardGui")
end

local function updateBoard()
    local sg = getBoardGui()
    if not sg then return end
    local bg = sg:FindFirstChild("Bg")
    if not bg then return end

    for i, ms in ipairs(milestones) do
        local row = bg:FindFirstChild("Row" .. i)
        if not row then continue end

        local label  = row:FindFirstChild("Label")
        local status = row:FindFirstChild("Status")

        if label then
            label.Text = ms.label
            label.TextColor3 = ms.claimed
                and Color3.fromRGB(100, 220, 100)
                or  Color3.fromRGB(220, 220, 220)
        end
        if status then
            if ms.claimed then
                status.Text       = "✓  +" .. ms.reward .. " coins"
                status.TextColor3 = Color3.fromRGB(100, 220, 100)
            else
                status.Text       = ms.progress .. " / " .. ms.goal
                status.TextColor3 = Color3.fromRGB(160, 160, 160)
            end
        end
    end
end

-- ─── Completion Flash ─────────────────────────────────────────────────────────
local function showCompletionFlash(label, reward)
    local flash = Instance.new("TextLabel")
    flash.Size             = UDim2.new(0, 380, 0, 60)
    flash.Position         = UDim2.new(0.5, -190, 0.25, 0)
    flash.BackgroundColor3 = Color3.fromRGB(160, 120, 0)
    flash.TextColor3       = Color3.fromRGB(255, 255, 255)
    flash.TextScaled       = true
    flash.Font             = Enum.Font.GothamBold
    flash.Text             = "Milestone: " .. label .. "  +" .. reward .. " coins"
    flash.ZIndex           = 50
    flash.BorderSizePixel  = 0
    flash.Parent           = hud
    local c = Instance.new("UICorner", flash)
    c.CornerRadius = UDim.new(0, 12)
    game:GetService("Debris"):AddItem(flash, 4)
end

-- ─── Remote Handlers ──────────────────────────────────────────────────────────
initRemote.OnClientEvent:Connect(function(data)
    milestones = data.milestones or {}
    updateBoard()
end)

completeRemote.OnClientEvent:Connect(function(data)
    -- Update local state
    for _, ms in ipairs(milestones) do
        if ms.id == data.id then
            ms.claimed  = true
            ms.progress = ms.goal
            break
        end
    end
    showCompletionFlash(data.label, data.reward)
    updateBoard()
end)

print("[LifetimeChallengeClient] Ready.")
