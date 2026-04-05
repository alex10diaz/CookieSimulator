-- TEMP_DevAdmin.server.lua - DEV ONLY, remove before launch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

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
    player:SetAttribute("InTutorial", false)
    print("[DevAdmin] Reset data for " .. player.Name)
end)

RemoteManager.Get("DevAdmin_Note").OnServerEvent:Connect(function(player, note)
    if not isAuthorized(player) then return end
    if type(note) ~= "string" then return end

    note = note:sub(1, 200)
    if note:match("^%s*$") then return end

    print(string.format("[DEV NOTE %s] %s: %s", os.date("%H:%M:%S"), player.Name, note))
end)

print("[TEMP_DevAdmin] Dev tools active (owner-only).")
