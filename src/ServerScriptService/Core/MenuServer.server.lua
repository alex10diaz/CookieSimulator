-- MenuServer (Script, ServerScriptService/Core)
-- Handles menu remote events and wires GameState → PreOpen/Open transitions to MenuManager.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager       = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local MenuManager         = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MenuManager"))
local CookieData          = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local CookieUnlockManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("CookieUnlockManager"))
local StationRemapService = require(ServerScriptService:WaitForChild("Core"):WaitForChild("StationRemapService"))
local PlayerDataManager   = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local openMenuBoardRemote     = RemoteManager.Get("OpenMenuBoard")
local setMenuRemote           = RemoteManager.Get("SetMenuSelection")
local menuResultRemote        = RemoteManager.Get("MenuSelectionResult")
local menuLockedRemote        = RemoteManager.Get("MenuLocked")
local purchaseCookieRemote    = RemoteManager.Get("PurchaseCookie")
local purchaseCookieResultRemote = RemoteManager.Get("PurchaseCookieResult")

local MAX_MENU_SIZE  = 6
local _remapToken    = 0  -- P1-3: debounce PreOpen remaps so only the latest fires

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
    local allCookies = buildCookiePayload()
    local activeMenu = MenuManager.GetActiveMenu()

    local function fireOne(p)
        local ownedCookies = CookieUnlockManager.GetOwned(p)
        openMenuBoardRemote:FireClient(p, {
            allCookies   = allCookies,
            activeMenu   = activeMenu,
            ownedCookies = ownedCookies,
        })
    end

    if targetPlayer then
        fireOne(targetPlayer)
    else
        for _, p in ipairs(Players:GetPlayers()) do
            fireOne(p)
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
        -- Remap warmers/fridges to the confirmed active menu
        StationRemapService.RemapStations(MenuManager.GetActiveMenu())
    end
end)

-- ── PLAYER JOINS ────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    -- Grant starter cookies (idempotent — safe to call every join)
    -- Wait for PlayerDataManager profile to load before granting/reading ownership
    task.spawn(function()
        local deadline = tick() + 10
        while not PlayerDataManager.GetData(player) and tick() < deadline do
            task.wait(0.1)
        end
        CookieUnlockManager.GrantStarters(player)
        local state = workspace:GetAttribute("GameState")
        if state == "PreOpen" then
            sendOpenMenuBoard(player)
        end
    end)
end)

-- ── REMOTE: SetMenuSelection ────────────────────────────────────
setMenuRemote.OnServerEvent:Connect(function(player, cookieIds)
    if type(cookieIds) ~= "table" then
        menuResultRemote:FireClient(player, false, "Invalid selection")
        return
    end
    if #cookieIds < 1 or #cookieIds > MAX_MENU_SIZE then
        menuResultRemote:FireClient(player, false, "Select 1–" .. MAX_MENU_SIZE .. " cookies")
        return
    end
    -- Validate all IDs exist in the full catalog
    local allCookies = MenuManager.GetAllCookies()
    for _, id in ipairs(cookieIds) do
        local found = false
        for _, valid in ipairs(allCookies) do
            if id == valid then found = true; break end
        end
        if not found then
            menuResultRemote:FireClient(player, false, "Invalid cookie: " .. tostring(id))
            return
        end
    end
    -- Validate all selected cookies are owned by this player
    for _, id in ipairs(cookieIds) do
        if not CookieUnlockManager.IsOwned(player, id) then
            menuResultRemote:FireClient(player, false, "Cookie not owned: " .. tostring(id))
            return
        end
    end

    local ok, result = MenuManager.SetMenu(cookieIds)
    if ok then
        local updatedMenu = MenuManager.GetActiveMenu()
        for _, p in ipairs(Players:GetPlayers()) do
            menuResultRemote:FireClient(p, true, "Menu updated!", updatedMenu)
        end
        print("[MenuServer]", player.Name, "set menu to:", table.concat(updatedMenu, ", "))
        -- P1-3: debounced remap — cancel any pending remap from a prior selection,
        -- read live GetActiveMenu() at fire-time, skip if Open already locked+remapped.
        _remapToken += 1
        local token = _remapToken
        task.defer(function()
            if _remapToken ~= token then return end          -- superseded by a later SetMenu
            if MenuManager.IsLocked() then return end        -- Open transition already remapped
            StationRemapService.RemapStations(MenuManager.GetActiveMenu())
        end)
    else
        menuResultRemote:FireClient(player, false, result)
    end
end)

-- ── REMOTE: PurchaseCookie ──────────────────────────────────────
purchaseCookieRemote.OnServerEvent:Connect(function(player, cookieId)
    if type(cookieId) ~= "string" then
        purchaseCookieResultRemote:FireClient(player, false, "Invalid cookie", cookieId)
        return
    end
    local ok, result = CookieUnlockManager.PurchaseCookie(player, cookieId)
    if ok then
        local newCoins = result
        purchaseCookieResultRemote:FireClient(player, true, newCoins, cookieId)
        print("[MenuServer]", player.Name, "unlocked cookie:", cookieId, "| coins left:", newCoins)
    else
        purchaseCookieResultRemote:FireClient(player, false, result, cookieId)
    end
end)

print("[MenuServer] Ready.")
