-- StationRemapService (ModuleScript, ServerScriptService/Core)
-- Remaps the 6 physical warmer and fridge models to match the active menu.
-- Call RemapStations(orderedMenuIds) once per shift at Open start.
-- orderedMenuIds: array of up to 6 cookieId strings, in slot order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local CookieData    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager  = require(ServerScriptService:WaitForChild("Core"):WaitForChild("OrderManager"))

local stationRemappedRemote = RemoteManager.Get("StationRemapped")

local StationRemapService = {}

-- Sort warmer models by WarmerId attribute (1-6)
local function getSortedWarmers()
    local folder = Workspace:FindFirstChild("Warmers")
    if not folder then return {} end
    local list = {}
    for _, model in ipairs(folder:GetChildren()) do
        local id = model:GetAttribute("WarmerId")
        if id then table.insert(list, { model = model, slot = id }) end
    end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    return list
end

-- Sort fridge models by current FridgeId alphabetically for stable ordering
local function getSortedFridges()
    local folder = Workspace:FindFirstChild("Fridges")
    if not folder then return {} end
    local list = {}
    for _, model in ipairs(folder:GetChildren()) do
        local fridgeId = model:GetAttribute("FridgeId")
        if fridgeId and fridgeId ~= "" then
            table.insert(list, { model = model, fridgeId = fridgeId })
        end
    end
    table.sort(list, function(a, b) return a.fridgeId < b.fridgeId end)
    return list
end

-- Disable all prompts and hide UI on a warmer model (unused slot)
local function hideWarmerSlot(model)
    model:SetAttribute("CookieId", "")
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            desc.Enabled = false
        elseif desc:IsA("BillboardGui") then
            desc.Enabled = false
        elseif desc:IsA("SurfaceGui") then
            desc.Enabled = false
        end
    end
    local doorPanel = model:FindFirstChild("DoorPanel")
    if doorPanel then
        local sg = doorPanel:FindFirstChild("WarmersDisplay")
        if sg then
            local lbl = sg:FindFirstChild("TextLabel", true)
            if lbl then lbl.Text = "" end
        end
        doorPanel.Color = Color3.fromRGB(90, 90, 90)
    end
end

-- Re-enable prompts and UI for an active warmer slot
local function showWarmerSlot(model, cookie)
    -- WarmerPrompt is NEVER used by human players (pipeline fills warmers automatically).
    -- Disable it on all active slots so it never appears.
    local warmerPrompt = model:FindFirstChild("WarmerPrompt", true)
    if warmerPrompt then warmerPrompt.Enabled = false end

    local shell = model:FindFirstChild("Shell")
    if shell then
        for _, desc in ipairs(shell:GetDescendants()) do
            if desc:IsA("BillboardGui") then desc.Enabled = true end
        end
        -- WarmerPickupPrompt: update title; Enabled state managed by setWarmersEnabled per phase
        local wpp = shell:FindFirstChild("WarmerPickupPrompt", true)
        if wpp then
            wpp.ActionText = "Take " .. cookie.name
            -- Leave Enabled as-is here; StaffManager.setWarmersEnabled controls it per phase
        end

        -- WarmerNameGui BillboardGui
        local nameBB = shell:FindFirstChild("WarmerNameGui")
        if nameBB then
            nameBB.Enabled = true
            local nameLbl = nameBB:FindFirstChild("NameLabel", true)
            if nameLbl then nameLbl.Text = cookie.name end
        end
    end
end

