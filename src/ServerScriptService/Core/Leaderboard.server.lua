
local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local function leaderboardSetup(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local money = Instance.new("IntValue")
	money.Name = "Cookies"
	money.Value = 0
	money.Parent = leaderstats

	local isPrimary = Instance.new("BoolValue")
	isPrimary.Name = "IsPrimary"
	isPrimary.Value = true
	isPrimary.Parent = money
end

Players.PlayerAdded:Connect(leaderboardSetup)
for _, player in ipairs(Players:GetPlayers()) do
	leaderboardSetup(player)
end

-- Sync leaderstats.Cookies from PlayerDataManager every 5 seconds
task.spawn(function()
	while true do
		task.wait(5)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = PlayerDataManager.GetData(player)
			if data then
				local ls = player:FindFirstChild("leaderstats")
				if ls then
					local cookiesVal = ls:FindFirstChild("Cookies")
					if cookiesVal then
						cookiesVal.Value = data.coins or 0
					end
				end
			end
		end
	end
end)

print("[Leaderboard] Ready — syncing coins every 5s.")
