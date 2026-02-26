-- src/StarterPlayer/StarterPlayerScripts/DeliveryClient.client.lua
-- M1: Client-side box carry indicator and NPC delivery trigger.
-- Listens for BoxCreated (to know we have a box) and shows a ProximityPrompt
-- trigger for NPC delivery spots.

local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local boxCreated     = RemoteManager.Get("BoxCreated")
local deliverRemote  = RemoteManager.Get("DeliverBox")
local deliveryResult = RemoteManager.Get("DeliveryResult")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── State ────────────────────────────────────────────────────────────────────
local carriedBoxId = nil

-- ─── Carrying indicator UI ────────────────────────────────────────────────────
local function showCarryIndicator(boxId)
    local existing = playerGui:FindFirstChild("CarryIndicator")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name         = "CarryIndicator"
    sg.ResetOnSpawn = false
    sg.Parent       = playerGui

    local label = Instance.new("TextLabel")
    label.Size              = UDim2.new(0, 280, 0, 44)
    label.Position          = UDim2.new(0.5, -140, 0.85, 0)
    label.BackgroundColor3  = Color3.fromRGB(60, 120, 200)
    label.BackgroundTransparency = 0.1
    label.TextColor3        = Color3.fromRGB(255, 255, 255)
    label.TextScaled        = true
    label.Font              = Enum.Font.GothamBold
    label.Text              = "Carrying box #" .. boxId .. " — deliver to customer!"
    label.BorderSizePixel   = 0
    label.Parent            = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = label
end

local function clearCarryIndicator()
    local existing = playerGui:FindFirstChild("CarryIndicator")
    if existing then existing:Destroy() end
end

-- ─── BoxCreated: check if this is our box ────────────────────────────────────
boxCreated.OnClientEvent:Connect(function(box)
    if box and box.carrier == player.Name then
        carriedBoxId = box.boxId
        showCarryIndicator(box.boxId)
        print("[DeliveryClient] Carrying box #" .. box.boxId)
    end
end)

-- ─── DeliveryResult: clear carry state ───────────────────────────────────────
deliveryResult.OnClientEvent:Connect(function()
    carriedBoxId = nil
    clearCarryIndicator()
end)

-- ─── ProximityPrompt: NPC delivery trigger ────────────────────────────────────
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
    if triggeringPlayer ~= player then return end
    if prompt.Name ~= "DeliveryPrompt" then return end
    if not carriedBoxId then
        print("[DeliveryClient] No box to deliver")
        return
    end
    deliverRemote:FireServer(carriedBoxId)
    print("[DeliveryClient] Fired DeliverBox for box #" .. carriedBoxId)
end)

print("[DeliveryClient] Ready.")
