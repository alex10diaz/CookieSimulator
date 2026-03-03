# Cinematic Tutorial Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Replace the 3-step text-only tutorial with a 9-step cinematic experience: fade-to-black transitions, camera glides, Pink Sugar cookie forced through the full pipeline, and a Final Menu that routes to Start Day or Replay.

**Architecture:** TutorialController (server) drives a 9-step state machine and fires `TutorialStep` payloads; TutorialCamera (new client) handles fade/teleport/glide/release per step and manages the GameSpawn teleport on dismiss; TutorialUI (updated client) owns the FadeFrame DOM node, bottom panel, and Final Menu; MixerController (client) reads a PlayerGui attribute to restrict the cookie picker during step 2.

**Tech Stack:** Roblox Luau, TweenService, existing RemoteManager, PlayerDataManager, all existing station result remotes.

**Design doc:** `docs/plans/2026-03-02-cinematic-tutorial-design.md`

---

## Context (read before coding)

### Studio sync rule
Rojo is **STOPPED**. Every change requires TWO actions:
1. Edit the file on disk (`Write`/`Edit` tool)
2. Sync to Studio via MCP `run_code`

Both must be done for every task. Never skip the Studio sync.

### Workspace objects confirmed
```
workspace.POS.Tablet                        ← POS camera target
workspace.Mixers["Mixer 1"]                 ← Mixer camera target
workspace.DoughCamera                       ← Dough camera target (Part, already exists at -3,9,-28)
workspace.Fridges.fridge_pink_sugar         ← Pink Sugar fridge camera target
workspace.Ovens.Oven1                       ← Oven camera target
workspace.Store["Frost Table"]              ← Frost camera target
workspace.Dress["Dress Table"]              ← Dress camera target
workspace.WaitingArea.Spot1                 ← Delivery camera target
workspace.GameSpawn                         ← NEW: must be placed in Task 2
workspace.TutorialSpawn                     ← NEW: must be placed in Task 2
```

### Remote events
All remotes live in `ReplicatedStorage/GameEvents` and are managed by RemoteManager.
- **Adding** a remote = add name to REMOTES table in `RemoteManager.lua` + create the RemoteEvent in Studio via MCP.
- **Never** create remotes outside RemoteManager.

### Key require paths
```lua
RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
```

### TutorialStep payload structure
```lua
{
    step          = number,      -- 1–9 active; 10 = final menu; 0 = dismiss+spawn
    total         = 9,
    msg           = string,      -- text for bottom panel
    target        = string,      -- camera target key, nil for step 10 and 0
    forceCookieId = string|nil,  -- "pink_sugar" on step 2 only
    isReturn      = bool|nil,    -- true when returning player receives step=0
}
```

---

## Task 1: Register ReplayTutorial and StartGame remotes

**Files:**
- Modify: `src/ReplicatedStorage/Modules/RemoteManager.lua`

### Step 1: Edit RemoteManager.lua on disk

Find the line `"TutorialStep",` (last entry in REMOTES) and add the two new remotes after it:

```lua
    "TutorialStep",
    "ReplayTutorial",
    "StartGame",
```

### Step 2: Create the RemoteEvents in Studio via MCP

```lua
-- run_code in Studio:
local GE = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents")
for _, name in ipairs({"ReplayTutorial", "StartGame"}) do
    if not GE:FindFirstChild(name) then
        local r = Instance.new("RemoteEvent")
        r.Name   = name
        r.Parent = GE
        print("[Task1] Created: " .. name)
    else
        print("[Task1] Already exists: " .. name)
    end
end
```

### Step 3: Verify

Play in Studio → Output should show no RemoteManager errors. Check `ReplicatedStorage/GameEvents` contains `ReplayTutorial` and `StartGame`.

### Step 4: Commit

```bash
git add src/ReplicatedStorage/Modules/RemoteManager.lua
git commit -m "feat(tutorial): register ReplayTutorial and StartGame remotes"
```

