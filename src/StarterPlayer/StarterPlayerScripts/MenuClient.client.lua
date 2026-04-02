-- MenuClient (LocalScript, StarterPlayerScripts)  M7 Polish
-- Shows the Menu Board GUI during PreOpen so players can choose today's cookie menu.
-- Owned cookies show a checkbox (max 6 selectable).
-- Locked cookies show their unlock cost and an "Unlock" button.
-- Fade-to-black plays when confirming the menu.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local RemoteManager            = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local openMenuBoardRemote      = RemoteManager.Get("OpenMenuBoard")
local setMenuRemote            = RemoteManager.Get("SetMenuSelection")
local menuResultRemote         = RemoteManager.Get("MenuSelectionResult")
local menuLockedRemote         = RemoteManager.Get("MenuLocked")
local purchaseCookieRemote     = RemoteManager.Get("PurchaseCookie")
local purchaseCookieResultRemote = RemoteManager.Get("PurchaseCookieResult")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MAX_SELECT = 6
local ACCENT     = Color3.fromRGB(255, 200, 0)  -- gold

local onResultCallback         = nil
local onLockCallback           = nil
local onPurchaseResultCallback = nil

menuResultRemote.OnClientEvent:Connect(function(success, message, updatedMenu)
    if onResultCallback then onResultCallback(success, message, updatedMenu) end
end)

menuLockedRemote.OnClientEvent:Connect(function(finalMenu)
    if onLockCallback then
        onLockCallback(finalMenu)
    else
        local existing = playerGui:FindFirstChild("MenuBoardGui")
        if existing then existing:Destroy() end
    end
end)

purchaseCookieResultRemote.OnClientEvent:Connect(function(success, newCoinsOrMsg, cookieId)
    if onPurchaseResultCallback then
        onPurchaseResultCallback(success, newCoinsOrMsg, cookieId)
    end
end)

-- ── Fade helpers ──────────────────────────────────────────────────────────────
local function createBlackFade()
    local fadeGui = Instance.new("ScreenGui")
    fadeGui.Name           = "MenuFadeGui"
    fadeGui.ResetOnSpawn   = false
    fadeGui.DisplayOrder          = 100
    fadeGui.IgnoreGuiInset        = true
    fadeGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
    fadeGui.Parent                = playerGui

    local fill = Instance.new("Frame", fadeGui)
    fill.Size                   = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    fill.BackgroundTransparency = 1
    fill.BorderSizePixel        = 0

    return fadeGui, fill
end

local function fadeIn(fill, duration)
    local tween = TweenService:Create(fill,
        TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0 })
    tween:Play(); tween.Completed:Wait()
end

local function fadeOut(fill, duration)
    local tween = TweenService:Create(fill,
        TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 1 })
    tween:Play(); tween.Completed:Wait()
end

