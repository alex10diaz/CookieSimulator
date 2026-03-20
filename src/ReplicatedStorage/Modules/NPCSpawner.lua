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

    -- VIP: gold BillboardGui label above head (avatar appearance is fixed, can't recolor parts)
    if config.isVIP then
        local head = npc:FindFirstChild("Head")
        if head then
            local bb           = Instance.new("BillboardGui")
            bb.Name            = "VIPGui"
            bb.Size            = UDim2.new(0, 60, 0, 24)
            bb.StudsOffset     = VIP_LABEL_OFFSET
            bb.AlwaysOnTop     = false
            bb.Parent          = head

            local lbl                    = Instance.new("TextLabel")
            lbl.Size                     = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundColor3         = Color3.fromRGB(255, 200, 0)
            lbl.BackgroundTransparency   = 0.1
            lbl.TextColor3               = Color3.fromRGB(0, 0, 0)
            lbl.Font                     = Enum.Font.GothamBold
            lbl.TextScaled               = true
            lbl.Text                     = "⭐ VIP"
            lbl.Parent                   = bb
        end
    end

    -- Hide patience timer immediately — will be shown only when NPC is seated.
    local head0 = npc:FindFirstChild("Head")
    local pg0   = head0 and head0:FindFirstChild("PatienceGui")
    if pg0 then pg0.Enabled = false end

    local spawnCF = config.spawnCFrame or CFrame.new(Vector3.new(-5, 2, 30))
    npc:SetPrimaryPartCFrame(spawnCF)

    local npcFolder = Workspace:FindFirstChild(NPC_FOLDER)
    if not npcFolder then
        npcFolder        = Instance.new("Folder")
        npcFolder.Name   = NPC_FOLDER
        npcFolder.Parent = Workspace
    end
    npc.Parent = npcFolder
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
    local function cancel()
        cancelled = true
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