---

## Task 2: Place GameSpawn and TutorialSpawn in Studio

**Files:** Studio-only (no disk files for this task)

These are invisible anchor Parts. `GameSpawn` is where ALL players arrive after the tutorial (or on returning join). `TutorialSpawn` is where the player's character lands before the first camera glide.

### Step 1: Place both Parts via MCP

```lua
-- run_code in Studio:
local ws = workspace

-- GameSpawn: place at the main bakery starting position (adjust X,Y,Z in Studio after)
local gs = Instance.new("Part")
gs.Name          = "GameSpawn"
gs.Size          = Vector3.new(4, 1, 4)
gs.Position      = Vector3.new(0, 3, 0)   -- ← ADJUST this to your desired starting spot
gs.Anchored      = true
gs.CanCollide    = false
gs.Transparency  = 0.8
gs.BrickColor    = BrickColor.new("Bright green")
gs.Parent        = ws
print("[Task2] GameSpawn created at", gs.Position)

-- TutorialSpawn: place near the entrance/lobby (adjust after)
local ts = Instance.new("Part")
ts.Name          = "TutorialSpawn"
ts.Size          = Vector3.new(4, 1, 4)
ts.Position      = Vector3.new(0, 3, 10)   -- ← ADJUST this too
ts.Anchored      = true
ts.CanCollide    = false
ts.Transparency  = 0.8
ts.BrickColor    = BrickColor.new("Bright blue")
ts.Parent        = ws
print("[Task2] TutorialSpawn created at", ts.Position)
```

### Step 2: Adjust positions in Studio

After running the MCP code, select `GameSpawn` and `TutorialSpawn` in the Studio Explorer and drag them to the right positions:
- `GameSpawn`: the spot players stand when they first enter the bakery floor
- `TutorialSpawn`: near the entrance, before step 1 glide kicks in

### Step 3: Verify

In Studio Explorer, both `workspace.GameSpawn` and `workspace.TutorialSpawn` should exist and be visible as green/blue blocks.

*(No git commit for this task — workspace objects are not tracked by Rojo)*

---

## Task 3: Create TutorialCamera.client.lua

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/TutorialCamera.client.lua`

### Step 1: Write the file on disk

Create `src/StarterPlayer/StarterPlayerScripts/TutorialCamera.client.lua`:

```lua
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

local function getCharacterParts()
    local char = player.Character
    if not char then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, hrp
end

-- ─── Cinematic Transition ─────────────────────────────────────────────────────
-- Fade to black → teleport → fade in → camera glide → release to Follow
local function performTransition(targetKey)
    local targetObj = TARGET_PARTS[targetKey]
    if not targetObj then
        warn("[TutorialCamera] Unknown target key: " .. tostring(targetKey))
        return
    end

    local _, hrp = getCharacterParts()
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
    print("[TutorialCamera] → " .. targetKey .. " (glide complete, player has control)")
end

-- ─── GameSpawn Transition ─────────────────────────────────────────────────────
-- Used on step 0 (tutorial done or returning player). No glide — clean arrival.
local function spawnAtGameSpawn()
    local spawnPart = TARGET_PARTS.GameSpawn or workspace:FindFirstChild("GameSpawn")
    if not spawnPart then
        warn("[TutorialCamera] workspace.GameSpawn not found — place it in Studio (Task 2)!")
        camera.CameraType = Enum.CameraType.Custom
        return
    end

    local _, hrp = getCharacterParts()
    if not hrp then
        camera.CameraType = Enum.CameraType.Custom
        return
    end

    local spawnPos = getPosition(spawnPart)

    -- Fade black → teleport → camera Custom → fade in
    fadeOut()
    hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
    camera.CameraType = Enum.CameraType.Custom
    fadeIn()
    print("[TutorialCamera] → GameSpawn (tutorial complete)")
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

    -- Steps 1–9: cinematic transition to the step's target station
    if data.target then
        task.spawn(performTransition, data.target)
    end
