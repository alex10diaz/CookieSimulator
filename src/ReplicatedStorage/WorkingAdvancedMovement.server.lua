local pfs = game:GetService("PathfindingService")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local animator = hum:WaitForChild("Animator")

local FRIDGE_FRONT_POS = Vector3.new(-27, 1, -17.6)
local IDLE_ANIM_ID     = "rbxassetid://180435571"
local OCCUPY_RADIUS    = 3.5

-- ============================================================
-- HELPERS
-- ============================================================
local function getPart(name)
    local folder = workspace:WaitForChild("POS")
    for _, v in ipairs(folder:GetChildren()) do
        if v.Name == name and v:IsA("BasePart") then return v end
    end
    return nil
end

local function navigateTo(targetPos)
    local path = pfs:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
    local ok = pcall(function() path:ComputeAsync(hrp.Position, targetPos) end)
    if not ok or path.Status ~= Enum.PathStatus.Success then
        hum:MoveTo(targetPos)
        hum.MoveToFinished:Wait()
        return
    end
    for _, wp in ipairs(path:GetWaypoints()) do
        hum:MoveTo(wp.Position)
        hum.MoveToFinished:Wait()
    end
end

local function faceToward(targetPos)
    local dir = Vector3.new(targetPos.X - hrp.Position.X, 0, targetPos.Z - hrp.Position.Z)
    if dir.Magnitude < 0.01 then return end
    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + dir.Unit)
end

local function isNearPosition(pos, radius)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= char and obj:FindFirstChild("HumanoidRootPart") then
            if (obj.HumanoidRootPart.Position - pos).Magnitude < radius then
                return true
            end
        end
    end
    return false
end

local function getRandomWaitSpot()
    local wa = workspace:WaitForChild("Waiting area")
    local halfX = (wa.Size.X / 2) - 1.5
    local halfZ = (wa.Size.Z / 2) - 1.5
    for _ = 1, 30 do
        local rx = wa.Position.X + math.random(-math.floor(halfX*10), math.floor(halfX*10)) / 10
        local rz = wa.Position.Z + math.random(-math.floor(halfZ*10), math.floor(halfZ*10)) / 10
        local spot = Vector3.new(rx, wa.Position.Y + 1, rz)
        if not isNearPosition(spot, OCCUPY_RADIUS) then
            return spot
        end
    end
    return Vector3.new(wa.Position.X, wa.Position.Y + 1, wa.Position.Z)
end

local function playIdleAnim()
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        track:Stop()
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = IDLE_ANIM_ID
    local track = animator:LoadAnimation(anim)
    track.Priority = Enum.AnimationPriority.Action
    track:Play()
    return track
end

-- ============================================================
-- CUSTOMER: real POS gameplay path
-- ============================================================
local function runCustomer()
    local steps = { "Tablet", "POS", "Show", "Show2", "Door", "Leave" }
    for _, name in ipairs(steps) do
        local part = getPart(name)
        if not part then continue end

        -- Wait for spot to clear before moving in
        local attempts = 0
        while isNearPosition(part.Position, 3) and attempts < 60 do
            task.wait(0.5)
            attempts += 1
        end

        navigateTo(part.Position)

        if name == "Leave" then
            char:Destroy()
            return
        end
        task.wait(3)
    end
end

-- ============================================================
-- AMBIENT: POS 1 or 2 slot, then waiting area
-- ============================================================
local function runAmbient()
    -- The spawner sets which slot this NPC owns via attribute
    local slotName = script:GetAttribute("AmbientSlot") -- "Show" or "Show2"
    local door = getPart("Door")
    local leave = getPart("Leave")

    -- Enter through door
    if door then navigateTo(door.Position) end

    -- Walk to assigned slot
    local slotPart = getPart(slotName)
    if slotPart then
        navigateTo(slotPart.Position)
        task.wait(math.random(4, 7)) -- pretend to order
    end

    -- Walk to waiting area
    local waitSpot = getRandomWaitSpot()
    navigateTo(waitSpot)

    -- Face fridge, go idle
    faceToward(FRIDGE_FRONT_POS)
    hum.WalkSpeed = 0
    local idleTrack = playIdleAnim()

    -- Wait naturally
    task.wait(math.random(8, 18))

    -- Leave
    hum.WalkSpeed = 16
    idleTrack:Stop()
    if leave then navigateTo(leave.Position) end
    char:Destroy()
end

-- ============================================================
-- ENTRY
-- ============================================================
task.wait(0.2)
local npcType = script:GetAttribute("NPCType") or "customer"
if npcType == "ambient" then
    runAmbient()
else
    runCustomer()
end
