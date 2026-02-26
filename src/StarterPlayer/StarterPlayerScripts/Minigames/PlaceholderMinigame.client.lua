-- src/StarterPlayer/StarterPlayerScripts/Minigames/PlaceholderMinigame.client.lua
-- M1: Placeholder for all station minigames.
-- Replace each with real mechanic in Milestone 2.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Config: which events to intercept ────────────────────────────────────────
local STATIONS = {
    { start = "StartMixMinigame",    result = "MixMinigameResult",    label = "Mixing..."    },
    { start = "StartDoughMinigame",  result = "DoughMinigameResult",  label = "Dough Table..." },
    { start = "StartOvenMinigame",   result = "OvenMinigameResult",   label = "Baking..."    },
    { start = "StartFrostMinigame",  result = "FrostMinigameResult",  label = "Frosting..."  },
    { start = "StartDressMinigame",  result = "DressMinigameResult",  label = "Packing..."   },
}

-- ─── Placeholder UI ───────────────────────────────────────────────────────────
local function showPlaceholder(label, onComplete)
    local existing = playerGui:FindFirstChild("PlaceholderMinigame")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name            = "PlaceholderMinigame"
    sg.ResetOnSpawn    = false
    sg.Parent          = playerGui

    local frame = Instance.new("Frame")
    frame.Size              = UDim2.new(0, 300, 0, 120)
    frame.Position          = UDim2.new(0.5, -150, 0.5, -60)
    frame.BackgroundColor3  = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel   = 0
    frame.Parent            = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size              = UDim2.new(1, 0, 0.5, 0)
    title.BackgroundTransparency = 1
    title.TextColor3        = Color3.fromRGB(255, 255, 255)
    title.TextScaled        = true
    title.Font              = Enum.Font.GothamBold
    title.Text              = label
    title.Parent            = frame

    local btn = Instance.new("TextButton")
    btn.Size                = UDim2.new(0.6, 0, 0.35, 0)
    btn.Position            = UDim2.new(0.2, 0, 0.58, 0)
    btn.BackgroundColor3    = Color3.fromRGB(80, 200, 120)
    btn.TextColor3          = Color3.fromRGB(255, 255, 255)
    btn.TextScaled          = true
    btn.Font                = Enum.Font.GothamBold
    btn.Text                = "Complete"
    btn.BorderSizePixel     = 0
    btn.Parent              = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        sg:Destroy()
        onComplete()
    end)
end

-- ─── Wire each station ────────────────────────────────────────────────────────
for _, station in ipairs(STATIONS) do
    local startRemote  = RemoteManager.Get(station.start)
    local resultRemote = RemoteManager.Get(station.result)

    startRemote.OnClientEvent:Connect(function(...)
        local args = {...}
        showPlaceholder(station.label, function()
            -- Fire result back with "Good" score (80)
            resultRemote:FireServer(80, table.unpack(args))
        end)
    end)
end

print("[PlaceholderMinigame] All 5 station placeholders active.")
