-- LeaderboardClient
-- Both boards: Rank | Name | Cookies | Orders | Coins
-- SessionBoard: stats this round
-- AllTimeBoard: lifetime stats
-- FEAT-7: YouRow shows local player's rank if outside top 6

local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local leaderboardUpdate = RemoteManager.Get("LeaderboardUpdate")

local MAX_ROWS = 6
local LOCAL_PLAYER = Players.LocalPlayer

local sessionBoard = Workspace:WaitForChild("SessionBoard", 60)
local alltimeBoard = Workspace:WaitForChild("AllTimeBoard", 60)
if not sessionBoard then warn("[LeaderboardClient] SessionBoard missing"); return end
if not alltimeBoard then warn("[LeaderboardClient] AllTimeBoard missing"); return end

local sessionBg = sessionBoard:WaitForChild("LeaderboardGui"):WaitForChild("Background")
local alltimeBg = alltimeBoard:WaitForChild("LeaderboardGui"):WaitForChild("Background")

local function getRows(bg)
    local rows = {}
    for i = 1, MAX_ROWS do rows[i] = bg:FindFirstChild("Row" .. i) end
    return rows
end

local sessionRows = getRows(sessionBg)
local alltimeRows = getRows(alltimeBg)

-- FEAT-7: Create YouRow on each board (clone Row6, gold tint, initially hidden)
local YOU_COLOR = Color3.fromRGB(255, 210, 60)
local function makeYouRow(bg)
    local existing = bg:FindFirstChild("YouRow")
    if existing then return existing end
    local template = bg:FindFirstChild("Row6")
    if not template then return nil end
    local row = template:Clone()
    row.Name = "YouRow"
    row.Position = UDim2.new(0, 8, 0, 444)  -- 8px below Row6 (380+48+8 = 436 → 444 with gap)
    row.BackgroundColor3 = YOU_COLOR
    row.BackgroundTransparency = 0.15
    -- Tint the inner frame too
    local inner = row:FindFirstChild("Frame")
    if inner then inner.BackgroundColor3 = YOU_COLOR; inner.BackgroundTransparency = 0.3 end
    row.Visible = false
    row.Parent = bg
    return row
end

local sessionYouRow = makeYouRow(sessionBg)
local alltimeYouRow = makeYouRow(alltimeBg)

local function fillRow(row, entry, isYou)
    if not row then return end
    local rankL  = row:FindFirstChild("Rank")
    local nameL  = row:FindFirstChild("Name")
    local cookL  = row:FindFirstChild("Cookies")
    local orderL = row:FindFirstChild("Orders")
    local coinL  = row:FindFirstChild("Coins")
    if entry then
        if rankL  then rankL.Text  = "#" .. entry.rank end
        if nameL  then nameL.Text  = isYou and "You" or entry.name end
        if cookL  then cookL.Text  = tostring(entry.cookies or 0) end
        if orderL then orderL.Text = tostring(entry.orders  or 0) end
        if coinL  then coinL.Text  = tostring(entry.coins   or 0) end
    else
        if rankL  then rankL.Text  = "" end
        if nameL  then nameL.Text  = "--" end
        if cookL  then cookL.Text  = "" end
        if orderL then orderL.Text = "" end
        if coinL  then coinL.Text  = "" end
    end
end

local function fillBoard(rows, entries, youRow, selfEntry)
    for i = 1, MAX_ROWS do
        local row   = rows[i]
        local entry = entries and entries[i]
        if not row then break end
        local isLocalPlayer = entry and entry.name == LOCAL_PLAYER.Name
        local rankL   = row:FindFirstChild("Rank")
        local nameL   = row:FindFirstChild("Name")
        local cookL   = row:FindFirstChild("Cookies")
        local orderL  = row:FindFirstChild("Orders")
        local coinL   = row:FindFirstChild("Coins")
        -- Highlight local player row gold if in top 6
        if isLocalPlayer then
            row.BackgroundColor3 = YOU_COLOR
            row.BackgroundTransparency = 0.15
        else
            row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            row.BackgroundTransparency = 0.3
        end
        if entry then
            if rankL  then rankL.Text  = "#" .. entry.rank end
            if nameL  then nameL.Text  = isLocalPlayer and "You" or entry.name end
            if cookL  then cookL.Text  = tostring(entry.cookies or 0) end
            if orderL then orderL.Text = tostring(entry.orders  or 0) end
            if coinL  then coinL.Text  = tostring(entry.coins   or 0) end
        else
            if rankL  then rankL.Text  = tostring(i) end
            if nameL  then nameL.Text  = "—" end
            if cookL  then cookL.Text  = "" end
            if orderL then orderL.Text = "" end
            if coinL  then coinL.Text  = "" end
        end
    end
    -- YouRow: show only if player is outside top 6
    if youRow then
        if selfEntry then
            youRow.Visible = true
            fillRow(youRow, selfEntry, true)
        else
            youRow.Visible = false
        end
    end
end

leaderboardUpdate.OnClientEvent:Connect(function(payload)
    fillBoard(sessionRows, payload and payload.session, sessionYouRow, payload and payload.selfSession)
    fillBoard(alltimeRows,  payload and payload.alltime,  alltimeYouRow, payload and payload.selfAlltime)
end)

fillBoard(sessionRows, nil, sessionYouRow, nil)
fillBoard(alltimeRows,  nil, alltimeYouRow, nil)
print("[LeaderboardClient] Ready (FEAT-7: self-rank enabled)")
