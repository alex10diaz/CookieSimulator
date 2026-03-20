-- ExteriorManager.server.lua
-- Moving street cars, drive-thru car, sidewalk pedestrians

local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- ── CAR BUILDER ──────────────────────────────────────────────────────────────
local function makeCar(bodyColor)
    local model = Instance.new("Model")
    model.Name = "StreetCar"

    local function cp(name, size, offset, color, mat)
        local p = Instance.new("Part")
        p.Name = name; p.Size = size
        p.Color = color or bodyColor
        p.Material = mat or Enum.Material.SmoothPlastic
        p.Anchored = false; p.CanCollide = false; p.CastShadow = true
        p:SetAttribute("OffX", offset.X)
        p:SetAttribute("OffY", offset.Y)
        p:SetAttribute("OffZ", offset.Z)
        p.Parent = model
        return p
    end

    local body = Instance.new("Part")
    body.Name = "Body"; body.Size = Vector3.new(8, 2.2, 4)
    body.Color = bodyColor; body.Material = Enum.Material.SmoothPlastic
    body.Anchored = true; body.CanCollide = false
    body.Parent = model; model.PrimaryPart = body

    cp("Cabin", Vector3.new(4.5, 1.4, 3.8), Vector3.new(0, 1.8, 0))
    local wf = cp("WF", Vector3.new(0.15,1.3,3.6), Vector3.new(2.05,1.85,0),
        Color3.fromRGB(160,205,235), Enum.Material.Glass)
    wf.Transparency = 0.45
    local wr = cp("WR", Vector3.new(0.15,1.3,3.6), Vector3.new(-2.05,1.85,0),
        Color3.fromRGB(160,205,235), Enum.Material.Glass)
    wr.Transparency = 0.45

    local wc = Color3.fromRGB(28, 28, 28)
    for _, o in ipairs({
        Vector3.new( 2.5,-0.8, 2.2), Vector3.new( 2.5,-0.8,-2.2),
        Vector3.new(-2.5,-0.8, 2.2), Vector3.new(-2.5,-0.8,-2.2),
    }) do
        local w = cp("Wheel", Vector3.new(0.5,1.1,1.1), o, wc)
        w.Shape = Enum.PartType.Cylinder
    end
    for _, z in ipairs({1.3, -1.3}) do
        local hl = cp("Headlight", Vector3.new(0.2,0.45,0.7), Vector3.new(4.05,0.1,z),
            Color3.fromRGB(255,255,220), Enum.Material.Neon)
        hl.Transparency = 0.2
        local tl = cp("Taillight", Vector3.new(0.2,0.45,0.7), Vector3.new(-4.05,0.1,z),
            Color3.fromRGB(220,30,30), Enum.Material.Neon)
        tl.Transparency = 0.2
    end
    cp("Grille",  Vector3.new(0.15,0.6,2.5), Vector3.new(4.05,-0.5,0),  Color3.fromRGB(35,35,35))
    cp("BumperF", Vector3.new(0.4,0.4,4.2),  Vector3.new(4.2,-0.9,0),   Color3.fromRGB(200,200,200))
    cp("BumperR", Vector3.new(0.4,0.4,4.2),  Vector3.new(-4.2,-0.9,0),  Color3.fromRGB(200,200,200))

    for _, p in ipairs(model:GetChildren()) do
        if p ~= body and p:IsA("BasePart") then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = body; weld.Part1 = p; weld.Parent = model
            p.CFrame = body.CFrame * CFrame.new(
                p:GetAttribute("OffX") or 0,
                p:GetAttribute("OffY") or 0,
                p:GetAttribute("OffZ") or 0)
        end
    end
    return model
end

