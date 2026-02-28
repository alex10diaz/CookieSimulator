-- src/StarterPlayer/StarterPlayerScripts/Minigames/MixerController.client.lua
-- Handles the cookie picker UI and signals the server via player attribute.
-- The server fires "ShowMixPicker" to this client to open the UI.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local ShowMixPicker = RemoteManager.Get("ShowMixPicker")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Cookie options shown in the picker
local COOKIES = {
    { id = "pink_sugar",           label = "Pink Sugar"     },
    { id = "chocolate_chip",       label = "Choc Chip"      },
    { id = "birthday_cake",        label = "Bday Cake"      },
    { id = "cookies_and_cream",    label = "C&C"            },
    { id = "snickerdoodle",        label = "Snickerdoodle"  },
    { id = "lemon_blackraspberry", label = "Lemon Berry"    },
}

local function showPicker()
    if playerGui:FindFirstChild("MixPickerGui") or playerGui:FindFirstChild("MixGui") then return end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "MixPickerGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = playerGui

    local bg = Instance.new("Frame", sg)
    bg.Size                   = UDim2.new(0, 280, 0, 260) -- Adjusted size
    bg.Position               = UDim2.new(0.5, -140, 0.5, -130)
    bg.BackgroundColor3       = Color3.fromRGB(30, 30, 30)
    bg.BackgroundTransparency = 0.1
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)

    local title = Instance.new("TextLabel", bg)
    title.Size                   = UDim2.new(1, 0, 0, 36)
    title.BackgroundTransparency = 1
    title.TextColor3             = Color3.fromRGB(255, 255, 255)
    title.TextScaled             = true
    title.Font                   = Enum.Font.GothamBold
    title.Text                   = "Choose a Cookie"
    
    local cancelBtn = Instance.new("TextButton", bg)
    cancelBtn.Size             = UDim2.new(0, 28, 0, 28)
    cancelBtn.Position         = UDim2.new(1, -34, 0, 4)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    cancelBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    cancelBtn.TextScaled       = true
    cancelBtn.Font             = Enum.Font.GothamBold
    cancelBtn.Text             = "X"
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)
    cancelBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    local list = Instance.new("UIListLayout", bg)
    list.Padding = UDim.new(0, 8)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Position = UDim2.new(0, 0, 0, 44)

    for i, cookie in ipairs(COOKIES) do
        local btn = Instance.new("TextButton", bg)
        btn.LayoutOrder = i
        btn.Size             = UDim2.new(0.9, 0, 0, 50)
        btn.BackgroundColor3 = Color3.fromRGB(240, 200, 140)
        btn.TextColor3       = Color3.fromRGB(30, 30, 30)
        btn.TextScaled       = true
        btn.TextWrapped      = true
        btn.Font             = Enum.Font.GothamBold
        btn.Text             = cookie.label
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        btn.MouseButton1Click:Connect(function()
            player:SetAttribute("PendingMixCookie", cookie.id)
            sg:Destroy()
        end)
    end
end

ShowMixPicker.OnClientEvent:Connect(showPicker)

print("[MixerController] Ready.")