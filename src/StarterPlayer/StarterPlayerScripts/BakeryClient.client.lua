-- StarterPlayerScripts/BakeryClient (LocalScript)
-- Handles bakery naming dialog (first join) and bakery level HUD label.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local setNameRemote      = RemoteManager.Get("SetBakeryName")
local nameResultRemote   = RemoteManager.Get("BakeryNameResult")
local levelUpRemote      = RemoteManager.Get("BakeryLevelUp")
local dataInitRemote     = RemoteManager.Get("PlayerDataInit")
local updateNameplateRem = RemoteManager.Get("UpdateNameplate")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── HUD LABEL (bakery level) ─────────────────────────────────────
local HUD             = PlayerGui:WaitForChild("HUD", 30)
local bakeryLevelLabel = HUD and HUD:FindFirstChild("BakeryLevelLabel", true)

local function updateLevelLabel(level)
    if bakeryLevelLabel then
        bakeryLevelLabel.Text = "🏪 Lv." .. tostring(level)
    end
end

-- ── NAMING DIALOG ────────────────────────────────────────────────
local BakeryNameGui = PlayerGui:WaitForChild("BakeryNameGui", 30)
local dialog, titleLabel, subLabel, nameBox, confirmBtn, errorLabel

if BakeryNameGui then
    dialog      = BakeryNameGui:WaitForChild("Dialog")
    titleLabel  = dialog:WaitForChild("Title")
    subLabel    = dialog:WaitForChild("Subtitle")
    nameBox     = dialog:WaitForChild("NameBox")
    confirmBtn  = dialog:WaitForChild("ConfirmButton")
    errorLabel  = dialog:WaitForChild("ErrorLabel")
end

local function showDialog()
    if not BakeryNameGui then return end
    BakeryNameGui.Enabled = true
    nameBox:CaptureFocus()
end

local function hideDialog()
    if not BakeryNameGui then return end
    BakeryNameGui.Enabled = false
end

local function showError(msg)
    if not errorLabel then return end
    errorLabel.Text    = msg
    errorLabel.Visible = true
end

local function clearError()
    if not errorLabel then return end
    errorLabel.Visible = false
end

-- ── LEVEL-UP CELEBRATION SCREEN ──────────────────────────────────
local celebrationGui = nil
local celebrationActive = false

