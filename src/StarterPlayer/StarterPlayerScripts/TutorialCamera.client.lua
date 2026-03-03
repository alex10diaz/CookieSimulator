-- src/StarterPlayer/StarterPlayerScripts/TutorialCamera.client.lua
-- Cinematic fade/teleport/glide per tutorial step.
-- Listens to TutorialStep; reads FadeFrame from TutorialGui (created by TutorialUI).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local RemoteManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local tutorialStepRemote = RemoteManager.Get("TutorialStep")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for TutorialGui and its FadeFrame (created by TutorialUI.client.lua)
local tutorialGui = playerGui:WaitForChild("TutorialGui", 15)
local fadeFrame   = tutorialGui and tutorialGui:WaitForChild("FadeFrame", 10)
if not fadeFrame then
	warn("[TutorialCamera] FadeFrame not found in TutorialGui — check TutorialUI.client.lua")
end

-- ─── Camera Target Mapping ────────────────────────────────────────────────────
-- Maps the `target` string from TutorialStep payload → a Part or Model in workspace.
-- Each value is the Part/Model the camera should frame and the character spawn offset from.
local TARGET_PARTS = {
	POS             = workspace.POS.Tablet,
	Mixer           = workspace.Mixers["Mixer 1"],
	DoughTable      = workspace.DoughCamera,
	FridgePinkSugar = workspace.Fridges.fridge_pink_sugar,
	Oven            = workspace.Ovens.Oven1,
	FrostTable      = workspace.Store["Frost Table"],
	DressTable      = workspace.Dress["Dress Table"],
	WaitingArea     = workspace.WaitingArea.Spot1,
	GameSpawn       = workspace:FindFirstChild("GameSpawn"),
}

local FADE_TIME  = 0.4
local GLIDE_TIME = 2.0

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function getPosition(obj)
	if not obj then return Vector3.new(0, 5, 0) end
	if obj:IsA("BasePart") then return obj.Position end
	if obj:IsA("Model") then
		local cf, _ = obj:GetBoundingBox()
		return cf.Position
	end
	return Vector3.new(0, 5, 0)
end

local function fadeOut()
	if not fadeFrame then return end
	local t = TweenService:Create(fadeFrame, TweenInfo.new(FADE_TIME), { BackgroundTransparency = 0 })
	t:Play(); t.Completed:Wait()
end

local function fadeIn()
	if not fadeFrame then return end
	local t = TweenService:Create(fadeFrame, TweenInfo.new(FADE_TIME), { BackgroundTransparency = 1 })
	t:Play(); t.Completed:Wait()
end

local function getHRP()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

-- ─── Cinematic Transition ─────────────────────────────────────────────────────
-- Fade to black → teleport → fade in → camera glide → release to Follow
local function performTransition(targetKey)
	local targetObj = TARGET_PARTS[targetKey]
	if not targetObj then
		warn("[TutorialCamera] Unknown target key: " .. tostring(targetKey))
		return
	end

	local hrp = getHRP()
	if not hrp then return end

	local targetPos = getPosition(targetObj)

	-- 1. Screen goes black
	fadeOut()

	-- 2. Teleport character to stand in front of station
	hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 0, 6), targetPos)

	-- 3. Camera starts wide (above and behind station)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(targetPos + Vector3.new(0, 15, 20), targetPos)

	-- 4. Screen fades in — player sees the wide camera framing the station
	fadeIn()

	-- 5. Camera glides smoothly to a closer focus position (cinematic push-in)
	local focusCFrame = CFrame.new(targetPos + Vector3.new(0, 6, 10), targetPos)
	local glide = TweenService:Create(camera,
		TweenInfo.new(GLIDE_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ CFrame = focusCFrame }
	)
	glide:Play()
	glide.Completed:Wait()

	-- 6. Return control to player — they can now move and interact with the station
	camera.CameraType = Enum.CameraType.Custom
	print("[TutorialCamera] -> " .. targetKey .. " (glide complete, player has control)")
end

-- ─── GameSpawn Transition ─────────────────────────────────────────────────────
-- Used on step 0 (tutorial done or returning player). No glide — clean arrival.
local function spawnAtGameSpawn()
	local spawnPart = TARGET_PARTS.GameSpawn or workspace:FindFirstChild("GameSpawn")
	if not spawnPart then
		warn("[TutorialCamera] workspace.GameSpawn not found — place it in Studio!")
		camera.CameraType = Enum.CameraType.Custom
		return
	end

	local hrp = getHRP()
	if not hrp then
		camera.CameraType = Enum.CameraType.Custom
		return
	end

	local spawnPos = getPosition(spawnPart)

	-- Fade black -> teleport -> camera Custom -> fade in
	fadeOut()
	hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
	camera.CameraType = Enum.CameraType.Custom
	fadeIn()
	print("[TutorialCamera] -> GameSpawn (tutorial complete)")
end

-- ─── Main Listener ────────────────────────────────────────────────────────────
tutorialStepRemote.OnClientEvent:Connect(function(data)
	if not data then return end

	if data.step == 0 then
		-- Tutorial dismissed (complete, skip, or returning player)
		task.spawn(spawnAtGameSpawn)
		return
	end

	if data.step == 10 then
		-- Final menu — TutorialUI handles this, no camera transition
		return
	end

	-- Steps 1-9: cinematic transition to the step's target station
	if data.target then
		task.spawn(performTransition, data.target)
	end
end)

print("[TutorialCamera] Ready.")
