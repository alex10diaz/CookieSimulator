-- SoundController.client.lua (S-5)
-- Plays 3 key sounds: mixer whir during mix, oven ding on completion, cash register on delivery.
-- Replace SoundIds with any free Roblox audio assets you prefer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

-- ── Sound IDs (swap these for your preferred assets) ─────────────────────────
local ID_MIXER_LOOP   = "rbxassetid://9117709834"   -- machine/motor hum (looped)
local ID_OVEN_DING    = "rbxassetid://4612375233"   -- oven-ready bell
local ID_CASH_REG     = "rbxassetid://131070686"    -- cash register ka-ching

-- ── Create sounds in SoundService (client-local) ──────────────────────────────
local function makeSound(id, volume, looped)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume  = volume or 0.6
    s.Looped  = looped or false
    s.RollOffMaxDistance = 0  -- 2D sound (not positional)
    s.Parent  = SoundService
    return s
end

local mixerSound = makeSound(ID_MIXER_LOOP, 0.45, true)
local ovenSound  = makeSound(ID_OVEN_DING,  0.7,  false)
local cashSound  = makeSound(ID_CASH_REG,   0.8,  false)

-- ── Remotes ──────────────────────────────────────────────────────────────────
local startMixEvent   = RemoteManager.Get("StartMixMinigame")
local mixResultEvent  = RemoteManager.Get("MixMinigameResult")   -- client fires this, so we listen via OnClientEvent won't work
local ovenResultEvent = RemoteManager.Get("OvenMinigameResult")
local deliveryEvent   = RemoteManager.Get("DeliveryResult")
local cancelEvent     = RemoteManager.Get("CancelMinigame")      -- fired by client, not useful here

-- Mix start → play loop; oven result or mix result → stop loop
startMixEvent.OnClientEvent:Connect(function()
    if not mixerSound.IsPlaying then mixerSound:Play() end
end)

-- Stop mixer when minigame ends (result or cancel)
local mixResultRemote = RemoteManager.Get("MixMinigameResult")
-- MixMinigameResult is fired Server→Client when the server confirms the result
-- but actually the client fires it TO the server, so OnClientEvent won't fire here.
-- Instead we stop the loop when the mix UI closes, which is on a brief delay.
-- Safest: stop after 12 seconds max (mix duration is ~8s + buffer)
startMixEvent.OnClientEvent:Connect(function()
    task.delay(12, function()
        if mixerSound.IsPlaying then mixerSound:Stop() end
    end)
end)

-- Oven minigame result → ding
ovenResultEvent.OnClientEvent:Connect(function()
    ovenSound:Play()
end)

-- Delivery confirmed → cash register
deliveryEvent.OnClientEvent:Connect(function()
    cashSound:Play()
end)

print("[SoundController] Ready.")
