-- src/StarterPlayer/StarterPlayerScripts/Minigames/MixerController.client.lua
-- Shows cookie picker when server fires ShowMixPicker.
-- Player clicks a cookie → FireServer(cookieId) → server starts mix session.
-- During tutorial step 2, reads TutorialForceCookie attribute to restrict picker to one cookie.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local CookieData      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local ShowMixPicker   = RemoteManager.Get("ShowMixPicker")
local RequestMixStart = RemoteManager.Get("RequestMixStart")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ACCENT = Color3.fromRGB(255, 200, 0)  -- gold

local function showPicker(menuList)
    if playerGui:FindFirstChild("MixPickerGui") or playerGui:FindFirstChild("MixGui") then return end

    local forcedCookie = playerGui:GetAttribute("TutorialForceCookie")
    local isForced     = forcedCookie ~= nil

    local menuSet = nil
    if menuList and #menuList > 0 then
        menuSet = {}
        for _, id in ipairs(menuList) do menuSet[id] = true end
    end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "MixPickerGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = playerGui

    -- ── Main card ──
    local bg = Instance.new("Frame", sg)
    bg.Size                   = UDim2.new(0, 300, 0, 320)
    bg.Position               = UDim2.new(0.5, -150, 0.5, -160)
    bg.BackgroundColor3       = Color3.fromRGB(14, 14, 26)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel        = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)
    local bgStroke = Instance.new("UIStroke", bg)
    bgStroke.Color     = ACCENT
    bgStroke.Thickness = 1.5

    -- ── Gold header bar ──
    local headerBar = Instance.new("Frame", bg)
    headerBar.Name             = "HeaderBar"
    headerBar.Size             = UDim2.new(1, 0, 0, 44)
    headerBar.BackgroundColor3 = ACCENT
    headerBar.BorderSizePixel  = 0
    Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 16)
    local hFlat = Instance.new("Frame", headerBar)
    hFlat.Size             = UDim2.new(1, 0, 0.5, 0)
    hFlat.Position         = UDim2.new(0, 0, 0.5, 0)
    hFlat.BackgroundColor3 = ACCENT
    hFlat.BorderSizePixel  = 0

    local titleLbl = Instance.new("TextLabel", headerBar)
    titleLbl.Size                   = UDim2.new(1, -56, 1, 0)
    titleLbl.Position               = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3             = Color3.fromRGB(20, 14, 4)
    titleLbl.TextScaled             = true
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.Text                   = isForced and "Tutorial: Pink Sugar Only!" or "Choose a Cookie"
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left

    -- ── Cancel button ──
    local cancelBtn = Instance.new("TextButton", bg)
    cancelBtn.Size             = UDim2.new(0, 30, 0, 30)
    cancelBtn.Position         = UDim2.new(1, -38, 0, 7)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(200, 55, 55)
    cancelBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    cancelBtn.TextScaled       = true
    cancelBtn.Font             = Enum.Font.GothamBold
    cancelBtn.Text             = "X"
    cancelBtn.BorderSizePixel  = 0
    cancelBtn.ZIndex           = 5
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(1, 0)
    cancelBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    -- ── Cookie list ──
    local listFrame = Instance.new("ScrollingFrame", bg)
    listFrame.Size                   = UDim2.new(1, -16, 1, -54)
    listFrame.Position               = UDim2.new(0, 8, 0, 50)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel        = 0
    listFrame.ScrollBarThickness     = 4
    listFrame.ScrollBarImageColor3   = ACCENT
    listFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)

    local list = Instance.new("UIListLayout", listFrame)
    list.Padding             = UDim.new(0, 6)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.SortOrder           = Enum.SortOrder.LayoutOrder

    local ROW_H   = 36
    local ROW_GAP = 6
    local rowCount = 0

    for i, cookie in ipairs(CookieData.Cookies) do
        local inMenu = (not menuSet) or (menuSet[cookie.id] == true)
        if not inMenu then continue end

        local isMatch = (not isForced) or (cookie.id == forcedCookie)
        rowCount += 1

        local btn = Instance.new("TextButton", listFrame)
        btn.LayoutOrder      = i
        btn.Size             = UDim2.new(0.94, 0, 0, ROW_H)
        btn.BackgroundColor3 = isMatch
            and Color3.fromRGB(36, 30, 8)
            or  Color3.fromRGB(20, 20, 34)
        btn.TextColor3       = isMatch
            and Color3.fromRGB(255, 215, 80)
            or  Color3.fromRGB(70, 70, 90)
        btn.TextScaled       = true
        btn.Font             = Enum.Font.GothamBold
        btn.Text             = cookie.name
        btn.BorderSizePixel  = 0
        btn.Active           = isMatch
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Color     = isMatch
            and Color3.fromRGB(180, 140, 20)
            or  Color3.fromRGB(35, 35, 55)
        btnStroke.Thickness = 1

        if isMatch then
            btn.MouseButton1Click:Connect(function()
                sg:Destroy()
                RequestMixStart:FireServer(cookie.id)
            end)
        end
    end

    listFrame.CanvasSize = UDim2.new(0, 0, 0, rowCount * ROW_H + math.max(0, rowCount - 1) * ROW_GAP)
end

ShowMixPicker.OnClientEvent:Connect(function(menuList)
    showPicker(menuList)
end)

print("[MixerController] Ready.")
