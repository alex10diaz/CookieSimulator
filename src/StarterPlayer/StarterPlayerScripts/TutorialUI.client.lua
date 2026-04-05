-- src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua
-- Shows the tutorial step overlay pushed by TutorialController (server).
-- Owns: FadeFrame (used by TutorialCamera), bottom panel, Final Menu.
-- M7 Polish: dark navy + gold UIStroke + gold header bars (matches minigame UIs).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")
local startGameRemote    = RemoteManager.Get("StartGame")
local replayRemote       = RemoteManager.Get("ReplayTutorial")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local coolTransitions = require(ReplicatedStorage:WaitForChild("coolTransitions"))
local tutTransitions  = coolTransitions.TransitionManager.new(playerGui, {
    color        = Color3.fromRGB(14, 14, 26),
    displayOrder = 30,
})

local ACCENT  = Color3.fromRGB(255, 200, 0)   -- gold
local NAVY    = Color3.fromRGB(14, 14, 26)     -- dark panel

-- ─── Build ScreenGui ──────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name           = "TutorialGui"
sg.ResetOnSpawn   = false
sg.Enabled        = true
sg.DisplayOrder   = 5
sg.IgnoreGuiInset = true
sg.Parent         = playerGui

local function getViewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function clamp(n, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, n))
end

local function ensureTextConstraint(label, minSize, maxSize)
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not constraint then
		constraint = Instance.new("UITextSizeConstraint")
		constraint.Parent = label
	end
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
end

-- ─── FadeFrame ────────────────────────────────────────────────────────────────
local fadeFrame = Instance.new("Frame")
fadeFrame.Name                   = "FadeFrame"
fadeFrame.Size                   = UDim2.new(1, 0, 1, 0)
fadeFrame.Position               = UDim2.new(0, 0, 0, 0)
fadeFrame.BackgroundColor3       = Color3.new(0, 0, 0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel        = 0
fadeFrame.ZIndex                 = 20
fadeFrame.Parent                 = sg

-- ─── Bottom Panel ─────────────────────────────────────────────────────────────
local PW = clamp(getViewportSize().X - 24, 280, 420)
local panel = Instance.new("Frame")
panel.Name                   = "TutorialPanel"
panel.Size                   = UDim2.new(0, PW, 0, 136)
panel.Position               = UDim2.new(0.5, -PW/2, 1, -156)
panel.BackgroundColor3       = NAVY
panel.BackgroundTransparency = 0
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.Parent                 = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = ACCENT
panelStroke.Thickness = 1.5

-- Gold header bar (matches minigame UIs)
local headerBar = Instance.new("Frame", panel)
headerBar.Name             = "HeaderBar"
headerBar.Size             = UDim2.new(1, 0, 0, 44)
headerBar.BackgroundColor3 = ACCENT
headerBar.BorderSizePixel  = 0
Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 16)
local headerFlat = Instance.new("Frame", headerBar)
headerFlat.Size             = UDim2.new(1, 0, 0.5, 0)
headerFlat.Position         = UDim2.new(0, 0, 0.5, 0)
headerFlat.BackgroundColor3 = ACCENT
headerFlat.BorderSizePixel  = 0

local stepLbl = Instance.new("TextLabel")
stepLbl.Name                   = "StepLabel"
stepLbl.Size                   = UDim2.new(1, -90, 1, 0)
stepLbl.Position               = UDim2.new(0, 14, 0, 0)
stepLbl.BackgroundTransparency = 1
stepLbl.TextColor3             = Color3.fromRGB(20, 14, 4)
stepLbl.TextScaled             = true
stepLbl.Font                   = Enum.Font.GothamBold
stepLbl.TextXAlignment         = Enum.TextXAlignment.Left
stepLbl.Text                   = "Tutorial  —  Step 1 / 5"
stepLbl.Parent                 = headerBar
ensureTextConstraint(stepLbl, 12, 22)

