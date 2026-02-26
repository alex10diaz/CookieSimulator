# Milestone 2: Real Minigames — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace PlaceholderMinigame with 5 self-contained client minigame scripts (Mix, Dough, Oven, Frost, Dress) that fire scores 0–100 to the server through the existing MinigameServer pipeline.

**Architecture:** One LocalScript per minigame in `src/StarterPlayer/StarterPlayerScripts/Minigames/`. Each script listens for its StartXxx remote, builds a ScreenGui overlay, runs its mechanic, then fires XxxMinigameResult back to the server with a 0–100 score. No new remotes. No shared framework. MinigameServer needs one patch (Dress gets cookieId passed when fired).

**Tech Stack:** Roblox Luau, RunService.Heartbeat, UserInputService, RemoteManager (existing), Rojo (file sync), MCP run_code for Studio verification.

---

## Task 0: Delete PlaceholderMinigame

**Files:**
- Delete: `src/StarterPlayer/StarterPlayerScripts/Minigames/PlaceholderMinigame.client.lua`

**Step 1: Verify placeholder exists**

Run in MCP (run_code):
```lua
local scripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local mg = scripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("PlaceholderMinigame") and "EXISTS" or "MISSING")
```
Expected output: `EXISTS`

**Step 2: Delete the file**

```bash
rm "src/StarterPlayer/StarterPlayerScripts/Minigames/PlaceholderMinigame.client.lua"
```

**Step 3: Verify it's gone from Studio**

Wait 2 seconds for Rojo sync, then run in MCP:
```lua
local scripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local mg = scripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("PlaceholderMinigame") and "STILL EXISTS (FAIL)" or "GONE (OK)")
```
Expected output: `GONE (OK)`

**Step 4: Commit**

```bash
git add -A src/StarterPlayer/StarterPlayerScripts/Minigames/PlaceholderMinigame.client.lua
git commit -m "feat(m2): delete PlaceholderMinigame, beginning real minigames"
```

---

## Task 1: MixMinigame — Rotating Ring

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/Minigames/MixMinigame.client.lua`

**Step 1: Verify script doesn't exist yet**

Run in MCP:
```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("MixMinigame") and "EXISTS (UNEXPECTED)" or "MISSING (OK)")
```
Expected: `MISSING (OK)`

**Step 2: Write the file**

Create `src/StarterPlayer/StarterPlayerScripts/Minigames/MixMinigame.client.lua`:

```lua
-- src/StarterPlayer/StarterPlayerScripts/Minigames/MixMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote    = RemoteManager.Get("StartMixMinigame")
local resultRemote   = RemoteManager.Get("MixMinigameResult")

local player = Players.LocalPlayer

-- deg/s for each of the 3 rounds
local ROUND_SPEEDS  = {120, 168, 216}
local HIT_THRESHOLD = 22   -- degrees tolerance
local ROUND_TIMEOUT = 4    -- seconds per round
local TOTAL_ROUNDS  = 3
local RING_RADIUS   = 110  -- px from center to marker
local GREEN_ANGLE   = 90   -- degrees; 90 = right side (3 o'clock) in Roblox screen coords

startRemote.OnClientEvent:Connect(function()
    -- Lock movement
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0

    -- Build GUI
    local sg = Instance.new("ScreenGui")
    sg.Name            = "MixGui"
    sg.ResetOnSpawn    = false
    sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    sg.Parent          = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                    = UDim2.new(0, 440, 0, 440)
    bg.Position                = UDim2.new(0.5, -220, 0.5, -220)
    bg.BackgroundColor3        = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency  = 0.1
    bg.BorderSizePixel         = 0
    bg.Parent                  = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                  = UDim2.new(1, 0, 0, 40)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
    titleLbl.TextScaled            = true
    titleLbl.Font                  = Enum.Font.GothamBold
    titleLbl.Text                  = "MIX — Round 1/" .. TOTAL_ROUNDS
    titleLbl.Parent                = bg

    -- Green hit zone (fixed at top of ring: angle=0 in our convention)
    local greenZone = Instance.new("Frame")
    greenZone.Size             = UDim2.new(0, 34, 0, 34)
    greenZone.Position         = UDim2.new(0.5, -17, 0.5, -17 - RING_RADIUS)
    greenZone.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    greenZone.BorderSizePixel  = 0
    greenZone.Parent           = bg
    Instance.new("UICorner", greenZone).CornerRadius = UDim.new(1, 0)

    -- Orbiting marker
    local marker = Instance.new("Frame")
    marker.Size             = UDim2.new(0, 22, 0, 22)
    marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    marker.BorderSizePixel  = 0
    marker.Parent           = bg
    Instance.new("UICorner", marker).CornerRadius = UDim.new(1, 0)

    -- HIT button
    local hitBtn = Instance.new("TextButton")
    hitBtn.Size             = UDim2.new(0, 110, 0, 54)
    hitBtn.Position         = UDim2.new(0.5, -55, 0.5, -27)
    hitBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
    hitBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    hitBtn.TextScaled       = true
    hitBtn.Font             = Enum.Font.GothamBold
    hitBtn.Text             = "HIT!"
    hitBtn.BorderSizePixel  = 0
    hitBtn.Parent           = bg
    Instance.new("UICorner", hitBtn).CornerRadius = UDim.new(0, 10)

    -- Timer bar
    local timerBar = Instance.new("Frame")
    timerBar.Size             = UDim2.new(1, -20, 0, 8)
    timerBar.Position         = UDim2.new(0, 10, 1, -20)
    timerBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    timerBar.BorderSizePixel  = 0
    timerBar.Parent           = bg
    local timerFill = Instance.new("Frame")
    timerFill.Size             = UDim2.new(1, 0, 1, 0)
    timerFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    timerFill.BorderSizePixel  = 0
    timerFill.Parent           = timerBar
    Instance.new("UICorner", timerFill).CornerRadius = UDim.new(0, 4)

    -- State
    local hits         = 0
    local markerAngle  = 0
    local currentRound = 0
    local roundActive  = false
    local roundConn, hitConn

    local function cleanup()
        if roundConn then roundConn:Disconnect() end
        if hitConn   then hitConn:Disconnect()   end
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.min(hits * 34, 100))
    end

    local function startRound(roundNum)
        if roundNum > TOTAL_ROUNDS then
            cleanup()
            return
        end
        currentRound = roundNum
        titleLbl.Text = "MIX — Round " .. roundNum .. "/" .. TOTAL_ROUNDS
        markerAngle   = 0
        roundActive   = true
        local speed   = ROUND_SPEEDS[roundNum]
        local elapsed = 0

        if roundConn then roundConn:Disconnect() end
        roundConn = RunService.Heartbeat:Connect(function(dt)
            if not roundActive then return end
            elapsed = elapsed + dt
            timerFill.Size = UDim2.new(math.clamp(1 - elapsed / ROUND_TIMEOUT, 0, 1), 0, 1, 0)

            -- Advance marker angle
            markerAngle = (markerAngle + speed * dt) % 360
            -- angle=0 maps to top: subtract 90° so 0 = up
            local rad = math.rad(markerAngle - 90)
            local mx  = math.cos(rad) * RING_RADIUS
            local my  = math.sin(rad) * RING_RADIUS
            marker.Position = UDim2.new(0.5, mx - 11, 0.5, my - 11)

            if elapsed >= ROUND_TIMEOUT then
                roundActive = false
                roundConn:Disconnect()
                task.delay(0.3, function() startRound(currentRound + 1) end)
            end
        end)

        if hitConn then hitConn:Disconnect() end
        hitConn = hitBtn.MouseButton1Click:Connect(function()
            if not roundActive then return end
            roundActive = false
            roundConn:Disconnect()
            hitConn:Disconnect()

            -- Check if marker is within threshold of green zone (top = 0 degrees)
            local diff = math.abs(((markerAngle - 0 + 180) % 360) - 180)
            if diff <= HIT_THRESHOLD then
                hits = hits + 1
                hitBtn.BackgroundColor3 = Color3.fromRGB(255, 230, 0)
            else
                hitBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            end
            task.delay(0.4, function()
                hitBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
                startRound(currentRound + 1)
            end)
        end)
    end

    startRound(1)
end)

