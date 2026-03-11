-- StarterPlayerScripts/LobbyTVClient (LocalScript)
-- Updates the lobby "TODAY'S MENU" TV whenever the station remap fires.
-- Shows placeholder dashes during PreOpen/Intermission, cookie names during Open.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local CookieData    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))

local stationRemapped = RemoteManager.Get("StationRemapped")

-- ── FIND TV ────────────────────────────────────────────────────────────────────
local tv = Workspace:WaitForChild("LobbyTV", 30)
if not tv then warn("[LobbyTV] LobbyTV part not found"); return end
local sg    = tv:WaitForChild("MenuDisplay")
local bg    = sg:WaitForChild("Frame")

local slots = {}
for i = 1, 6 do
    local row = bg:FindFirstChild("Slot" .. i)
    slots[i]  = row and row:FindFirstChild("CookieName")
end

-- ── UPDATE FUNCTIONS ───────────────────────────────────────────────────────────
local function showMenu(slotMap)
    for i = 1, 6 do
        if slots[i] then
            local cookieId = slotMap and slotMap[i]
            if cookieId then
                local ck = CookieData.GetById(cookieId)
                slots[i].Text      = ck and ck.name or cookieId
                slots[i].TextColor3 = Color3.fromRGB(255, 230, 150)
            else
                slots[i].Text      = "—"
                slots[i].TextColor3 = Color3.fromRGB(180, 180, 200)
            end
        end
    end
end

local function resetToPlaceholder()
    for i = 1, 6 do
        if slots[i] then
            slots[i].Text       = "—"
            slots[i].TextColor3 = Color3.fromRGB(180, 180, 200)
        end
    end
end

-- ── REMOTES ────────────────────────────────────────────────────────────────────
stationRemapped.OnClientEvent:Connect(function(slotMap)
    showMenu(slotMap)
end)

-- Reset to placeholders when phase goes back to PreOpen or Intermission
Workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    local state = Workspace:GetAttribute("GameState") or "Lobby"
    if state == "PreOpen" or state == "Intermission" or state == "Lobby" then
        resetToPlaceholder()
    end
end)
