-- SoundController.client.lua
-- All client-side sounds: UI clicks, station sounds, delivery, level-up.
-- Swap rbxassetid values for preferred free Roblox audio assets.

local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService  = game:GetService("SoundService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Sound IDs ─────────────────────────────────────────────────────────────────
local IDS = {
    -- Station sounds
    MIXER_LOOP    = "rbxassetid://9117709834",  -- machine/motor hum (looped)
    OVEN_DING     = "rbxassetid://4612375233",  -- oven-ready bell
    OVEN_OPEN     = "rbxassetid://5803015743",  -- oven door thud
    DOUGH_THUD    = "rbxassetid://5803015743",  -- dough impact / slap
    DOUGH_DONE    = "rbxassetid://4590662766",  -- dough stage complete chime
    FROST_SQUIRT  = "rbxassetid://6518383320",  -- frosting squirt / swirl
    FROST_DONE    = "rbxassetid://4590662766",  -- frost stage complete chime
    -- Delivery & rewards
    CASH_REG      = "rbxassetid://131070686",   -- cash register ka-ching (delivery success)
    DELIVERY_FAIL = "rbxassetid://2865227271",  -- low buzzer (delivery fail)
    COINS_JINGLE  = "rbxassetid://4590662766",  -- coins reward chime
    -- NPC & interactions
    NPC_BELL      = "rbxassetid://131634004",   -- customer arrives bell
    FRIDGE_CLICK  = "rbxassetid://6026984224",  -- fridge door open
    BOX_PICKUP    = "rbxassetid://5804534642",  -- box pickup thud
    -- UI
    UI_CLICK      = "rbxassetid://608537390",   -- soft UI tap
    ORDER_BELL    = "rbxassetid://131634004",   -- ding (player accepts NPC order)
    LEVEL_UP      = "rbxassetid://3331843335",  -- fanfare (bakery level up)
    MASTERY_UP    = "rbxassetid://4590662766",  -- soft chime (station mastery up)
    -- Ambient
    MUSIC         = "rbxassetid://1843073454",  -- bakery background loop
}

-- ── Build sounds ──────────────────────────────────────────────────────────────
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
    npcBell     = makeSound(IDS.NPC_BELL,      0.7,  false),
    fridgeClick = makeSound(IDS.FRIDGE_CLICK,  0.5,  false),
    boxPickup   = makeSound(IDS.BOX_PICKUP,    0.55, false),
    uiClick     = makeSound(IDS.UI_CLICK,      0.4,  false),
    orderBell   = makeSound(IDS.ORDER_BELL,    0.65, false),
    levelUp     = makeSound(IDS.LEVEL_UP,      0.85, false),
    masteryUp   = makeSound(IDS.MASTERY_UP,    0.55, false),
    music       = makeSound(IDS.MUSIC,         0.28, true),
}

-- Ambient music starts immediately
sounds.music:Play()

-- ── Global UI click listener ──────────────────────────────────────────────────
-- Connects a click sound to any TextButton that appears in PlayerGui
local function hookButton(btn)
    if not btn:IsA("TextButton") then return end
    btn.MouseButton1Click:Connect(function()
        if sounds.uiClick.IsLoaded then
            sounds.uiClick:Play()
        end
    end)
end

local function hookGui(gui)
    for _, desc in ipairs(gui:GetDescendants()) do
        hookButton(desc)
    end
    gui.DescendantAdded:Connect(hookButton)
end

-- Hook all current + future ScreenGuis
for _, gui in ipairs(playerGui:GetChildren()) do hookGui(gui) end
playerGui.ChildAdded:Connect(function(child)
    task.defer(function() hookGui(child) end)
end)

-- ── Station sounds ────────────────────────────────────────────────────────────
local mixStart = RemoteManager.Get("StartMixMinigame")
local mixStop  = RemoteManager.Get("MinigameEnded")   -- server fires when any minigame ends

