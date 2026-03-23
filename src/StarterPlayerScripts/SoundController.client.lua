-- SoundController.client.lua
-- All client-side sounds: UI clicks, station sounds, delivery, level-up, ambient.
-- Swap rbxassetid values in the IDS table to change any sound.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local IDS = {
	MIXER_LOOP    = "rbxassetid://9125678301",
	OVEN_DING     = "rbxassetid://127688458104225",
	OVEN_OPEN     = "rbxassetid://134785860029004",
	DOUGH_THUD    = "rbxassetid://138357469605324",
	DOUGH_DONE    = "rbxassetid://96441802692039",
	FROST_SQUIRT  = "rbxassetid://9119512290",
    FROST_DONE    = "rbxassetid://4590662766",
	CASH_REG      = "rbxassetid://139806997485371",
	DELIVERY_FAIL = "rbxassetid://124571230236752",
	COINS_JINGLE  = "rbxassetid://106322755125894",
	NPC_BELL      = "rbxassetid://135435498618469",
	FRIDGE_CLICK  = "rbxassetid://73830484780236",
	BOX_PICKUP    = "rbxassetid://85613175570810",
	UI_CLICK      = "rbxassetid://133196982070163",
	ORDER_BELL    = "rbxassetid://139488704715914",
	LEVEL_UP      = "rbxassetid://122536582003999",
	MASTERY_UP    = "rbxassetid://108161825312558",
	MUSIC         = "rbxassetid://140699797365730",
}

local function makeSound(id, volume, looped)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume  = volume or 0.6
    s.Looped  = looped or false
    s.Parent  = SoundService
    return s
end

local sounds = {
    mixerLoop   = makeSound(IDS.MIXER_LOOP,    0.45, true),
    ovenDing    = makeSound(IDS.OVEN_DING,     0.7,  false),
    ovenOpen    = makeSound(IDS.OVEN_OPEN,     0.5,  false),
    doughThud   = makeSound(IDS.DOUGH_THUD,    0.55, false),
    doughDone   = makeSound(IDS.DOUGH_DONE,    0.5,  false),
    frostSqrt   = makeSound(IDS.FROST_SQUIRT,  0.5,  false),
    frostDone   = makeSound(IDS.FROST_DONE,    0.5,  false),
    cashReg     = makeSound(IDS.CASH_REG,      0.8,  false),
    delivFail   = makeSound(IDS.DELIVERY_FAIL, 0.6,  false),
    coinsJingle = makeSound(IDS.COINS_JINGLE,  0.5,  false),
    npcBell     = makeSound(IDS.NPC_BELL,      0.35, false),
    fridgeClick = makeSound(IDS.FRIDGE_CLICK,  0.5,  false),
    boxPickup   = makeSound(IDS.BOX_PICKUP,    0.55, false),
    uiClick     = makeSound(IDS.UI_CLICK,      0.4,  false),
    orderBell   = makeSound(IDS.ORDER_BELL,    0.65, false),
    levelUp     = makeSound(IDS.LEVEL_UP,      0.85, false),
    masteryUp   = makeSound(IDS.MASTERY_UP,    0.55, false),
    music       = makeSound(IDS.MUSIC,         0.10, true),
}

sounds.music.Name = "BakeryMusic"
sounds.music:Play()

-- Global UI click
local function hookButton(btn)
    if not btn:IsA("TextButton") then return end
    btn.MouseButton1Click:Connect(function()
        if sounds.uiClick.IsLoaded then sounds.uiClick:Play() end
    end)
end
local function hookGui(gui)
    for _, desc in ipairs(gui:GetDescendants()) do hookButton(desc) end
    gui.DescendantAdded:Connect(hookButton)
end
for _, gui in ipairs(playerGui:GetChildren()) do hookGui(gui) end
playerGui.ChildAdded:Connect(function(child) task.defer(function() hookGui(child) end) end)

