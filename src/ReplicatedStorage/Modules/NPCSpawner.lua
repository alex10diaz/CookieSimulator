-- NPCSpawner
-- Handles NPC model creation and pathfinding movement.
-- Used exclusively by NPCController (server-side).

local PathfindingService = game:GetService("PathfindingService")
local ServerStorage      = game:GetService("ServerStorage")
local Workspace          = game:GetService("Workspace")

local NPCSpawner = {}

local TEMPLATE_NAME    = "NPCTemplate"
local NPC_FOLDER       = "NPCs"
local VIP_LABEL_OFFSET = Vector3.new(0, 2.5, 0)

-- R6 default animation IDs
local ANIM_IDLE = "rbxassetid://180435571"
local ANIM_WALK = "rbxassetid://180426354"

local function getAnimator(npcModel)
    local hum = npcModel:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local existing = hum:FindFirstChildOfClass("Animator")
    if existing then return existing end
    return Instance.new("Animator", hum)
end

local function loadTrack(animator, assetId)
    local anim = Instance.new("Animation")
    anim.AnimationId = assetId
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    return ok and track or nil
end

local function playIdle(npcModel)
    local animator = getAnimator(npcModel)
    if not animator then return end
    local track = loadTrack(animator, ANIM_IDLE)
    if track then track.Looped = true; track:Play() end
end

-- Randomised appearance palettes
local SKIN_TONES = {
    Color3.fromRGB(255,220,177), Color3.fromRGB(234,192,134),
    Color3.fromRGB(198,134, 66), Color3.fromRGB(141, 85, 36),
    Color3.fromRGB( 89, 47, 14),
}
local SHIRT_COLORS = {
    Color3.fromRGB( 60,120,200), Color3.fromRGB(200, 60, 60),
    Color3.fromRGB( 60,170, 80), Color3.fromRGB(180, 90,200),
    Color3.fromRGB(220,160, 40), Color3.fromRGB( 50,180,180),
    Color3.fromRGB(230,230,230), Color3.fromRGB( 40, 40, 60),
}
local PANTS_COLORS = {
    Color3.fromRGB( 50, 50, 80), Color3.fromRGB( 80, 50, 30),
    Color3.fromRGB( 30, 60, 40), Color3.fromRGB( 70, 70, 70),
    Color3.fromRGB( 40, 40,100), Color3.fromRGB(100, 80, 60),
}

