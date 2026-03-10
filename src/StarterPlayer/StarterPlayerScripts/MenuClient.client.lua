-- MenuClient (LocalScript, StarterPlayerScripts)
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

-- Module-level callbacks so connections are centralised per board instance
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

-- ── FADE HELPERS ──────────────────────────────────────────────
local function createBlackFade()
    local fadeGui = Instance.new("ScreenGui")
    fadeGui.Name           = "MenuFadeGui"
    fadeGui.ResetOnSpawn   = false
    fadeGui.DisplayOrder   = 100
    fadeGui.IgnoreGuiInset = true
    fadeGui.Parent         = playerGui

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
        { BackgroundTransparency = 0 }
    )
    tween:Play()
    tween.Completed:Wait()
end

local function fadeOut(fill, duration)
    local tween = TweenService:Create(fill,
        TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 1 }
    )
    tween:Play()
    tween.Completed:Wait()
end

-- ── BUILD MENU BOARD GUI ──────────────────────────────────────
local function buildMenuBoard(payload)
    local existing = playerGui:FindFirstChild("MenuBoardGui")
    if existing then existing:Destroy() end

    local allCookies   = payload.allCookies   -- { id, label, price } in CookieData order
    local activeMenu   = payload.activeMenu   -- { cookieId, ... } current menu
    local ownedCookies = payload.ownedCookies or {}

    -- Build owned set for quick lookup
    local ownedSet = {}
    for _, id in ipairs(ownedCookies) do ownedSet[id] = true end

    -- Split into owned / locked lists (preserving CookieData order)
    local ownedList  = {}
    local lockedList = {}
    for _, info in ipairs(allCookies) do
        if ownedSet[info.id] then
            table.insert(ownedList, info)
        else
            table.insert(lockedList, info)
        end
    end

    -- Initial selection: activeMenu ∩ owned, capped at MAX_SELECT
    local selected = {}
    local selCount = 0
    for _, id in ipairs(activeMenu) do
        if ownedSet[id] and selCount < MAX_SELECT then
            selected[id] = true
            selCount += 1
        end
    end
    -- If empty (first time), auto-select all owned up to MAX_SELECT
    if next(selected) == nil then
        for _, info in ipairs(ownedList) do
            if selCount >= MAX_SELECT then break end
            selected[info.id] = true
            selCount += 1
        end
    end

    -- ── Root ScreenGui ─────────────────────────────────────────
    local sg = Instance.new("ScreenGui")
    sg.Name           = "MenuBoardGui"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 20
    sg.IgnoreGuiInset = false
    sg.Parent         = playerGui

    -- Dark overlay
    local overlay = Instance.new("Frame", sg)
    overlay.Size                   = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.55
    overlay.BorderSizePixel        = 0

    -- Card frame
    local card = Instance.new("Frame", sg)
    card.Size                   = UDim2.new(0, 400, 0, 480)
    card.Position               = UDim2.new(0.5, -200, 0.5, -240)
    card.BackgroundColor3       = Color3.fromRGB(42, 28, 18)
    card.BackgroundTransparency = 0
    card.BorderSizePixel        = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)

    -- Accent bar
    local accentBar = Instance.new("Frame", card)
    accentBar.Size             = UDim2.new(1, 0, 0, 6)
    accentBar.BackgroundColor3 = Color3.fromRGB(220, 160, 60)
    accentBar.BorderSizePixel  = 0
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 16)

    -- Title
    local title = Instance.new("TextLabel", card)
    title.Size                   = UDim2.new(1, -20, 0, 40)
    title.Position               = UDim2.new(0, 10, 0, 14)
    title.BackgroundTransparency = 1
    title.TextColor3             = Color3.fromRGB(255, 220, 140)
    title.TextScaled             = true
    title.Font                   = Enum.Font.GothamBold
    title.Text                   = "Today's Menu"

    -- Subtitle
    local sub = Instance.new("TextLabel", card)
    sub.Size                   = UDim2.new(1, -20, 0, 20)
    sub.Position               = UDim2.new(0, 10, 0, 54)
    sub.BackgroundTransparency = 1
    sub.TextColor3             = Color3.fromRGB(200, 175, 135)
    sub.TextScaled             = true
    sub.Font                   = Enum.Font.Gotham
    sub.Text                   = "Pick up to " .. MAX_SELECT .. " cookies to serve today"

    -- Status counter
    local statusLabel = Instance.new("TextLabel", card)
    statusLabel.Size                   = UDim2.new(1, -20, 0, 20)
    statusLabel.Position               = UDim2.new(0, 10, 0, 76)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3             = Color3.fromRGB(140, 210, 140)
    statusLabel.TextScaled             = true
    statusLabel.Font                   = Enum.Font.GothamBold
    statusLabel.Text                   = "0 / " .. MAX_SELECT .. " selected"

    -- Cookie list (ScrollingFrame)
    local listFrame = Instance.new("ScrollingFrame", card)
    listFrame.Size                   = UDim2.new(1, -20, 0, 300)
    listFrame.Position               = UDim2.new(0, 10, 0, 102)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel        = 0
    listFrame.ScrollBarThickness     = 4
    listFrame.ScrollBarImageColor3   = Color3.fromRGB(220, 160, 60)
    listFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)

    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.Padding             = UDim.new(0, 4)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder           = Enum.SortOrder.LayoutOrder

    -- Confirm button
    local confirmBtn = Instance.new("TextButton", card)
    confirmBtn.Size             = UDim2.new(0.8, 0, 0, 44)
    confirmBtn.Position         = UDim2.new(0.1, 0, 0, 416)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(80, 165, 75)
    confirmBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    confirmBtn.TextScaled       = true
    confirmBtn.Font             = Enum.Font.GothamBold
    confirmBtn.Text             = "Set Menu"
    confirmBtn.BorderSizePixel  = 0
    Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 10)

    local hintLabel = Instance.new("TextLabel", card)
    hintLabel.Size                   = UDim2.new(1, -20, 0, 16)
    hintLabel.Position               = UDim2.new(0, 10, 0, 462)
    hintLabel.BackgroundTransparency = 1
    hintLabel.TextColor3             = Color3.fromRGB(140, 120, 90)
    hintLabel.TextScaled             = true
    hintLabel.Font                   = Enum.Font.Gotham
    hintLabel.Text                   = "Menu locks when the store opens"

    -- ── ROW HELPERS ──────────────────────────────────────────────
    local checkboxRefs = {}  -- cookieId → { row, checkLabel, nameLabel }

    local function countSelected()
        local n = 0
        for _ in pairs(selected) do n += 1 end
        return n
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
        ref.row.BackgroundColor3  = on and Color3.fromRGB(75, 58, 32) or Color3.fromRGB(44, 34, 22)
        ref.checkLabel.Text       = on and "☑" or "☐"
        ref.checkLabel.TextColor3 = on and Color3.fromRGB(255, 200, 90) or Color3.fromRGB(110, 95, 70)
        ref.nameLabel.TextColor3  = on and Color3.fromRGB(245, 225, 185) or Color3.fromRGB(130, 115, 90)
    end

    -- ── OWNED SECTION HEADER ─────────────────────────────────────
    local ROW_H    = 34
    local HDR_H    = 22
    local ROW_GAP  = 4
    local totalHeight = 0

    local ownedHeader = Instance.new("TextLabel", listFrame)
    ownedHeader.LayoutOrder       = 0
    ownedHeader.Size              = UDim2.new(1, 0, 0, HDR_H)
    ownedHeader.BackgroundTransparency = 1
    ownedHeader.TextXAlignment    = Enum.TextXAlignment.Left
    ownedHeader.TextColor3        = Color3.fromRGB(200, 160, 70)
    ownedHeader.TextScaled        = true
    ownedHeader.Font              = Enum.Font.GothamBold
    ownedHeader.Text              = "  ☆ Owned (" .. #ownedList .. ")"
    totalHeight += HDR_H + ROW_GAP

    -- ── OWNED ROWS ────────────────────────────────────────────────
    for i, info in ipairs(ownedList) do
        local isOn = selected[info.id] == true

        local row = Instance.new("TextButton", listFrame)
        row.LayoutOrder      = i
        row.Size             = UDim2.new(1, 0, 0, ROW_H)
        row.BackgroundColor3 = isOn and Color3.fromRGB(75, 58, 32) or Color3.fromRGB(44, 34, 22)
        row.BorderSizePixel  = 0
        row.Text             = ""
        row.AutoButtonColor  = false
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        local checkLbl = Instance.new("TextLabel", row)
        checkLbl.Size                   = UDim2.new(0, 30, 1, 0)
        checkLbl.Position               = UDim2.new(0, 6, 0, 0)
        checkLbl.BackgroundTransparency = 1
        checkLbl.TextScaled             = true
        checkLbl.Font                   = Enum.Font.GothamBold
        checkLbl.Text                   = isOn and "☑" or "☐"
        checkLbl.TextColor3             = isOn
            and Color3.fromRGB(255, 200, 90) or Color3.fromRGB(110, 95, 70)

        local nameLbl = Instance.new("TextLabel", row)
        nameLbl.Size                   = UDim2.new(0.6, 0, 1, 0)
        nameLbl.Position               = UDim2.new(0, 40, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
        nameLbl.TextScaled             = true
        nameLbl.Font                   = Enum.Font.Gotham
        nameLbl.Text                   = info.label
        nameLbl.TextColor3             = isOn
            and Color3.fromRGB(245, 225, 185) or Color3.fromRGB(130, 115, 90)

        local priceLbl = Instance.new("TextLabel", row)
        priceLbl.Size                   = UDim2.new(0, 50, 1, 0)
        priceLbl.Position               = UDim2.new(1, -54, 0, 0)
        priceLbl.BackgroundTransparency = 1
        priceLbl.TextScaled             = true
        priceLbl.Font                   = Enum.Font.Gotham
        priceLbl.Text                   = info.price .. "🪙"
        priceLbl.TextColor3             = Color3.fromRGB(200, 170, 100)

        checkboxRefs[info.id] = { row = row, checkLabel = checkLbl, nameLabel = nameLbl }
        totalHeight += ROW_H + ROW_GAP

        row.MouseButton1Click:Connect(function()
            if selected[info.id] then
                if countSelected() <= 1 then return end  -- keep at least 1
                selected[info.id] = nil
            else
                if countSelected() >= MAX_SELECT then return end  -- cap at 6
                selected[info.id] = true
            end
            refreshCheckRow(info.id)
            updateStatus()
        end)
    end

    -- ── LOCKED SECTION HEADER ─────────────────────────────────────
    if #lockedList > 0 then
        local lockedHeader = Instance.new("TextLabel", listFrame)
        lockedHeader.LayoutOrder       = 1000
        lockedHeader.Size              = UDim2.new(1, 0, 0, HDR_H)
        lockedHeader.BackgroundTransparency = 1
        lockedHeader.TextXAlignment    = Enum.TextXAlignment.Left
        lockedHeader.TextColor3        = Color3.fromRGB(160, 130, 90)
        lockedHeader.TextScaled        = true
        lockedHeader.Font              = Enum.Font.GothamBold
        lockedHeader.Text              = "  🔒 Locked (" .. #lockedList .. ")"
        totalHeight += HDR_H + ROW_GAP

        -- ── LOCKED ROWS ──────────────────────────────────────────
        local unlockBtnRefs = {}  -- cookieId → TextButton (for disabling during purchase)

        for i, info in ipairs(lockedList) do
            local cost = nil
            -- Compute unlock cost client-side for display (server re-validates on purchase)
            if info.price == 4 then cost = 100
            elseif info.price == 5 then cost = 250
            elseif info.price == 6 then cost = 500
            elseif info.price == 7 then cost = 1000
            else cost = 100 end
            -- Special pricing for original main-6
            if info.id == "cookies_and_cream" or info.id == "lemon_blackraspberry" then
                cost = 100
            end

            local row = Instance.new("Frame", listFrame)
            row.LayoutOrder      = 1000 + i
            row.Size             = UDim2.new(1, 0, 0, ROW_H)
            row.BackgroundColor3 = Color3.fromRGB(32, 26, 18)
            row.BorderSizePixel  = 0
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

            local lockIcon = Instance.new("TextLabel", row)
            lockIcon.Size                   = UDim2.new(0, 26, 1, 0)
            lockIcon.Position               = UDim2.new(0, 4, 0, 0)
            lockIcon.BackgroundTransparency = 1
            lockIcon.TextScaled             = true
            lockIcon.Font                   = Enum.Font.GothamBold
            lockIcon.Text                   = "🔒"
            lockIcon.TextColor3             = Color3.fromRGB(130, 105, 65)

            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size                   = UDim2.new(0.5, 0, 1, 0)
            nameLbl.Position               = UDim2.new(0, 34, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
            nameLbl.TextScaled             = true
            nameLbl.Font                   = Enum.Font.Gotham
            nameLbl.Text                   = info.label
            nameLbl.TextColor3             = Color3.fromRGB(100, 85, 60)

            local unlockBtn = Instance.new("TextButton", row)
            unlockBtn.Size             = UDim2.new(0, 90, 0, 24)
            unlockBtn.Position         = UDim2.new(1, -96, 0.5, -12)
            unlockBtn.BackgroundColor3 = Color3.fromRGB(190, 140, 40)
            unlockBtn.TextColor3       = Color3.fromRGB(255, 245, 220)
            unlockBtn.TextScaled       = true
            unlockBtn.Font             = Enum.Font.GothamBold
            unlockBtn.Text             = cost .. " 🪙 Buy"
            unlockBtn.BorderSizePixel  = 0
            Instance.new("UICorner", unlockBtn).CornerRadius = UDim.new(0, 6)

            unlockBtnRefs[info.id] = unlockBtn
            totalHeight += ROW_H + ROW_GAP

            unlockBtn.MouseButton1Click:Connect(function()
                if not unlockBtn.Active then return end
                unlockBtn.Active = false
                unlockBtn.Text   = "..."
                purchaseCookieRemote:FireServer(info.id)
            end)
        end

        -- Handle purchase result: re-enable failed buttons, rebuild board on success
        local currentPayload = payload
        onPurchaseResultCallback = function(success, newCoinsOrMsg, cookieId)
            if success then
                -- Update local ownedCookies and rebuild the board
                local newOwned = {}
                for _, id in ipairs(currentPayload.ownedCookies or {}) do
                    table.insert(newOwned, id)
                end
                table.insert(newOwned, cookieId)
                local updatedPayload = {
                    allCookies   = currentPayload.allCookies,
                    activeMenu   = currentPayload.activeMenu,
                    ownedCookies = newOwned,
                }
                currentPayload = updatedPayload
                -- Persist current selection to carry through rebuild
                local currentSelected = {}
                for id in pairs(selected) do table.insert(currentSelected, id) end
                updatedPayload.activeMenu = currentSelected
                buildMenuBoard(updatedPayload)
            else
                -- Re-enable the failed button
                local btn = unlockBtnRefs[cookieId]
                if btn and btn.Parent then
                    btn.Active = true
                    btn.Text   = "Retry"
                end
            end
        end
    end

    -- Set canvas height
    listFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    updateStatus()

    -- ── FADE & CONFIRM ──────────────────────────────────────────
    local fadeGui  = nil
    local fadeFill = nil

    local function doFadeIn()
        fadeGui, fadeFill = createBlackFade()
        fadeIn(fadeFill, 0.3)
    end

    local function doFadeOut()
        if fadeFill and fadeFill.Parent then
            fadeOut(fadeFill, 0.3)
        end
        if fadeGui and fadeGui.Parent then
            fadeGui:Destroy()
        end
        fadeGui  = nil
        fadeFill = nil
    end

    -- ── LOCK HANDLER ─────────────────────────────────────────────
    local function lockMenu(_finalMenu)
        for _, ref in pairs(checkboxRefs) do
            ref.row.Active          = false
            ref.row.AutoButtonColor = false
        end
        confirmBtn.Text             = "🔒 Menu Locked!"
        confirmBtn.BackgroundColor3 = Color3.fromRGB(110, 55, 55)
        confirmBtn.AutoButtonColor  = false
        sub.Text                    = "Store is open — today's menu is set!"
        hintLabel.Text              = ""
        task.delay(4, function()
            if sg and sg.Parent then sg:Destroy() end
        end)
    end

    -- ── RESULT HANDLER ──────────────────────────────────────────
    local function handleResult(success, message, updatedMenu)
        if success then
            doFadeOut()
            task.delay(0.2, function()
                if sg and sg.Parent then sg:Destroy() end
            end)
        else
            doFadeOut()
            confirmBtn.Text             = message or "Error"
            confirmBtn.BackgroundColor3 = Color3.fromRGB(160, 55, 55)
            confirmBtn.Active           = true
            task.delay(2, function()
                if confirmBtn and confirmBtn.Parent then
                    confirmBtn.Text             = "Set Menu"
                    confirmBtn.BackgroundColor3 = Color3.fromRGB(80, 165, 75)
                end
            end)
        end
    end

    onResultCallback = handleResult
    onLockCallback   = lockMenu

    sg.Destroying:Connect(function()
        if onResultCallback        == handleResult then onResultCallback        = nil end
        if onLockCallback          == lockMenu     then onLockCallback          = nil end
        if onPurchaseResultCallback ~= nil         then onPurchaseResultCallback = nil end
    end)

    -- Confirm button click → fade then fire server
    confirmBtn.MouseButton1Click:Connect(function()
        local ids = {}
        for id in pairs(selected) do table.insert(ids, id) end
        if #ids < 1 then return end
        confirmBtn.Active = false
        confirmBtn.Text   = "..."
        task.spawn(function()
            doFadeIn()
            setMenuRemote:FireServer(ids)
        end)
    end)
end

-- ── LISTENERS ────────────────────────────────────────────────
openMenuBoardRemote.OnClientEvent:Connect(function(payload)
    buildMenuBoard(payload)
end)

print("[MenuClient] Ready.")
