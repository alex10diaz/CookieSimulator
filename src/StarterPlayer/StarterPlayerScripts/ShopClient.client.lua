-- StarterPlayerScripts/ShopClient (LocalScript)
-- Handles the back room shop GUI: two tabs (Upgrades | Cosmetics).
-- Receives player unlock data via PlayerDataInit and PurchaseResult remotes.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local purchaseRemote  = RemoteManager.Get("PurchaseItem")
local resultRemote    = RemoteManager.Get("PurchaseResult")
local dataInitRemote  = RemoteManager.Get("PlayerDataInit")

local player   = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local ShopGui  = PlayerGui:WaitForChild("ShopGui", 30)
if not ShopGui then warn("[ShopClient] ShopGui not found"); return end

local bg         = ShopGui:WaitForChild("Background")
local closeBtn   = bg:WaitForChild("CloseButton")
local coinsLabel = bg:WaitForChild("CoinsLabel")
local tabUpgrade = bg:WaitForChild("TabUpgrades")
local tabCosm    = bg:WaitForChild("TabCosmetics")
local itemList   = bg:WaitForChild("ItemList")  -- ScrollingFrame

-- ── CLIENT STATE ────────────────────────────────────────────────
local ownedStations  = {}
local ownedCosmetics = {}
local playerCoins    = 0
local activeTab      = "Upgrades"

-- ── CATALOG (mirrors UnlockManager — static) ────────────────────
local CATALOG = {
    { id = "tip_boost_1",      tab = "Upgrades",  name = "Tip Boost I",          price = 3000, desc = "+10% NPC tips each shift",              requires = nil },
    { id = "patience_boost_1", tab = "Upgrades",  name = "Patient Customers I",  price = 2500, desc = "+10s NPC patience",                      requires = nil },
    { id = "tip_boost_2",      tab = "Upgrades",  name = "Tip Boost II",         price = 6000, desc = "+20% total NPC tips (requires Boost I)",  requires = "tip_boost_1" },
    { id = "patience_boost_2", tab = "Upgrades",  name = "Patient Customers II", price = 5000, desc = "+20s total patience (requires Boost I)",   requires = "patience_boost_1" },
    { id = "hat_chef",         tab = "Cosmetics", name = "Chef Hat",             price = 500,  desc = "A classic tall chef's hat",               requires = nil },
    { id = "hat_beret",        tab = "Cosmetics", name = "Baker's Beret",        price = 750,  desc = "A stylish baker's beret",                 requires = nil },
    { id = "apron_classic",    tab = "Cosmetics", name = "Classic Apron",        price = 600,  desc = "A timeless white baker's apron",          requires = nil },
    { id = "apron_pink",       tab = "Cosmetics", name = "Pink Apron",           price = 800,  desc = "Show your sweet side",                    requires = nil },
    { id = "apron_cookie",     tab = "Cosmetics", name = "Cookie Print Apron",   price = 1200, desc = "Covered in tiny cookie prints",           requires = nil },
    { id = "hat_cap",          tab = "Cosmetics", name = "Baker's Cap",          price = 400,  desc = "Simple and clean baseball-style cap",     requires = nil },
}

-- ── HELPERS ─────────────────────────────────────────────────────
local function isOwned(item)
    local list = item.tab == "Cosmetics" and ownedCosmetics or ownedStations
    for _, id in ipairs(list) do
        if id == item.id then return true end
    end
    return false
end

local function canAfford(item)
    return playerCoins >= item.price
end

local function requiresMet(item)
    if not item.requires then return true end
    -- Check both lists
    for _, id in ipairs(ownedStations)  do if id == item.requires then return true end end
    for _, id in ipairs(ownedCosmetics) do if id == item.requires then return true end end
    return false
end

local function updateCoinsLabel()
    coinsLabel.Text = "💰 " .. tostring(playerCoins) .. " coins"
end

