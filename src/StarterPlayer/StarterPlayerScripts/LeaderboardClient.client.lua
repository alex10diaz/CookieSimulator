-- LeaderboardClient
-- Listens for LeaderboardUpdate and refreshes the in-world SurfaceGui board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local leaderboardUpdate = RemoteManager.Get("LeaderboardUpdate")

local MAX_ROWS = 6

-- ── WAIT FOR BOARD ─────────────────────────────────────────────
local board = Workspace:WaitForChild("LeaderboardBoard", 60)
if not board then
    warn("[LeaderboardClient] LeaderboardBoard not found in Workspace")
    return
end
local gui = board:WaitForChild("LeaderboardGui", 10)
if not gui then
    warn("[LeaderboardClient] LeaderboardGui not found on LeaderboardBoard")
    return
end

-- ── ROW REFERENCES ────────────────────────────────────────────
local rows = {}
for i = 1, MAX_ROWS do
    rows[i] = gui:FindFirstChild("Row" .. i)
end

local emptyRow = "—"

local function clearRows()
    for i = 1, MAX_ROWS do
        local row = rows[i]
        if row then
            local rankL = row:FindFirstChild("Rank")
            local nameL = row:FindFirstChild("Name")
            local cookL = row:FindFirstChild("Cookies")
            if rankL then rankL.Text = tostring(i) end
            if nameL then nameL.Text = emptyRow end
            if cookL then cookL.Text = "" end
        end
    end
end

-- ── UPDATE HANDLER ─────────────────────────────────────────────
leaderboardUpdate.OnClientEvent:Connect(function(entries)
    -- Clear all rows first
    clearRows()
    if not entries then return end
    for i, entry in ipairs(entries) do
        local row = rows[i]
        if not row then break end
        local rankL = row:FindFirstChild("Rank")
        local nameL = row:FindFirstChild("Name")
        local cookL = row:FindFirstChild("Cookies")
        if rankL then rankL.Text = "#" .. entry.rank end
        if nameL then nameL.Text = entry.name end
        if cookL then cookL.Text = tostring(entry.cookies) .. " 🍪" end
    end
end)

clearRows()
print("[LeaderboardClient] Ready")
