local NPCSpawner = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("NPCSpawner"))
local workspace = game:GetService("Workspace")

local MAX_CUSTOMERS    = 5
local SPAWN_INTERVAL   = 4

-- Track ambient slots explicitly so we never double-fill them
local ambientSlots = {
    Show  = false, -- false = free, true = occupied
    Show2 = false,
}

local function getNextRigName()
    local used = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name:sub(1, 3) == "Rig" then
            used[obj.Name] = true
        end
    end
    for i = 1, 100 do
        local name = "Rig" .. i
        if not used[name] then return name end
    end
    return "Rig"
end

local function countNPCsByType(npcType)
    local count = 0
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name:sub(1, 3) == "Rig" then
            local mov = obj:FindFirstChild("WorkingAdvancedMovement")
            if mov and mov:GetAttribute("NPCType") == npcType then
                count += 1
            end
        end
    end
    return count
end

local function spawnAmbient(slotName)
    ambientSlots[slotName] = true

    local rig = NPCSpawner.SpawnRig()
    if not rig then ambientSlots[slotName] = false return end
    rig.Name = getNextRigName()

    local mov = rig:FindFirstChild("WorkingAdvancedMovement")
    if mov then
        mov:SetAttribute("NPCType", "ambient")
        mov:SetAttribute("AmbientSlot", slotName)
    end

    -- When this NPC is destroyed, free the slot
    rig.AncestryChanged:Connect(function()
        if not rig:IsDescendantOf(workspace) then
            ambientSlots[slotName] = false
        end
    end)
end

local function spawnCustomer()
    local rig = NPCSpawner.SpawnRig()
    if not rig then return end
    rig.Name = getNextRigName()

    local mov = rig:FindFirstChild("WorkingAdvancedMovement")
    if mov then
        mov:SetAttribute("NPCType", "customer")
    end
end

-- Main loop
while true do
    -- Fill ambient slots
    for slotName, occupied in pairs(ambientSlots) do
        if not occupied then
            spawnAmbient(slotName)
            task.wait(1) -- slight stagger so they don't spawn on top of each other
        end
    end

    -- Fill customer queue
    if countNPCsByType("customer") < MAX_CUSTOMERS then
        spawnCustomer()
    end

    task.wait(SPAWN_INTERVAL)
end