print("[MixMinigame] Ready.")
```

**Step 3: Verify script synced to Studio**

Wait 2 seconds for Rojo, then run in MCP:
```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
local s = mg and mg:FindFirstChild("MixMinigame")
print(s and "MixMinigame EXISTS (OK)" or "MISSING (FAIL)")
```
Expected: `MixMinigame EXISTS (OK)`

**Step 4: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Minigames/MixMinigame.client.lua
git commit -m "feat(m2): add MixMinigame rotating ring (3 rounds, HIT button)"
```

---

## Task 2: DoughMinigame — Slider + Spot Tap

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/Minigames/DoughMinigame.client.lua`

**Step 1: Verify script doesn't exist yet**

Run in MCP:
```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("DoughMinigame") and "EXISTS (UNEXPECTED)" or "MISSING (OK)")
```

**Step 2: Write the file**

Create `src/StarterPlayer/StarterPlayerScripts/Minigames/DoughMinigame.client.lua`:

```lua
-- src/StarterPlayer/StarterPlayerScripts/Minigames/DoughMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartDoughMinigame")
local resultRemote  = RemoteManager.Get("DoughMinigameResult")

local player = Players.LocalPlayer

local TOTAL_TIMEOUT = 10   -- seconds for both tasks combined
local SPOT_FADE_TIME = 2.5  -- seconds before each spot disappears
local SPOT_COUNT     = 4
local TRACK_WIDTH    = 300
local HANDLE_SIZE    = 32