function StationRemapService.RemapStations(orderedMenuIds)
    if not orderedMenuIds or #orderedMenuIds == 0 then
        warn("[StationRemapService] No menu ids provided — skipping remap")
        return
    end

    local warmers = getSortedWarmers()
    local fridges = getSortedFridges()
    local slotMap = {}  -- slot index -> cookieId (for remote broadcast)

    -- Snapshot old CookieId per slot BEFORE overwriting (for warmer entry remap)
    local oldCookieIdBySlot = {}
    for _, wEntry in ipairs(warmers) do
        oldCookieIdBySlot[wEntry.slot] = wEntry.model:GetAttribute("CookieId") or ""
    end

    -- Track which fridge IDs are active (for hiding unused fridges)
    local activeFridgeIds = {}

    for slotIndex, cookieId in ipairs(orderedMenuIds) do
        local cookie = CookieData.GetById(cookieId)
        if not cookie then
            warn("[StationRemapService] Unknown cookieId:", cookieId)
            continue
        end

        slotMap[slotIndex] = cookieId

        -- ── Remap warmer ─────────────────────────────────────────
        local warmerEntry = warmers[slotIndex]
        if warmerEntry then
            local model = warmerEntry.model
            model:SetAttribute("CookieId", cookieId)

            -- Update name label inside WarmersDisplay SurfaceGui on DoorPanel
            local doorPanel = model:FindFirstChild("DoorPanel")
            if doorPanel then
                local sg = doorPanel:FindFirstChild("WarmersDisplay")
                if sg then
                    local lbl = sg:FindFirstChild("TextLabel", true)
                    if lbl then lbl.Text = cookie.name end
                end
                doorPanel.Color = cookie.doughColor
            end

            -- Re-enable UI and update prompt titles
            showWarmerSlot(model, cookie)
        end

        -- ── Remap fridge ─────────────────────────────────────────
        local fridgeEntry = fridges[slotIndex]
        if fridgeEntry then
            local model = fridgeEntry.model
            model:SetAttribute("FridgeId", cookie.fridgeId)
            activeFridgeIds[cookie.fridgeId] = true

            local display = model:FindFirstChild("FridgeDisplay", true)
            if display then
                display.Enabled = true  -- BUG-58: show billboard for active fridge
                local nameLbl = display:FindFirstChild("CookieName", true)
                    or display:FindFirstChild("TextLabel", true)
                if nameLbl then nameLbl.Text = cookie.name end
            end

            -- Update proximity prompt action text and re-enable
            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    desc.ActionText = "Pull " .. cookie.name .. " Dough"
                    desc.Enabled    = true
                end
            end
        end

        if cookie.fridgeId then activeFridgeIds[cookie.fridgeId] = true end
    end

    -- ── Hide unused warmer slots ──────────────────────────────────
    for i = #orderedMenuIds + 1, #warmers do
        local wEntry = warmers[i]
        if wEntry then hideWarmerSlot(wEntry.model) end
    end

    -- ── Hide unused fridge slots (any fridge whose FridgeId is not in active menu) ──
    local fridgesFolder = Workspace:FindFirstChild("Fridges")
    if fridgesFolder then
        for _, model in ipairs(fridgesFolder:GetChildren()) do
            local fId = model:GetAttribute("FridgeId") or ""
            if fId ~= "" and not activeFridgeIds[fId] then
                -- Clear and hide
                for _, desc in ipairs(model:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") then desc.Enabled = false end
                end
                local display = model:FindFirstChild("FridgeDisplay", true)
                if display then
                    local lbl = display:FindFirstChild("CookieName", true)
                        or display:FindFirstChild("TextLabel", true)
                    if lbl then lbl.Text = "" end
                end
            end
        end
    end

    -- Sync OrderManager's internal warmer entries to the new CookieIds
    local oldToNew = {}
    for _, wEntry in ipairs(warmers) do
        local oldId = oldCookieIdBySlot[wEntry.slot] or ""
        local newId = wEntry.model:GetAttribute("CookieId") or ""
        if oldId ~= "" and newId ~= "" and oldId ~= newId then
            oldToNew[oldId] = newId
        end
    end
    if next(oldToNew) then
        OrderManager.RemapWarmerCookieIds(oldToNew)
    end

    -- Broadcast to all clients
    stationRemappedRemote:FireAllClients(slotMap)
    print("[StationRemapService] Remapped", #orderedMenuIds, "stations")
end

return StationRemapService
