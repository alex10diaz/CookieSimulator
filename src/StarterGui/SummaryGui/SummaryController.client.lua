-- src/StarterGui/SummaryGui/SummaryController.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local summaryEvent   = RemoteManager.Get("EndOfDaySummary")
local stateRemote    = RemoteManager.Get("GameStateChanged")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui       = playerGui:WaitForChild("SummaryGui")
local frame     = gui:WaitForChild("SummaryFrame")
local body      = frame:WaitForChild("Body")

summaryEvent.OnClientEvent:Connect(function(data)
    body.Text = string.format(
        "Orders Completed: %d\nCoins Earned: %d\nBest Combo: x%d\nAvg Rating: %s",
        data.orders  or 0,
        data.coins   or 0,
        data.combo   or 0,
        string.rep("*", math.round(data.avgStars or 3))
    )
    gui.Enabled = true
end)

stateRemote.OnClientEvent:Connect(function(state)
    if state == "PreOpen" then
        gui.Enabled = false
    end
end)

print("[SummaryController] Ready.")