-- ── PEDESTRIAN BUILDER ───────────────────────────────────────────────────────
local SKINS  = {
    Color3.fromRGB(255,220,177), Color3.fromRGB(234,192,134),
    Color3.fromRGB(198,134,66),  Color3.fromRGB(141,85,36),
}
local SHIRTS = {
    Color3.fromRGB(60,120,200), Color3.fromRGB(200,60,60),
    Color3.fromRGB(60,170,80),  Color3.fromRGB(180,90,200),
    Color3.fromRGB(220,160,40), Color3.fromRGB(230,230,230),
}
local PANTS = {
    Color3.fromRGB(50,50,80), Color3.fromRGB(80,50,30),
    Color3.fromRGB(30,60,40), Color3.fromRGB(70,70,70),
}

local function makePed()
    local model = Instance.new("Model"); model.Name = "Pedestrian"
    local skin  = SKINS [math.random(#SKINS)]
    local shirt = SHIRTS[math.random(#SHIRTS)]
    local pants = PANTS [math.random(#PANTS)]

    local function bp(name, size, color)
        local p = Instance.new("Part")
        p.Name = name; p.Size = size; p.Color = color
        p.Material = Enum.Material.SmoothPlastic
        p.Anchored = false; p.CanCollide = false
        p.Parent = model; return p
    end

    local hrp   = bp("HumanoidRootPart", Vector3.new(2,2,1), Color3.new())
    hrp.Transparency = 1
    local torso = bp("Torso",     Vector3.new(2,2,1), shirt)
    local head  = bp("Head",      Vector3.new(1,1,1), skin)
    local lArm  = bp("Left Arm",  Vector3.new(1,2,1), shirt)
    local rArm  = bp("Right Arm", Vector3.new(1,2,1), shirt)
    local lLeg  = bp("Left Leg",  Vector3.new(1,2,1), pants)
    local rLeg  = bp("Right Leg", Vector3.new(1,2,1), pants)

    local face = Instance.new("Decal", head)
    face.Face = Enum.NormalId.Front
    face.Texture = "rbxasset://textures/face.png"

    local hum = Instance.new("Humanoid", model)
    hum.MaxHealth = 100; hum.Health = 100
    hum.JumpHeight = 0; hum.JumpPower = 0
    hum.WalkSpeed = 8 + math.random() * 4
    model.PrimaryPart = hrp

    local function joint(name, p0, p1, c0, c1)
        local m = Instance.new("Motor6D")
        m.Name = name; m.Part0 = p0; m.Part1 = p1
        m.C0 = c0; m.C1 = c1; m.Parent = p0
    end
    local pi  = math.pi
    local pi2 = math.pi / 2
    joint("RootJoint",      hrp,   torso,
        CFrame.new(0,0,0)*CFrame.Angles(-pi2,0,pi), CFrame.new(0,0,0)*CFrame.Angles(-pi2,0,pi))
    joint("Neck",           torso, head,  CFrame.new(0,1,0),      CFrame.new(0,-0.5,0))
    joint("Left Shoulder",  torso, lArm,  CFrame.new(-1.5,0.5,0), CFrame.new(0.5,0.5,0))
    joint("Right Shoulder", torso, rArm,  CFrame.new(1.5,0.5,0),  CFrame.new(-0.5,0.5,0))
    joint("Left Hip",       torso, lLeg,  CFrame.new(-0.5,-1,0),  CFrame.new(0,1,0))
    joint("Right Hip",      torso, rLeg,  CFrame.new(0.5,-1,0),   CFrame.new(0,1,0))
    return model
end

-- ── FOLDERS ──────────────────────────────────────────────────────────────────
local function getFolder(name)
    local f = Workspace:FindFirstChild(name)
    if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = Workspace end
    return f
end
local carFolder = getFolder("ExteriorCars")
local pedFolder = getFolder("SidewalkPeds")

-- ── CAR COLORS ───────────────────────────────────────────────────────────────
local CAR_COLORS = {
    Color3.fromRGB(200, 50,  50),
    Color3.fromRGB(50,  80, 200),
    Color3.fromRGB(230,230,230),
    Color3.fromRGB(40,  40,  40),
    Color3.fromRGB(60, 160,  80),
    Color3.fromRGB(200,160,  30),
}

local STREET_Y = 1.75;  local STREET_Z = 44
local DT_Y     = 2.35;  local DT_Z     = -13

-- ── STREET CARS ──────────────────────────────────────────────────────────────
local function spawnStreetCar(colorIdx, goingWest, initDelay)
    task.delay(initDelay, function()
        while true do
            local car  = makeCar(CAR_COLORS[colorIdx])
            car.Parent = carFolder
            local body = car.PrimaryPart
            local rot  = goingWest and CFrame.Angles(0, math.pi, 0) or CFrame.new()
            local startX = goingWest and  135 or -135
            local endX   = goingWest and -135 or  135
            body.CFrame = CFrame.new(startX, STREET_Y, STREET_Z) * rot
            local speed = 28 + math.random(-4, 6)
            local tw = TweenService:Create(body,
                TweenInfo.new(270 / speed, Enum.EasingStyle.Linear),
                { CFrame = CFrame.new(endX, STREET_Y, STREET_Z) * rot })
            tw:Play(); tw.Completed:Wait()
            car:Destroy()
            task.wait(math.random(2, 6))
        end
    end)
end

spawnStreetCar(1, true,  0)
spawnStreetCar(3, true,  4)
spawnStreetCar(5, true,  9)
spawnStreetCar(2, false, 2)
spawnStreetCar(4, false, 7)
spawnStreetCar(6, false, 12)

-- ── DRIVE-THRU CAR ───────────────────────────────────────────────────────────
local function spawnDTCar(initDelay)
    task.delay(initDelay, function()
        while true do
            local car  = makeCar(CAR_COLORS[math.random(#CAR_COLORS)])
            car.Parent = carFolder
            local body = car.PrimaryPart
            local rot  = CFrame.Angles(0, math.pi, 0)
            body.CFrame = CFrame.new(5, DT_Y, DT_Z) * rot
            local approach = TweenService:Create(body,
                TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { CFrame = CFrame.new(-28, DT_Y, DT_Z) * rot })
            approach:Play(); approach.Completed:Wait()
            task.wait(math.random(8, 14))
            local exit = TweenService:Create(body,
                TweenInfo.new(3.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { CFrame = CFrame.new(-90, DT_Y, DT_Z) * rot })
            exit:Play(); exit.Completed:Wait()
            car:Destroy()
            task.wait(math.random(10, 20))
        end
    end)
end

spawnDTCar(0)
spawnDTCar(18)

-- ── SIDEWALK PEDESTRIANS ─────────────────────────────────────────────────────
local PED_CFGS = {
    { startX = -20, endX =  5,  z = 27.5, speed = 9  },
    { startX =  15, endX = -10, z = 26.5, speed = 11 },
    { startX =  -5, endX =  22, z = 28,   speed = 8  },
    { startX =  10, endX = -18, z = 27,   speed = 10 },
}

for i, cfg in ipairs(PED_CFGS) do
    task.delay(i * 1.5, function()
        local ped = makePed(); ped.Parent = pedFolder
        ped:PivotTo(CFrame.new(cfg.startX, 3, cfg.z))
        local hum = ped:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        hum.WalkSpeed = cfg.speed
        local goEnd = true
        while ped and ped.Parent do
            local tgt = goEnd
                and Vector3.new(cfg.endX, 1, cfg.z)
                or  Vector3.new(cfg.startX, 1, cfg.z)
            hum:MoveTo(tgt)
            local done = false
            local conn = hum.MoveToFinished:Connect(function() done = true end)
            local t = 0
            while not done and t < 25 do task.wait(0.5); t += 0.5 end
            conn:Disconnect()
            goEnd = not goEnd
            task.wait(math.random(1, 3))
        end
    end)
end

print("[ExteriorManager] Ready")
