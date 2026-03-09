-- MenuManager (ModuleScript, ServerScriptService/Core)
-- Shared state for the active cookie menu.
-- Required by MenuServer (wiring), PersistentNPCSpawner, and MinigameServer.

local ALL_COOKIES = {
    "pink_sugar",
    "chocolate_chip",
    "birthday_cake",
    "cookies_and_cream",
    "snickerdoodle",
    "lemon_blackraspberry",
}

local activeMenu = { table.unpack(ALL_COOKIES) }  -- default: all 6
local menuLocked = false

local MenuManager = {}

function MenuManager.GetAllCookies()
    return ALL_COOKIES
end

function MenuManager.GetActiveMenu()
    return activeMenu
end

function MenuManager.SetMenu(cookieIds)
    if menuLocked then
        return false, "Menu is locked while the store is open"
    end
    if type(cookieIds) ~= "table" or #cookieIds < 1 then
        return false, "Select at least 1 cookie"
    end
    -- Validate all IDs against the known cookie list
    for _, id in ipairs(cookieIds) do
        local found = false
        for _, valid in ipairs(ALL_COOKIES) do
            if id == valid then found = true; break end
        end
        if not found then
            return false, "Invalid cookie: " .. tostring(id)
        end
    end
    activeMenu = { table.unpack(cookieIds) }
    return true, activeMenu
end

function MenuManager.LockMenu()
    menuLocked = true
end

function MenuManager.UnlockMenu()
    menuLocked = false
    activeMenu = { table.unpack(ALL_COOKIES) }  -- reset to all cookies for new session
end

function MenuManager.IsLocked()
    return menuLocked
end

return MenuManager
