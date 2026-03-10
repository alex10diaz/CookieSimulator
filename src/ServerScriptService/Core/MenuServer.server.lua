-- MenuServer (Script, ServerScriptService/Core)
-- Handles menu remote events and wires GameState → PreOpen/Open transitions to MenuManager.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local MenuManager   = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MenuManager"))
local CookieData    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))

local openMenuBoardRemote = RemoteManager.Get("OpenMenuBoard")
local setMenuRemote       = RemoteManager.Get("SetMenuSelection")
local menuResultRemote    = RemoteManager.Get("MenuSelectionResult")
local menuLockedRemote    = RemoteManager.Get("MenuLocked")

local function buildCookiePayload()
    local result = {}
    for _, id in ipairs(MenuManager.GetAllCookies()) do
        local cookie = CookieData.GetById(id)
        if cookie then
            table.insert(result, { id = id, label = cookie.name, price = cookie.price })
        end
    end
    return result
end

local function sendOpenMenuBoard(targetPlayer)
    local payload = {
        allCookies = buildCookiePayload(),
        activeMenu = MenuManager.GetActiveMenu(),
    }
    if targetPlayer then
        openMenuBoardRemote:FireClient(targetPlayer, payload)
    else
        for _, p in ipairs(Players:GetPlayers()) do
            openMenuBoardRemote:FireClient(p, payload)
        end
    end
end

local function sendMenuLocked()
    local finalMenu = MenuManager.GetActiveMenu()
    for _, p in ipairs(Players:GetPlayers()) do
        menuLockedRemote:FireClient(p, finalMenu)
    end
end

-- ── GAME STATE LISTENER ────────────────────────────────────────
workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    local state = workspace:GetAttribute("GameState")
    if state == "PreOpen" then
        MenuManager.UnlockMenu()
        task.defer(sendOpenMenuBoard)  -- slight defer so clients have time to load
    elseif state == "Open" then
        MenuManager.LockMenu()
        sendMenuLocked()
    end
end)

-- ── PLAYER JOINS DURING PreOpen ────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    local state = workspace:GetAttribute("GameState")
    if state == "PreOpen" then
        task.defer(function()
            sendOpenMenuBoard(player)
        end)
    end
end)

-- ── REMOTE: SetMenuSelection ───────────────────────────────────
setMenuRemote.OnServerEvent:Connect(function(player, cookieIds)
    -- Type guard
    if type(cookieIds) ~= "table" then
        menuResultRemote:FireClient(player, false, "Invalid selection")
        return
    end
    -- Size guard (prevent exploits)
    local maxCookies = #MenuManager.GetAllCookies()
    if #cookieIds < 1 or #cookieIds > maxCookies then
        menuResultRemote:FireClient(player, false, "Invalid selection size")
        return
    end

    local ok, result = MenuManager.SetMenu(cookieIds)
    if ok then
        local updatedMenu = MenuManager.GetActiveMenu()
        -- Broadcast the updated menu to ALL players so their UIs sync
        for _, p in ipairs(Players:GetPlayers()) do
            menuResultRemote:FireClient(p, true, "Menu updated!", updatedMenu)
        end
        print("[MenuServer]", player.Name, "set menu to:", table.concat(updatedMenu, ", "))
    else
        menuResultRemote:FireClient(player, false, result)
    end
end)

print("[MenuServer] Ready.")
