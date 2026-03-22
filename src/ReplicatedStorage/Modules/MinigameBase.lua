-- MinigameBase
-- Shared client utilities for all minigames.
-- Handles: result display, connection tracking, cleanup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MinigameBase = {}

-- ============================================================
-- CONNECTION TRACKER
-- ============================================================
function MinigameBase.NewTracker()
    local tracker = { _conns = {} }

    function tracker:Add(conn)
        table.insert(self._conns, conn)
        return conn
    end

    function tracker:DisconnectAll()
        for _, c in ipairs(self._conns) do
            if typeof(c) == "RBXScriptConnection" then
                c:Disconnect()
            end
        end
        self._conns = {}
    end

    return tracker
end

-- ============================================================
-- RESULT POPUP
-- ============================================================
function MinigameBase.ShowResult(emoji, label, score)
    local Players   = game:GetService("Players")
    local player    = Players.LocalPlayer
    if not player then return end
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("MinigameResult")
    if existing then existing:Destroy() end

    local result = Instance.new("ScreenGui")
    result.Name         = "MinigameResult"
    result.ResetOnSpawn = false
    result.DisplayOrder = 25   -- P0-3: above HUD (20) and minigame GUIs (22)
    result.Parent       = playerGui

    local card = Instance.new("Frame")
    card.Size             = UDim2.new(0, 320, 0, 90)
    card.Position         = UDim2.new(0.5, -160, 0.5, -45)
    card.BackgroundColor3 = Color3.fromRGB(220, 235, 255)
    card.BorderSizePixel  = 0
    card.Parent           = result
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1, -10, 1, -10)
    lbl.Position           = UDim2.new(0, 5, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text               = emoji .. " " .. label .. ": " .. score .. "%"
    lbl.TextColor3         = Color3.fromRGB(10, 60, 120)
    lbl.TextScaled         = true
    lbl.Font               = Enum.Font.GothamBold
    lbl.Parent             = card

    task.delay(2.5, function() result:Destroy() end)
end

-- ============================================================
-- STANDARD FINISH
-- ============================================================
function MinigameBase.Finish(params)
    local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

    if params.gui then params.gui.Enabled = false end
    if params.tracker then params.tracker:DisconnectAll() end

    MinigameBase.ShowResult(params.emoji, params.label, params.score)
    RemoteManager.Get(params.resultRemoteName):FireServer(params.score)
end

return MinigameBase
