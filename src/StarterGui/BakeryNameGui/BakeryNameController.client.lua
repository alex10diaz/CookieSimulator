-- BakeryNameGui/BakeryNameController (LocalScript)
-- Shows on first join if player has no bakery name set.

local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local setNameRemote     = RemoteManager.Get("SetBakeryName")
local nameResultRemote  = RemoteManager.Get("BakeryNameResult")
local dataInitRemote    = RemoteManager.Get("PlayerDataInit")

local gui        = script.Parent
local dialog     = gui:WaitForChild("Dialog")
local nameBox    = dialog:WaitForChild("NameBox")
local errorLbl   = dialog:WaitForChild("ErrorLabel")
local confirmBtn = dialog:WaitForChild("ConfirmButton")

gui.Enabled = false
errorLbl.Text = ""

local TI = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function showDialog()
    gui.Enabled = true
    local origPos = dialog.Position
    dialog.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale + 0.08, origPos.Y.Offset)
    TweenService:Create(dialog, TI, { Position = origPos }):Play()
    task.defer(function() nameBox:CaptureFocus() end)
end

local function tryConfirm()
    local name = nameBox.Text:match("^%s*(.-)%s*$")
    if #name < 2  then errorLbl.Text = "At least 2 characters required"; return end
    if #name > 24 then errorLbl.Text = "Maximum 24 characters"; return end
    if not name:match("%a") then errorLbl.Text = "Must contain letters"; return end
    errorLbl.Text = "Saving..."
    confirmBtn.Active = false
    setNameRemote:FireServer(name)
end

confirmBtn.Activated:Connect(tryConfirm)
nameBox.FocusLost:Connect(function(entered) if entered then tryConfirm() end end)

dataInitRemote.OnClientEvent:Connect(function(data)
    if not data.bakeryName or data.bakeryName == "" then
        showDialog()
    end
end)

nameResultRemote.OnClientEvent:Connect(function(success, nameOrError)
    if success then
        gui.Enabled = false
    else
        errorLbl.Text = nameOrError or "Invalid name"
        confirmBtn.Active = true
    end
end)

print("[BakeryNameController] Ready.")