end)

print("[TutorialCamera] Ready.")
```

### Step 2: Create LocalScript in Studio via MCP

```lua
-- run_code in Studio:
local SP  = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")
if not SPS then error("[Task3] StarterPlayerScripts not found") end

local existing = SPS:FindFirstChild("TutorialCamera")
if existing then existing:Destroy() end

local s = Instance.new("LocalScript")
s.Name   = "TutorialCamera"
-- Paste the FULL source from Step 1 here as the Source string
s.Source = [[ PASTE_FULL_SOURCE_HERE ]]
s.Parent = SPS
print("[Task3] TutorialCamera LocalScript created in Studio")
```

*(Replace `PASTE_FULL_SOURCE_HERE` with the full Lua source from Step 1)*

### Step 3: Verify

Play in Studio (tutorial player). Check Output:
- `[TutorialCamera] Ready.`
- No errors about missing FadeFrame (Task 4 must be done first for that test)

### Step 4: Commit

```bash
git add src/StarterPlayer/StarterPlayerScripts/TutorialCamera.client.lua
git commit -m "feat(tutorial): add TutorialCamera - cinematic fade/glide per step"
```

---

## Task 4: Update TutorialUI.client.lua

Add `FadeFrame` (required by TutorialCamera), the Final Menu (step 10), and the `TutorialForceCookie` attribute logic. Keep all existing bottom panel code.

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua`

### Step 1: Write the updated file on disk

Replace the entire file with this (changes are marked with `-- NEW` comments):

```lua
-- src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua
-- Shows the tutorial step overlay pushed by TutorialController (server).
-- Owns: FadeFrame (used by TutorialCamera), bottom panel, Final Menu.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")
local startGameRemote    = RemoteManager.Get("StartGame")       -- NEW
local replayRemote       = RemoteManager.Get("ReplayTutorial")  -- NEW

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Build ScreenGui ──────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name         = "TutorialGui"
sg.ResetOnSpawn = false
sg.Enabled      = true          -- always enabled; child visibility drives show/hide
sg.DisplayOrder = 10
sg.IgnoreGuiInset = true        -- NEW: needed so FadeFrame covers full screen
sg.Parent       = playerGui

-- ─── FadeFrame (NEW) — full-screen black overlay for cinematic transitions ────
-- TutorialCamera.client.lua controls its BackgroundTransparency via TweenService.
local fadeFrame = Instance.new("Frame")
fadeFrame.Name                  = "FadeFrame"
fadeFrame.Size                  = UDim2.new(1, 0, 1, 0)
fadeFrame.Position              = UDim2.new(0, 0, 0, 0)
fadeFrame.BackgroundColor3      = Color3.new(0, 0, 0)
fadeFrame.BackgroundTransparency = 1   -- starts invisible
fadeFrame.BorderSizePixel       = 0
fadeFrame.ZIndex                = 20   -- above all other UI elements
fadeFrame.Parent                = sg

-- ─── Bottom Panel (unchanged from M5) ────────────────────────────────────────
local panel = Instance.new("Frame")
panel.Name             = "TutorialPanel"
panel.Size             = UDim2.new(0, 420, 0, 110)
panel.Position         = UDim2.new(0, 14, 1, -130)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.Parent           = sg
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

-- ─── Final Menu (NEW) — shown on step 10 ─────────────────────────────────────
local finalMenu = Instance.new("Frame")
finalMenu.Name                  = "FinalMenu"
finalMenu.Size                  = UDim2.new(0, 320, 0, 170)
finalMenu.Position              = UDim2.new(0.5, -160, 0.5, -85)
finalMenu.BackgroundColor3      = Color3.fromRGB(20, 20, 30)
finalMenu.BackgroundTransparency = 0.05
finalMenu.BorderSizePixel       = 0
finalMenu.Visible               = false
finalMenu.ZIndex                = 15
finalMenu.Parent                = sg
Instance.new("UICorner", finalMenu).CornerRadius = UDim.new(0, 16)

local menuTitle = Instance.new("TextLabel")
menuTitle.Size                   = UDim2.new(1, -20, 0, 40)
menuTitle.Position               = UDim2.new(0, 10, 0, 10)
menuTitle.BackgroundTransparency = 1
menuTitle.TextColor3             = Color3.fromRGB(255, 220, 80)
menuTitle.TextScaled             = true
menuTitle.Font                   = Enum.Font.GothamBold
menuTitle.Text                   = "You're ready to bake! 🍪"
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
        -- Clear forced cookie attribute (NEW)
        playerGui:SetAttribute("TutorialForceCookie", nil)
        return
    end

    if data.step == 10 then
        -- Final menu only
        panel.Visible    = false
        finalMenu.Visible = true
        return
    end

    -- Steps 1–9: show bottom panel
    stepLbl.Text  = "Step " .. data.step .. " / 9"
    msgLbl.Text   = data.msg or ""
    panel.Visible = true

    -- Set or clear the forced cookie attribute for MixerController (NEW)
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

-- Start Day button (NEW)
startDayBtn.MouseButton1Click:Connect(function()
    finalMenu.Visible = false
    startGameRemote:FireServer()
end)

-- Replay Tutorial button (NEW)
replayBtn.MouseButton1Click:Connect(function()
    finalMenu.Visible = false
    replayRemote:FireServer()
end)

print("[TutorialUI] Ready.")
```