-- Skip button in header (top-right, matches minigame exit button style)
local skipBtn = Instance.new("TextButton")
skipBtn.Name             = "SkipButton"
skipBtn.Size             = UDim2.new(0, 54, 0, 44)
skipBtn.Position         = UDim2.new(1, -62, 0, 0)
skipBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
skipBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
skipBtn.TextScaled       = true
skipBtn.Font             = Enum.Font.GothamBold
skipBtn.Text             = "Skip"
skipBtn.BorderSizePixel  = 0
skipBtn.ZIndex           = 5
skipBtn.Parent           = headerBar
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 6)
ensureTextConstraint(skipBtn, 11, 18)

local msgLbl = Instance.new("TextLabel")
msgLbl.Name                   = "MessageLabel"
msgLbl.Size                   = UDim2.new(1, -28, 0, 76)
msgLbl.Position               = UDim2.new(0, 14, 0, 50)
msgLbl.BackgroundTransparency = 1
msgLbl.TextColor3             = Color3.fromRGB(220, 220, 240)
msgLbl.TextWrapped            = true
msgLbl.TextScaled             = false
msgLbl.TextSize               = 17
msgLbl.Font                   = Enum.Font.Gotham
msgLbl.TextXAlignment         = Enum.TextXAlignment.Left
msgLbl.TextYAlignment         = Enum.TextYAlignment.Top
msgLbl.Text                   = ""
msgLbl.Parent                 = panel

-- ─── Final Menu ───────────────────────────────────────────────────────────────
local finalMenu = Instance.new("Frame")
finalMenu.Name                   = "FinalMenu"
finalMenu.Size                   = UDim2.new(0, 340, 0, 220)
finalMenu.Position               = UDim2.new(0.5, -170, 0.5, -110)
finalMenu.BackgroundColor3       = NAVY
finalMenu.BackgroundTransparency = 0
finalMenu.BorderSizePixel        = 0
finalMenu.Visible                = false
finalMenu.ZIndex                 = 15
finalMenu.Parent                 = sg
Instance.new("UICorner", finalMenu).CornerRadius = UDim.new(0, 16)
local finalStroke = Instance.new("UIStroke", finalMenu)
finalStroke.Color     = ACCENT
finalStroke.Thickness = 1.5

-- Gold header bar
local finalHeader = Instance.new("Frame", finalMenu)
finalHeader.Name             = "HeaderBar"
finalHeader.Size             = UDim2.new(1, 0, 0, 44)
finalHeader.BackgroundColor3 = ACCENT
finalHeader.BorderSizePixel  = 0
finalHeader.ZIndex           = 16
Instance.new("UICorner", finalHeader).CornerRadius = UDim.new(0, 16)
local fhFlat = Instance.new("Frame", finalHeader)
fhFlat.Size             = UDim2.new(1, 0, 0.5, 0)
fhFlat.Position         = UDim2.new(0, 0, 0.5, 0)
fhFlat.BackgroundColor3 = ACCENT
fhFlat.BorderSizePixel  = 0

local menuTitle = Instance.new("TextLabel", finalHeader)
menuTitle.Size                   = UDim2.new(1, -14, 1, 0)
menuTitle.Position               = UDim2.new(0, 14, 0, 0)
menuTitle.BackgroundTransparency = 1
menuTitle.TextColor3             = Color3.fromRGB(20, 14, 4)
menuTitle.TextScaled             = true
menuTitle.Font                   = Enum.Font.GothamBold
menuTitle.Text                   = "You're ready to bake!"
menuTitle.TextXAlignment         = Enum.TextXAlignment.Left
menuTitle.ZIndex                 = 16
ensureTextConstraint(menuTitle, 13, 24)

