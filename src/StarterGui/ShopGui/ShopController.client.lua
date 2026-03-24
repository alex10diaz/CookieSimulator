-- ShopGui/ShopController (LocalScript)
-- Opens via ShopPrompt in back room. Tabs: Upgrades / Cosmetics.

local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PPS               = game:GetService("ProximityPromptService")

local RemoteManager    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local purchaseRemote   = RemoteManager.Get("PurchaseItem")
local purchaseResult   = RemoteManager.Get("PurchaseResult")
local dataInitRemote   = RemoteManager.Get("PlayerDataInit")

local CATALOG = {
    {id="tip_boost_1",        tab="Upgrades",  name="Tip Boost I",          price=3000, desc="+10% NPC tips each shift"},
    {id="patience_boost_1",   tab="Upgrades",  name="Patient Customers I",  price=2500, desc="+10s NPC patience"},
    {id="tip_boost_2",        tab="Upgrades",  name="Tip Boost II",         price=6000, desc="+20% NPC tips (needs Boost I)",  requires="tip_boost_1"},
    {id="patience_boost_2",   tab="Upgrades",  name="Patient Customers II", price=5000, desc="+20s patience (needs Boost I)",  requires="patience_boost_1"},
    {id="hat_chef",           tab="Cosmetics", name="Chef Hat",             price=500,  desc="A classic tall chef's hat"},
    {id="hat_beret",          tab="Cosmetics", name="Baker's Beret",        price=750,  desc="A stylish baker's beret"},
    {id="hat_cap",            tab="Cosmetics", name="Baker's Cap",          price=400,  desc="Simple and clean baseball-style cap"},
    {id="apron_classic",      tab="Cosmetics", name="Classic Apron",        price=600,  desc="A timeless white baker's apron"},
    {id="apron_pink",         tab="Cosmetics", name="Pink Apron",           price=800,  desc="Show your sweet side"},
    {id="apron_cookie",       tab="Cosmetics", name="Cookie Print Apron",   price=1200, desc="Covered in tiny cookie prints"},
    {id="hat_station_mix",    tab="Cosmetics", name="Flour Dusted Cap",     price=0,    desc="Earned: Mixer Lv.3",        source="station"},
    {id="apron_station_bake", tab="Cosmetics", name="Oven Master Apron",    price=0,    desc="Earned: Baker Lv.3",        source="station"},
    {id="hat_station_dec",    tab="Cosmetics", name="Decorator's Crown",    price=0,    desc="Earned: Decorator Lv.5",    source="station"},
    {id="apron_station_frost",tab="Cosmetics", name="Glazer's Apron",       price=0,    desc="Earned: Glazer Lv.3",       source="station"},
}

local C = {
    CARD  = Color3.fromRGB(22,22,40),
    GOLD  = Color3.fromRGB(255,200,0),
    GREEN = Color3.fromRGB(80,220,100),
    MUTED = Color3.fromRGB(140,140,165),
    WHITE = Color3.fromRGB(255,255,255),
}

local gui      = script.Parent
local bg       = gui:WaitForChild("Background")
local coinLbl  = bg:WaitForChild("CoinsLabel")
local closeBtn = bg:WaitForChild("CloseButton")
local tabUpg   = bg:WaitForChild("TabUpgrades")
local tabCos   = bg:WaitForChild("TabCosmetics")
local itemList = bg:WaitForChild("ItemList")

gui.Enabled = false

local playerCoins    = 0
local ownedStations  = {}
local ownedCosmetics = {}
local activeTab      = "Upgrades"
local purchasing     = false

local function owns(id)
    for _, v in ipairs(ownedStations)  do if v == id then return true end end
    for _, v in ipairs(ownedCosmetics) do if v == id then return true end end
    return false
end