### Step 2: Sync to Studio via MCP

```lua
-- run_code in Studio:
local SP  = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")
local existing = SPS:FindFirstChild("TutorialUI")
if existing then existing:Destroy() end

local s = Instance.new("LocalScript")
s.Name   = "TutorialUI"
-- Paste the FULL source from Step 1 here
s.Source = [[ PASTE_FULL_SOURCE_HERE ]]
s.Parent = SPS
print("[Task4] TutorialUI updated in Studio")
```

### Step 3: Verify

Play in Studio. Check:
- `[TutorialUI] Ready.` in Output
- No errors on startup
- `playerGui.TutorialGui.FadeFrame` exists in Explorer during play

### Step 4: Commit

```bash
git add src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua
git commit -m "feat(tutorial): update TutorialUI - FadeFrame, FinalMenu, forceCookie attribute"
```

---

## Task 5: Update MixerController.client.lua (Pink Sugar restriction)

Modify `showPicker()` to read `TutorialForceCookie` attribute and grey out non-matching cookies. Zero logic changes to how picking works — just visual restriction.

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Minigames/MixerController.client.lua`

### Step 1: Edit the file on disk

Change only the `showPicker()` function. Find this block (lines 24–89 in the current file):

```lua
local function showPicker()
    if playerGui:FindFirstChild("MixPickerGui") or playerGui:FindFirstChild("MixGui") then return end
```

Replace the entire `showPicker` function with:

```lua
local function showPicker()
    if playerGui:FindFirstChild("MixPickerGui") or playerGui:FindFirstChild("MixGui") then return end

    -- Check if tutorial is forcing a specific cookie (set by TutorialUI on step 2)
    local forcedCookie = playerGui:GetAttribute("TutorialForceCookie")
    local isForced     = forcedCookie ~= nil

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
    -- Tutorial mode: show which cookie is required (NEW)
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
        local isMatch = (not isForced) or (cookie.id == forcedCookie)

        local btn = Instance.new("TextButton", listFrame)
        btn.LayoutOrder      = i
        btn.Size             = UDim2.new(0.9, 0, 0, 30)
        -- Dim non-matching cookies during tutorial (NEW)
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
        btn.Active           = isMatch  -- non-matching buttons are non-interactive (NEW)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        if isMatch then
            btn.MouseButton1Click:Connect(function()
                sg:Destroy()
                RequestMixStart:FireServer(cookie.id)
            end)
        end
    end
