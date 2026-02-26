-- src/StarterGui/SummaryGui/SummaryController.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local summaryEvent   = RemoteManager.Get("EndOfDaySummary")
local stateRemote    = RemoteManager.Get("GameStateChanged")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui       = playerGui:WaitForChild("SummaryGui")

-- ─── Build UI ─────────────────────────────────────────────────────────────────
local frame = gui:FindFirstChild("SummaryFrame")
if not frame then
    frame = Instance.new("Frame")
    frame.Name             = "SummaryFrame"
    frame.Size             = UDim2.new(0, 400, 0, 280)
    frame.Position         = UDim2.new(0.5, -200, 0.5, -140)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel  = 0
    frame.Parent           = gui
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 16)
    c.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name                  = "Title"
    title.Size                  = UDim2.new(1, 0, 0.22, 0)
    title.BackgroundTransparency = 1
    title.TextColor3            = Color3.fromRGB(255, 200, 0)
    title.TextScaled            = true
    title.Font                  = Enum.Font.GothamBold
    title.Text                  = "End of Day!"
    title.Parent                = frame
end

local body = frame:FindFirstChild("Body")
if not body then
    body = Instance.new("TextLabel")
    body.Name                  = "Body"
    body.Size                  = UDim2.new(1, -20, 0.68, 0)
    body.Position              = UDim2.new(0, 10, 0.24, 0)
    body.BackgroundTransparency = 1
    body.TextColor3            = Color3.fromRGB(220, 220, 220)
    body.TextScaled            = true
    body.Font                  = Enum.Font.Gotham
    body.Text                  = "Orders Completed: 0\nCoins Earned: 0\nBest Combo: x0\nAvg Rating: ***"
    body.Parent                = frame
end

-- ─── Events ───────────────────────────────────────────────────────────────────
summaryEvent.OnClientEvent:Connect(function(data)
    body.Text = string.format(
        "Orders Completed: %d\nCoins Earned: %d\nBest Combo: x%d\nAvg Rating: %s",
        data.orders  or 0,
        data.coins   or 0,
        data.combo   or 0,
        string.rep("*", math.round(data.avgStars or 3))
    )
    gui.Enabled = true
end)

stateRemote.OnClientEvent:Connect(function(state)
    if state == "PreOpen" then
        gui.Enabled = false
    end
end)

print("[SummaryController] Ready.")