startRemote.OnClientEvent:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0

    local sg = Instance.new("ScreenGui")
    sg.Name           = "DoughGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 420, 0, 480)
    bg.Position               = UDim2.new(0.5, -210, 0.5, -240)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                  = UDim2.new(1, 0, 0, 40)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
    titleLbl.TextScaled            = true
    titleLbl.Font                  = Enum.Font.GothamBold
    titleLbl.Text                  = "DOUGH — Knead it!"
    titleLbl.Parent                = bg

    -- Timer bar
    local timerBar = Instance.new("Frame")
    timerBar.Size             = UDim2.new(1, -20, 0, 8)
    timerBar.Position         = UDim2.new(0, 10, 1, -20)
    timerBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    timerBar.BorderSizePixel  = 0
    timerBar.Parent           = bg
    local timerFill = Instance.new("Frame")
    timerFill.Size             = UDim2.new(1, 0, 1, 0)
    timerFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    timerFill.BorderSizePixel  = 0
    timerFill.Parent           = timerBar
    Instance.new("UICorner", timerFill).CornerRadius = UDim.new(0, 4)

    -- ── SLIDER ─────────────────────────────────────────────────────────────────
    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Size                  = UDim2.new(1, 0, 0, 28)
    sliderLabel.Position              = UDim2.new(0, 0, 0, 48)
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.TextColor3            = Color3.fromRGB(200, 200, 200)
    sliderLabel.TextScaled            = true
    sliderLabel.Font                  = Enum.Font.Gotham
    sliderLabel.Text                  = "Drag handle into the green zone, then release"
    sliderLabel.Parent                = bg

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(0, TRACK_WIDTH, 0, 24)
    track.Position         = UDim2.new(0.5, -TRACK_WIDTH / 2, 0, 84)
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    track.BorderSizePixel  = 0
    track.ClipsDescendants = false
    track.Parent           = bg
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 6)

    -- Target zone (random position in middle 60% of track)
    local zoneStartFrac = (math.random(20, 60)) / 100
    local zoneWidthFrac = 0.20
    local zoneFrame = Instance.new("Frame")
    zoneFrame.Size             = UDim2.new(zoneWidthFrac, 0, 1, 0)
    zoneFrame.Position         = UDim2.new(zoneStartFrac, 0, 0, 0)
    zoneFrame.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    zoneFrame.BorderSizePixel  = 0
    zoneFrame.Parent           = track
    Instance.new("UICorner", zoneFrame).CornerRadius = UDim.new(0, 6)

    -- Draggable handle
    local handle = Instance.new("TextButton")
    handle.Size             = UDim2.new(0, HANDLE_SIZE, 1, 10)
    handle.Position         = UDim2.new(0, -HANDLE_SIZE / 2, 0, -5)
    handle.BackgroundColor3 = Color3.fromRGB(220, 180, 80)
    handle.TextColor3       = Color3.fromRGB(30, 30, 30)
    handle.TextScaled       = true
    handle.Font             = Enum.Font.GothamBold
    handle.Text             = "||"
    handle.BorderSizePixel  = 0
    handle.ZIndex           = 2
    handle.Parent           = track
    Instance.new("UICorner", handle).CornerRadius = UDim.new(0, 6)

    -- ── SPOT TAP AREA ───────────────────────────────────────────────────────────
    local tapLabel = Instance.new("TextLabel")
    tapLabel.Size                  = UDim2.new(1, 0, 0, 28)
    tapLabel.Position              = UDim2.new(0, 0, 0, 130)
    tapLabel.BackgroundTransparency = 1
    tapLabel.TextColor3            = Color3.fromRGB(200, 200, 200)
    tapLabel.TextScaled            = true
    tapLabel.Font                  = Enum.Font.Gotham
    tapLabel.Text                  = "Tap the spots before they fade!"
    tapLabel.Parent                = bg

    local tapArea = Instance.new("Frame")
    tapArea.Size             = UDim2.new(1, -20, 0, 260)
    tapArea.Position         = UDim2.new(0, 10, 0, 164)
    tapArea.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    tapArea.BorderSizePixel  = 0
    tapArea.ClipsDescendants = true
    tapArea.Parent           = bg
    Instance.new("UICorner", tapArea).CornerRadius = UDim.new(0, 8)

    -- ── STATE ───────────────────────────────────────────────────────────────────
    local sliderScore = 0
    local spotsHit    = 0
    local sliderDone  = false
    local isDragging  = false
    local handleFrac  = 0   -- 0..1 position along track
    local elapsed     = 0
    local finished    = false

    local function finalize()
        if finished then return end
        finished = true
        local tapScore = math.floor(spotsHit / SPOT_COUNT * 50)
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 7.2
        sg:Destroy()
        resultRemote:FireServer(sliderScore + tapScore)
    end

    -- Slider drag
    handle.MouseButton1Down:Connect(function()
        isDragging = true
    end)

    UserInputService.InputEnded:Connect(function(input)
        if finished then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 and isDragging then
            isDragging = false
            if not sliderDone then
                sliderDone = true
                local zoneCenter = zoneStartFrac + zoneWidthFrac / 2
                local dist = math.abs(handleFrac - zoneCenter)
                local halfZone = zoneWidthFrac / 2
                if handleFrac >= zoneStartFrac and handleFrac <= zoneStartFrac + zoneWidthFrac then
                    sliderScore = 50
                elseif dist < halfZone + 0.12 then
                    sliderScore = math.floor(50 * math.max(0, 1 - (dist - halfZone) / 0.12))
                else
                    sliderScore = 0
                end
                handle.BackgroundColor3 = sliderScore >= 25
                    and Color3.fromRGB(80, 200, 80)
                    or  Color3.fromRGB(200, 80, 80)
            end
        end
    end)

    -- Spawn spots (staggered)
    for i = 1, SPOT_COUNT do
        task.delay(i * 0.15, function()
            if finished then return end
            local spot = Instance.new("TextButton")
            spot.Size             = UDim2.new(0, 52, 0, 52)
            spot.Position         = UDim2.new(0, math.random(10, 320), 0, math.random(10, 195))
            spot.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
            spot.TextColor3       = Color3.fromRGB(255, 255, 255)
            spot.TextScaled       = true
            spot.Font             = Enum.Font.GothamBold
            spot.Text             = "!"
            spot.BorderSizePixel  = 0
            spot.ZIndex           = 3
            spot.Parent           = tapArea
            Instance.new("UICorner", spot).CornerRadius = UDim.new(1, 0)

            local spotHit = false
            spot.MouseButton1Click:Connect(function()
                if spotHit or finished then return end
                spotHit     = true
                spotsHit    = spotsHit + 1
                spot:Destroy()
            end)

            -- Fade over SPOT_FADE_TIME
            local fadeElapsed = 0
            local fadeConn
            fadeConn = RunService.Heartbeat:Connect(function(dt)
                if not spot.Parent then fadeConn:Disconnect() return end
                fadeElapsed = fadeElapsed + dt
                spot.BackgroundTransparency = math.clamp(fadeElapsed / SPOT_FADE_TIME, 0, 1)
                if fadeElapsed >= SPOT_FADE_TIME then
                    fadeConn:Disconnect()
                    if spot.Parent then spot:Destroy() end
                end
            end)
        end)
    end

    -- Main loop: timer + handle drag update
    local mainConn
    mainConn = RunService.Heartbeat:Connect(function(dt)
        if finished then mainConn:Disconnect() return end
        elapsed = elapsed + dt
        timerFill.Size = UDim2.new(math.clamp(1 - elapsed / TOTAL_TIMEOUT, 0, 1), 0, 1, 0)

        if isDragging then
            local mousePos  = UserInputService:GetMouseLocation()
            local trackAbs  = track.AbsolutePosition
            local rel       = (mousePos.X - trackAbs.X) / TRACK_WIDTH
            handleFrac      = math.clamp(rel, 0, 1)
            handle.Position = UDim2.new(handleFrac, -HANDLE_SIZE / 2, 0, -5)
        end

        if elapsed >= TOTAL_TIMEOUT then
            mainConn:Disconnect()
            finalize()
        end
    end)