end
```

### Step 2: Sync to Studio via MCP

```lua
-- run_code in Studio:
local SP   = game:GetService("StarterPlayer")
local SPS  = SP:FindFirstChild("StarterPlayerScripts")
local mins = SPS:FindFirstChild("Minigames")
local existing = mins and mins:FindFirstChild("MixerController")
if not existing then error("[Task5] MixerController not found in StarterPlayerScripts/Minigames") end

-- Patch: read the current source, splice in the new showPicker function
-- NOTE: Due to the size of the change, destroy and recreate the script
local src = existing.Source

-- The source should be updated via Write tool first, then this recreates in Studio:
existing:Destroy()
local s = Instance.new("LocalScript")
s.Name   = "MixerController"
s.Source = [[ PASTE_FULL_UPDATED_SOURCE_HERE ]]
s.Parent = mins
print("[Task5] MixerController updated in Studio")
```

### Step 3: Verify

Play in Studio, go to a Mixer:
1. Without tutorial active: picker shows all 6 cookies, all clickable, title = "Choose a Cookie"
2. Manually set attribute in command bar: `game.Players.LocalPlayer.PlayerGui:SetAttribute("TutorialForceCookie","pink_sugar")`
3. Open picker: Pink Sugar is normal, other 5 are dimmed/greyed, title = "Tutorial: Pink Sugar Only!"
4. Only Pink Sugar button fires when clicked

### Step 4: Commit

```bash
git add src/StarterPlayer/StarterPlayerScripts/Minigames/MixerController.client.lua
git commit -m "feat(tutorial): MixerController reads TutorialForceCookie attribute, greys non-matching"
```

---

## Task 6: Rewrite TutorialController.server.lua

Full rewrite. 9-step state machine, advance() per station gate, step 10 final menu, returning player spawn.

**Files:**
- Modify: `src/ServerScriptService/Core/TutorialController.server.lua`

### Step 1: Write the full file on disk

```lua
-- src/ServerScriptService/Core/TutorialController.server.lua
-- Drives the 9-step cinematic tutorial for first-time players.
-- Server-authoritative: step state lives here. Client is display-only.
-- Progression: join (new) → step 1 → station results → step 10 (final menu) → complete
-- Returning players: join → step 0 (isReturn=true) → GameSpawn teleport via TutorialCamera

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local tutorialStepRemote  = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote  = RemoteManager.Get("TutorialComplete")
local startGameRemote     = RemoteManager.Get("StartGame")
local replayRemote        = RemoteManager.Get("ReplayTutorial")

-- Station result remotes (advance gates)
local orderAcceptedRemote  = RemoteManager.Get("OrderAccepted")
local mixResultRemote      = RemoteManager.Get("MixMinigameResult")
local doughResultRemote    = RemoteManager.Get("DoughMinigameResult")
local depositDoughRemote   = RemoteManager.Get("DepositDough")
local pullFridgeRemote     = RemoteManager.Get("PullFromFridgeResult")
local ovenResultRemote     = RemoteManager.Get("OvenMinigameResult")
local frostResultRemote    = RemoteManager.Get("FrostMinigameResult")
local dressResultRemote    = RemoteManager.Get("DressMinigameResult")
local deliveryRemote       = RemoteManager.Get("DeliveryResult")

-- ─── State ───────────────────────────────────────────────────────────────────
-- activeTutorials[userId] = { step = N }  (nil = not in tutorial)
local activeTutorials = {}

local TOTAL_STEPS = 9

