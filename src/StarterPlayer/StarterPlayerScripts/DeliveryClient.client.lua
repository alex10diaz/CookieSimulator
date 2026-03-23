-- src/StarterPlayer/StarterPlayerScripts/DeliveryClient.client.lua
-- M1: Client-side box carry indicator and NPC delivery trigger.
-- Listens for BoxCreated (to know we have a box) and shows a ProximityPrompt
-- trigger for NPC delivery spots.

local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local boxCreated     = RemoteManager.Get("BoxCreated")
local deliverRemote  = RemoteManager.Get("DeliverBox")
local deliveryResult = RemoteManager.Get("DeliveryResult")
local forceDropBox   = RemoteManager.Get("ForceDropBox")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── State ────────────────────────────────────────────────────────────────────
local carriedBoxId = nil

-- ─── Cookie display names ─────────────────────────────────────────────────────
local COOKIE_DISPLAY = {
    pink_sugar           = "Pink Sugar",
    chocolate_chip       = "Choc Chip",
    birthday_cake        = "Birthday Cake",
    cookies_and_cream    = "Cookies & Cream",
    snickerdoodle        = "Snickerdoodle",
    lemon_blackraspberry = "Lemon Berry",
}

-- ─── Carry indicator ──────────────────────────────────────────────────────────
local function showCarryIndicator(box)
    local existing = playerGui:FindFirstChild("CarryIndicator")
    if existing then existing:Destroy() end

    local cookieName = COOKIE_DISPLAY[box.cookieId] or (box.cookieId or "cookie")

    local sg = Instance.new("ScreenGui")
    sg.Name                  = "CarryIndicator"
    sg.ResetOnSpawn          = false
    sg.DisplayOrder          = 2
    sg.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
    sg.Parent                = playerGui

    local card = Instance.new("Frame", sg)
    card.Size                   = UDim2.new(0, 340, 0, 48)
    card.Position               = UDim2.new(0.5, -170, 0.85, 0)
    card.BackgroundColor3       = Color3.fromRGB(14, 14, 26)
    card.BackgroundTransparency = 0
    card.BorderSizePixel        = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color     = Color3.fromRGB(255, 200, 0)
    cardStroke.Thickness = 1.5

    -- Left gold accent stripe
    local stripe = Instance.new("Frame", card)
    stripe.Size             = UDim2.new(0, 5, 1, 0)
    stripe.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    stripe.BorderSizePixel  = 0
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel", card)
    label.Size               = UDim2.new(1, -14, 1, 0)
    label.Position           = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3         = Color3.fromRGB(255, 215, 80)
    label.TextScaled         = true
    label.Font               = Enum.Font.GothamBold
    label.Text               = cookieName .. " box  —  walk to customer!"
    label.TextXAlignment     = Enum.TextXAlignment.Left
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

-- ─── ForceDropBox: NPC left before delivery ───────────────────────────────────
forceDropBox.OnClientEvent:Connect(function()
    if carriedBoxId then
        print("[DeliveryClient] Box #" .. carriedBoxId .. " dropped — customer left")
        carriedBoxId = nil
        clearCarryIndicator()
    end
end)

-- Delivery trigger is handled server-side via ProximityPrompt in PersistentNPCSpawner.
print("[DeliveryClient] Ready.")
