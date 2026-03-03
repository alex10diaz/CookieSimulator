-- src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua
-- Shows the tutorial step overlay pushed by TutorialController (server).
-- Owns: FadeFrame (used by TutorialCamera), bottom panel, Final Menu.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")
local startGameRemote    = RemoteManager.Get("StartGame")
local replayRemote       = RemoteManager.Get("ReplayTutorial")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Build ScreenGui ──────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name           = "TutorialGui"
sg.ResetOnSpawn   = false
sg.Enabled        = true          -- always enabled; child visibility drives show/hide
sg.DisplayOrder   = 10
sg.IgnoreGuiInset = true          -- needed so FadeFrame covers full screen including top bar
sg.Parent         = playerGui

-- ─── FadeFrame — full-screen black overlay for cinematic transitions ──────────
-- TutorialCamera.client.lua controls its BackgroundTransparency via TweenService.
local fadeFrame = Instance.new("Frame")
fadeFrame.Name                   = "FadeFrame"
fadeFrame.Size                   = UDim2.new(1, 0, 1, 0)
fadeFrame.Position               = UDim2.new(0, 0, 0, 0)
fadeFrame.BackgroundColor3       = Color3.new(0, 0, 0)
fadeFrame.BackgroundTransparency = 1   -- starts invisible
fadeFrame.BorderSizePixel        = 0
fadeFrame.ZIndex                 = 20  -- above all other UI elements
fadeFrame.Parent                 = sg

-- ─── Bottom Panel ─────────────────────────────────────────────────────────────
local panel = Instance.new("Frame")
panel.Name                   = "TutorialPanel"
panel.Size                   = UDim2.new(0, 420, 0, 110)
panel.Position               = UDim2.new(0, 14, 1, -130)
panel.BackgroundColor3       = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.Parent                 = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local stepLbl = Instance.new("TextLabel")
stepLbl.Name                   = "StepLabel"
stepLbl.Size                   = UDim2.new(0.55, 0, 0, 26)
stepLbl.Position               = UDim2.new(0, 12, 0, 10)
stepLbl.BackgroundTransparency = 1
stepLbl.TextColor3             = Color3.fromRGB(255, 200, 60)
stepLbl.TextScaled             = true
stepLbl.Font                   = Enum.Font.GothamBold
stepLbl.TextXAlignment         = Enum.TextXAlignment.Left
stepLbl.Text                   = "Step 1 / 9"
stepLbl.Parent                 = panel

local skipBtn = Instance.new("TextButton")
skipBtn.Name             = "SkipButton"
skipBtn.Size             = UDim2.new(0, 80, 0, 28)
skipBtn.Position         = UDim2.new(1, -92, 0, 8)
skipBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
skipBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
skipBtn.TextScaled       = true
skipBtn.Font             = Enum.Font.Gotham
skipBtn.Text             = "Skip"
skipBtn.BorderSizePixel  = 0
skipBtn.Parent           = panel
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 8)

local msgLbl = Instance.new("TextLabel")
msgLbl.Name                   = "MessageLabel"
msgLbl.Size                   = UDim2.new(1, -24, 0, 56)
msgLbl.Position               = UDim2.new(0, 12, 0, 46)
msgLbl.BackgroundTransparency = 1
msgLbl.TextColor3             = Color3.fromRGB(240, 240, 240)
msgLbl.TextWrapped            = true
msgLbl.TextScaled             = false
msgLbl.TextSize               = 18
msgLbl.Font                   = Enum.Font.Gotham
msgLbl.TextXAlignment         = Enum.TextXAlignment.Left
msgLbl.Text                   = ""
msgLbl.Parent                 = panel

-- ─── Final Menu — shown on step 10 ───────────────────────────────────────────
local finalMenu = Instance.new("Frame")
finalMenu.Name                   = "FinalMenu"
finalMenu.Size                   = UDim2.new(0, 320, 0, 170)
finalMenu.Position               = UDim2.new(0.5, -160, 0.5, -85)
finalMenu.BackgroundColor3       = Color3.fromRGB(20, 20, 30)
finalMenu.BackgroundTransparency = 0.05
finalMenu.BorderSizePixel        = 0
finalMenu.Visible                = false
finalMenu.ZIndex                 = 15
finalMenu.Parent                 = sg
Instance.new("UICorner", finalMenu).CornerRadius = UDim.new(0, 16)

local menuTitle = Instance.new("TextLabel")
menuTitle.Size                   = UDim2.new(1, -20, 0, 40)
menuTitle.Position               = UDim2.new(0, 10, 0, 10)
menuTitle.BackgroundTransparency = 1
menuTitle.TextColor3             = Color3.fromRGB(255, 220, 80)
menuTitle.TextScaled             = true
menuTitle.Font                   = Enum.Font.GothamBold
menuTitle.Text                   = "You're ready to bake!"
menuTitle.ZIndex                 = 16
menuTitle.Parent                 = finalMenu

local startDayBtn = Instance.new("TextButton")
startDayBtn.Name             = "StartDayButton"
startDayBtn.Size             = UDim2.new(0, 280, 0, 50)
startDayBtn.Position         = UDim2.new(0, 20, 0, 60)
startDayBtn.BackgroundColor3 = Color3.fromRGB(34, 160, 70)
startDayBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
startDayBtn.TextScaled       = true
startDayBtn.Font             = Enum.Font.GothamBold
startDayBtn.Text             = "START DAY (PRE-OPEN)"
startDayBtn.BorderSizePixel  = 0
startDayBtn.ZIndex           = 16
startDayBtn.Parent           = finalMenu
Instance.new("UICorner", startDayBtn).CornerRadius = UDim.new(0, 10)

local replayBtn = Instance.new("TextButton")
replayBtn.Name             = "ReplayButton"
replayBtn.Size             = UDim2.new(0, 280, 0, 40)
replayBtn.Position         = UDim2.new(0, 20, 0, 120)
replayBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
replayBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
replayBtn.TextScaled       = true
replayBtn.Font             = Enum.Font.Gotham
replayBtn.Text             = "REPLAY TUTORIAL"
replayBtn.BorderSizePixel  = 0
replayBtn.ZIndex           = 16
replayBtn.Parent           = finalMenu
Instance.new("UICorner", replayBtn).CornerRadius = UDim.new(0, 10)

-- ─── Logic ───────────────────────────────────────────────────────────────────
tutorialStepRemote.OnClientEvent:Connect(function(data)
	if not data then return end

	-- Always hide final menu when any step fires
	finalMenu.Visible = false

	if data.step == 0 then
		-- Tutorial dismissed (complete, skip, or returning player)
		panel.Visible = false
		playerGui:SetAttribute("TutorialForceCookie", nil)
		return
	end

	if data.step == 10 then
		-- Final menu only — no bottom panel
		panel.Visible     = false
		finalMenu.Visible = true
		return
	end

	-- Steps 1–9: show bottom panel
	stepLbl.Text  = "Step " .. data.step .. " / 9"
	msgLbl.Text   = data.msg or ""
	panel.Visible = true

	-- Set or clear the forced cookie attribute for MixerController
	if data.forceCookieId then
		playerGui:SetAttribute("TutorialForceCookie", data.forceCookieId)
	else
		playerGui:SetAttribute("TutorialForceCookie", nil)
	end
end)

-- Skip button
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

print("[TutorialUI] Ready.")
