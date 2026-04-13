local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local OrderManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("OrderManager"))

local function leaderboardSetup(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cookies = Instance.new("IntValue")
	cookies.Name = "Cookies"
	cookies.Value = 0
	cookies.Parent = leaderstats

	local isPrimary = Instance.new("BoolValue")
	isPrimary.Name = "IsPrimary"
	isPrimary.Value = true
	isPrimary.Parent = cookies
end

Players.PlayerAdded:Connect(leaderboardSetup)

-- Wire to OrderManager delivery events
OrderManager.On("BoxDelivered", function(data)
	local box = data and data.box
	if not box then return end
	local carrierName = box.carrier
	local count = box.packSize or 1

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name == carrierName then
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local stat = leaderstats:FindFirstChild("Cookies")
				if stat then
					stat.Value = stat.Value + count
				end
			end
			break
		end
	end
end)