local function showLevelUpToast(level)
    updateLevelLabel(level)

    -- Only one celebration at a time
    if celebrationActive then return end
    celebrationActive = true

    -- Build ScreenGui at runtime
    local gui = Instance.new("ScreenGui")
    gui.Name            = "BakeryLevelUpCelebration"
    gui.DisplayOrder          = 30
    gui.ResetOnSpawn          = false
    gui.IgnoreGuiInset        = true
    gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
    gui.Parent                = PlayerGui

    -- Dark backdrop
    local backdrop = Instance.new("Frame")
    backdrop.Name              = "Backdrop"
    backdrop.Size              = UDim2.fromScale(1, 1)
    backdrop.Position          = UDim2.fromScale(0, 0)
    backdrop.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.45
    backdrop.BorderSizePixel   = 0
    backdrop.ZIndex            = 1
    backdrop.Parent            = gui

    -- Center card
    local card = Instance.new("Frame")
    card.Name              = "Card"
    card.AnchorPoint       = Vector2.new(0.5, 0.5)
    card.Position          = UDim2.fromScale(0.5, 0.5)
    card.Size              = UDim2.new(0, 420, 0, 260)
    card.BackgroundColor3  = Color3.fromRGB(30, 20, 10)
    card.BorderSizePixel   = 0
    card.ZIndex            = 2
    card.Parent            = gui

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 20)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color     = Color3.fromRGB(255, 200, 60)
    cardStroke.Thickness = 3
    cardStroke.Parent    = card

    -- "BAKERY LEVEL UP!" header
    local header = Instance.new("TextLabel")
    header.Name              = "Header"
    header.Size              = UDim2.new(1, 0, 0, 52)
    header.Position          = UDim2.new(0, 0, 0, 20)
    header.BackgroundTransparency = 1
    header.Text              = "BAKERY LEVEL UP!"
    header.TextColor3        = Color3.fromRGB(255, 200, 60)
    header.TextScaled        = true
    header.Font              = Enum.Font.GothamBold
    header.ZIndex            = 3
    header.Parent            = card

    -- Big level number
    local levelNum = Instance.new("TextLabel")
    levelNum.Name            = "LevelNum"
    levelNum.Size            = UDim2.new(1, 0, 0, 110)
    levelNum.Position        = UDim2.new(0, 0, 0, 72)
    levelNum.BackgroundTransparency = 1
    levelNum.Text            = tostring(level)
    levelNum.TextColor3      = Color3.fromRGB(255, 255, 255)
    levelNum.TextScaled      = true
    levelNum.Font            = Enum.Font.GothamBold
    levelNum.ZIndex          = 3
    levelNum.Parent          = card

    -- Subtitle
    local sub = Instance.new("TextLabel")
    sub.Name                 = "Sub"
    sub.Size                 = UDim2.new(1, -20, 0, 36)
    sub.Position             = UDim2.new(0, 10, 0, 188)
    sub.BackgroundTransparency = 1
    sub.Text                 = "Keep baking to grow your empire!"
    sub.TextColor3           = Color3.fromRGB(200, 180, 140)
    sub.TextScaled           = true
    sub.Font                 = Enum.Font.Gotham
    sub.ZIndex               = 3
    sub.Parent               = card

    -- Tap to dismiss hint
    local hint = Instance.new("TextLabel")
    hint.Name                = "Hint"
    hint.Size                = UDim2.new(1, 0, 0, 24)
    hint.Position            = UDim2.new(0, 0, 1, -30)
    hint.BackgroundTransparency = 1
    hint.Text                = "Tap anywhere to continue"
    hint.TextColor3          = Color3.fromRGB(150, 130, 100)
    hint.TextScaled          = true
    hint.Font                = Enum.Font.Gotham
    hint.ZIndex              = 3
    hint.Parent              = gui

    -- Bounce in animation: scale 0 → 1
    card.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(card,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 420, 0, 260) }
    ):Play()

    local function dismiss()
        if not gui.Parent then return end
        local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(backdrop, fadeInfo, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(card, fadeInfo, { Size = UDim2.new(0, 0, 0, 0) }):Play()
        task.delay(0.35, function()
            gui:Destroy()
            celebrationActive = false
        end)
    end

    -- Click anywhere to dismiss early
    backdrop.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dismiss()
        end
    end)

    -- Auto-dismiss after 3 seconds
    task.delay(3, dismiss)
end

-- ── REMOTE LISTENERS ─────────────────────────────────────────────
dataInitRemote.OnClientEvent:Connect(function(data)
    if data.bakeryLevel then updateLevelLabel(data.bakeryLevel) end
    -- Show naming dialog only if bakery name is not yet set
    if data.bakeryName == "" then
        task.defer(showDialog)
    end
end)

levelUpRemote.OnClientEvent:Connect(function(newLevel)
    showLevelUpToast(newLevel)
end)

nameResultRemote.OnClientEvent:Connect(function(success, result)
    if success then
        hideDialog()
        clearError()
        print("[BakeryClient] Bakery named:", result)
    else
        showError(result)
        confirmBtn.Text = "Confirm"
        confirmBtn.AutoButtonColor = true
    end
end)

-- ── CONFIRM BUTTON ───────────────────────────────────────────────
if confirmBtn then
    confirmBtn.MouseButton1Click:Connect(function()
        local name = nameBox.Text
        if #name:match("^%s*(.-)%s*$") < 2 then
            showError("Name must be at least 2 characters")
            return
        end
        clearError()
        confirmBtn.Text           = "..."
        confirmBtn.AutoButtonColor = false
        setNameRemote:FireServer(name)
    end)

    nameBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            confirmBtn.MouseButton1Click:Fire()
        end
    end)
end

-- ── NAMEPLATE UPDATE ─────────────────────────────────────────────
local function setNameplateText(name)
    local part = workspace:FindFirstChild("Store Nameplate", true)
    if not part then return end
    local gui = part:FindFirstChildOfClass("SurfaceGui")
    if not gui then return end
    local label = gui:FindFirstChildOfClass("TextLabel")
    if label then label.Text = name end
end

updateNameplateRem.OnClientEvent:Connect(function(name)
    setNameplateText(name)
end)