local STEPS = {
    [1] = { msg = "Head to the POS and accept a customer order!",             target = "POS",             forceCookieId = nil           },
    [2] = { msg = "Go to a Mixer and press E to start mixing!",               target = "Mixer",           forceCookieId = "pink_sugar"  },
    [3] = { msg = "Shape your dough at the Dough Table — press E!",           target = "DoughTable",      forceCookieId = nil           },
    [4] = { msg = "Stock the dough in the Pink Sugar fridge!",                target = "FridgePinkSugar", forceCookieId = nil           },
    [5] = { msg = "Pull the chilled dough out of the fridge!",                target = "FridgePinkSugar", forceCookieId = nil           },
    [6] = { msg = "Slide it into the Oven — watch the timer!",                target = "Oven",            forceCookieId = nil           },
    [7] = { msg = "Apply pink frosting at the Frost Table!",                  target = "FrostTable",      forceCookieId = nil           },
    [8] = { msg = "Dress and pack your cookie!",                              target = "DressTable",      forceCookieId = nil           },
    [9] = { msg = "Carry the box to the customer and press E to deliver!",    target = "WaitingArea",     forceCookieId = nil           },
}

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function sendStep(player, step)
    local payload

    if step == 0 then
        -- Dismiss + GameSpawn teleport (issued by completeTutorial)
        payload = { step = 0, total = TOTAL_STEPS, msg = "", isReturn = false }

    elseif step == 10 then
        -- Final menu
        payload = { step = 10, total = TOTAL_STEPS, msg = "" }

    else
        local data = STEPS[step]
        if not data then
            warn("[TutorialController] sendStep: invalid step " .. tostring(step))
            return
        end
        payload = {
            step          = step,
            total         = TOTAL_STEPS,
            msg           = data.msg,
            target        = data.target,
            forceCookieId = data.forceCookieId,
        }
    end

    tutorialStepRemote:FireClient(player, payload)
    print(string.format("[TutorialController] %s → step %s", player.Name, tostring(step)))
end

local function advance(player)
    local session = activeTutorials[player.UserId]
    if not session then return end
    session.step += 1
    sendStep(player, session.step)
end

local function completeTutorial(player)
    local userId = player.UserId
    if not activeTutorials[userId] then return end
    activeTutorials[userId] = nil
    PlayerDataManager.SetTutorialCompleted(player)
    sendStep(player, 0)   -- client: dismiss overlay + teleport to GameSpawn
    print("[TutorialController] " .. player.Name .. " tutorial COMPLETE — saved to DataStore")
end

-- ─── Player Join ─────────────────────────────────────────────────────────────
local function handlePlayerJoin(player)
    task.wait(3)  -- allow PlayerDataManager to finish loading profile
    if not player or not player.Parent then return end

    local data = PlayerDataManager.GetData(player)
    if not data then return end

    if data.tutorialCompleted then
        -- Returning player: no tutorial, just teleport to GameSpawn via a step=0 with isReturn=true
        local payload = { step = 0, total = TOTAL_STEPS, msg = "", isReturn = true }
        tutorialStepRemote:FireClient(player, payload)
        print("[TutorialController] " .. player.Name .. " returning player → GameSpawn")
        return
    end

    -- First-time player: start tutorial at step 1
    activeTutorials[player.UserId] = { step = 1 }
    sendStep(player, 1)
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(handlePlayerJoin, player)
end)

Players.PlayerRemoving:Connect(function(player)
    activeTutorials[player.UserId] = nil
end)

-- Handle players already in-game when this script loads (Studio testing)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(handlePlayerJoin, player)
end

-- ─── Skip button ─────────────────────────────────────────────────────────────
tutorialDoneRemote.OnServerEvent:Connect(function(player)
    completeTutorial(player)
end)

-- ─── Start Day button (Final Menu) ───────────────────────────────────────────
startGameRemote.OnServerEvent:Connect(function(player)
    completeTutorial(player)
end)

-- ─── Replay Tutorial button (Final Menu) ─────────────────────────────────────
replayRemote.OnServerEvent:Connect(function(player)
    -- Reset to step 1 without saving completion — player must press Start Day to save
    activeTutorials[player.UserId] = { step = 1 }
    sendStep(player, 1)
    print("[TutorialController] " .. player.Name .. " replaying tutorial from step 1")
end)