end)

print("[DoughMinigame] Ready.")
```

**Step 3: Verify in Studio**

Run in MCP:
```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("DoughMinigame") and "DoughMinigame EXISTS (OK)" or "MISSING (FAIL)")
```

**Step 4: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Minigames/DoughMinigame.client.lua
git commit -m "feat(m2): add DoughMinigame slider + spot tap"
```

---

## Task 3: OvenMinigame — Temperature Bar

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/Minigames/OvenMinigame.client.lua`

**Step 1: Verify script doesn't exist yet**

```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("OvenMinigame") and "EXISTS (UNEXPECTED)" or "MISSING (OK)")
```

**Step 2: Write the file**

Create `src/StarterPlayer/StarterPlayerScripts/Minigames/OvenMinigame.client.lua`:

```lua
-- src/StarterPlayer/StarterPlayerScripts/Minigames/OvenMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartOvenMinigame")
local resultRemote  = RemoteManager.Get("OvenMinigameResult")

local player = Players.LocalPlayer

local FILL_TIME      = 6     -- seconds for bar to fill completely
local BAR_HEIGHT     = 260   -- px
local ZONE_HEIGHT_PX = 56    -- px (≈21.5% of bar)
-- zoneCenter drifts in this fraction-of-bar range (measured from bottom)
local ZONE_MIN       = 0.25
local ZONE_MAX       = 0.75

startRemote.OnClientEvent:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0

    local sg = Instance.new("ScreenGui")
    sg.Name           = "OvenGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 300, 0, 420)
    bg.Position               = UDim2.new(0.5, -150, 0.5, -210)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                  = UDim2.new(1, 0, 0, 44)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
    titleLbl.TextScaled            = true
    titleLbl.TextWrapped           = true
    titleLbl.Font                  = Enum.Font.GothamBold
    titleLbl.Text                  = "OVEN — Stop at the right temp!"
    titleLbl.Parent                = bg

    -- Vertical bar track
    local barTrack = Instance.new("Frame")
    barTrack.Size             = UDim2.new(0, 60, 0, BAR_HEIGHT)
    barTrack.Position         = UDim2.new(0.5, -30, 0, 50)
    barTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    barTrack.BorderSizePixel  = 0
    barTrack.ClipsDescendants = false
    barTrack.Parent           = bg
    Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0, 8)

    -- Fill (anchored at bottom, grows upward)
    local fillFrame = Instance.new("Frame")
    fillFrame.Size             = UDim2.new(1, 0, 0, 0)
    fillFrame.AnchorPoint      = Vector2.new(0, 1)
    fillFrame.Position         = UDim2.new(0, 0, 1, 0)
    fillFrame.BackgroundColor3 = Color3.fromRGB(220, 120, 30)
    fillFrame.BorderSizePixel  = 0
    fillFrame.Parent           = barTrack
    Instance.new("UICorner", fillFrame).CornerRadius = UDim.new(0, 8)

    -- Green zone (drifts, rendered in barTrack space)
    -- zoneCenter starts mid-range; drifts via sin wave
    local zoneCenter = (ZONE_MIN + ZONE_MAX) / 2
    local zoneFrame  = Instance.new("Frame")
    zoneFrame.Size             = UDim2.new(1, 6, 0, ZONE_HEIGHT_PX)
    zoneFrame.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    zoneFrame.BackgroundTransparency = 0.3
    zoneFrame.BorderSizePixel  = 0
    zoneFrame.ZIndex           = 2
    zoneFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
    zoneFrame.Position         = UDim2.new(0.5, 0, 1 - zoneCenter, 0)
    zoneFrame.Parent           = barTrack
    Instance.new("UICorner", zoneFrame).CornerRadius = UDim.new(0, 4)

    -- HOT / COLD labels
    local function sideLabel(text, yPos, col)
        local lbl = Instance.new("TextLabel")
        lbl.Size                  = UDim2.new(0, 55, 0, 24)
        lbl.Position              = UDim2.new(0.5, 38, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3            = col
        lbl.TextScaled            = true
        lbl.Font                  = Enum.Font.GothamBold
        lbl.Text                  = text
        lbl.Parent                = bg
    end
    sideLabel("HOT",  50,  Color3.fromRGB(255, 100, 50))
    sideLabel("COLD", 310, Color3.fromRGB(100, 180, 255))

    -- STOP button
    local stopBtn = Instance.new("TextButton")
    stopBtn.Size             = UDim2.new(0.6, 0, 0, 50)
    stopBtn.Position         = UDim2.new(0.2, 0, 1, -70)
    stopBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    stopBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    stopBtn.TextScaled       = true
    stopBtn.Font             = Enum.Font.GothamBold
    stopBtn.Text             = "STOP"
    stopBtn.BorderSizePixel  = 0
    stopBtn.Parent           = bg
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 10)

    -- Scoring: 0..1 fill fraction vs 0..1 zone center (from bottom)
    local function calcScore(fillFrac)
        local halfZone = (ZONE_HEIGHT_PX / 2) / BAR_HEIGHT
        local dist     = math.abs(fillFrac - zoneCenter)
        if dist <= halfZone then
            -- Inside zone: 70–100
            return math.floor(70 + 30 * (1 - dist / halfZone))
        elseif dist <= halfZone + 0.10 then
            -- Just outside: 40–69
            return math.floor(40 + 30 * (1 - (dist - halfZone) / 0.10))
        else
            -- Far outside: 0–39
            return math.floor(math.max(0, 39 * (1 - dist)))
        end
    end

    local elapsed = 0
    local stopped = false
    local mainConn

    local function finish(score)
        if mainConn then mainConn:Disconnect() end
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.clamp(score, 0, 100))
    end

    stopBtn.MouseButton1Click:Connect(function()
        if stopped then return end
        stopped = true
        finish(calcScore(math.clamp(elapsed / FILL_TIME, 0, 1)))
    end)

    mainConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local frac = math.clamp(elapsed / FILL_TIME, 0, 1)

        -- Fill bar
        fillFrame.Size = UDim2.new(1, 0, frac, 0)

        -- Drift zone (sin wave, 0.8 rad/s)
        local drift  = math.sin(elapsed * 0.8) * 0.18
        zoneCenter   = math.clamp((ZONE_MIN + ZONE_MAX) / 2 + drift, ZONE_MIN, ZONE_MAX)
        zoneFrame.Position = UDim2.new(0.5, 0, 1 - zoneCenter, 0)

        if frac >= 1 and not stopped then
            stopped = true
            finish(10)  -- burned
        end
    end)
