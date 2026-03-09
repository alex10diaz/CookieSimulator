-- src/StarterPlayer/StarterPlayerScripts/Minigames/MixerController.client.lua
-- Shows cookie picker when server fires ShowMixPicker.
-- Player clicks a cookie → FireServer(cookieId) → server starts mix session.
-- During tutorial step 2, reads TutorialForceCookie attribute to restrict picker to one cookie.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local ShowMixPicker     = RemoteManager.Get("ShowMixPicker")
local RequestMixStart   = RemoteManager.Get("RequestMixStart")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COOKIES = {
	{ id = "pink_sugar",           label = "Pink Sugar"     },
	{ id = "chocolate_chip",       label = "Choc Chip"      },
	{ id = "birthday_cake",        label = "Bday Cake"      },
	{ id = "cookies_and_cream",    label = "C&C"            },
	{ id = "snickerdoodle",        label = "Snickerdoodle"  },
	{ id = "lemon_blackraspberry", label = "Lemon Berry"    },
}

local function showPicker(menuList)
	if playerGui:FindFirstChild("MixPickerGui") or playerGui:FindFirstChild("MixGui") then return end

	-- Check if tutorial is forcing a specific cookie (set by TutorialUI on step 2)
	local forcedCookie = playerGui:GetAttribute("TutorialForceCookie")
	local isForced     = forcedCookie ~= nil

	-- Build menu lookup set from server-provided active menu (nil = show all)
	local menuSet = nil
	if menuList and #menuList > 0 then
		menuSet = {}
		for _, id in ipairs(menuList) do menuSet[id] = true end
	end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "MixPickerGui"
	sg.ResetOnSpawn   = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent         = playerGui

	local bg = Instance.new("Frame", sg)
	bg.Size                   = UDim2.new(0, 280, 0, 260)
	bg.Position               = UDim2.new(0.5, -140, 0.5, -130)
	bg.BackgroundColor3       = Color3.fromRGB(30, 30, 30)
	bg.BackgroundTransparency = 0.1
	bg.BorderSizePixel        = 0
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)

	local title = Instance.new("TextLabel", bg)
	title.Size                   = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.TextColor3             = Color3.fromRGB(255, 255, 255)
	title.TextScaled             = true
	title.Font                   = Enum.Font.GothamBold
	-- Tutorial mode: show which cookie is required
	title.Text = isForced and "Tutorial: Pink Sugar Only!" or "Choose a Cookie"

	local cancelBtn = Instance.new("TextButton", bg)
	cancelBtn.Size             = UDim2.new(0, 28, 0, 28)
	cancelBtn.Position         = UDim2.new(1, -34, 0, 4)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	cancelBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	cancelBtn.TextScaled       = true
	cancelBtn.Font             = Enum.Font.GothamBold
	cancelBtn.Text             = "X"
	cancelBtn.BorderSizePixel  = 0
	Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)
	cancelBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

	local listFrame = Instance.new("Frame", bg)
	listFrame.Size                   = UDim2.new(1, 0, 1, -44)
	listFrame.Position               = UDim2.new(0, 0, 0, 44)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel        = 0

	local list = Instance.new("UIListLayout", listFrame)
	list.Padding             = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder           = Enum.SortOrder.LayoutOrder

	for i, cookie in ipairs(COOKIES) do
		local inMenu  = (not menuSet) or (menuSet[cookie.id] == true)
		local isMatch = inMenu and ((not isForced) or (cookie.id == forcedCookie))

		local btn = Instance.new("TextButton", listFrame)
		btn.LayoutOrder      = i
		btn.Size             = UDim2.new(0.9, 0, 0, 30)
		-- Dim non-matching cookies during tutorial
		btn.BackgroundColor3 = isMatch
			and Color3.fromRGB(240, 200, 140)
			or  Color3.fromRGB(120, 100, 80)
		btn.TextColor3       = isMatch
			and Color3.fromRGB(30, 30, 30)
			or  Color3.fromRGB(120, 120, 120)
		btn.TextScaled       = true
		btn.Font             = Enum.Font.GothamBold
		btn.Text             = cookie.label
		btn.BorderSizePixel  = 0
		btn.Active           = isMatch  -- non-matching buttons are non-interactive
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

		if isMatch then
			btn.MouseButton1Click:Connect(function()
				sg:Destroy()
				RequestMixStart:FireServer(cookie.id)
			end)
		end
	end
end

ShowMixPicker.OnClientEvent:Connect(function(menuList)
	showPicker(menuList)
end)

print("[MixerController] Ready.")
