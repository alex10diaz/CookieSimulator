-- MainMenuController (LocalScript)
-- Shows the main menu on join; hides it when the game transitions out of Lobby.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local stateRemote   = RemoteManager.Get("GameStateChanged")

local gui     = script.Parent
local bg      = gui:WaitForChild("Background")
local card    = bg:WaitForChild("MenuCard")
local playBtn = card:WaitForChild("PlayButton")

local dismissed = false

local function hideMenu()
    if dismissed then return end
    dismissed = true
    gui.Enabled = false
end

-- Hide menu as soon as game moves out of Lobby
stateRemote.OnClientEvent:Connect(function(state)
    if state ~= "Lobby" then hideMenu() end
end)

-- Play button — Activated fires on both mouse click and touch tap
playBtn.Activated:Connect(function()
    hideMenu()
end)

-- If game is already past Lobby when this loads, hide immediately
task.defer(function()
    local attr = game:GetService("Workspace"):GetAttribute("GameState")
    if attr and attr ~= "Lobby" then hideMenu() end
end)

print("[MainMenuController] Ready.")
