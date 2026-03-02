-- src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua
-- Shows the tutorial step overlay pushed by TutorialController (server).
-- Fires TutorialComplete when the player presses Skip.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Build UI ────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name         = "TutorialGui"
sg.ResetOnSpawn = false
sg.Enabled      = false
sg.ZIndex       = 10
sg.Parent       = playerGui

local panel = Instance.new("Frame")
panel.Name             = "TutorialPanel"
panel.Size             = UDim2.new(0, 420, 0, 110)
panel.Position         = UDim2.new(0, 14, 1, -130)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel  = 0
panel.Parent           = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

-- Step indicator (top-left)
local stepLbl = Instance.new("TextLabel")
stepLbl.Name                   = "StepLabel"
stepLbl.Size                   = UDim2.new(0.55, 0, 0, 26)
stepLbl.Position               = UDim2.new(0, 12, 0, 10)
stepLbl.BackgroundTransparency = 1
stepLbl.TextColor3             = Color3.fromRGB(255, 200, 60)
stepLbl.TextScaled             = true
stepLbl.Font                   = Enum.Font.GothamBold
stepLbl.TextXAlignment         = Enum.TextXAlignment.Left
stepLbl.Text                   = "Step 1 / 3"
stepLbl.Parent                 = panel

-- Skip button (top-right)
local skipBtn = Instance.new("TextButton")
skipBtn.Name             = "SkipButton"
skipBtn.Size             = UDim2.new(0, 80, 0, 28)
skipBtn.Position         = UDim2.new(1, -92, 0, 8)
skipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
skipBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
skipBtn.TextScaled       = true
skipBtn.Font             = Enum.Font.Gotham
skipBtn.Text             = "Skip"
skipBtn.BorderSizePixel  = 0
skipBtn.Parent           = panel
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 8)

-- Instruction text
local msgLbl = Instance.new("TextLabel")
msgLbl.Name                   = "MessageLabel"
msgLbl.Size                   = UDim2.new(1, -24, 0, 56)
msgLbl.Position               = UDim2.new(0, 12, 0, 46)
msgLbl.BackgroundTransparency = 1
msgLbl.TextColor3             = Color3.fromRGB(240, 240, 240)
msgLbl.TextWrapped            = true
msgLbl.TextScaled             = false
msgLbl.TextSize               = 18
msgLbl.Font                   = Enum.Font.Gotham
msgLbl.TextXAlignment         = Enum.TextXAlignment.Left
msgLbl.Text                   = ""
msgLbl.Parent                 = panel

-- ─── Logic ───────────────────────────────────────────────────────────────────
tutorialStepRemote.OnClientEvent:Connect(function(data)
    if not data or data.step == 0 then
        sg.Enabled = false
        return
    end
    stepLbl.Text = "Step " .. data.step .. " / " .. (data.total or 3)
    msgLbl.Text  = data.msg or ""
    sg.Enabled   = true
end)

skipBtn.MouseButton1Click:Connect(function()
    sg.Enabled = false
    tutorialDoneRemote:FireServer()
end)

print("[TutorialUI] Ready.")