end)

print("[OvenMinigame] Ready.")
```

**Step 3: Verify in Studio**

```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("OvenMinigame") and "OvenMinigame EXISTS (OK)" or "MISSING (FAIL)")
```

**Step 4: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Minigames/OvenMinigame.client.lua
git commit -m "feat(m2): add OvenMinigame temperature bar with drifting zone"
```

---

## Task 4: FrostMinigame — Checkpoint Trace

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/Minigames/FrostMinigame.client.lua`

> Note: Server only fires `StartFrostMinigame` for cookies where `NeedsFrost = true`. This script simply waits for the remote and runs when it arrives.

**Step 1: Verify script doesn't exist yet**

```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("FrostMinigame") and "EXISTS (UNEXPECTED)" or "MISSING (OK)")
```

**Step 2: Write the file**

Create `src/StarterPlayer/StarterPlayerScripts/Minigames/FrostMinigame.client.lua`:

```lua
-- src/StarterPlayer/StarterPlayerScripts/Minigames/FrostMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartFrostMinigame")
local resultRemote  = RemoteManager.Get("FrostMinigameResult")

local player = Players.LocalPlayer

local TIMER           = 7    -- seconds
local HIT_RADIUS      = 30   -- px from dot center to mouse to count as hit
local NUM_CHECKPOINTS = 8

-- Pixel offsets from the center of the 360×360 play area
local CHECKPOINT_OFFSETS = {
    Vector2.new(  0, -150),
    Vector2.new(120,  -90),
    Vector2.new(150,   40),
    Vector2.new( 60,  140),
    Vector2.new(-80,  130),
    Vector2.new(-140,  20),
    Vector2.new(-80,  -70),
    Vector2.new(  0,    0),
}

