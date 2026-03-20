-- MainMenuController (LocalScript)
-- Shows the main menu on join; hides it when the game transitions out of Lobby.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local stateRemote   = RemoteManager.Get("GameStateChanged")

local gui    = script.Parent
local bg     = gui:WaitForChild("Background")
local card   = bg:WaitForChild("MenuCard")
local playBtn = card:WaitForChild("PlayButton")

local function hideMenu()
    local t = TweenService:Create(bg, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
    t:Play()
    t.Completed:Connect(function() gui.Enabled = false end)
end

-- Hide menu as soon as game moves out of Lobby
stateRemote.OnClientEvent:Connect(function(state)
    if state ~= "Lobby" and gui.Enabled then
        hideMenu()
    end
end)

-- Play button: manually trigger if still in Lobby (e.g. game already running)
playBtn.MouseButton1Click:Connect(function()
    hideMenu()
end)

-- If game is already past Lobby when this loads, hide immediately
task.defer(function()
    local attr = game:GetService("Workspace"):GetAttribute("GameState")
    if attr and attr ~= "Lobby" then
        gui.Enabled = false
    end
end)

print("[MainMenuController] Ready.")
