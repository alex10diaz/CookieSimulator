-- ServerScriptService/Core/EventManager.server.lua
-- Manages timed events during the Open phase.
-- M6: Rush Hour — faster NPC spawns + 1.5x coin multiplier for 120 seconds.

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local events     = ServerStorage:WaitForChild("Events")
local rushStartBE = events:WaitForChild("RushHourStart")
local rushEndBE   = events:WaitForChild("RushHourEnd")
local rushRemote  = RemoteManager.Get("RushHour")

-- ── CONFIG ────────────────────────────────────────────────────────────────────

local RUSH_DELAY_MIN = 90   -- earliest Rush Hour starts (seconds after Open)
local RUSH_DELAY_MAX = 240  -- latest Rush Hour starts
local RUSH_DURATION  = 120  -- how long Rush Hour lasts (seconds)

-- ── STATE ─────────────────────────────────────────────────────────────────────

local cancelPending = nil  -- cancels scheduled/active Rush Hour on EndOfDay

-- ── RUSH HOUR ─────────────────────────────────────────────────────────────────

local function endRushHour()
	workspace:SetAttribute("RushHourActive", false)
	rushEndBE:Fire()
	rushRemote:FireAllClients({ active = false })
	cancelPending = nil
	print("[EventManager] Rush Hour ended")
end

local function startRushHour()
	workspace:SetAttribute("RushHourActive", true)
	rushStartBE:Fire()
	rushRemote:FireAllClients({ active = true, duration = RUSH_DURATION })
	print("[EventManager] Rush Hour started!")

	local thread = task.delay(RUSH_DURATION, endRushHour)
	cancelPending = function()
		task.cancel(thread)
		endRushHour()
	end
end

local function scheduleRushHour()
	local delay = math.random(RUSH_DELAY_MIN, RUSH_DELAY_MAX)
	print(string.format("[EventManager] Rush Hour scheduled in %ds", delay))

	local thread = task.delay(delay, startRushHour)
	cancelPending = function()
		task.cancel(thread)
		cancelPending = nil
	end
end

-- ── GAMESTATE WIRING ──────────────────────────────────────────────────────────

workspace:GetAttributeChangedSignal("GameState"):Connect(function()
	local state = workspace:GetAttribute("GameState")
	if state == "Open" then
		scheduleRushHour()
	elseif state == "EndOfDay" or state == "Lobby" then
		if cancelPending then
			cancelPending()
		end
		workspace:SetAttribute("RushHourActive", false)
	end
end)

print("[EventManager] Loaded")