-- Reward label shown under the header
local rewardLbl = Instance.new("TextLabel", finalMenu)
rewardLbl.Name                   = "RewardLabel"
rewardLbl.Size                   = UDim2.new(1, -28, 0, 28)
rewardLbl.Position               = UDim2.new(0, 14, 0, 50)
rewardLbl.BackgroundTransparency = 1
rewardLbl.TextColor3             = ACCENT
rewardLbl.TextScaled             = true
rewardLbl.Font                   = Enum.Font.GothamBold
rewardLbl.Text                   = ""
rewardLbl.ZIndex                 = 16
ensureTextConstraint(rewardLbl, 12, 20)

local startDayBtn = Instance.new("TextButton")
startDayBtn.Name             = "StartDayButton"
startDayBtn.Size             = UDim2.new(1, -28, 0, 52)
startDayBtn.Position         = UDim2.new(0, 14, 0, 88)
startDayBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 40)
startDayBtn.TextColor3       = Color3.fromRGB(200, 240, 200)
startDayBtn.TextScaled       = true
startDayBtn.Font             = Enum.Font.GothamBold
startDayBtn.Text             = "START DAY (PRE-OPEN)"
startDayBtn.BorderSizePixel  = 0
startDayBtn.ZIndex           = 16
startDayBtn.Parent           = finalMenu
Instance.new("UICorner", startDayBtn).CornerRadius = UDim.new(0, 10)
local sdStroke = Instance.new("UIStroke", startDayBtn)
sdStroke.Color     = Color3.fromRGB(50, 160, 60)
sdStroke.Thickness = 1.5
ensureTextConstraint(startDayBtn, 12, 20)

local replayBtn = Instance.new("TextButton")
replayBtn.Name             = "ReplayButton"
replayBtn.Size             = UDim2.new(1, -28, 0, 44)
replayBtn.Position         = UDim2.new(0, 14, 0, 150)
replayBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 52)
replayBtn.TextColor3       = Color3.fromRGB(160, 160, 190)
replayBtn.TextScaled       = true
replayBtn.Font             = Enum.Font.Gotham
replayBtn.Text             = "REPLAY TUTORIAL"
replayBtn.BorderSizePixel  = 0
replayBtn.ZIndex           = 16
replayBtn.Parent           = finalMenu
Instance.new("UICorner", replayBtn).CornerRadius = UDim.new(0, 10)
local rpStroke = Instance.new("UIStroke", replayBtn)
rpStroke.Color     = Color3.fromRGB(55, 55, 80)
rpStroke.Thickness = 1
ensureTextConstraint(replayBtn, 11, 18)

local function applyResponsiveLayout()
	local vp = getViewportSize()
	local compact = vp.X <= 700 or vp.Y <= 500
	local panelWidth = clamp(vp.X - 24, 280, 420)
	local panelHeight = compact and 126 or 136
	panel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
	panel.Position = UDim2.new(0.5, -math.floor(panelWidth / 2), 1, -(panelHeight + 20))

	headerBar.Size = UDim2.new(1, 0, 0, compact and 40 or 44)
	stepLbl.Size = UDim2.new(1, compact and -82 or -90, 1, 0)
	stepLbl.Position = UDim2.new(0, 12, 0, 0)
	skipBtn.Size = UDim2.new(0, compact and 50 or 54, 0, compact and 40 or 44)
	skipBtn.Position = UDim2.new(1, compact and -58 or -62, 0, 0)

	msgLbl.Position = UDim2.new(0, 14, 0, compact and 46 or 50)
	msgLbl.Size = UDim2.new(1, -28, 0, compact and 68 or 76)
	msgLbl.TextSize = compact and 15 or 17

	local finalWidth = clamp(vp.X - 40, 260, 340)
	local finalHeight = compact and 198 or 220
	finalMenu.Size = UDim2.new(0, finalWidth, 0, finalHeight)
	finalMenu.Position = UDim2.new(0.5, -math.floor(finalWidth / 2), 0.5, -math.floor(finalHeight / 2))
	finalHeader.Size = UDim2.new(1, 0, 0, compact and 40 or 44)
	rewardLbl.Position = UDim2.new(0, 14, 0, compact and 46 or 50)
	rewardLbl.Size = UDim2.new(1, -28, 0, compact and 24 or 28)
	startDayBtn.Position = UDim2.new(0, 14, 0, compact and 78 or 88)
	startDayBtn.Size = UDim2.new(1, -28, 0, compact and 46 or 52)
	replayBtn.Position = UDim2.new(0, 14, 0, compact and 132 or 150)
	replayBtn.Size = UDim2.new(1, -28, 0, compact and 40 or 44)
