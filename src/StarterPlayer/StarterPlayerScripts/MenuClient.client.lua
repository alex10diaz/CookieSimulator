-- MenuClient (LocalScript, StarterPlayerScripts)
-- Shows the Menu Board GUI during PreOpen so players can choose today's cookie menu.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager       = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local openMenuBoardRemote = RemoteManager.Get("OpenMenuBoard")
local setMenuRemote       = RemoteManager.Get("SetMenuSelection")
local menuResultRemote    = RemoteManager.Get("MenuSelectionResult")
local menuLockedRemote    = RemoteManager.Get("MenuLocked")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Module-level handlers so connections are centralised
local onResultCallback = nil
local onLockCallback   = nil

menuResultRemote.OnClientEvent:Connect(function(success, message, updatedMenu)
    if onResultCallback then onResultCallback(success, message, updatedMenu) end
end)

menuLockedRemote.OnClientEvent:Connect(function(finalMenu)
    if onLockCallback then
        onLockCallback(finalMenu)
    else
        -- Board isn't open but menu locked — destroy stale GUI if any
        local existing = playerGui:FindFirstChild("MenuBoardGui")
        if existing then existing:Destroy() end
    end
end)

-- ── BUILD MENU BOARD GUI ─────────────────────────────────────
local function buildMenuBoard(payload)
    -- Remove any existing board
    local existing = playerGui:FindFirstChild("MenuBoardGui")
    if existing then existing:Destroy() end

    local allCookies = payload.allCookies  -- { id, label, price }
    local activeMenu = payload.activeMenu  -- { cookieId, ... }

    -- Build initial selected set from active menu
    local selected = {}
    for _, id in ipairs(activeMenu) do selected[id] = true end

    -- ── Root ScreenGui ──────────────────────────────────────
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
    card.Size                   = UDim2.new(0, 390, 0, 430)
    card.Position               = UDim2.new(0.5, -195, 0.5, -215)
    card.BackgroundColor3       = Color3.fromRGB(42, 28, 18)
    card.BackgroundTransparency = 0
    card.BorderSizePixel        = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)

    -- Accent bar at top
    local accentBar = Instance.new("Frame", card)
    accentBar.Size            = UDim2.new(1, 0, 0, 6)
    accentBar.BackgroundColor3 = Color3.fromRGB(220, 160, 60)
    accentBar.BorderSizePixel = 0
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 16)

    -- Title
    local title = Instance.new("TextLabel", card)
    title.Size                   = UDim2.new(1, -20, 0, 42)
    title.Position               = UDim2.new(0, 10, 0, 14)
    title.BackgroundTransparency = 1
    title.TextColor3             = Color3.fromRGB(255, 220, 140)
    title.TextScaled             = true
    title.Font                   = Enum.Font.GothamBold
    title.Text                   = "🍪  Today's Menu"

    -- Subtitle
    local sub = Instance.new("TextLabel", card)
    sub.Size                   = UDim2.new(1, -20, 0, 22)
    sub.Position               = UDim2.new(0, 10, 0, 56)
    sub.BackgroundTransparency = 1
    sub.TextColor3             = Color3.fromRGB(200, 175, 135)
    sub.TextScaled             = true
    sub.Font                   = Enum.Font.Gotham
    sub.Text                   = "Choose which cookies to serve today"

    -- Status counter
    local statusLabel = Instance.new("TextLabel", card)
    statusLabel.Size                   = UDim2.new(1, -20, 0, 20)
    statusLabel.Position               = UDim2.new(0, 10, 0, 80)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3             = Color3.fromRGB(140, 210, 140)
    statusLabel.TextScaled             = true
    statusLabel.Font                   = Enum.Font.Gotham
    statusLabel.Text                   = #allCookies .. " / " .. #allCookies .. " selected"

    -- Cookie list container (ScrollingFrame handles any catalog size)
    local listFrame = Instance.new("ScrollingFrame", card)
    listFrame.Size                   = UDim2.new(1, -20, 0, 250)
    listFrame.Position               = UDim2.new(0, 10, 0, 108)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel        = 0
    listFrame.ScrollBarThickness     = 4
    listFrame.ScrollBarImageColor3   = Color3.fromRGB(220, 160, 60)
    listFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)  -- set after rows built

    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.Padding             = UDim.new(0, 5)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder           = Enum.SortOrder.LayoutOrder

    -- Row reference table for refresh
    local rowRefs = {}

    local totalCookies = #allCookies

    local function countSelected()
        local n = 0
        for _ in pairs(selected) do n += 1 end
        return n
    end

    local function updateStatus()
        local n = countSelected()
        statusLabel.Text       = n .. " / " .. totalCookies .. " selected"
        statusLabel.TextColor3 = n >= 1
            and Color3.fromRGB(140, 210, 140)
            or  Color3.fromRGB(220, 90, 90)
    end

    local function refreshRow(id)
        local ref = rowRefs[id]
        if not ref then return end
        local on = selected[id] == true
        ref.row.BackgroundColor3   = on
            and Color3.fromRGB(75, 58, 32)
            or  Color3.fromRGB(44, 34, 22)
        ref.checkLabel.Text        = on and "☑" or "☐"
        ref.checkLabel.TextColor3  = on
            and Color3.fromRGB(255, 200, 90)
            or  Color3.fromRGB(110, 95, 70)
        ref.nameLabel.TextColor3   = on
            and Color3.fromRGB(245, 225, 185)
            or  Color3.fromRGB(130, 115, 90)
    end

    -- Build cookie rows
    for i, cookieInfo in ipairs(allCookies) do
        local isOn = selected[cookieInfo.id] == true

        local row = Instance.new("TextButton", listFrame)
        row.LayoutOrder       = i
        row.Size              = UDim2.new(1, 0, 0, 36)
        row.BackgroundColor3  = isOn and Color3.fromRGB(75, 58, 32) or Color3.fromRGB(44, 34, 22)
        row.BorderSizePixel   = 0
        row.Text              = ""
        row.AutoButtonColor   = false
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        -- Checkbox icon
        local checkLbl = Instance.new("TextLabel", row)
        checkLbl.Size                   = UDim2.new(0, 32, 1, 0)
        checkLbl.Position               = UDim2.new(0, 6, 0, 0)
        checkLbl.BackgroundTransparency = 1
        checkLbl.TextScaled             = true
        checkLbl.Font                   = Enum.Font.GothamBold
        checkLbl.Text                   = isOn and "☑" or "☐"
        checkLbl.TextColor3             = isOn
            and Color3.fromRGB(255, 200, 90)
            or  Color3.fromRGB(110, 95, 70)

        -- Cookie name
        local nameLbl = Instance.new("TextLabel", row)
        nameLbl.Size                   = UDim2.new(0.65, 0, 1, 0)
        nameLbl.Position               = UDim2.new(0, 42, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
        nameLbl.TextScaled             = true
        nameLbl.Font                   = Enum.Font.Gotham
        nameLbl.Text                   = cookieInfo.label
        nameLbl.TextColor3             = isOn
            and Color3.fromRGB(245, 225, 185)
            or  Color3.fromRGB(130, 115, 90)

        -- Price tag
        local priceLbl = Instance.new("TextLabel", row)
        priceLbl.Size                   = UDim2.new(0, 65, 1, 0)
        priceLbl.Position               = UDim2.new(1, -68, 0, 0)
        priceLbl.BackgroundTransparency = 1
        priceLbl.TextScaled             = true
        priceLbl.Font                   = Enum.Font.GothamBold
        priceLbl.Text                   = "💰" .. cookieInfo.price
        priceLbl.TextColor3             = Color3.fromRGB(255, 195, 70)

        rowRefs[cookieInfo.id] = { row = row, checkLabel = checkLbl, nameLabel = nameLbl }

        row.MouseButton1Click:Connect(function()
            if selected[cookieInfo.id] then
                -- Must keep at least 1 selected
                if countSelected() <= 1 then return end
                selected[cookieInfo.id] = nil
            else
                selected[cookieInfo.id] = true
            end
            refreshRow(cookieInfo.id)
            updateStatus()
        end)
    end

    -- Set canvas height so ScrollingFrame knows how far to scroll
    local ROW_H = 36
    local ROW_GAP = 5
    listFrame.CanvasSize = UDim2.new(0, 0, 0, #allCookies * ROW_H + math.max(0, #allCookies - 1) * ROW_GAP)

    updateStatus()

    -- Confirm button
    local confirmBtn = Instance.new("TextButton", card)
    confirmBtn.Size             = UDim2.new(0.8, 0, 0, 44)
    confirmBtn.Position         = UDim2.new(0.1, 0, 0, 370)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(80, 165, 75)
    confirmBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    confirmBtn.TextScaled       = true
    confirmBtn.Font             = Enum.Font.GothamBold
    confirmBtn.Text             = "Set Menu"
    confirmBtn.BorderSizePixel  = 0
    Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 10)

    -- Hint label
    local hintLabel = Instance.new("TextLabel", card)
    hintLabel.Size                   = UDim2.new(1, -20, 0, 18)
    hintLabel.Position               = UDim2.new(0, 10, 0, 418)
    hintLabel.BackgroundTransparency = 1
    hintLabel.TextColor3             = Color3.fromRGB(140, 120, 90)
    hintLabel.TextScaled             = true
    hintLabel.Font                   = Enum.Font.Gotham
    hintLabel.Text                   = "Menu locks when the store opens"

    -- ── LOCK HANDLER ─────────────────────────────────────────
    local function lockMenu(_finalMenu)
        -- Disable all cookie row buttons
        for _, ref in pairs(rowRefs) do
            ref.row.Active            = false
            ref.row.AutoButtonColor   = false
        end
        confirmBtn.Text             = "🔒 Menu Locked!"
        confirmBtn.BackgroundColor3 = Color3.fromRGB(110, 55, 55)
        confirmBtn.AutoButtonColor  = false
        sub.Text                    = "Store is open — today's menu is set!"
        hintLabel.Text              = ""
        -- Auto-hide after 4 seconds
        task.delay(4, function()
            if sg and sg.Parent then sg:Destroy() end
        end)
    end

    -- ── RESULT HANDLER ────────────────────────────────────────
    local function handleResult(success, message, updatedMenu)
        if success then
            -- Sync UI to server-confirmed menu
            if updatedMenu then
                selected = {}
                for _, id in ipairs(updatedMenu) do selected[id] = true end
                for _, cookieInfo in ipairs(allCookies) do
                    refreshRow(cookieInfo.id)
                end
                updateStatus()
            end
            confirmBtn.Text             = "✓ Saved!"
            confirmBtn.BackgroundColor3 = Color3.fromRGB(55, 140, 55)
            task.delay(1.5, function()
                if sg and sg.Parent then sg:Destroy() end
            end)
        else
            confirmBtn.Text             = message or "Error"
            confirmBtn.BackgroundColor3 = Color3.fromRGB(160, 55, 55)
            task.delay(2, function()
                if confirmBtn and confirmBtn.Parent then
                    confirmBtn.Text             = "Set Menu"
                    confirmBtn.BackgroundColor3 = Color3.fromRGB(80, 165, 75)
                    confirmBtn.AutoButtonColor  = true
                end
            end)
        end
    end

    -- Hook module-level callbacks for this board instance
    onResultCallback = handleResult
    onLockCallback   = lockMenu

    -- Clear callbacks when GUI is destroyed
    sg.Destroying:Connect(function()
        if onResultCallback == handleResult then onResultCallback = nil end
        if onLockCallback   == lockMenu     then onLockCallback   = nil end
    end)

    -- Confirm button click
    confirmBtn.MouseButton1Click:Connect(function()
        local ids = {}
        for id in pairs(selected) do table.insert(ids, id) end
        if #ids < 1 then return end
        confirmBtn.Text           = "..."
        confirmBtn.AutoButtonColor = false
        setMenuRemote:FireServer(ids)
    end)
end

-- ── LISTENERS ────────────────────────────────────────────────
openMenuBoardRemote.OnClientEvent:Connect(function(payload)
    buildMenuBoard(payload)
end)

print("[MenuClient] Ready.")
