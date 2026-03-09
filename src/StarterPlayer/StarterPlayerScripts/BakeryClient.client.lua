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

-- ── LEVEL-UP TOAST ───────────────────────────────────────────────
local toast = HUD and HUD:FindFirstChild("BakeryLevelToast", true)

local function showLevelUpToast(level)
    updateLevelLabel(level)
    if not toast then return end
    toast.Text    = "🏪 Bakery Level Up! Lv." .. tostring(level)
    toast.Visible = true
    task.delay(3, function()
        toast.Visible = false
    end)
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