-- ─── Station Advance Gates ────────────────────────────────────────────────────
-- Each gate checks that the player is on the expected step before advancing.
-- This prevents accidental cross-step advancement if a remote fires at wrong time.

local function makeGate(expectedStep)
    return function(player, ...)
        local session = activeTutorials[player.UserId]
        if session and session.step == expectedStep then
            advance(player)
        end
    end
end

orderAcceptedRemote.OnServerEvent:Connect(makeGate(1))
mixResultRemote.OnServerEvent:Connect(makeGate(2))
doughResultRemote.OnServerEvent:Connect(makeGate(3))
depositDoughRemote.OnServerEvent:Connect(makeGate(4))
pullFridgeRemote.OnServerEvent:Connect(makeGate(5))
ovenResultRemote.OnServerEvent:Connect(makeGate(6))
frostResultRemote.OnServerEvent:Connect(makeGate(7))
dressResultRemote.OnServerEvent:Connect(makeGate(8))
deliveryRemote.OnServerEvent:Connect(makeGate(9))

print("[TutorialController] Ready — 9-step cinematic tutorial active.")
```

### Step 2: Sync to Studio via MCP

```lua
-- run_code in Studio:
local SSS  = game:GetService("ServerScriptService")
local core = SSS:FindFirstChild("Core")
if not core then error("[Task6] Core folder not found") end

local existing = core:FindFirstChild("TutorialController")
if existing then existing:Destroy() end

local s = Instance.new("Script")
s.Name   = "TutorialController"
-- Paste the full source from Step 1
s.Source = [[ PASTE_FULL_SOURCE_HERE ]]
s.Parent = core
print("[Task6] TutorialController rewritten in Studio")
```

### Step 3: Verify

Play in Studio. Check Output:
- `[TutorialController] Ready — 9-step cinematic tutorial active.`
- If first-time player: `[TutorialController] <name> → step 1`
- If returning player: `[TutorialController] <name> returning player → GameSpawn`

To force first-time player for testing: temporarily add `if false and data.tutorialCompleted then` in `handlePlayerJoin`.

### Step 4: Commit

```bash
git add src/ServerScriptService/Core/TutorialController.server.lua
git commit -m "feat(tutorial): rewrite TutorialController - 9-step cinematic state machine"
```

---

## Task 7: Update GameStateManager.server.lua (PreOpen timer)

One constant change: first-day PreOpen from 5:00 to 7:30 so tutorial players have ~5 minutes of real PreOpen after finishing.

**Files:**
- Modify: `src/ServerScriptService/Core/GameStateManager.server.lua`

### Step 1: Find the PreOpen constant

Open `src/ServerScriptService/Core/GameStateManager.server.lua`. Search for the PreOpen duration constant. It will look like one of:

```lua
local PREOPEN_FIRST  = 5 * 60     -- or
local PREOPEN_FIRST  = 300         -- or
local PREOPEN_FIRST  = 5*60
```

### Step 2: Change the constant

Replace whichever form it takes with:

```lua
local PREOPEN_FIRST  = 7 * 60 + 30  -- 7:30 — gives tutorial players ~5 min of real PreOpen
```

*(If the constant has a different name, change that name. Leave all other timing constants untouched.)*

### Step 3: Sync the change to Studio via MCP

Use a targeted string patch:

```lua
-- run_code in Studio:
local SSS = game:GetService("ServerScriptService")
local gsm = SSS:FindFirstChild("Core") and SSS.Core:FindFirstChild("GameStateManager")
if not gsm then error("[Task7] GameStateManager not found") end

local src = gsm.Source
-- Replace the old duration (find the exact string from your file)
local newSrc = src:gsub("PREOPEN_FIRST%s*=%s*5%s*%*%s*60", "PREOPEN_FIRST = 7 * 60 + 30", 1)
if newSrc == src then
    -- Try alternate forms
    newSrc = src:gsub("PREOPEN_FIRST%s*=%s*300", "PREOPEN_FIRST = 7 * 60 + 30", 1)
