-- MainMenuController
-- Handles main menu interactions.
-- TODO: Replace placeholder with full designed menu.

local gui     = script.Parent
local bg      = gui:WaitForChild("Background")
local playBtn = bg:WaitForChild("PlayButton")

playBtn.MouseButton1Click:Connect(function()
    gui.Enabled = false
    -- TODO: trigger game start / character spawn
end)
