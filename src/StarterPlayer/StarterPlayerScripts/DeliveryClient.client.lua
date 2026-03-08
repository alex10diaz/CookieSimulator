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
local forceDropBox   = RemoteManager.Get("ForceDropBox")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── State ────────────────────────────────────────────────────────────────────
local carriedBoxId = nil

-- ─── Carrying indicator UI ────────────────────────────────────────────────────
local COOKIE_DISPLAY = {
    pink_sugar           = "Pink Sugar",
    chocolate_chip       = "Choc Chip",
    birthday_cake        = "Birthday Cake",
    cookies_and_cream    = "Cookies & Cream",
    snickerdoodle        = "Snickerdoodle",
    lemon_blackraspberry = "Lemon Berry",
}

local function showCarryIndicator(box)
    local existing = playerGui:FindFirstChild("CarryIndicator")
    if existing then existing:Destroy() end

    local cookieName = COOKIE_DISPLAY[box.cookieId] or (box.cookieId or "cookie")

    local sg = Instance.new("ScreenGui")
    sg.Name         = "CarryIndicator"
    sg.ResetOnSpawn = false
    sg.Parent       = playerGui

    local label = Instance.new("TextLabel")
    label.Size               = UDim2.new(0, 320, 0, 44)
    label.Position           = UDim2.new(0.5, -160, 0.85, 0)
    label.BackgroundColor3   = Color3.fromRGB(60, 120, 200)
    label.BackgroundTransparency = 0.1
    label.TextColor3         = Color3.fromRGB(255, 255, 255)
    label.TextScaled         = true
    label.Font               = Enum.Font.GothamBold
    label.Text               = cookieName .. " box — walk to customer!"
    label.BorderSizePixel    = 0
    label.Parent             = sg
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
end

local function clearCarryIndicator()
    local existing = playerGui:FindFirstChild("CarryIndicator")
    if existing then existing:Destroy() end
end

-- ─── BoxCreated: check if this is our box ────────────────────────────────────
boxCreated.OnClientEvent:Connect(function(box)
    if box and box.carrier == player.Name then
        carriedBoxId = box.boxId
        showCarryIndicator(box)
        print("[DeliveryClient] Carrying box #" .. box.boxId .. " (" .. tostring(box.cookieId) .. ")")
    end
end)

-- ─── DeliveryResult: clear carry state ───────────────────────────────────────
deliveryResult.OnClientEvent:Connect(function()
    carriedBoxId = nil
    clearCarryIndicator()
end)

-- ─── ForceDropBox: NPC left before delivery — drop carried box ───────────────
forceDropBox.OnClientEvent:Connect(function()
    if carriedBoxId then
        print("[DeliveryClient] Box #" .. carriedBoxId .. " dropped — customer left")
        carriedBoxId = nil
        clearCarryIndicator()
    end
end)

-- Delivery trigger is handled server-side via ProximityPrompt in PersistentNPCSpawner.
-- No client-side remote fire needed.

print("[DeliveryClient] Ready.")
