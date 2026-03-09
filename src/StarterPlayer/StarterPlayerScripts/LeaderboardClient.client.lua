-- LeaderboardClient
-- Refreshes two physical SurfaceGui leaderboard boards:
--   SessionBoard  (-25, 8, -157): cookies + orders THIS round
--   AllTimeBoard  (+25, 8, -157): cookies + coins ALL TIME

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local leaderboardUpdate = RemoteManager.Get("LeaderboardUpdate")

local MAX_ROWS = 6

-- ── WAIT FOR BOARDS ───────────────────────────────────────────
local sessionBoard  = Workspace:WaitForChild("SessionBoard",  60)
local alltimeBoard  = Workspace:WaitForChild("AllTimeBoard",  60)

if not sessionBoard then warn("[LeaderboardClient] SessionBoard missing"); return end
if not alltimeBoard then warn("[LeaderboardClient] AllTimeBoard missing"); return end

local sessionGui = sessionBoard:WaitForChild("LeaderboardGui", 10)
local alltimeGui = alltimeBoard:WaitForChild("LeaderboardGui", 10)

if not sessionGui then warn("[LeaderboardClient] SessionBoard gui missing"); return end
if not alltimeGui then warn("[LeaderboardClient] AllTimeBoard gui missing"); return end

-- ── ROW HELPERS ───────────────────────────────────────────────
local function getRows(gui)
    local bg   = gui:FindFirstChild("Background")
    local rows = {}
    if bg then
        for i = 1, MAX_ROWS do
            rows[i] = bg:FindFirstChild("Row" .. i)
        end
    end
    return rows
end

local sessionRows = getRows(sessionGui)
local alltimeRows = getRows(alltimeGui)

local function clearBoard(rows, col3Name, col4Name)
    for i = 1, MAX_ROWS do
        local row = rows[i]
        if row then
            local rankL = row:FindFirstChild("Rank")
            local nameL = row:FindFirstChild("Name")
            local col3  = row:FindFirstChild(col3Name)
            local col4  = row:FindFirstChild(col4Name)
            if rankL then rankL.Text = tostring(i) end
            if nameL then nameL.Text = "—" end
            if col3  then col3.Text  = "" end
            if col4  then col4.Text  = "" end
        end
    end
end

local function fillBoard(rows, entries, col3Key, col3Label, col4Key, col4Label, col3Name, col4Name)
    for i = 1, MAX_ROWS do
        local row   = rows[i]
        local entry = entries and entries[i]
        if not row then break end

        local rankL = row:FindFirstChild("Rank")
        local nameL = row:FindFirstChild("Name")
        local col3  = row:FindFirstChild(col3Name)
        local col4  = row:FindFirstChild(col4Name)

        if entry then
            if rankL then rankL.Text = "#" .. entry.rank end
            if nameL then nameL.Text = entry.name end
            if col3  then col3.Text  = tostring(entry[col3Key] or 0) .. " " .. col3Label end
            if col4  then col4.Text  = tostring(entry[col4Key] or 0) .. " " .. col4Label end
        else
            if rankL then rankL.Text = tostring(i) end
            if nameL then nameL.Text = "—" end
            if col3  then col3.Text  = "" end
            if col4  then col4.Text  = "" end
        end
    end
end

-- ── UPDATE HANDLER ────────────────────────────────────────────
leaderboardUpdate.OnClientEvent:Connect(function(payload)
    local session = payload and payload.session or {}
    local alltime = payload and payload.alltime or {}

    -- Session board: Rank | Name | Cookies | Orders
    clearBoard(sessionRows, "Cookies", "Orders")
    fillBoard(sessionRows, session, "cookies", "🍪", "orders", "📦", "Cookies", "Orders")

    -- All-time board: Rank | Name | Cookies | Coins
    clearBoard(alltimeRows, "Cookies", "Coins")
    fillBoard(alltimeRows, alltime, "cookies", "🍪", "coins", "💰", "Cookies", "Coins")
end)

-- Initial clear
clearBoard(sessionRows, "Cookies", "Orders")
clearBoard(alltimeRows,  "Cookies", "Coins")

print("[LeaderboardClient] Ready — session + all-time boards")
