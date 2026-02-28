-- src/StarterPlayer/StarterPlayerScripts/Minigames/MixerController.client.lua
-- Handles Mixer ProximityPrompt → cookie picker → fires RequestMixStart to server.
-- Server then fires StartMixMinigame back; MixMinigame.client.lua takes over from there.

local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local RemoteManager   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local requestMixStart = RemoteManager.Get("RequestMixStart")

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

local BTN_W, BTN_H, BTN_PAD = 118, 60, 8

local function showPicker()
    if playerGui:FindFirstChild("MixPickerGui") then return end
    if playerGui:FindFirstChild("MixGui") then return end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "MixPickerGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = playerGui

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 280, 0, 340)
    bg.Position               = UDim2.new(0.5, -140, 0.5, -170)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)

    local title = Instance.new("TextLabel")
    title.Size                   = UDim2.new(1, 0, 0, 36)
    title.BackgroundTransparency = 1
    title.TextColor3             = Color3.fromRGB(255, 255, 255)
    title.TextScaled             = true
    title.Font                   = Enum.Font.GothamBold
    title.Text                   = "Choose a Cookie"
    title.Parent                 = bg

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size             = UDim2.new(0, 28, 0, 28)
    cancelBtn.Position         = UDim2.new(1, -34, 0, 4)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    cancelBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    cancelBtn.TextScaled       = true
    cancelBtn.Font             = Enum.Font.GothamBold
    cancelBtn.Text             = "X"
    cancelBtn.BorderSizePixel  = 0
    cancelBtn.Parent           = bg
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)
    cancelBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    local COLS = 3
    for i, cookie in ipairs(COOKIES) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, BTN_W, 0, BTN_H)
        btn.Position         = UDim2.new(0, 12 + col * (BTN_W + BTN_PAD),
                                          0, 44  + row * (BTN_H + BTN_PAD))
        btn.BackgroundColor3 = Color3.fromRGB(240, 200, 140)
        btn.TextColor3       = Color3.fromRGB(30, 30, 30)
        btn.TextScaled       = true
        btn.TextWrapped      = true
        btn.Font             = Enum.Font.GothamBold
        btn.Text             = cookie.label
        btn.BorderSizePixel  = 0
        btn.Parent           = bg
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        btn.MouseButton1Click:Connect(function()
            print("[MixerController] Cookie clicked: " .. tostring(cookie.id) .. " | remote type: " .. typeof(requestMixStart))
            sg:Destroy()
            requestMixStart:FireServer(cookie.id)
            print("[MixerController] FireServer called")
        end)
    end
end

-- Same pattern as POSClient: ProximityPromptService.PromptTriggered fires client-side
local mixersFolder = workspace:WaitForChild("Mixers", 10)
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
    if triggeringPlayer ~= player then return end
    local obj = prompt.Parent
    while obj do
        if obj == mixersFolder then showPicker() return end
        obj = obj.Parent
    end
end)

print("[MixerController] Ready.")
