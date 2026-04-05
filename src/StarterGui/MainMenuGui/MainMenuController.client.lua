-- MainMenuController (LocalScript)
-- M-9: Programmatic main menu — dark navy panel, gold accents, animated Play button.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local stateRemote        = RemoteManager.Get("GameStateChanged")
local dismissMenuRemote  = RemoteManager.Get("DismissMainMenu")

local coolTransitions  = require(ReplicatedStorage:WaitForChild("coolTransitions"))
local menuTransitions  = coolTransitions.TransitionManager.new(
    game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),
    { color = Color3.fromRGB(10, 10, 20), displayOrder = 50 }
)

-- ── Palette (matches HUDController) ──────────────────────────────────────────
local C = {
    BG_DARK  = Color3.fromRGB(10, 10, 20),
    CARD     = Color3.fromRGB(18, 18, 36),
    GOLD     = Color3.fromRGB(255, 200,  0),
    GOLD_DIM = Color3.fromRGB(180, 140,  0),
    WHITE    = Color3.fromRGB(255, 255, 255),
    MUTED    = Color3.fromRGB(160, 160, 185),
    BTN_BG   = Color3.fromRGB(255, 200,  0),
    BTN_TEXT = Color3.fromRGB( 15,  38,  70),
    BTN_HOV  = Color3.fromRGB(255, 220,  60),
}

local gui = script.Parent
-- Clear any Studio-built children; we own all layout from here
for _, ch in ipairs(gui:GetChildren()) do
    if ch:IsA("GuiObject") then ch:Destroy() end
end
gui.ResetOnSpawn = false

local function markMenuDismissed()
    dismissMenuRemote:FireServer()
end

-- ── Overlay ───────────────────────────────────────────────────────────────────
local overlay = Instance.new("Frame", gui)
overlay.Name              = "Overlay"
overlay.Size              = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3  = C.BG_DARK
overlay.BackgroundTransparency = 0
overlay.BorderSizePixel   = 0
overlay.ZIndex            = 10

-- ── Card ─────────────────────────────────────────────────────────────────────
local card = Instance.new("Frame", overlay)
card.Name                 = "MenuCard"
card.AnchorPoint          = Vector2.new(0.5, 0.5)
card.Position             = UDim2.new(0.5, 0, 0.5, 0)
card.Size                 = UDim2.new(0, 360, 0, 320)
card.BackgroundColor3     = C.CARD
card.BackgroundTransparency = 1   -- start invisible for fade-in
card.BorderSizePixel      = 0
card.ZIndex               = 11
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
local cardStroke = Instance.new("UIStroke", card)
cardStroke.Color       = C.GOLD
cardStroke.Thickness   = 2
cardStroke.Transparency = 1   -- fade in with card

-- ── Cookie icon ───────────────────────────────────────────────────────────────
local icon = Instance.new("TextLabel", card)
icon.Name                = "Icon"
icon.Size                = UDim2.new(1, 0, 0, 64)
icon.Position            = UDim2.new(0, 0, 0, 20)
icon.BackgroundTransparency = 1
icon.Text                = "🍪"
icon.TextScaled          = true
icon.Font                = Enum.Font.GothamBold
icon.ZIndex              = 12

-- ── Title ─────────────────────────────────────────────────────────────────────
local title = Instance.new("TextLabel", card)
title.Name               = "Title"
title.Size               = UDim2.new(1, -24, 0, 44)
title.Position           = UDim2.new(0, 12, 0, 90)
title.BackgroundTransparency = 1
title.Text               = "Cookie Empire"
title.TextColor3         = C.GOLD
title.Font               = Enum.Font.GothamBold
title.TextScaled         = true
title.ZIndex             = 12
local titleStroke = Instance.new("UIStroke", title)
titleStroke.Color        = C.GOLD_DIM
titleStroke.Thickness    = 1.5
titleStroke.Transparency = 0.5

-- ── Subtitle ──────────────────────────────────────────────────────────────────
local sub = Instance.new("TextLabel", card)
sub.Name                 = "Subtitle"
sub.Size                 = UDim2.new(1, -24, 0, 24)
sub.Position             = UDim2.new(0, 12, 0, 138)
sub.BackgroundTransparency = 1
sub.Text                 = "Master Bakery"
sub.TextColor3           = C.MUTED
sub.Font                 = Enum.Font.Gotham
sub.TextScaled           = true
sub.ZIndex               = 12

-- ── Gold accent divider ────────────────────────────────────────────────────────
local divider = Instance.new("Frame", card)
divider.Name             = "Divider"
divider.Size             = UDim2.new(0.7, 0, 0, 2)
divider.Position         = UDim2.new(0.15, 0, 0, 172)
divider.BackgroundColor3 = C.GOLD
divider.BackgroundTransparency = 0.4
divider.BorderSizePixel  = 0
divider.ZIndex           = 12
Instance.new("UICorner", divider).CornerRadius = UDim.new(1, 0)

-- ── Play button ───────────────────────────────────────────────────────────────
local playBtn = Instance.new("TextButton", card)
playBtn.Name             = "PlayButton"
playBtn.AnchorPoint      = Vector2.new(0.5, 0)
playBtn.Position         = UDim2.new(0.5, 0, 0, 195)
playBtn.Size             = UDim2.new(0, 200, 0, 52)
playBtn.BackgroundColor3 = C.BTN_BG
playBtn.BorderSizePixel  = 0
playBtn.Text             = "▶  Play"
playBtn.TextColor3       = C.BTN_TEXT
playBtn.Font             = Enum.Font.GothamBold
playBtn.TextSize         = 22
playBtn.ZIndex           = 12
Instance.new("UICorner", playBtn).CornerRadius = UDim.new(0, 10)

-- Hover states
local TI = TweenInfo.new(0.15)
playBtn.MouseEnter:Connect(function()
    TweenService:Create(playBtn, TI, { BackgroundColor3 = C.BTN_HOV }):Play()
end)
playBtn.MouseLeave:Connect(function()
    TweenService:Create(playBtn, TI, { BackgroundColor3 = C.BTN_BG }):Play()
end)

-- ── Version label ─────────────────────────────────────────────────────────────
local ver = Instance.new("TextLabel", card)
ver.Name                 = "Version"
ver.Size                 = UDim2.new(1, 0, 0, 20)
ver.Position             = UDim2.new(0, 0, 1, -26)
ver.BackgroundTransparency = 1
ver.Text                 = "Alpha v0.1"
ver.TextColor3           = C.MUTED
ver.Font                 = Enum.Font.Gotham
ver.TextSize             = 13
ver.ZIndex               = 12

-- ── Fade-in animation ─────────────────────────────────────────────────────────
local dismissed = false
task.defer(function()
    TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0 }):Play()
    TweenService:Create(cardStroke, TweenInfo.new(0.4), { Transparency = 0.2 }):Play()
end)

-- ── Hide logic ────────────────────────────────────────────────────────────────
local function hideMenu()
    if dismissed then return end
    dismissed = true
    markMenuDismissed()
    task.spawn(function()
        menuTransitions:PlayInOut(0.6, function()
            gui.Enabled = false
        end, "Center", "Iris", 0.5)
    end)
end

-- Hide when game is actually running (safety net — player should have clicked Play already)
stateRemote.OnClientEvent:Connect(function(state)
    if state == "Open" or state == "EndOfDay" or state == "Intermission" then
        hideMenu()
    end
end)

-- Play button: notify server + hide menu
playBtn.Activated:Connect(function()
    hideMenu()
end)

if gui.Enabled == false then
    markMenuDismissed()
end

print("[MainMenuController] Ready.")
