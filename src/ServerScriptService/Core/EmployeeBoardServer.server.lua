-- EmployeeBoardServer (Script, ServerScriptService/Core)
-- Creates and updates the Employee of the Shift board in the back room.
-- Board appears at EndOfDay, resets at PreOpen.

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local SessionStats = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))

local BOARD_NAME = "EmployeeBoard"
local BOARD_CF   = CFrame.new(0, 9, -156)
local BOARD_SIZE = Vector3.new(5, 8, 0.2)

-- ── Build board Part + SurfaceGui ──────────────────────────────────────────────
local function buildBoard()
    local part = Instance.new("Part")
    part.Name         = BOARD_NAME
    part.Size         = BOARD_SIZE
    part.CFrame       = BOARD_CF
    part.Anchored     = true
    part.CanCollide   = false
    part.Color        = Color3.fromRGB(12, 12, 22)
    part.Material     = Enum.Material.SmoothPlastic
    part.Parent       = workspace

    local sg = Instance.new("SurfaceGui", part)
    sg.Name          = "BoardGui"
    sg.Face          = Enum.NormalId.Back   -- +Z faces into the room
    sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 60
    sg.AlwaysOnTop   = false

    local bg = Instance.new("Frame", sg)
    bg.Name = "Bg"; bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(12, 12, 22); bg.BorderSizePixel = 0

    -- Gold top bar
    local bar = Instance.new("Frame", bg)
    bar.Size = UDim2.new(1,0,0,8); bar.BackgroundColor3 = Color3.fromRGB(255,200,0); bar.BorderSizePixel = 0

    -- Header
    local header = Instance.new("TextLabel", bg)
    header.Name = "Header"; header.Size = UDim2.new(1,-20,0,50)
    header.Position = UDim2.new(0,10,0,14)
    header.BackgroundTransparency = 1
    header.TextColor3 = Color3.fromRGB(255,200,0)
    header.Font = Enum.Font.GothamBold; header.TextScaled = true
    header.Text = "EMPLOYEE OF THE SHIFT"

    -- Avatar circle
    local avatar = Instance.new("ImageLabel", bg)
    avatar.Name = "Avatar"; avatar.Size = UDim2.new(0,150,0,150)
    avatar.Position = UDim2.new(0.5,-75,0,72)
    avatar.BackgroundColor3 = Color3.fromRGB(35,35,55); avatar.BorderSizePixel = 0
    avatar.Image = ""
    local corner = Instance.new("UICorner", avatar)
    corner.CornerRadius = UDim.new(1, 0)

    -- Ring around avatar
    local ring = Instance.new("UIStroke", avatar)
    ring.Color = Color3.fromRGB(255,200,0); ring.Thickness = 4

    -- Player name
    local nameLabel = Instance.new("TextLabel", bg)
    nameLabel.Name = "PlayerName"; nameLabel.Size = UDim2.new(1,-20,0,55)
    nameLabel.Position = UDim2.new(0,10,0,232)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
    nameLabel.Font = Enum.Font.GothamBold; nameLabel.TextScaled = true
    nameLabel.Text = "—"

    -- Subtitle
    local sub = Instance.new("TextLabel", bg)
    sub.Name = "Subtitle"; sub.Size = UDim2.new(1,-20,0,32)
    sub.Position = UDim2.new(0,10,0,292)
    sub.BackgroundTransparency = 1
    sub.TextColor3 = Color3.fromRGB(160,160,160)
    sub.Font = Enum.Font.Gotham; sub.TextScaled = true
    sub.Text = "This shift's top baker"

    -- Stars row
    local stars = Instance.new("TextLabel", bg)
    stars.Name = "Stars"; stars.Size = UDim2.new(1,-20,0,35)
    stars.Position = UDim2.new(0,10,0,330)
    stars.BackgroundTransparency = 1
    stars.TextColor3 = Color3.fromRGB(255,200,0)
    stars.Font = Enum.Font.GothamBold; stars.TextScaled = true
    stars.Text = "★ ★ ★ ★ ★"

    return part
end

-- ── Update helpers ─────────────────────────────────────────────────────────────
local board = buildBoard()

local function setWinner(winner)
    local sg = board:FindFirstChild("BoardGui")
    if not sg then return end
    local bg = sg:FindFirstChild("Bg")
    if not bg then return end

    local nameLabel = bg:FindFirstChild("PlayerName")
    local avatar    = bg:FindFirstChild("Avatar")
    local stars     = bg:FindFirstChild("Stars")

    if winner then
        if nameLabel then nameLabel.Text = winner.name end
        if stars     then stars.Text = "★ ★ ★ ★ ★" end
        if avatar then
            task.spawn(function()
                local ok, url = pcall(function()
                    return Players:GetUserThumbnailAsync(
                        winner.userId,
                        Enum.ThumbnailType.HeadShot,
                        Enum.ThumbnailSize.Size420x420
                    )
                end)
                if ok and avatar.Parent then
                    avatar.Image = url
                end
            end)
        end
    else
        if nameLabel then nameLabel.Text = "—" end
        if avatar    then avatar.Image   = "" end
        if stars     then stars.Text     = "" end
    end
end

-- ── State watcher ──────────────────────────────────────────────────────────────
workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    local state = workspace:GetAttribute("GameState")
    if state == "EndOfDay" then
        task.wait(0.5) -- brief delay so last station score is recorded
        setWinner(SessionStats.GetTopEmployee())
    elseif state == "PreOpen" or state == "Lobby" then
        setWinner(nil) -- clear board for next shift
    end
end)

print("[EmployeeBoard] Ready.")