-- ── RENDER ITEMS ────────────────────────────────────────────────
local function clearList()
    for _, child in ipairs(itemList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
end

local function renderItems()
    clearList()
    local yOffset = 0
    local ROW_H   = 72

    for _, item in ipairs(CATALOG) do
        if item.tab ~= activeTab then continue end

        local owned   = isOwned(item)
        local afford  = canAfford(item)
        local prereq  = requiresMet(item)

        -- Row frame
        local row = Instance.new("Frame")
        row.Name            = item.id
        row.Size            = UDim2.new(1, -8, 0, ROW_H - 4)
        row.Position        = UDim2.new(0, 4, 0, yOffset + 2)
        row.BackgroundColor3 = owned and Color3.fromRGB(50, 80, 50)
                              or Color3.fromRGB(45, 45, 55)
        row.BorderSizePixel = 0
        row.Parent          = itemList

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent       = row

        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size            = UDim2.new(0.55, 0, 0.45, 0)
        nameLabel.Position        = UDim2.new(0.02, 0, 0.05, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text            = item.name
        nameLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
        nameLabel.Font            = Enum.Font.GothamBold
        nameLabel.TextSize        = 14
        nameLabel.TextXAlignment  = Enum.TextXAlignment.Left
        nameLabel.Parent          = row

        -- Description
        local descLabel = Instance.new("TextLabel")
        descLabel.Size            = UDim2.new(0.7, 0, 0.45, 0)
        descLabel.Position        = UDim2.new(0.02, 0, 0.52, 0)
        descLabel.BackgroundTransparency = 1
        descLabel.Text            = item.desc
        descLabel.TextColor3      = Color3.fromRGB(180, 180, 200)
        descLabel.Font            = Enum.Font.Gotham
        descLabel.TextSize        = 11
        descLabel.TextXAlignment  = Enum.TextXAlignment.Left
        descLabel.TextWrapped     = true
        descLabel.Parent          = row

        -- Price label
        local priceLabel = Instance.new("TextLabel")
        priceLabel.Size            = UDim2.new(0.22, 0, 0.4, 0)
        priceLabel.Position        = UDim2.new(0.73, 0, 0.05, 0)
        priceLabel.BackgroundTransparency = 1
        priceLabel.Text            = owned and "✔ Owned" or ("💰 " .. item.price)
        priceLabel.TextColor3      = owned and Color3.fromRGB(100, 220, 100)
                                    or (afford and prereq and Color3.fromRGB(255, 220, 80)
                                        or Color3.fromRGB(160, 160, 160))
        priceLabel.Font            = Enum.Font.GothamBold
        priceLabel.TextSize        = 13
        priceLabel.TextXAlignment  = Enum.TextXAlignment.Center
        priceLabel.Parent          = row

        -- Buy button (hidden if owned)
        if not owned then
            local buyBtn = Instance.new("TextButton")
            buyBtn.Size            = UDim2.new(0.22, 0, 0.42, 0)
            buyBtn.Position        = UDim2.new(0.73, 0, 0.52, 0)
            buyBtn.BackgroundColor3 = (afford and prereq)
                                      and Color3.fromRGB(80, 180, 80)
                                      or  Color3.fromRGB(80, 80, 80)
            buyBtn.Text            = (not prereq) and "Locked" or "Buy"
            buyBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
            buyBtn.Font            = Enum.Font.GothamBold
            buyBtn.TextSize        = 13
            buyBtn.AutoButtonColor = afford and prereq
            buyBtn.Parent          = row

            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0, 5)
            bc.Parent       = buyBtn

            if afford and prereq then
                buyBtn.MouseButton1Click:Connect(function()
                    buyBtn.Text           = "..."
                    buyBtn.AutoButtonColor = false
                    purchaseRemote:FireServer(item.id)
                end)
            end
        end

        yOffset += ROW_H
    end

    itemList.CanvasSize = UDim2.new(0, 0, 0, yOffset + 4)
end

-- ── TAB SWITCHING ───────────────────────────────────────────────
local function setTab(tab)
    activeTab = tab
    tabUpgrade.BackgroundColor3 = tab == "Upgrades"
        and Color3.fromRGB(80, 160, 255) or Color3.fromRGB(50, 50, 65)
    tabCosm.BackgroundColor3 = tab == "Cosmetics"
        and Color3.fromRGB(80, 160, 255) or Color3.fromRGB(50, 50, 65)
    renderItems()
end

tabUpgrade.MouseButton1Click:Connect(function() setTab("Upgrades") end)
tabCosm.MouseButton1Click:Connect(function()   setTab("Cosmetics") end)

-- ── OPEN / CLOSE ────────────────────────────────────────────────
local function openShop()
    ShopGui.Enabled = true
    updateCoinsLabel()
    setTab("Upgrades")
end

local function closeShop()
    ShopGui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(closeShop)
ShopGui.Enabled = false

-- ── PROXIMITY PROMPT (back room shop terminal) ──────────────────
-- The prompt is on a Part named "ShopTerminal" inside Workspace/BackRoom
-- We wait for it in case it loads after this script
task.spawn(function()
    local ws = game:GetService("Workspace")
    local backRoom = ws:WaitForChild("BackRoom", 30)
    if not backRoom then warn("[ShopClient] BackRoom not found"); return end
    local terminal = backRoom:WaitForChild("ShopTerminal", 30)
    if not terminal then warn("[ShopClient] ShopTerminal not found"); return end
    local prompt = terminal:WaitForChild("ShopPrompt", 10)
    if not prompt then warn("[ShopClient] ShopPrompt not found"); return end
    prompt.Triggered:Connect(openShop)
end)

-- ── REMOTES ─────────────────────────────────────────────────────
-- Receive initial data on join
dataInitRemote.OnClientEvent:Connect(function(data)
    playerCoins    = data.coins or 0
    ownedStations  = data.unlockedStations  or {}
    ownedCosmetics = data.unlockedCosmetics or {}
end)

-- Receive HUD coin updates (keep in sync)
local hudRemote = RemoteManager.Get("HUDUpdate")
hudRemote.OnClientEvent:Connect(function(coins, xp, activeOrderName)
    if coins then
        playerCoins = coins
        if ShopGui.Enabled then updateCoinsLabel() end
    end
end)

-- Receive purchase results
resultRemote.OnClientEvent:Connect(function(data)
    if data.success then
        playerCoins    = data.newCoins
        ownedStations  = data.unlockedStations  or ownedStations
        ownedCosmetics = data.unlockedCosmetics or ownedCosmetics
        updateCoinsLabel()
        renderItems()  -- refresh Buy/Owned states
    else
        -- Re-render to restore button state (remove "...")
        renderItems()
        -- Optional: show brief error message in UI
        warn("[ShopClient] Purchase failed:", data.reason)
    end
end)