end

local viewportConn = nil
local function connectViewportResize()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if viewportConn then
		viewportConn:Disconnect()
	end
	viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
end

applyResponsiveLayout()
connectViewportResize()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	applyResponsiveLayout()
	connectViewportResize()
end)

-- ─── Logic ───────────────────────────────────────────────────────────────────
-- BUG-38: once step=0 is received (returning player OR completion), never re-show panel
local isTutorialComplete = false

tutorialStepRemote.OnClientEvent:Connect(function(data)
	if not data then return end
	tutTransitions:PlayInOut(0.5, function()
		-- Always hide final menu when any step fires
		finalMenu.Visible = false

		if data.step == 0 then
			-- Tutorial dismissed (complete, skip, or returning player)
			panel.Visible = false
			playerGui:SetAttribute("TutorialForceCookie", nil)
			isTutorialComplete = true  -- BUG-38: permanent guard
			return
		end

		-- Final menu: step > total (e.g. step=6, total=5)
		if data.step > (data.total or 5) then
			panel.Visible     = false
			finalMenu.Visible = true
			if data.reward and data.reward > 0 then
				rewardLbl.Text = "Reward: +" .. data.reward .. " Coins!"
			else
				rewardLbl.Text = ""
			end
			return
		end

		-- BUG-38: reset flag on any valid step so dev-triggered restarts work
		isTutorialComplete = false

		-- Steps 1–N: show bottom panel with dynamic counter
		stepLbl.Text  = "Tutorial  —  Step " .. data.step .. " / " .. (data.total or 5)
		msgLbl.Text   = data.msg or ""
		panel.Visible = true

		if data.forceCookieId then
			playerGui:SetAttribute("TutorialForceCookie", data.forceCookieId)
		else
			playerGui:SetAttribute("TutorialForceCookie", nil)
		end
	end, "Center", "Iris", 0.5)
end)

-- Skip button — fires TutorialComplete; server handles completion from any step
skipBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
	tutorialDoneRemote:FireServer()
end)

-- Start Day button
startDayBtn.MouseButton1Click:Connect(function()
	finalMenu.Visible = false
	startGameRemote:FireServer()
end)

-- Replay Tutorial button
replayBtn.MouseButton1Click:Connect(function()
	finalMenu.Visible = false
	replayRemote:FireServer()
end)

-- Hide AI hire prompts while this player is in tutorial
local function setHirePromptsEnabled(enabled)
	for _, obj in ipairs(workspace:GetChildren()) do
		if string.sub(obj.Name, 1, 11) == "HireAnchor_" then
			local prompt = obj:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = enabled end
		end
	end
end

local lp = Players.LocalPlayer
local function onInTutorialChanged()
	local inTutorial = lp:GetAttribute("InTutorial")
	setHirePromptsEnabled(not inTutorial)
end

lp:GetAttributeChangedSignal("InTutorial"):Connect(onInTutorialChanged)
onInTutorialChanged()  -- apply immediately on load

workspace.ChildAdded:Connect(function(child)
	if string.sub(child.Name, 1, 11) == "HireAnchor_" then
		if lp:GetAttribute("InTutorial") then
			local prompt = child:WaitForChild("ProximityPrompt", 3)
			if prompt then prompt.Enabled = false end
		end
	end
end)

print("[TutorialUI] Ready.")