startRemote.OnClientEvent:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0

    local sg = Instance.new("ScreenGui")
    sg.Name           = "FrostGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 420, 0, 460)
    bg.Position               = UDim2.new(0.5, -210, 0.5, -230)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                  = UDim2.new(1, 0, 0, 40)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
    titleLbl.TextScaled            = true
    titleLbl.Font                  = Enum.Font.GothamBold
    titleLbl.Text                  = "FROST — Trace the path!"
    titleLbl.Parent                = bg

    -- Timer bar
    local timerBar = Instance.new("Frame")
    timerBar.Size             = UDim2.new(1, -20, 0, 8)
    timerBar.Position         = UDim2.new(0, 10, 1, -20)
    timerBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    timerBar.BorderSizePixel  = 0
    timerBar.Parent           = bg
    local timerFill = Instance.new("Frame")
    timerFill.Size             = UDim2.new(1, 0, 1, 0)
    timerFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    timerFill.BorderSizePixel  = 0
    timerFill.Parent           = timerBar
    Instance.new("UICorner", timerFill).CornerRadius = UDim.new(0, 4)

    -- Play area (360×360 centered in bg below title)
    local playArea = Instance.new("Frame")
    playArea.Size             = UDim2.new(0, 360, 0, 360)
    playArea.Position         = UDim2.new(0.5, -180, 0, 50)
    playArea.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
    playArea.BorderSizePixel  = 0
    playArea.ClipsDescendants = false
    playArea.Parent           = bg
    Instance.new("UICorner", playArea).CornerRadius = UDim.new(0, 8)

    local AREA_CENTER = Vector2.new(180, 180)

    -- Build checkpoint dots
    local dots = {}
    for i, offset in ipairs(CHECKPOINT_OFFSETS) do
        local dot = Instance.new("TextLabel")
        dot.Size             = UDim2.new(0, 40, 0, 40)
        dot.AnchorPoint      = Vector2.new(0.5, 0.5)
        dot.Position         = UDim2.new(0, AREA_CENTER.X + offset.X,
                                          0, AREA_CENTER.Y + offset.Y)
        dot.BackgroundColor3 = i == 1
            and Color3.fromRGB(255, 220, 0)    -- first = active (yellow)
            or  Color3.fromRGB(180, 180, 255)  -- others = inactive (blue-ish)
        dot.TextColor3       = Color3.fromRGB(20, 20, 20)
        dot.TextScaled       = true
        dot.Font             = Enum.Font.GothamBold
        dot.Text             = tostring(i)
        dot.BorderSizePixel  = 0
        dot.ZIndex           = 3
        dot.Parent           = playArea
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        dots[i] = dot
    end

    local activeIndex = 1
    local numHit      = 0
    local elapsed     = 0
    local finished    = false
    local mainConn, moveConn

    local function finish()
        if finished then return end
        finished = true
        if mainConn then mainConn:Disconnect() end
        if moveConn then moveConn:Disconnect() end
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.floor(numHit / NUM_CHECKPOINTS * 100))
    end

    -- Timer
    mainConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        timerFill.Size = UDim2.new(math.clamp(1 - elapsed / TIMER, 0, 1), 0, 1, 0)
        if elapsed >= TIMER then finish() end
    end)

    -- Mouse proximity detection (no click required)
    moveConn = UserInputService.InputChanged:Connect(function(input)
        if finished then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if activeIndex > NUM_CHECKPOINTS then return end

        local dot = dots[activeIndex]
        if not dot or not dot.Parent then return end

        -- dot center in screen space
        local dotAbsCenter = dot.AbsolutePosition + Vector2.new(20, 20)
        local mousePos     = UserInputService:GetMouseLocation()
        local dist         = (mousePos - dotAbsCenter).Magnitude

        if dist <= HIT_RADIUS then
            numHit = numHit + 1
            dot.BackgroundColor3 = Color3.fromRGB(80, 200, 80)   -- green = hit
            activeIndex = activeIndex + 1
            if activeIndex <= NUM_CHECKPOINTS then
                dots[activeIndex].BackgroundColor3 = Color3.fromRGB(255, 220, 0)
            else
                task.delay(0.3, finish)
            end
        end
    end)
end)

print("[FrostMinigame] Ready.")
```

**Step 3: Verify in Studio**

```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("FrostMinigame") and "FrostMinigame EXISTS (OK)" or "MISSING (FAIL)")
```

**Step 4: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Minigames/FrostMinigame.client.lua
git commit -m "feat(m2): add FrostMinigame spiral checkpoint trace"
```

---

## Task 5: DressMinigame + MinigameServer patch

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/Minigames/DressMinigame.client.lua`
- Modify: `src/ServerScriptService/Minigames/MinigameServer.server.lua` (line 141 — pass cookieId)

### Part A: Patch MinigameServer

**Step 1: Understand the current code**

In `MinigameServer.server.lua`, the `dress` branch of `startSession` ends with (around line 138–142):
```lua
dressPending[player] = entry
activeSessions[player] = { station = stationName, batchId = batchId, warmerEntry = entry }
local startRemote = RemoteManager.Get(config.start)
startRemote:FireClient(player)
return
```
The client needs `cookieId` to know which cookie type to show. `entry` has `entry.cookieId` since it comes from `TakeFromWarmers`.

**Step 2: Apply the patch**

Edit `src/ServerScriptService/Minigames/MinigameServer.server.lua` — change:
```lua
        startRemote:FireClient(player)
        return
    end

    activeSessions[player] = { station = stationName, batchId = batchId }
```
to:
```lua
        startRemote:FireClient(player, entry.cookieId)
        return
    end

    activeSessions[player] = { station = stationName, batchId = batchId }
```

This is a 1-line change on the `dress` early-return branch.

**Step 3: Verify patch in Studio**

Run in MCP to confirm script loaded cleanly (no syntax errors):
```lua
local ss = game:GetService("ServerScriptService")
local ms = ss:FindFirstChild("Minigames") and ss.Minigames:FindFirstChild("MinigameServer")
print(ms and "MinigameServer found (OK)" or "NOT FOUND (check path)")
```

### Part B: Write DressMinigame

**Step 4: Write the file**

Create `src/StarterPlayer/StarterPlayerScripts/Minigames/DressMinigame.client.lua`:

```lua
-- src/StarterPlayer/StarterPlayerScripts/Minigames/DressMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartDressMinigame")
local resultRemote  = RemoteManager.Get("DressMinigameResult")

local player = Players.LocalPlayer

local TIMER    = 8
local REQUIRED = 4   -- correct cookies needed to complete

-- Display names keyed by CookieData id
local COOKIE_DISPLAY = {
    pink_sugar            = "Pink Sugar",
    chocolate_chip        = "Choc Chip",
    birthday_cake         = "Bday Cake",
    cookies_and_cream     = "C&C",
    snickerdoodle         = "Snickerdoodle",
    lemon_blackraspberry  = "Lemon Berry",
}

-- All ids for wrong-pick selection
local ALL_IDS = {
    "pink_sugar", "chocolate_chip", "birthday_cake",
    "cookies_and_cream", "snickerdoodle", "lemon_blackraspberry",
}

