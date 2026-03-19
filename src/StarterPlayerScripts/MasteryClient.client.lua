-- MasteryClient (LocalScript)  — M7 Polish
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ROLE_ICONS = {
    Mixer="🥣", Baller="🍪", Baker="🔥", Glazer="🧁", Decorator="🎁"
}

local function showToast(data)
    local sg = Instance.new("ScreenGui")
    sg.Name = "MasteryToast"; sg.ResetOnSpawn = false
    sg.DisplayOrder = 25; sg.Parent = playerGui

    -- Card starts above screen, slides down
    local card = Instance.new("Frame", sg)
    card.Size = UDim2.new(0, 300, 0, 64)
    card.Position = UDim2.new(0.5, -150, 0, -70)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
    card.BackgroundTransparency = 0; card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", card)
    stroke.Color = Color3.fromRGB(255, 200, 0); stroke.Thickness = 2; stroke.Transparency = 0.2

    -- Gold accent left bar
    local accent = Instance.new("Frame", card)
    accent.Size = UDim2.new(0,4,1,0); accent.BackgroundColor3 = Color3.fromRGB(255,200,0)
    accent.BorderSizePixel = 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0,4)

    -- Role icon badge
    local badge = Instance.new("Frame", card)
    badge.Size = UDim2.new(0,44,0,44); badge.Position = UDim2.new(0,8,0.5,-22)
    badge.BackgroundColor3 = Color3.fromRGB(35,28,5); badge.BorderSizePixel = 0
    Instance.new("UICorner", badge).CornerRadius = UDim.new(1,0)
    local badgeIcon = Instance.new("TextLabel", badge)
    badgeIcon.Size = UDim2.new(1,0,1,0); badgeIcon.BackgroundTransparency = 1
    badgeIcon.TextScaled = true; badgeIcon.Text = ROLE_ICONS[data.role] or "⭐"

    -- Top line: role + level
    local topLine = Instance.new("TextLabel", card)
    topLine.Size = UDim2.new(1,-62,0,30); topLine.Position = UDim2.new(0,58,0,6)
    topLine.BackgroundTransparency = 1
    topLine.TextColor3 = Color3.fromRGB(255,210,0); topLine.Font = Enum.Font.GothamBold
    topLine.TextScaled = true; topLine.TextXAlignment = Enum.TextXAlignment.Left
    topLine.Text = data.role .. "  Level " .. data.level

    -- Bottom line: reward
    local botLine = Instance.new("TextLabel", card)
    botLine.Size = UDim2.new(1,-62,0,22); botLine.Position = UDim2.new(0,58,0,36)
    botLine.BackgroundTransparency = 1
    botLine.TextColor3 = Color3.fromRGB(160,200,120); botLine.Font = Enum.Font.Gotham
    botLine.TextScaled = true; botLine.TextXAlignment = Enum.TextXAlignment.Left
    botLine.Text = (data.coins and data.coins > 0) and ("+" .. data.coins .. " coins reward") or "Station Mastery Up!"

    -- Slide in
    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -150, 0, 90) }):Play()

    -- Slide out
    task.delay(3.5, function()
        local t = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad),
            { Position = UDim2.new(0.5, -150, 0, -70) })
        t:Play(); t.Completed:Connect(function() sg:Destroy() end)
    end)
end

RemoteManager.Get("MasteryLevelUp").OnClientEvent:Connect(showToast)
print("[MasteryClient] Ready.")