local function randomizeAppearance(npc)
    local skin   = SKIN_TONES  [math.random(#SKIN_TONES)]
    local shirt  = SHIRT_COLORS[math.random(#SHIRT_COLORS)]
    local pants  = PANTS_COLORS[math.random(#PANTS_COLORS)]
    for _, part in ipairs(npc:GetChildren()) do
        if part:IsA("BasePart") then
            local n = part.Name
            if n == "Head" or n == "HumanoidRootPart" then
                if n == "Head" then part.Color = skin end
            elseif n == "Torso" or n == "Left Arm" or n == "Right Arm" then
                part.Color = shirt
            elseif n == "Left Leg" or n == "Right Leg" then
                part.Color = pants
            end
        end
    end
end

-- ─── CreateNPC ────────────────────────────────────────────────────────────────
-- config: { name, isVIP, spawnCFrame }
-- Returns the NPC Model, or nil on failure.
function NPCSpawner.CreateNPC(config)
    local npc

    -- Prefer the avatar pool if it's ready
    local avatarsReady = Workspace:GetAttribute("NPCAvatarsReady")
    local avatarFolder = ServerStorage:FindFirstChild("NPCAvatars")
    if avatarsReady and avatarFolder then
        local pool = avatarFolder:GetChildren()
        if #pool > 0 then
            local pick = pool[math.random(1, #pool)]
            npc = pick:Clone()
        end
    end

    -- Fallback: use NPCTemplate
    if not npc then
        local template = ServerStorage:FindFirstChild(TEMPLATE_NAME)
        if not template then
            warn("[NPCSpawner] NPCTemplate not found in ServerStorage")
            return nil
        end
        npc = template:Clone()
        randomizeAppearance(npc)  -- random shirt/pants/skin each spawn
    end

    npc.Name = config.name or "Customer"

    -- M-5: VIP gold BillboardGui — larger, always-on-top, gold glow
    if config.isVIP then
        local head = npc:FindFirstChild("Head")
        if head then
            local bb           = Instance.new("BillboardGui")
            bb.Name            = "VIPGui"
            bb.Size            = UDim2.new(0, 110, 0, 32)
            bb.StudsOffset     = Vector3.new(0, 5.2, 0)  -- above patience bar
            bb.AlwaysOnTop     = true
            bb.Parent          = head

            local lbl                    = Instance.new("TextLabel")
            lbl.Size                     = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundColor3         = Color3.fromRGB(255, 185, 0)
            lbl.BackgroundTransparency   = 0
            lbl.TextColor3               = Color3.fromRGB(30, 20, 0)
            lbl.Font                     = Enum.Font.GothamBold
            lbl.TextScaled               = true
            lbl.Text                     = "★ VIP ★"
            lbl.Parent                   = bb
            Instance.new("UICorner", lbl).CornerRadius = UDim.new(0.5, 0)

            local stroke             = Instance.new("UIStroke", lbl)
            stroke.Color             = Color3.fromRGB(255, 240, 100)
            stroke.Thickness         = 1.5
            stroke.Transparency      = 0.1
        end
    end

    -- Hide patience timer immediately — will be shown only when NPC is seated.
    local head0 = npc:FindFirstChild("Head")
    local pg0   = head0 and head0:FindFirstChild("PatienceGui")
    if pg0 then
        pg0.Enabled = false
        -- M-1: inject patience progress bar into the existing PatienceGui
        -- Resize billboard to give space for bar strip below the text
        pg0.Size = UDim2.new(0, 120, 0, 52)
        pg0.StudsOffset = Vector3.new(0, 3.2, 0)
        local frame0 = pg0:FindFirstChildOfClass("Frame")
        if frame0 then
            -- Shrink text area to top 65%
            local lbl0 = frame0:FindFirstChild("TimerLabel")
            if lbl0 then
                lbl0.Size     = UDim2.new(1, 0, 0.65, 0)
                lbl0.Position = UDim2.new(0, 0, 0, 0)
            end
            -- Bar background strip (bottom 28%)
            local barBg = Instance.new("Frame", frame0)
            barBg.Name                    = "BarBg"
            barBg.Size                    = UDim2.new(0.92, 0, 0.26, 0)
            barBg.Position                = UDim2.new(0.04, 0, 0.70, 0)
            barBg.BackgroundColor3        = Color3.fromRGB(30, 30, 50)
            barBg.BackgroundTransparency  = 0.2
            barBg.BorderSizePixel         = 0
            Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
            -- Bar fill
            local barFill = Instance.new("Frame", barBg)
            barFill.Name                   = "BarFill"
            barFill.Size                   = UDim2.new(1, 0, 1, 0)
            barFill.BackgroundColor3       = Color3.fromRGB(80, 220, 80)
            barFill.BackgroundTransparency = 0
            barFill.BorderSizePixel        = 0
            Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
        end
    end

    -- Disable NPC-NPC collisions so NPCs pass through each other instead of
    -- stacking/launching when they converge in doorways or queue spots.
    for _, part in ipairs(npc:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    -- Re-enable the HumanoidRootPart so the humanoid can still stand on floors
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CanCollide = true end

    local spawnCF = config.spawnCFrame or CFrame.new(Vector3.new(-5, 2, 30))
    npc:SetPrimaryPartCFrame(spawnCF)

    local npcFolder = Workspace:FindFirstChild(NPC_FOLDER)
    if not npcFolder then
        npcFolder        = Instance.new("Folder")
        npcFolder.Name   = NPC_FOLDER
        npcFolder.Parent = Workspace
    end
    npc.Parent = npcFolder
    playIdle(npc)
    return npc
end

-- ─── MoveTo ───────────────────────────────────────────────────────────────────
-- Pathfinds the NPC to targetPos.  Calls onArrived(reached) when done.
-- Returns a cancel() function.
function NPCSpawner.MoveTo(npcModel, targetPos, onArrived)
    local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
    local hrp      = npcModel:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then
        if onArrived then onArrived(false) end
        return function() end
    end

    local cancelled = false
    local walkTrack = nil
    do
        local animator = getAnimator(npcModel)
        if animator then
            walkTrack = loadTrack(animator, ANIM_WALK)
            if walkTrack then walkTrack.Looped = true; walkTrack:Play() end
        end
    end

    local function stopWalk()
        if walkTrack then pcall(function() walkTrack:Stop() end); walkTrack = nil end
        playIdle(npcModel)
    end

    local function cancel()
        cancelled = true
        stopWalk()
        pcall(function() humanoid:MoveTo(hrp.Position) end)
    end

    local path = PathfindingService:CreatePath({
        AgentHeight   = 4,
        AgentRadius   = 1,
        AgentCanJump  = false,
        AgentCanClimb = false,
    })

    local ok = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)

    local waypoints = {}
    if ok and path.Status == Enum.PathStatus.Success then
        waypoints = path:GetWaypoints()
    end

    if #waypoints == 0 then
        -- Fallback: direct Humanoid:MoveTo
        humanoid:MoveTo(targetPos)
        local conn
        conn = humanoid.MoveToFinished:Connect(function(reached)
            conn:Disconnect()
            stopWalk()
            if not cancelled and onArrived then onArrived(reached) end
        end)
        return cancel
    end

    local idx  = 1
    local conn
    conn = humanoid.MoveToFinished:Connect(function(reached)
        if cancelled then
            conn:Disconnect()
            return
        end
        idx += 1
        if not reached or idx > #waypoints then
            conn:Disconnect()
            stopWalk()
            if onArrived then onArrived(reached) end
            return
        end
        humanoid:MoveTo(waypoints[idx].Position)
    end)

    humanoid:MoveTo(waypoints[1].Position)
    return cancel
end

-- ─── SetTimerText ─────────────────────────────────────────────────────────────
function NPCSpawner.SetTimerText(npcModel, text)
    local head = npcModel:FindFirstChild("Head")
    if not head then return end
    local gui   = head:FindFirstChild("PatienceGui")
    if not gui then return end
    -- Hide the entire BillboardGui when there is no text to show.
    -- This prevents the gray frame appearing during walk-in and queuing.
    gui.Enabled = (text ~= "")
    local frame = gui:FindFirstChildOfClass("Frame")
    if not frame then return end
    local lbl   = frame:FindFirstChild("TimerLabel")
    if lbl then lbl.Text = text end
end

-- ─── SetPatienceBar ───────────────────────────────────────────────────────────
-- M-1: ratio 0.0–1.0; colors green→yellow→red; hides bar when ratio<=0
function NPCSpawner.SetPatienceBar(npcModel, ratio)
    local head = npcModel:FindFirstChild("Head")
    if not head then return end
    local pg = head:FindFirstChild("PatienceGui")
    if not pg then return end
    local frame = pg:FindFirstChildOfClass("Frame")
    if not frame then return end
    local barBg = frame:FindFirstChild("BarBg")
    if not barBg then return end
    local barFill = barBg:FindFirstChild("BarFill")
    if not barFill then return end

    ratio = math.clamp(ratio, 0, 1)
    barFill.Size = UDim2.new(ratio, 0, 1, 0)

    -- Color: green (>60%) → yellow (30–60%) → red (<30%)
    local r, g, b
    if ratio > 0.6 then
        r, g, b = 80, 220, 80
    elseif ratio > 0.3 then
        local t = (ratio - 0.3) / 0.3  -- 0→1 from yellow to green
        r = math.floor(80  + (1 - t) * (230 - 80))
        g = math.floor(220 - (1 - t) * (220 - 200))
        b = 50
    else
        local t = ratio / 0.3  -- 0→1 from red to orange
        r = 230
        g = math.floor(t * 130)
        b = 50
    end
    barFill.BackgroundColor3 = Color3.fromRGB(r, g, b)
end

-- ─── SetPromptEnabled ─────────────────────────────────────────────────────────
function NPCSpawner.SetPromptEnabled(npcModel, enabled)
    local head = npcModel:FindFirstChild("Head")
    if not head then return end
    local pp = head:FindFirstChild("OrderPrompt")
    if pp then pp.Enabled = enabled end
end

-- ─── GetPrompt ────────────────────────────────────────────────────────────────
function NPCSpawner.GetPrompt(npcModel)
    local head = npcModel:FindFirstChild("Head")
    if not head then return nil end
    return head:FindFirstChild("OrderPrompt")
end

-- ─── Remove ───────────────────────────────────────────────────────────────────
function NPCSpawner.Remove(npcModel)
    if npcModel and npcModel.Parent then
        npcModel:Destroy()
    end
end

return NPCSpawner