startRemote.OnClientEvent:Connect(function(cookieId)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0

    local cookieName = COOKIE_DISPLAY[cookieId] or cookieId

    local sg = Instance.new("ScreenGui")
    sg.Name           = "DressGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 440, 0, 460)
    bg.Position               = UDim2.new(0.5, -220, 0.5, -230)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    -- Order ticket
    local orderLbl = Instance.new("TextLabel")
    orderLbl.Size             = UDim2.new(1, -20, 0, 56)
    orderLbl.Position         = UDim2.new(0, 10, 0, 10)
    orderLbl.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    orderLbl.TextColor3       = Color3.fromRGB(20, 20, 20)
    orderLbl.TextScaled       = true
    orderLbl.Font             = Enum.Font.GothamBold
    orderLbl.Text             = "Pack: " .. cookieName .. " ×" .. REQUIRED
    orderLbl.BorderSizePixel  = 0
    orderLbl.Parent           = bg
    Instance.new("UICorner", orderLbl).CornerRadius = UDim.new(0, 8)

    local instrLbl = Instance.new("TextLabel")
    instrLbl.Size                  = UDim2.new(1, 0, 0, 26)
    instrLbl.Position              = UDim2.new(0, 0, 0, 72)
    instrLbl.BackgroundTransparency = 1
    instrLbl.TextColor3            = Color3.fromRGB(200, 200, 200)
    instrLbl.TextScaled            = true
    instrLbl.Font                  = Enum.Font.Gotham
    instrLbl.Text                  = "Click the correct cookies!"
    instrLbl.Parent                = bg

    -- Build 6 buttons: 4 correct + 2 wrong, shuffled
    local wrongIds = {}
    for _, id in ipairs(ALL_IDS) do
        if id ~= cookieId then
            table.insert(wrongIds, id)
        end
    end
    -- Shuffle wrongIds and pick 2
    for i = #wrongIds, 2, -1 do
        local j = math.random(1, i)
        wrongIds[i], wrongIds[j] = wrongIds[j], wrongIds[i]
    end

    local buttonData = {}
    for _ = 1, REQUIRED do
        table.insert(buttonData, { id = cookieId, correct = true })
    end
    table.insert(buttonData, { id = wrongIds[1], correct = false })
    table.insert(buttonData, { id = wrongIds[2], correct = false })
    -- Shuffle button list
    for i = #buttonData, 2, -1 do
        local j = math.random(1, i)
        buttonData[i], buttonData[j] = buttonData[j], buttonData[i]
    end

    -- 3-column, 2-row grid (manual positions)
    local BTN_W, BTN_H = 126, 108
    local BTN_PAD      = 8
    local GRID_LEFT    = (440 - (3 * BTN_W + 2 * BTN_PAD)) / 2
    local gridPositions = {}
    for row = 0, 1 do
        for col = 0, 2 do
            table.insert(gridPositions, {
                x = GRID_LEFT + col * (BTN_W + BTN_PAD),
                y = 106 + row * (BTN_H + BTN_PAD),
            })
        end
    end

    -- Slot indicator at top (shows how many collected)
    local slotsFrame = Instance.new("Frame")
    slotsFrame.Size                   = UDim2.new(1, -20, 0, 24)
    slotsFrame.Position               = UDim2.new(0, 10, 0, 100)
    slotsFrame.BackgroundTransparency = 1
    slotsFrame.Parent                 = bg

    local slotDots = {}
    for i = 1, REQUIRED do
        local slot = Instance.new("Frame")
        slot.Size             = UDim2.new(0, 20, 0, 20)
        slot.Position         = UDim2.new(0, (i - 1) * 28, 0, 0)
        slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        slot.BorderSizePixel  = 0
        slot.Parent           = slotsFrame
        Instance.new("UICorner", slot).CornerRadius = UDim.new(1, 0)
        slotDots[i] = slot
    end

    local correctClicks = 0
    local wrongClicks   = 0
    local done          = false

    local function fillSlot()
        if slotDots[correctClicks] then
            slotDots[correctClicks].BackgroundColor3 = Color3.fromRGB(80, 200, 80)
        end
    end

    local function finalize()
        if done then return end
        done = true
        local score = math.max(0, math.floor(correctClicks / REQUIRED * 100) - wrongClicks * 10)
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 7.2
        sg:Destroy()
        resultRemote:FireServer(score)
    end

    for i, data in ipairs(buttonData) do
        local pos = gridPositions[i]
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, BTN_W, 0, BTN_H)
        btn.Position         = UDim2.new(0, pos.x, 0, pos.y)
        btn.BackgroundColor3 = data.correct
            and Color3.fromRGB(240, 200, 150)
            or  Color3.fromRGB(160, 160, 160)
        btn.TextColor3       = Color3.fromRGB(20, 20, 20)
        btn.TextScaled       = true
        btn.TextWrapped      = true
        btn.Font             = Enum.Font.GothamBold
        btn.Text             = COOKIE_DISPLAY[data.id] or data.id
        btn.BorderSizePixel  = 0
        btn.Parent           = bg
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        local clicked = false
        btn.MouseButton1Click:Connect(function()
            if done or clicked then return end

            if data.correct then
                clicked = true
                correctClicks = correctClicks + 1
                btn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                fillSlot()
                if correctClicks >= REQUIRED then
                    task.delay(0.3, finalize)
                end
            else
                wrongClicks = wrongClicks + 1
                btn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
                task.delay(0.5, function()
                    if btn.Parent then
                        btn.BackgroundColor3 = Color3.fromRGB(160, 160, 160)
                    end
                end)
            end
        end)
    end

    -- Timer bar
    local timerBar = Instance.new("Frame")
    timerBar.Size             = UDim2.new(1, -20, 0, 8)
    timerBar.Position         = UDim2.new(0, 10, 1, -20)
    timerBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    timerBar.BorderSizePixel  = 0
    timerBar.Parent           = bg
    local timerFill = Instance.new("Frame")
    timerFill.Size             = UDim2.new(1, 0, 1, 0)
    timerFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    timerFill.BorderSizePixel  = 0
    timerFill.Parent           = timerBar
    Instance.new("UICorner", timerFill).CornerRadius = UDim.new(0, 4)

    local elapsed   = 0
    local timerConn
    timerConn = RunService.Heartbeat:Connect(function(dt)
        if done then timerConn:Disconnect() return end
        elapsed = elapsed + dt
        timerFill.Size = UDim2.new(math.clamp(1 - elapsed / TIMER, 0, 1), 0, 1, 0)
        if elapsed >= TIMER then
            timerConn:Disconnect()
            finalize()
        end
    end)