end
if newSrc == src then
    error("[Task7] Could not find PREOPEN_FIRST constant — patch manually")
end
gsm.Source = newSrc
print("[Task7] GameStateManager PREOPEN_FIRST → 7:30")
```

### Step 4: Verify

Check Studio GameStateManager source — PREOPEN_FIRST should now be `7 * 60 + 30`.

### Step 5: Commit

```bash
git add src/ServerScriptService/Core/GameStateManager.server.lua
git commit -m "fix(tutorial): extend first-day PreOpen to 7:30 for tutorial players"
```

---

## Task 8: Integration Verify + Final Commit

### Manual test sequence

**Test A — First-time player flow:**
1. Force fresh tutorial by temporarily patching: `if false and data.tutorialCompleted then` in TutorialController
2. Play in Studio
3. Expected: step 1 panel appears + camera glides to POS
4. Accept any order at POS → step 2 panel + glide to Mixer
5. Open mixer picker → Pink Sugar is normal, 5 others are dimmed, title = "Tutorial: Pink Sugar Only!"
6. Mix pink_sugar → step 3 + glide to DoughCamera
7. Shape dough → step 4 + glide to pink_sugar fridge
8. Deposit dough → step 5 (same target)
9. Pull dough → step 6 + glide to Oven
10. Bake → step 7 + glide to Frost Table
11. Frost → step 8 + glide to Dress Table
12. Dress → step 9 + glide to WaitingArea
13. Deliver → step 10: Final Menu appears ("You're ready to bake! 🍪")
14. Press "START DAY": Final Menu closes → fade black → spawn at GameSpawn → camera Custom
15. Check DataStore: `tutorialCompleted = true` (rejoin → returning player flow)

**Test B — Returning player flow:**
1. Rejoin with saved `tutorialCompleted = true`
2. Expected: No tutorial panel. Screen fades black → player appears at GameSpawn → fade in. No step text.

**Test C — Skip flow:**
1. Force first-time player
2. Press "Skip" immediately
3. Expected: Panel hides → fade to GameSpawn → camera Custom. DataStore marks complete.

**Test D — Replay flow:**
1. Complete tutorial to step 10 Final Menu
2. Press "REPLAY TUTORIAL"
3. Expected: step 1 fires again → glide to POS. Final Menu gone. (DataStore NOT saved yet — only "Start Day" saves)

**Test E — picker clears after step 2:**
1. Let tutorial reach step 3 (DoughTable)
2. Open mixer (if reachable): picker shows all 6 cookies normally (no restriction)
3. Check: `playerGui:GetAttribute("TutorialForceCookie")` = nil in command bar

### Final cleanup commit

```bash
git add -A
git commit -m "feat(tutorial): cinematic 9-step tutorial complete - camera glide, GameSpawn, FinalMenu, Pink Sugar forcing"
```

---

## Files Changed Summary

| File | Change |
|------|--------|
| `src/ReplicatedStorage/Modules/RemoteManager.lua` | +`ReplayTutorial`, `StartGame` remotes |
| `src/StarterPlayer/StarterPlayerScripts/TutorialCamera.client.lua` | NEW — cinematic fade/teleport/glide |
| `src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua` | +FadeFrame, +FinalMenu, +forceCookie attribute logic, step /9 |
| `src/StarterPlayer/StarterPlayerScripts/Minigames/MixerController.client.lua` | +TutorialForceCookie restriction in showPicker |
| `src/ServerScriptService/Core/TutorialController.server.lua` | Full rewrite — 9 steps, makeGate(), returning players |
| `src/ServerScriptService/Core/GameStateManager.server.lua` | PREOPEN_FIRST = 7:30 |
| `workspace.GameSpawn` *(Studio only)* | New invisible Part — all players spawn here |
| `workspace.TutorialSpawn` *(Studio only)* | New invisible Part — pre-tutorial position |