-- ── Build menu board ──────────────────────────────────────────────────────────
local function buildMenuBoard(payload)
    local existing = playerGui:FindFirstChild("MenuBoardGui")
    if existing then existing:Destroy() end

    local allCookies   = payload.allCookies
    local activeMenu   = payload.activeMenu
    local ownedCookies = payload.ownedCookies or {}

    local ownedSet = {}
    for _, id in ipairs(ownedCookies) do ownedSet[id] = true end

    local ownedList, lockedList = {}, {}
    for _, info in ipairs(allCookies) do
        if ownedSet[info.id] then
            table.insert(ownedList, info)
        else
            table.insert(lockedList, info)
        end
    end

    local selected = {}
    local selCount = 0
    for _, id in ipairs(activeMenu) do
        if ownedSet[id] and selCount < MAX_SELECT then
            selected[id] = true; selCount += 1
        end
    end
    if next(selected) == nil then
        for _, info in ipairs(ownedList) do
            if selCount >= MAX_SELECT then break end
            selected[info.id] = true; selCount += 1
        end
    end

    -- ── Root ──
    local sg = Instance.new("ScreenGui")
    sg.Name           = "MenuBoardGui"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder          = 20
    sg.IgnoreGuiInset        = false
    sg.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
    sg.Parent                = playerGui

    local overlay = Instance.new("Frame", sg)
    overlay.Size                   = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.55
    overlay.BorderSizePixel        = 0

    -- Main card
    local card = Instance.new("Frame", sg)
    card.Size                   = UDim2.new(0, 410, 0, 490)
    card.Position               = UDim2.new(0.5, -205, 0.5, -245)
    card.BackgroundColor3       = Color3.fromRGB(14, 14, 26)
    card.BackgroundTransparency = 0
    card.BorderSizePixel        = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color     = ACCENT
    cardStroke.Thickness = 1.5

    -- Gold header bar
    local headerBar = Instance.new("Frame", card)
    headerBar.Size             = UDim2.new(1, 0, 0, 46)
    headerBar.BackgroundColor3 = ACCENT
    headerBar.BorderSizePixel  = 0
    Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 16)
    local hFlat = Instance.new("Frame", headerBar)
    hFlat.Size             = UDim2.new(1, 0, 0.5, 0)
    hFlat.Position         = UDim2.new(0, 0, 0.5, 0)
    hFlat.BackgroundColor3 = ACCENT
    hFlat.BorderSizePixel  = 0
    local titleLbl = Instance.new("TextLabel", headerBar)
    titleLbl.Size                   = UDim2.new(1, -14, 1, 0)
    titleLbl.Position               = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3             = Color3.fromRGB(20, 14, 4)
    titleLbl.TextScaled             = true
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.Text                   = "Today's Menu"
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", card)
    sub.Size                   = UDim2.new(1, -20, 0, 20)
    sub.Position               = UDim2.new(0, 10, 0, 54)
    sub.BackgroundTransparency = 1
    sub.TextColor3             = Color3.fromRGB(160, 160, 200)
    sub.TextScaled             = true
    sub.Font                   = Enum.Font.Gotham
    sub.Text                   = "Pick up to " .. MAX_SELECT .. " cookies to serve today"

    local statusLabel = Instance.new("TextLabel", card)
    statusLabel.Size                   = UDim2.new(1, -20, 0, 20)
    statusLabel.Position               = UDim2.new(0, 10, 0, 76)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3             = Color3.fromRGB(140, 210, 140)
    statusLabel.TextScaled             = true
    statusLabel.Font                   = Enum.Font.GothamBold
    statusLabel.Text                   = "0 / " .. MAX_SELECT .. " selected"

    local listFrame = Instance.new("ScrollingFrame", card)
    listFrame.Size                   = UDim2.new(1, -20, 0, 300)
    listFrame.Position               = UDim2.new(0, 10, 0, 100)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel        = 0
    listFrame.ScrollBarThickness     = 4
    listFrame.ScrollBarImageColor3   = ACCENT
    listFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)

    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.Padding             = UDim.new(0, 4)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder           = Enum.SortOrder.LayoutOrder

    local confirmBtn = Instance.new("TextButton", card)
    confirmBtn.Size             = UDim2.new(0.8, 0, 0, 44)
    confirmBtn.Position         = UDim2.new(0.1, 0, 0, 414)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 40)
    confirmBtn.TextColor3       = Color3.fromRGB(200, 255, 200)
    confirmBtn.TextScaled       = true
    confirmBtn.Font             = Enum.Font.GothamBold
    confirmBtn.Text             = "Set Menu"
    confirmBtn.BorderSizePixel  = 0
    Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 10)
    local cbStroke = Instance.new("UIStroke", confirmBtn)
    cbStroke.Color     = Color3.fromRGB(50, 185, 75)
    cbStroke.Thickness = 1.5

    local hintLabel = Instance.new("TextLabel", card)
    hintLabel.Size                   = UDim2.new(1, -20, 0, 16)
    hintLabel.Position               = UDim2.new(0, 10, 0, 462)
    hintLabel.BackgroundTransparency = 1
    hintLabel.TextColor3             = Color3.fromRGB(80, 80, 110)
    hintLabel.TextScaled             = true
    hintLabel.Font                   = Enum.Font.Gotham
    hintLabel.Text                   = "Menu locks when the store opens"

    -- ── Row helpers ────────────────────────────────────────────────────────────
    local checkboxRefs = {}

    local function countSelected()
        local n = 0; for _ in pairs(selected) do n += 1 end; return n
    end

    local function updateStatus()
        local n = countSelected()
        statusLabel.Text       = n .. " / " .. MAX_SELECT .. " selected"
        statusLabel.TextColor3 = n >= 1
            and Color3.fromRGB(140, 210, 140)
            or  Color3.fromRGB(220, 90, 90)
        confirmBtn.Active = n >= 1
    end

    local function refreshCheckRow(id)
        local ref = checkboxRefs[id]
        if not ref then return end
        local on = selected[id] == true
        ref.row.BackgroundColor3  = on and Color3.fromRGB(38, 32, 8) or Color3.fromRGB(20, 20, 38)
        ref.checkLabel.Text       = on and "[X]" or "[ ]"
        ref.checkLabel.TextColor3 = on and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(70, 70, 100)
        ref.nameLabel.TextColor3  = on and Color3.fromRGB(255, 215, 120) or Color3.fromRGB(130, 130, 170)
        local s = ref.row:FindFirstChildOfClass("UIStroke")
        if s then s.Color = on and Color3.fromRGB(180, 140, 20) or Color3.fromRGB(35, 35, 60) end
    end

    -- Owned section
    local ROW_H = 34; local HDR_H = 22; local ROW_GAP = 4; local totalHeight = 0

    local ownedHeader = Instance.new("TextLabel", listFrame)
    ownedHeader.LayoutOrder       = 0
    ownedHeader.Size              = UDim2.new(1, 0, 0, HDR_H)
    ownedHeader.BackgroundTransparency = 1
    ownedHeader.TextXAlignment    = Enum.TextXAlignment.Left
    ownedHeader.TextColor3        = ACCENT
    ownedHeader.TextScaled        = true
    ownedHeader.Font              = Enum.Font.GothamBold
    ownedHeader.Text              = "  Owned (" .. #ownedList .. ")"
    totalHeight += HDR_H + ROW_GAP

    for i, info in ipairs(ownedList) do
        local isOn = selected[info.id] == true

        local row = Instance.new("TextButton", listFrame)
        row.LayoutOrder      = i
        row.Size             = UDim2.new(1, 0, 0, ROW_H)
        row.BackgroundColor3 = isOn and Color3.fromRGB(38, 32, 8) or Color3.fromRGB(20, 20, 38)
        row.BorderSizePixel  = 0; row.Text = ""; row.AutoButtonColor = false
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local rs = Instance.new("UIStroke", row)
        rs.Color = isOn and Color3.fromRGB(180, 140, 20) or Color3.fromRGB(35, 35, 60); rs.Thickness = 1

        local checkLbl = Instance.new("TextLabel", row)
        checkLbl.Size=UDim2.new(0,34,1,0); checkLbl.Position=UDim2.new(0,6,0,0)
        checkLbl.BackgroundTransparency=1; checkLbl.TextScaled=true; checkLbl.Font=Enum.Font.GothamBold
        checkLbl.Text = isOn and "[X]" or "[ ]"
        checkLbl.TextColor3 = isOn and Color3.fromRGB(255,200,60) or Color3.fromRGB(70,70,100)

        local nameLbl = Instance.new("TextLabel", row)
        nameLbl.Size=UDim2.new(0.65,0,1,0); nameLbl.Position=UDim2.new(0,42,0,0)
        nameLbl.BackgroundTransparency=1; nameLbl.TextXAlignment=Enum.TextXAlignment.Left
        nameLbl.TextScaled=true; nameLbl.Font=Enum.Font.Gotham; nameLbl.Text=info.label
        nameLbl.TextColor3 = isOn and Color3.fromRGB(255,215,120) or Color3.fromRGB(130,130,170)

        local priceLbl = Instance.new("TextLabel", row)
        priceLbl.Size=UDim2.new(0,60,1,0); priceLbl.Position=UDim2.new(1,-64,0,0)
        priceLbl.BackgroundTransparency=1; priceLbl.TextScaled=true; priceLbl.Font=Enum.Font.Gotham
        priceLbl.Text=info.price.."c"; priceLbl.TextColor3=Color3.fromRGB(140,120,60)

        checkboxRefs[info.id] = { row=row, checkLabel=checkLbl, nameLabel=nameLbl }
        totalHeight += ROW_H + ROW_GAP

        row.MouseButton1Click:Connect(function()
            if selected[info.id] then
                if countSelected() <= 1 then return end
                selected[info.id] = nil
            else
                if countSelected() >= MAX_SELECT then return end
                selected[info.id] = true
            end
            refreshCheckRow(info.id); updateStatus()
        end)
    end

    -- Locked section
    if #lockedList > 0 then
        local lockedHeader = Instance.new("TextLabel", listFrame)
        lockedHeader.LayoutOrder=1000; lockedHeader.Size=UDim2.new(1,0,0,HDR_H)
        lockedHeader.BackgroundTransparency=1; lockedHeader.TextXAlignment=Enum.TextXAlignment.Left
        lockedHeader.TextColor3=Color3.fromRGB(80,80,120); lockedHeader.TextScaled=true
        lockedHeader.Font=Enum.Font.GothamBold; lockedHeader.Text="  Locked ("..#lockedList..")"
        totalHeight += HDR_H + ROW_GAP

        local unlockBtnRefs = {}

        for i, info in ipairs(lockedList) do
            local cost = nil
            if info.price==4 then cost=100 elseif info.price==5 then cost=250
            elseif info.price==6 then cost=500 elseif info.price==7 then cost=1000
            else cost=100 end
            if info.id=="cookies_and_cream" or info.id=="lemon_blackraspberry" then cost=100 end

            local row = Instance.new("Frame", listFrame)
            row.LayoutOrder=1000+i; row.Size=UDim2.new(1,0,0,ROW_H)
            row.BackgroundColor3=Color3.fromRGB(18,18,34); row.BorderSizePixel=0
            Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
            local rs=Instance.new("UIStroke",row); rs.Color=Color3.fromRGB(35,35,60); rs.Thickness=1

            local lockIcon=Instance.new("TextLabel",row)
            lockIcon.Size=UDim2.new(0,26,1,0); lockIcon.Position=UDim2.new(0,4,0,0)
            lockIcon.BackgroundTransparency=1; lockIcon.TextScaled=true
            lockIcon.Font=Enum.Font.GothamBold; lockIcon.Text="[L]"
            lockIcon.TextColor3=Color3.fromRGB(60,60,90)

            local nameLbl=Instance.new("TextLabel",row)
            nameLbl.Size=UDim2.new(0.5,0,1,0); nameLbl.Position=UDim2.new(0,34,0,0)
            nameLbl.BackgroundTransparency=1; nameLbl.TextXAlignment=Enum.TextXAlignment.Left
            nameLbl.TextScaled=true; nameLbl.Font=Enum.Font.Gotham; nameLbl.Text=info.label
            nameLbl.TextColor3=Color3.fromRGB(70,70,100)

            local unlockBtn=Instance.new("TextButton",row)
            unlockBtn.Size=UDim2.new(0,90,0,24); unlockBtn.Position=UDim2.new(1,-96,0.5,-12)
            unlockBtn.BackgroundColor3=Color3.fromRGB(36,30,8); unlockBtn.TextColor3=Color3.fromRGB(255,200,60)
            unlockBtn.TextScaled=true; unlockBtn.Font=Enum.Font.GothamBold
            unlockBtn.Text=cost.."c Unlock"; unlockBtn.BorderSizePixel=0
            Instance.new("UICorner",unlockBtn).CornerRadius=UDim.new(0,6)
            local ubs=Instance.new("UIStroke",unlockBtn); ubs.Color=Color3.fromRGB(180,140,20); ubs.Thickness=1

            unlockBtnRefs[info.id] = unlockBtn
            totalHeight += ROW_H + ROW_GAP

            unlockBtn.MouseButton1Click:Connect(function()
                if not unlockBtn.Active then return end
                unlockBtn.Active=false; unlockBtn.Text="..."
                purchaseCookieRemote:FireServer(info.id)
            end)
        end

        -- BUG-89: capture refs at this build scope so rebuild picks up fresh table
        local _unlockBtnRefs = unlockBtnRefs
        local _currentPayload = payload
        onPurchaseResultCallback = function(success, newCoinsOrMsg, cookieId)
            if success then
                local newOwned = {}
                for _, id in ipairs(_currentPayload.ownedCookies or {}) do table.insert(newOwned, id) end
                table.insert(newOwned, cookieId)
                local updatedPayload = { allCookies=_currentPayload.allCookies,
                    activeMenu=_currentPayload.activeMenu, ownedCookies=newOwned }
                _currentPayload = updatedPayload
                local currentSelected = {}
                for id in pairs(selected) do table.insert(currentSelected, id) end
                updatedPayload.activeMenu = currentSelected
                buildMenuBoard(updatedPayload)
            else
                -- BUG-89: use local refs so we always reference the correct board's buttons
                local btn = _unlockBtnRefs[cookieId]
                if btn and btn.Parent then btn.Active=true; btn.Text="Retry" end
            end
        end
    end

    listFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    updateStatus()

    -- Fade & confirm
    local fadeGui, fadeFill = nil, nil

    local function doFadeIn()
        fadeGui, fadeFill = createBlackFade(); fadeIn(fadeFill, 0.3)
    end
    local function doFadeOut()
        if fadeFill and fadeFill.Parent then fadeOut(fadeFill, 0.3) end
        if fadeGui  and fadeGui.Parent  then fadeGui:Destroy() end
        fadeGui=nil; fadeFill=nil
    end

    local function lockMenu(_finalMenu)
        for _, ref in pairs(checkboxRefs) do
            ref.row.Active=false; ref.row.AutoButtonColor=false
        end
        confirmBtn.Text="Menu Locked!"; confirmBtn.BackgroundColor3=Color3.fromRGB(60,20,20)
        confirmBtn.AutoButtonColor=false
        sub.Text="Store is open \xe2\x80\x94 today's menu is set!"; hintLabel.Text=""
        task.delay(4, function() if sg and sg.Parent then sg:Destroy() end end)
    end

    local function handleResult(success, message, _updatedMenu)
        if success then
            doFadeOut()
            task.delay(0.2, function() if sg and sg.Parent then sg:Destroy() end end)
        else
            doFadeOut()
            confirmBtn.Text=message or "Error"; confirmBtn.BackgroundColor3=Color3.fromRGB(100,20,20)
            confirmBtn.Active=true
            task.delay(2, function()
                if confirmBtn and confirmBtn.Parent then
                    confirmBtn.Text="Set Menu"; confirmBtn.BackgroundColor3=Color3.fromRGB(30,100,40)
                end
            end)
        end
    end

    onResultCallback=handleResult; onLockCallback=lockMenu

    -- BUG-89: capture the purchase callback at this build scope; only nil it if it
    -- hasn't been overwritten by a rebuild that's already in progress
    local _myPurchaseCallback = onPurchaseResultCallback
    sg.Destroying:Connect(function()
        if onResultCallback==handleResult then onResultCallback=nil end
        if onLockCallback==lockMenu then onLockCallback=nil end
        -- only clear if our callback hasn't already been replaced by a newer board
        if onPurchaseResultCallback == _myPurchaseCallback then
            onPurchaseResultCallback = nil
        end
    end)

    confirmBtn.MouseButton1Click:Connect(function()
        local ids = {}
        for id in pairs(selected) do table.insert(ids, id) end
        if #ids < 1 then return end
        confirmBtn.Active=false; confirmBtn.Text="..."
        task.spawn(function() doFadeIn(); setMenuRemote:FireServer(ids) end)
    end)
end

-- ── Listeners ─────────────────────────────────────────────────────────────────
openMenuBoardRemote.OnClientEvent:Connect(function(payload)
    if Players.LocalPlayer:GetAttribute("InTutorial") then return end
    buildMenuBoard(payload)
end)

print("[MenuClient] Ready.")