-- Mix loop: start on mix begin, stop on minigame end or after max duration
mixStart.OnClientEvent:Connect(function()
    if not sounds.mixerLoop.IsPlaying then
        sounds.mixerLoop:Play()
    end
    -- Fallback stop after 15s in case MinigameEnded doesn't fire
    task.delay(15, function()
        if sounds.mixerLoop.IsPlaying then sounds.mixerLoop:Stop() end
    end)
end)

local ok, mixEndRemote = pcall(function() return RemoteManager.Get("MinigameEnded") end)
if ok and mixEndRemote then
    mixEndRemote.OnClientEvent:Connect(function()
        if sounds.mixerLoop.IsPlaying then sounds.mixerLoop:Stop() end
    end)
end

-- Oven start + complete
RemoteManager.Get("StartOvenMinigame").OnClientEvent:Connect(function()
    sounds.ovenOpen:Play()
end)
RemoteManager.Get("OvenMinigameResult").OnClientEvent:Connect(function()
    sounds.ovenDing:Play()
end)

-- Dough start + complete
RemoteManager.Get("StartDoughMinigame").OnClientEvent:Connect(function()
    sounds.doughThud:Play()
end)
RemoteManager.Get("DoughMinigameResult").OnClientEvent:Connect(function()
    sounds.doughDone:Play()
end)

-- Frost start + complete
RemoteManager.Get("StartFrostMinigame").OnClientEvent:Connect(function()
    sounds.frostSqrt:Play()
end)
RemoteManager.Get("FrostMinigameResult").OnClientEvent:Connect(function()
    sounds.frostDone:Play()
end)

-- ── Delivery ──────────────────────────────────────────────────────────────────
-- DeliveryResult fires (stars, coins, xp) — stars 1-5 = success, 0 = fail
RemoteManager.Get("DeliveryResult").OnClientEvent:Connect(function(stars)
    if stars and stars >= 1 then
        sounds.cashReg:Play()
    else
        sounds.delivFail:Play()
    end
end)

-- ── Order accepted bell ───────────────────────────────────────────────────────
local okOrder, orderAccepted = pcall(function() return RemoteManager.Get("OrderAccepted") end)
if okOrder and orderAccepted then
    orderAccepted.OnClientEvent:Connect(function()
        sounds.orderBell:Play()
    end)
end

-- ── Level-up sounds ───────────────────────────────────────────────────────────
RemoteManager.Get("BakeryLevelUp").OnClientEvent:Connect(function()
    sounds.levelUp:Play()
end)

RemoteManager.Get("MasteryLevelUp").OnClientEvent:Connect(function()
    sounds.masteryUp:Play()
end)

print("[SoundController] Ready.")

--[[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  HOW TO REPLACE A SOUND
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Find a free sound in the Roblox Creator Marketplace
   (creator.roblox.com → Marketplace → Audio → filter "Free")
2. Click the sound → copy the number from the URL:
   e.g. roblox.com/library/131070686 → ID is 131070686
3. In the IDS table at the top of this file, replace the number:
   CASH_REG = "rbxassetid://131070686"
              ───────────────^^^^^^^^^
               replace just this number
4. Save and push via MCP run_code (or re-run this script in Studio)

VOLUME GUIDE  (0 = silent, 1 = full)
  UI sounds:     0.3 – 0.5  (subtle, non-intrusive)
  Station FX:    0.5 – 0.7  (present but not distracting)
  Delivery/LvlUp 0.7 – 0.9  (reward moment, should feel good)
  Mixer loop:    0.4         (runs for several seconds, keep low)

CURRENT SOUND MAP
  MIXER_LOOP    → mix station active (looping)
  OVEN_OPEN     → oven minigame starts
  OVEN_DING     → oven minigame complete
  DOUGH_THUD    → dough minigame starts
  DOUGH_DONE    → dough minigame complete
  FROST_SQUIRT  → frost minigame starts
  FROST_DONE    → frost minigame complete
  CASH_REG      → successful delivery
  DELIVERY_FAIL → failed/0-star delivery
  UI_CLICK      → any button press in the game
  ORDER_BELL    → player accepts NPC order
  LEVEL_UP      → bakery level increases
  MASTERY_UP    → station mastery level increases
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--]]
