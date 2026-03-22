-- LeaderboardClient
-- Both boards: Rank | Name | Cookies | Orders | Coins
-- SessionBoard: stats this round
-- AllTimeBoard: lifetime stats

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local leaderboardUpdate = RemoteManager.Get("LeaderboardUpdate")

local MAX_ROWS = 6

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

local function fillBoard(rows, entries)
    for i = 1, MAX_ROWS do
        local row   = rows[i]
        local entry = entries and entries[i]
        if not row then break end
        local rankL   = row:FindFirstChild("Rank")
        local nameL   = row:FindFirstChild("Name")
        local cookL   = row:FindFirstChild("Cookies")
        local orderL  = row:FindFirstChild("Orders")
        local coinL   = row:FindFirstChild("Coins")
        if entry then
            if rankL  then rankL.Text  = "#" .. entry.rank end
            if nameL  then nameL.Text  = entry.name end
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
end

leaderboardUpdate.OnClientEvent:Connect(function(payload)
    fillBoard(sessionRows, payload and payload.session)
    fillBoard(alltimeRows,  payload and payload.alltime)
end)

fillBoard(sessionRows, nil)
fillBoard(alltimeRows,  nil)
print("[LeaderboardClient] Ready")