-- Mix loop
local mixStart = RemoteManager.Get("StartMixMinigame")
mixStart.OnClientEvent:Connect(function()
    if not sounds.mixerLoop.IsPlaying then sounds.mixerLoop:Play() end
    task.delay(15, function()
        if sounds.mixerLoop.IsPlaying then sounds.mixerLoop:Stop() end
    end)
end)
local ok, mixEnd = pcall(function() return RemoteManager.Get("MinigameEnded") end)
if ok and mixEnd then
    mixEnd.OnClientEvent:Connect(function()
        if sounds.mixerLoop.IsPlaying then sounds.mixerLoop:Stop() end
    end)
end

-- Oven
RemoteManager.Get("StartOvenMinigame").OnClientEvent:Connect(function() sounds.ovenOpen:Play() end)
RemoteManager.Get("OvenMinigameResult").OnClientEvent:Connect(function() sounds.ovenDing:Play() end)

-- Dough
RemoteManager.Get("StartDoughMinigame").OnClientEvent:Connect(function() sounds.doughThud:Play() end)
RemoteManager.Get("DoughMinigameResult").OnClientEvent:Connect(function() sounds.doughDone:Play() end)

-- Frost
RemoteManager.Get("StartFrostMinigame").OnClientEvent:Connect(function() sounds.frostSqrt:Play() end)
RemoteManager.Get("FrostMinigameResult").OnClientEvent:Connect(function() sounds.frostDone:Play() end)

-- Delivery
RemoteManager.Get("DeliveryResult").OnClientEvent:Connect(function(stars)
    if stars and stars >= 1 then
        sounds.cashReg:Play()
        sounds.coinsJingle:Play()
    else
        sounds.delivFail:Play()
    end
end)

-- Order accepted bell
local okO, orderAcc = pcall(function() return RemoteManager.Get("OrderAccepted") end)
if okO and orderAcc then
    orderAcc.OnClientEvent:Connect(function() sounds.orderBell:Play() end)
end

-- NPC arrival bell
RemoteManager.Get("StartOrderCutscene").OnClientEvent:Connect(function() sounds.npcBell:Play() end)

-- Fridge open + box pickup
local PPS = game:GetService("ProximityPromptService")
PPS.PromptTriggered:Connect(function(prompt)
    if prompt.Name == "FridgePrompt" then
        sounds.fridgeClick:Play()
    elseif prompt.Name == "WarmerPickupPrompt" then
        sounds.boxPickup:Play()
    end
end)

-- Level-up
RemoteManager.Get("BakeryLevelUp").OnClientEvent:Connect(function() sounds.levelUp:Play() end)
RemoteManager.Get("MasteryLevelUp").OnClientEvent:Connect(function() sounds.masteryUp:Play() end)

print("[SoundController] Ready — 18 sounds loaded.")

--[[
HOW TO REPLACE A SOUND
1. Find a free sound: creator.roblox.com → Marketplace → Audio → Free
2. Copy the number from the URL: roblox.com/library/131070686 → 131070686
3. In the IDS table at the top, change just the number for that key
4. Push via MCP run_code

VOLUME GUIDE (0=silent, 1=full)
  MUSIC:          0.25-0.35  (background, barely noticeable)
  UI sounds:      0.3-0.5    (subtle)
  Station sounds: 0.5-0.7    (present)
  Delivery/LvlUp: 0.7-0.9   (reward moment)

SOUND MAP
  MUSIC         → ambient bakery loop (always on)
  MIXER_LOOP    → mix station running (loop, auto-stops)
  OVEN_OPEN     → oven minigame starts
  OVEN_DING     → oven minigame complete
  DOUGH_THUD    → dough minigame starts
  DOUGH_DONE    → dough minigame complete
  FROST_SQUIRT  → frost minigame starts
  FROST_DONE    → frost minigame complete
  CASH_REG      → successful delivery (with COINS_JINGLE)
  COINS_JINGLE  → coins reward on delivery
  DELIVERY_FAIL → 0-star/failed delivery
  NPC_BELL      → customer arrives (NPCOrderReady)
  FRIDGE_CLICK  → fridge door opened
  BOX_PICKUP    → box picked up from warmer
  UI_CLICK      → any button pressed
  ORDER_BELL    → player accepts NPC order
  LEVEL_UP      → bakery level up
  MASTERY_UP    → station mastery level up
--]]