local function buildTab(tabName)
    for _, ch in ipairs(itemList:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    local yOff = 4
    for _, item in ipairs(CATALOG) do
        if item.tab ~= tabName then continue end
        local isOwned   = owns(item.id)
        local isStation = item.source == "station"
        local reqMet    = not item.requires or owns(item.requires)
        local canBuy    = not isOwned and not isStation and playerCoins >= item.price and reqMet

        local row = Instance.new("Frame", itemList)
        row.Size = UDim2.new(1,-8,0,60); row.Position = UDim2.new(0,4,0,yOff)
        row.BackgroundColor3 = C.CARD; row.BackgroundTransparency = 0.15; row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

        local nLbl = Instance.new("TextLabel", row)
        nLbl.Size = UDim2.new(0.62,0,0,22); nLbl.Position = UDim2.new(0,8,0,5)
        nLbl.BackgroundTransparency = 1; nLbl.TextXAlignment = Enum.TextXAlignment.Left
        nLbl.Text = item.name; nLbl.Font = Enum.Font.GothamBold; nLbl.TextSize = 13
        nLbl.TextColor3 = isOwned and C.MUTED or C.WHITE

        local dLbl = Instance.new("TextLabel", row)
        dLbl.Size = UDim2.new(0.62,0,0,18); dLbl.Position = UDim2.new(0,8,0,30)
        dLbl.BackgroundTransparency = 1; dLbl.TextXAlignment = Enum.TextXAlignment.Left
        dLbl.Text = item.desc; dLbl.Font = Enum.Font.Gotham; dLbl.TextSize = 11
        dLbl.TextColor3 = C.MUTED

        if isOwned then
            local b = Instance.new("TextLabel", row)
            b.Size = UDim2.new(0,72,0,26); b.Position = UDim2.new(1,-80,0.5,-13)
            b.BackgroundColor3 = C.GREEN; b.BackgroundTransparency = 0.3; b.BorderSizePixel = 0
            b.Text = "✓ Owned"; b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.TextColor3 = C.WHITE
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
        elseif isStation then
            local b = Instance.new("TextLabel", row)
            b.Size = UDim2.new(0,72,0,26); b.Position = UDim2.new(1,-80,0.5,-13)
            b.BackgroundColor3 = C.MUTED; b.BackgroundTransparency = 0.4; b.BorderSizePixel = 0
            b.Text = "Earn"; b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.TextColor3 = C.WHITE
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
        else
            local btn = Instance.new("TextButton", row)
            btn.Size = UDim2.new(0,86,0,30); btn.Position = UDim2.new(1,-94,0.5,-15)
            btn.BackgroundColor3 = canBuy and C.GOLD or C.MUTED
            btn.BackgroundTransparency = canBuy and 0 or 0.45; btn.BorderSizePixel = 0
            btn.Text = "🪙 "..item.price; btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
            btn.TextColor3 = canBuy and Color3.fromRGB(40,20,0) or C.WHITE
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
            if canBuy then
                local cid = item.id
                btn.Activated:Connect(function()
                    if purchasing then return end
                    purchasing = true; btn.Text = "..."; btn.Active = false
                    purchaseRemote:FireServer(cid)
                end)
            end
        end
        yOff += 68
    end
    itemList.CanvasSize = UDim2.new(0,0,0,yOff)
end

local function setTab(t)
    activeTab = t
    tabUpg.BackgroundTransparency = t == "Upgrades"  and 0.15 or 0.6
    tabCos.BackgroundTransparency = t == "Cosmetics" and 0.15 or 0.6
    buildTab(t)
end

closeBtn.Activated:Connect(function() gui.Enabled = false end)
tabUpg.Activated:Connect(function() setTab("Upgrades") end)
tabCos.Activated:Connect(function() setTab("Cosmetics") end)

PPS.PromptTriggered:Connect(function(prompt)
    if prompt.Name == "ShopPrompt" then
        coinLbl.Text = "🪙 " .. playerCoins
        setTab(activeTab)
        gui.Enabled = true
    end
end)

dataInitRemote.OnClientEvent:Connect(function(data)
    playerCoins    = data.coins or 0
    ownedStations  = data.unlockedStations  or {}
    ownedCosmetics = data.unlockedCosmetics or {}
    coinLbl.Text   = "🪙 " .. playerCoins
end)

purchaseResult.OnClientEvent:Connect(function(result)
    purchasing = false
    if result and result.success then
        playerCoins    = result.newCoins          or playerCoins
        ownedStations  = result.unlockedStations  or ownedStations
        ownedCosmetics = result.unlockedCosmetics or ownedCosmetics
        coinLbl.Text   = "🪙 " .. playerCoins
    end
    buildTab(activeTab)
end)

print("[ShopController] Ready.")
