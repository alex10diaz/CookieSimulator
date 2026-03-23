local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local SSS          = game:GetService("ServerScriptService")
local OrderManager = require(RS:WaitForChild("Modules"):WaitForChild("OrderManager"))
local PDM          = require(SSS:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local HIRE_COST      = 50
local WORKER_QUALITY = 75
local SHIRT = "rbxassetid://76531325740097"
local PANTS = "rbxassetid://98693082132232"

-- Baker stand positions (beside each station, not on the interaction spot)
local BAKER_CF = {
    mix   = CFrame.new(17.68, 4, -14.76) * CFrame.Angles(0, 0,              0), -- face -Z toward mixer
    dough = CFrame.new(  7,    4, -35.75) * CFrame.Angles(0, math.rad( 90),  0), -- face -X toward dough table
    oven  = CFrame.new(-5.44, 4, -82.68) * CFrame.Angles(0, math.rad(-45),  0), -- face +X/-Z toward oven cluster
    frost = CFrame.new( 5.95, 4, -67.81) * CFrame.Angles(0, math.rad( 90),  0), -- face -X toward frost table
    dress = CFrame.new(-20.09,4, -33.38) * CFrame.Angles(0, math.rad( 90),  0), -- face -X toward dress table
}
local LABELS     = {mix="Mixing",dough="Shaping",oven="Baking",frost="Frosting",dress="Packing"}
local ANCHOR_CF  = {
    mix=CFrame.new(17.68,2.5,-14.76), dough=CFrame.new(7,2.5,-35.75),
    oven=CFrame.new(-5.44,2.5,-82.68), frost=CFrame.new(5.95,2.5,-67.81),
    dress=CFrame.new(-20.09,2.5,-33.38),
}

local workers = {}; local workerCount = 0

-- Give debug coins to any joining player
Players.PlayerAdded:Connect(function(player)
    task.wait(5)
    if player and player.Parent then
        PDM.AddCoins(player, 500)
        print("[AIBakerSystem] Gave 500 debug coins to " .. player.Name)
    end
end)
-- Also give to anyone already in game
task.spawn(function()
    task.wait(2)
    for _, p in ipairs(Players:GetPlayers()) do
        PDM.AddCoins(p, 500)
        print("[AIBakerSystem] Gave 500 debug coins to " .. p.Name)
    end
end)

local function spawnRig(stationId, hiringPlayer)
    local existing = workspace:FindFirstChild("AIWorker_"..stationId)
    if existing then existing:Destroy() end

    local spawnCF = BAKER_CF[stationId] or CFrame.new(0,2,0)
    local rig

    -- Try character clone from hiring player
    local char = hiringPlayer and hiringPlayer.Character
    if char then
        local ok, result = pcall(function()
            char.Archivable = true
            local clone = char:Clone()
            char.Archivable = false
            for _, obj in ipairs(clone:GetDescendants()) do
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("Animator")
                   or obj:IsA("AnimationController") or obj:IsA("Sound") then
                    obj:Destroy()
                end
            end
            local hum = clone:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                hum.HealthDisplayDistance = 0
            end
            for _, p in ipairs(clone:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored=true; p.CanCollide=false end
            end
            -- Reset joint transforms so character is in T-pose, not frozen mid-walk
            for _, j in ipairs(clone:GetDescendants()) do
                if j:IsA("Motor6D") then j.Transform = CFrame.new() end
            end
            for _, obj in ipairs(clone:GetChildren()) do
                if obj:IsA("Shirt") or obj:IsA("Pants") then obj:Destroy() end
            end
            Instance.new("Shirt", clone).ShirtTemplate = SHIRT
            Instance.new("Pants", clone).PantsTemplate = PANTS
            local hrp = clone:FindFirstChild("HumanoidRootPart")
            if hrp then
                local origin = hrp.CFrame
                for _, p in ipairs(clone:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.CFrame = spawnCF * origin:ToObjectSpace(p.CFrame)
                    end
                end
                hrp.CFrame = spawnCF
                clone.PrimaryPart = hrp
            end
            return clone
        end)
        if ok and result then
            rig = result
        else
            warn("[AIBakerSystem] Clone failed: " .. tostring(result))
        end
    end

    -- Block fallback
    if not rig then
        rig = Instance.new("Model")
        local hrp = Instance.new("Part"); hrp.Name="HumanoidRootPart"; hrp.Size=Vector3.new(2,2,1)
        hrp.Anchored=true; hrp.CanCollide=false; hrp.BrickColor=BrickColor.new("Pastel brown")
        hrp.CFrame=spawnCF; hrp.Parent=rig
        local head = Instance.new("Part"); head.Name="Head"; head.Size=Vector3.new(2,1,1)
        head.Anchored=true; head.CanCollide=false; head.BrickColor=BrickColor.new("Pastel yellow")
        head.CFrame=spawnCF*CFrame.new(0,1.5,0); head.Parent=rig
        Instance.new("Humanoid",rig).DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
        rig.PrimaryPart=rig:FindFirstChild("HumanoidRootPart")
        Instance.new("Shirt",rig).ShirtTemplate=SHIRT
        Instance.new("Pants",rig).PantsTemplate=PANTS
    end

    rig.Name = "AIWorker_"..stationId
    rig.Parent = workspace

    local hrp2 = rig:FindFirstChild("HumanoidRootPart")
    if hrp2 then
        for _, bb in ipairs(hrp2:GetChildren()) do
            if bb:IsA("BillboardGui") then bb:Destroy() end
        end
        local nb = Instance.new("BillboardGui",hrp2); nb.Name="NameTag"
        nb.Size=UDim2.new(0,160,0,36); nb.StudsOffset=Vector3.new(0,3.5,0); nb.AlwaysOnTop=true
        local nl = Instance.new("TextLabel",nb); nl.Size=UDim2.new(1,0,1,0)
        nl.BackgroundTransparency=1; nl.Text="Baker ("..stationId..")"
        nl.TextColor3=Color3.new(1,1,1); nl.Font=Enum.Font.GothamBold; nl.TextScaled=true
    end
    print("[AIBakerSystem] Rig spawned for "..stationId.." | clone="..(char ~= nil and "attempted" or "skipped"))
end

local function runLoop(stationId, proxy)
    while workers[stationId] do
        pcall(function()
            if stationId == "mix" then
                local wf = workspace:FindFirstChild("Warmers"); local menu={}; local seen={}
                if wf then for _,m in ipairs(wf:GetChildren()) do
                    local c=m:GetAttribute("CookieId")
                    if c and c~="" and not seen[c] then seen[c]=true; table.insert(menu,c) end
                end end
                if #menu > 0 then
                    local wc=OrderManager.GetWarmerCountsByType(); local fs=OrderManager.GetFridgeState()
                    local cId=menu[1]; local low=math.huge
                    for _,id in ipairs(menu) do
                        local t=(wc[id] or 0)+(fs["fridge_"..id] or 0)
                        if t<low then low=t; cId=id end
                    end
                    local bId=OrderManager.TryStartBatch(proxy,cId)
                    if bId then task.wait(8); OrderManager.RecordStationScore(proxy,"mix",WORKER_QUALITY,bId) end
                end
            elseif stationId == "dough" then
                local b=OrderManager.GetBatchAtStage("dough")
                if b then task.wait(6); OrderManager.RecordStationScore(proxy,"dough",WORKER_QUALITY,b.batchId) end
            elseif stationId == "oven" then
                local ff=workspace:FindFirstChild("Fridges")
                if ff then for _,f in ipairs(ff:GetChildren()) do
                    local fId=f:GetAttribute("FridgeId")
                    if fId then local bId=OrderManager.PullFromFridge(proxy,fId)
                        if bId then task.wait(12); OrderManager.RecordOvenScore(proxy,WORKER_QUALITY,bId); break end
                    end
                end end
            elseif stationId == "frost" then
                if OrderManager.GetWarmerCount()>0 then
                    local e=OrderManager.TakeFromWarmers(true)
                    if e then task.wait(8); OrderManager.RecordFrostScore(proxy.Name,e.batchId,WORKER_QUALITY,e.snapshot or 0,e.cookieId) end
                end
            end
        end)
        task.wait(2)
    end
end

-- Create hire anchors + prompts
for stationId, acf in pairs(ANCHOR_CF) do
    local anchor=Instance.new("Part"); anchor.Name="HireAnchor_"..stationId
    anchor.Anchored=true; anchor.CanCollide=false; anchor.Transparency=1
    anchor.Size=Vector3.new(1,1,1); anchor.CFrame=acf; anchor.Parent=workspace
    local pp=Instance.new("ProximityPrompt",anchor)
    pp.ActionText="Hire Baker (50)"; pp.ObjectText=(LABELS[stationId]).." Station"
    pp.KeyboardKeyCode=Enum.KeyCode.H; pp.MaxActivationDistance=10; pp.RequiresLineOfSight=false

    local capturedId = stationId
    pp.Triggered:Connect(function(player)
        if workers[capturedId] then
            workers[capturedId]=false; workerCount=math.max(0,workerCount-1)
            local r=workspace:FindFirstChild("AIWorker_"..capturedId); if r then r:Destroy() end
            pp.ActionText="Hire Baker (50)"; print("[AIBakerSystem] Dismissed "..capturedId)
        else
            if workerCount>=5 then return end
            local profile=PDM.GetData(player)
            if not profile or (profile.coins or 0)<HIRE_COST then
                print("[AIBakerSystem] "..player.Name.." needs "..HIRE_COST.." coins, has "..(profile and profile.coins or 0))
                return
            end
            PDM.AddCoins(player,-HIRE_COST)
            workerCount+=1; workers[capturedId]=true; pp.ActionText="Dismiss Baker"
            spawnRig(capturedId, player)
            task.spawn(runLoop,capturedId,{Name="Baker_"..capturedId})
            print("[AIBakerSystem] "..player.Name.." hired baker at "..capturedId)
        end
    end)
end
-- ── SOLO MODE GATING ─────────────────────────────────────────────────────────
local function updateSoloMode()
    local solo = #Players:GetPlayers() == 1
    for _, anchor in ipairs(workspace:GetChildren()) do
        if anchor.Name:sub(1, 11) == "HireAnchor_" then
            local pp = anchor:FindFirstChildOfClass("ProximityPrompt")
            if pp then pp.Enabled = solo end
        end
    end
    if not solo then
        for stationId, active in pairs(workers) do
            if active then
                workers[stationId] = false
                workerCount = math.max(0, workerCount - 1)
                local rig = workspace:FindFirstChild("AIWorker_" .. stationId)
                if rig then rig:Destroy() end
            end
        end
    end
end
Players.PlayerAdded:Connect(function() task.wait(1); updateSoloMode() end)
Players.PlayerRemoving:Connect(function() task.wait(1); updateSoloMode() end)
task.delay(2, updateSoloMode)

print("[AIBakerSystem] Loaded and ready")
