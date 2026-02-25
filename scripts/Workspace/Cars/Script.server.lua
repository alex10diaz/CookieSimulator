local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

-- Get Cars folder
local carsFolder = Workspace:FindFirstChild("Cars")
if not carsFolder then
    warn("Cars folder not found in Workspace.")
    return
end

-- Get the Fusion model to use for spawning
local carTemplate = carsFolder:FindFirstChild("Fusion")
if not carTemplate or not carTemplate:IsA("Model") then
    warn("Fusion model not found in Cars folder.")
    return
end

local carSpeed = 60     -- increased for faster movement (studs per second)

function moveModelTo(model, cframe)
    -- Move the entire model to the given CFrame
    if model:IsA("Model") then
        model:PivotTo(cframe)
    elseif model:IsA("BasePart") then
        model.CFrame = cframe
    end
end

-- Helper to get the lowest Y of all BaseParts in a model (car base)
function getModelBaseY(model)
    local minY = nil
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            local y = (part.CFrame.Position - Vector3.new(0, part.Size.Y/2, 0)).Y
            if minY == nil or y < minY then
                minY = y
            end
        end
    end
    return minY
end

-- Helper to get the top Y of a part (spawn point)
function getPartTopY(part)
    return (part.Position + Vector3.new(0, part.Size.Y/2, 0)).Y
end

-- Assign a random color to all BaseParts in the car model
function colorCar(model)
    local randomColor = Color3.new(math.random(), math.random(), math.random())
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then
            part.Color = randomColor
        end
    end
end

-- Move the car along a path (waypoints), always facing the next waypoint (flipped)
function moveCarAlongPath(car, waypoints, yOffset)
    for i = 1, #waypoints - 1 do
        local currentWaypoint = waypoints[i]
        local nextWaypoint = waypoints[i+1]
        local startPos = currentWaypoint.Position
        local endPos = nextWaypoint.Position

        -- Calculate the direction to face (flipped)
        local direction = (endPos - startPos).Unit
        local flippedDirection = -direction
        local up = Vector3.new(0,1,0)

        -- Calculate start and end CFrames (with correct yOffset and +2.25 studs)
        local startCFrame = CFrame.lookAt(
            Vector3.new(startPos.X, startPos.Y + yOffset + 2.25, startPos.Z),
            Vector3.new(startPos.X, startPos.Y + yOffset + 2.25, startPos.Z) + flippedDirection,
            up
        )
        local endCFrame = CFrame.lookAt(
            Vector3.new(endPos.X, endPos.Y + yOffset + 2.25, endPos.Z),
            Vector3.new(endPos.X, endPos.Y + yOffset + 2.25, endPos.Z) + flippedDirection,
            up
        )

        local distance = (endPos - startPos).Magnitude
        local duration = distance / carSpeed
        local startTime = tick()
        while true do
            local elapsed = tick() - startTime
            local alpha = math.clamp(elapsed / duration, 0, 1)
            -- Interpolate position and orientation
            local interpPos = startPos:Lerp(endPos, alpha)
            local interpLook = interpPos + flippedDirection
            local interpCFrame = CFrame.lookAt(
                Vector3.new(interpPos.X, interpPos.Y + yOffset + 2.25, interpPos.Z),
                Vector3.new(interpLook.X, interpLook.Y + yOffset + 2.25, interpLook.Z),
                up
            )
            moveModelTo(car, interpCFrame)
            if alpha >= 1 then
                break
            end
            task.wait()
        end
    end
end