end)

print("[DressMinigame] Ready.")
```

**Step 5: Verify both files in Studio**

```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
print(mg and mg:FindFirstChild("DressMinigame") and "DressMinigame EXISTS (OK)" or "MISSING (FAIL)")
```

**Step 6: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Minigames/DressMinigame.client.lua
git add src/ServerScriptService/Minigames/MinigameServer.server.lua
git commit -m "feat(m2): add DressMinigame cookie click match + pass cookieId from MinigameServer"
```

---

## Task 6: Smoke Test — Full Pipeline Verification

**Goal:** Confirm all 5 scripts are present, no output errors on play, and remotes exist.

**Step 1: Verify all 5 scripts exist in Studio**

Run in MCP (run_code):
```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
if not mg then print("Minigames folder MISSING") return end
local expected = {"MixMinigame","DoughMinigame","OvenMinigame","FrostMinigame","DressMinigame"}
for _, name in ipairs(expected) do
    print(name .. ": " .. (mg:FindFirstChild(name) and "OK" or "MISSING"))
end
```
Expected: all 5 print `OK`

**Step 2: Verify PlaceholderMinigame is gone**

```lua
local mg = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Minigames")
print(mg:FindFirstChild("PlaceholderMinigame") and "PLACEHOLDER STILL EXISTS (FAIL)" or "Placeholder gone (OK)")
```
Expected: `Placeholder gone (OK)`

**Step 3: Verify all 10 minigame remotes exist**

```lua
local ge = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
local remotes = {
    "StartMixMinigame", "MixMinigameResult",
    "StartDoughMinigame", "DoughMinigameResult",
    "StartOvenMinigame", "OvenMinigameResult",
    "StartFrostMinigame", "FrostMinigameResult",
    "StartDressMinigame", "DressMinigameResult",
}
for _, name in ipairs(remotes) do
    print(name .. ": " .. (ge:FindFirstChild(name) and "OK" or "MISSING"))
end
```
Expected: all 10 print `OK`

**Step 4: Play-test smoke test via MCP run_script_in_play_mode**

Use `run_script_in_play_mode` to fire StartMixMinigame to a player and check for errors in console output. In Studio, trigger a mix session manually using:

```lua
-- Run in Studio Output (server context) to manually fire mix to any player
local p = game:GetService("Players"):GetPlayers()[1]
if p then
    game:GetService("ReplicatedStorage").GameEvents.StartMixMinigame:FireClient(p)
    print("Fired StartMixMinigame to " .. p.Name)
end
```

Expected: MixGui appears for the local player, ring spins, HIT button responds, score fires back without errors in output.

**Step 5: Check Output for errors after each minigame**

After play-testing each minigame, check Studio Output for:
- No "attempt to index nil" errors
- `[MixMinigame] Ready.` / `[DoughMinigame] Ready.` etc. printed on join
- Score value (0–100) printed from `[MinigameServer] PlayerName | mix | score: XX%`

**Step 6: Final commit**

```bash
git add .
git commit -m "feat(m2): milestone 2 complete — all 5 real minigames implemented"
```

---

## Acceptance Checklist

From the design doc — verify each before calling M2 done:

- [ ] `PlaceholderMinigame.client.lua` deleted; no placeholder UI during play
- [ ] Player cannot move (WalkSpeed=0, JumpPower=0) during any active minigame
- [ ] Mix: ring spins, 3 rounds with increasing speed, score 0–100 fires to server
- [ ] Dough: slider drag + 4 fading spots, score 0–100 fires to server
- [ ] Oven: bar fills over 6s, green zone drifts, STOP button works, score 0–100 fires
- [ ] Frost: 8 checkpoints in spiral order, mouse proximity detection, score 0–100 fires
- [ ] Dress: correct cookies selectable, wrong = -10 penalty, timer 8s, score 0–100 fires
- [ ] MinigameServer passes `cookieId` to `StartDressMinigame`
- [ ] All 5 scores flow through `MinigameServer.endSession` into `OrderManager` without errors
- [ ] Full order pipeline still completes end-to-end after M2

---

## Known Gotchas

- **Character reference**: All scripts get `player.Character` inside the remote callback (not at script load time) to avoid stale references after respawn.
- **OvenMinigame trigger**: `StartOvenMinigame` fires from `ovenDepositedBE` (BindableEvent from FridgeOvenSystem), not from the standard MINIGAMES loop. This is already handled in MinigameServer — no change needed.
- **MixMinigame trigger**: `StartMixMinigame` fires from `RequestMixStart` handler, not the standard loop. Also already handled.
- **Frost only for NeedsFrost cookies**: No client change needed; server controls when `StartFrostMinigame` fires.
- **DoughMinigame spots**: Spots spawn with `task.delay` stagger. If the minigame ends before a delayed spawn fires, the `if finished then return end` guard inside prevents spawning into a destroyed GUI.
