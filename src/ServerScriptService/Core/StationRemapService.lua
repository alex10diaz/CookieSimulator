-- StationRemapService (ModuleScript, ServerScriptService/Core)
-- Remaps the 6 physical warmer and fridge models to match the active menu.
-- Call RemapStations(orderedMenuIds) once per shift at Open start.
-- orderedMenuIds: array of up to 6 cookieId strings, in slot order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local CookieData    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

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

function StationRemapService.RemapStations(orderedMenuIds)
    if not orderedMenuIds or #orderedMenuIds == 0 then
        warn("[StationRemapService] No menu ids provided — skipping remap")
        return
    end

    local warmers = getSortedWarmers()
    local fridges = getSortedFridges()
    local slotMap = {}  -- slot index -> cookieId (for remote broadcast)

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
                    -- TextLabel is nested: WarmersDisplay > Frame > TextLabel
                    local lbl = sg:FindFirstChild("TextLabel", true)
                    if lbl then lbl.Text = cookie.name end
                end
                -- Accent color from cookie's dough color (already a Color3)
                doorPanel.Color = cookie.doughColor
            end

            -- Update WarmerNameGui BillboardGui on Shell part
            local shell = model:FindFirstChild("Shell")
            if shell then
                local nameBB = shell:FindFirstChild("WarmerNameGui")
                if nameBB then
                    local nameLbl = nameBB:FindFirstChild("NameLabel", true)
                    if nameLbl then nameLbl.Text = cookie.name end
                end
            end
        end

        -- ── Remap fridge ─────────────────────────────────────────
        local fridgeEntry = fridges[slotIndex]
        if fridgeEntry then
            local model = fridgeEntry.model
            model:SetAttribute("FridgeId", cookie.fridgeId)

            local display = model:FindFirstChild("FridgeDisplay", true)
            if display then
                -- Label may be named "CookieName" or plain "TextLabel"
                local nameLbl = display:FindFirstChild("CookieName", true)
                    or display:FindFirstChild("TextLabel", true)
                if nameLbl then nameLbl.Text = cookie.name end
            end
        end
    end

    -- Broadcast to all clients
    stationRemappedRemote:FireAllClients(slotMap)
    print("[StationRemapService] Remapped", #orderedMenuIds, "stations")
end

return StationRemapService