function moveCarWithPathfinding(car, startPos, endPos, yOffset)
    local path = PathfindingService:CreatePath({
        AgentRadius = 3,
        AgentHeight = 5,
        AgentCanJump = false,
        AgentCanClimb = false,
        WaypointSpacing = 4,
        Costs = {}
    })
    path:ComputeAsync(startPos, endPos)
    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        moveCarAlongPath(car, waypoints, yOffset)
    else
        -- Fallback: move in a straight line, face the endpoint (flipped)
        local direction = (endPos - startPos).Unit
        local flippedDirection = -direction
        local up = Vector3.new(0,1,0)
        local startCFrame = CFrame.lookAt(
            Vector3.new(startPos.X, startPos.Y + yOffset + 2.25, startPos.Z),
            Vector3.new(startPos.X, startPos.Y + yOffset + 2.25, startPos.Z) + flippedDirection,
            up
        )
        local endCFrame = CFrame.lookAt(
            Vector3.new(endPos.X, endPos.Y + yOffset + 2.25, endPos.Z),
            Vector3.new(endPos.X, endPos.Y + yOffset + 2.25, endPos.Z) + flippedDirection,
            up
        )
        local distance = (endPos - startPos).Magnitude
        local duration = distance / carSpeed
        local startTime = tick()
        while true do
            local elapsed = tick() - startTime
            local alpha = math.clamp(elapsed / duration, 0, 1)
            local interpPos = startPos:Lerp(endPos, alpha)
            local interpLook = interpPos + flippedDirection
            local interpCFrame = CFrame.lookAt(
                Vector3.new(interpPos.X, interpPos.Y + yOffset + 2.25, interpPos.Z),
                Vector3.new(interpLook.X, interpLook.Y + yOffset + 2.25, interpLook.Z),
                up
            )
            moveModelTo(car, interpCFrame)
            if alpha >= 1 then
                break
            end
            task.wait()
        end
    end
    car:Destroy()
end

-- Function to spawn cars on a given route (spawnPoint -> endPoint) with custom intervals and a Random object
function spawnCarsOnRoute(spawnPoint, endPoint, minInterval, maxInterval, randomObj)
    -- Add a small random initial delay to desynchronize first spawn
    task.wait(randomObj:NextNumber(0, maxInterval))
    while true do
        if not spawnPoint or not endPoint then
            warn("Spawn or end point missing for car route.")
            break
        end

        local car = carTemplate:Clone()
        car.Parent = carsFolder

        -- Assign random color to car
        colorCar(car)

        -- Calculate offset so car base sits exactly on top of spawnPoint
        local carBaseY = getModelBaseY(car)
        local spawnTopY = getPartTopY(spawnPoint)
        local yOffset = spawnTopY - carBaseY

        -- Calculate orientation: face from spawn to end (flipped)
        local spawnPos = Vector3.new(
            spawnPoint.Position.X,
            spawnPoint.Position.Y + spawnPoint.Size.Y/2,
            spawnPoint.Position.Z
        )
        local endPos = Vector3.new(
            endPoint.Position.X,
            endPoint.Position.Y + endPoint.Size.Y/2,
            endPoint.Position.Z
        )
        local direction = (endPos - spawnPos).Unit
        local flippedDirection = -direction
        local up = Vector3.new(0,1,0)
        local lookCFrame = CFrame.lookAt(
            Vector3.new(spawnPos.X, spawnPos.Y + yOffset + 2.25, spawnPos.Z),
            Vector3.new(spawnPos.X, spawnPos.Y + yOffset + 2.25, spawnPos.Z) + flippedDirection,
            up
        )

        moveModelTo(car, lookCFrame)

        -- Pathfind from spawn to end
        moveCarWithPathfinding(car, spawnPos, endPos, yOffset)

        -- Wait random interval before next car (using custom intervals and Random object)
        local waitTime = randomObj:NextNumber(minInterval, maxInterval)
        task.wait(waitTime)
    end
end

-- Get the four points
local pointA = carsFolder:FindFirstChild("PointA")
local pointB = carsFolder:FindFirstChild("PointB")
local pointC = carsFolder:FindFirstChild("PointC")
local pointD = carsFolder:FindFirstChild("PointD")

-- Create independent Random objects for each route
local randomA = Random.new()
local randomD = Random.new()

-- Start independent spawn loops for each valid route with different, more frequent intervals and independent randoms
if pointA and pointB then
    task.spawn(function()
        -- Example: PointA route spawns every 0.08 to 0.25 seconds
        spawnCarsOnRoute(pointA, pointB, 0.08, 0.25, randomA)
    end)
end
if pointD and pointC then
    task.spawn(function()
        -- Example: PointD route spawns every 0.12 to 0.32 seconds
        spawnCarsOnRoute(pointD, pointC, 0.12, 0.32, randomD)
    end)
end
