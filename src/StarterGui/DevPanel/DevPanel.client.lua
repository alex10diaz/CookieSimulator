-- TEMP_DevPanel.client.lua - DEV ONLY, remove before launch.
-- Floating owner-only panel for data reset and note-taking during playtests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local stateRemote = RemoteManager.Get("GameStateChanged")
local resetRemote = RemoteManager.Get("DevAdmin_ResetData")
local noteRemote = RemoteManager.Get("DevAdmin_Note")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function isAuthorized()
    if game.CreatorType == Enum.CreatorType.User then
        return player.UserId == game.CreatorId
    end

    if game.CreatorType == Enum.CreatorType.Group then
        local ok, rank = pcall(function()
            return player:GetRankInGroup(game.CreatorId)
        end)
        return ok and rank == 255
    end

    return false
end

if not isAuthorized() then
    return
end

local BG = Color3.fromRGB(15, 15, 25)
local BORDER = Color3.fromRGB(255, 200, 0)
local BTN = Color3.fromRGB(30, 30, 50)
local BTN_H = Color3.fromRGB(50, 50, 80)
local RED = Color3.fromRGB(180, 50, 50)
local TEXT = Color3.fromRGB(220, 220, 240)
local GOLD = Color3.fromRGB(255, 200, 0)

local sg = Instance.new("ScreenGui")
sg.Name = "DevPanel"
sg.ResetOnSpawn = false
sg.DisplayOrder = 100
sg.IgnoreGuiInset = false
sg.Parent = playerGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "DevToggle"
toggleBtn.Size = UDim2.new(0, 52, 0, 28)
toggleBtn.AnchorPoint = Vector2.new(1, 0.5)
toggleBtn.Position = UDim2.new(1, -16, 0.5, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
toggleBtn.TextColor3 = GOLD
toggleBtn.Text = "DEV"
toggleBtn.TextSize = 14
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.BorderSizePixel = 0
toggleBtn.ZIndex = 10
toggleBtn.Parent = sg
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(120, 30, 30)
toggleStroke.Thickness = 1.5
toggleStroke.Parent = toggleBtn

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 280, 0, 220)
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -76, 0.5, 0)
panel.BackgroundColor3 = BG
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 9
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = BORDER
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 32)
header.BackgroundColor3 = GOLD
header.BorderSizePixel = 0
header.ZIndex = 10
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local headerFlat = Instance.new("Frame")
headerFlat.Size = UDim2.new(1, 0, 0.5, 0)
headerFlat.Position = UDim2.new(0, 0, 0.5, 0)
headerFlat.BackgroundColor3 = GOLD
headerFlat.BorderSizePixel = 0
headerFlat.Parent = header

local headerLabel = Instance.new("TextLabel")
headerLabel.Size = UDim2.new(1, -8, 1, 0)
headerLabel.Position = UDim2.new(0, 8, 0, 0)
headerLabel.BackgroundTransparency = 1
headerLabel.TextColor3 = Color3.fromRGB(15, 10, 0)
headerLabel.Font = Enum.Font.GothamBold
headerLabel.TextScaled = true
headerLabel.Text = "DEV PANEL"
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.ZIndex = 11
headerLabel.Parent = header

local stateLabel = Instance.new("TextLabel")
stateLabel.Name = "StateLabel"
stateLabel.Size = UDim2.new(1, -16, 0, 22)
stateLabel.Position = UDim2.new(0, 8, 0, 38)
stateLabel.BackgroundTransparency = 1
stateLabel.TextColor3 = Color3.fromRGB(160, 220, 160)
stateLabel.Font = Enum.Font.Gotham
stateLabel.TextSize = 13
stateLabel.TextXAlignment = Enum.TextXAlignment.Left
stateLabel.Text = "State: -"
stateLabel.ZIndex = 10
stateLabel.Parent = panel

local nextY = 66

local function makeButton(label, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -16, 0, 30)
    button.Position = UDim2.new(0, 8, 0, nextY)
    button.BackgroundColor3 = color or BTN
    button.TextColor3 = TEXT
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.Text = label
    button.BorderSizePixel = 0
    button.ZIndex = 10
    button.Parent = panel
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)

    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = BTN_H
    end)

    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = color or BTN
    end)

    nextY += 34
    return button
end

local function makeDivider()
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -16, 0, 1)
    divider.Position = UDim2.new(0, 8, 0, nextY + 4)
    divider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    divider.BorderSizePixel = 0
    divider.ZIndex = 10
    divider.Parent = panel
    nextY += 14
end

local resetButton = makeButton("Reset My Data", RED)
local confirmReset = false

resetButton.MouseButton1Click:Connect(function()
    if not confirmReset then
        confirmReset = true
        resetButton.Text = "CONFIRM RESET?"

        task.delay(3, function()
            if confirmReset then
                confirmReset = false
                resetButton.Text = "Reset My Data"
            end
        end)

        return
    end

    confirmReset = false
    resetButton.Text = "Reset My Data"
    resetRemote:FireServer()
end)

makeDivider()

local noteBox = Instance.new("TextBox")
noteBox.Size = UDim2.new(1, -16, 0, 64)
noteBox.Position = UDim2.new(0, 8, 0, nextY)
noteBox.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
noteBox.TextColor3 = TEXT
noteBox.PlaceholderText = "Type a note..."
noteBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 110)
noteBox.Font = Enum.Font.Gotham
noteBox.TextSize = 13
noteBox.BorderSizePixel = 0
noteBox.ClearTextOnFocus = false
noteBox.TextXAlignment = Enum.TextXAlignment.Left
noteBox.TextYAlignment = Enum.TextYAlignment.Top
noteBox.MultiLine = true
noteBox.ZIndex = 10
noteBox.Parent = panel
Instance.new("UICorner", noteBox).CornerRadius = UDim.new(0, 6)

local noteStroke = Instance.new("UIStroke")
noteStroke.Color = Color3.fromRGB(60, 60, 90)
noteStroke.Thickness = 1
noteStroke.Parent = noteBox

local notePadding = Instance.new("UIPadding")
notePadding.PaddingLeft = UDim.new(0, 6)
notePadding.PaddingTop = UDim.new(0, 6)
notePadding.Parent = noteBox
nextY += 68

local submitButton = makeButton("Submit Note", BTN)

local function submitNote()
    local text = noteBox.Text
    if not text or text:match("^%s*$") then
        return
    end

    noteRemote:FireServer(text)
    noteBox.Text = ""
end

submitButton.MouseButton1Click:Connect(submitNote)

noteBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        submitNote()
    end
end)

panel.Size = UDim2.new(0, 280, 0, nextY + 12)

toggleBtn.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
end)

stateRemote.OnClientEvent:Connect(function(state, timeRemaining)
    if state then
        local mins = math.floor((timeRemaining or 0) / 60)
        local secs = (timeRemaining or 0) % 60
        stateLabel.Text = string.format("State: %s  %d:%02d", state, mins, secs)
    end
end)

task.defer(function()
    local state = workspace:GetAttribute("GameState")
    if state then
        stateLabel.Text = "State: " .. state
    end
end)

print("[TEMP_DevPanel] Dev panel ready for authorized owner.")
