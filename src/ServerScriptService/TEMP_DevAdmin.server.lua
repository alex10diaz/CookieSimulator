-- TEMP_DevAdmin.server.lua - DEV ONLY, remove before launch.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
local TutorialKitchen   = require(ServerScriptService:WaitForChild("TutorialKitchen"))

local function isAuthorized(player)
    if game.CreatorType == Enum.CreatorType.User then
        return player.UserId == game.CreatorId
    end
    if game.CreatorType == Enum.CreatorType.Group then
        local ok, rank = pcall(function()
            return player:GetRankInGroup(game.CreatorId)
        end)
        return ok and rank == 255
    end
    return false
end

RemoteManager.Get("DevAdmin_ResetData").OnServerEvent:Connect(function(player)
    if not isAuthorized(player) then return end
    PlayerDataManager.ResetData(player)
    print("[DevAdmin] Data reset for " .. player.Name)
end)

RemoteManager.Get("DevAdmin_StartTutorial").OnServerEvent:Connect(function(player)
    if not isAuthorized(player) then return end
    player:SetAttribute("InTutorial", true)
    task.delay(0.5, function()
        if player and player.Parent then
            TutorialKitchen.StartForPlayer(player)
        end
    end)
    print("[DevAdmin] Tutorial started for " .. player.Name)
end)

RemoteManager.Get("DevAdmin_AddCoins").OnServerEvent:Connect(function(player, amount)
    if not isAuthorized(player) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount > 1000000 then return end
    PlayerDataManager.AddCoins(player, math.floor(amount))
    print("[DevAdmin] +" .. math.floor(amount) .. " coins to " .. player.Name)
end)

RemoteManager.Get("DevAdmin_AddPlayerXP").OnServerEvent:Connect(function(player, amount)
    if not isAuthorized(player) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount > 1000000 then return end
    local newXP, newLevel = PlayerDataManager.AddXP(player, math.floor(amount))
    local data = PlayerDataManager.GetData(player)
    if data then
        RemoteManager.Get("HUDUpdate"):FireClient(player, data.coins, newXP, newLevel)
    end
    print("[DevAdmin] +" .. math.floor(amount) .. " player XP to " .. player.Name)
end)

RemoteManager.Get("DevAdmin_AddBakeryXP").OnServerEvent:Connect(function(player, amount)
    if not isAuthorized(player) then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount > 1000000 then return end
    PlayerDataManager.AwardBakeryXP(player, math.floor(amount))
    print("[DevAdmin] +" .. math.floor(amount) .. " bakery XP to " .. player.Name)
end)

RemoteManager.Get("DevAdmin_Note").OnServerEvent:Connect(function(player, note)
    if not isAuthorized(player) then return end
    if type(note) ~= "string" then return end
    note = note:sub(1, 200)
    if note:match("^%s*$") then return end
    print(string.format("[DEV NOTE %s] %s: %s", os.date("%H:%M:%S"), player.Name, note))
end)

print("[TEMP_DevAdmin] Dev tools active (owner-only).")
