-- ServerScriptService/Core/SessionStats (ModuleScript)
-- Tracks aggregate per-cycle delivery stats for the EndOfDay summary.
-- Call RecordDelivery after each delivery, GetSummary for EndOfDay, Reset at new cycle start.

local SessionStats = {}

local data = {
    orders       = 0,
    coins        = 0,
    cookiesBaked = 0,
    totalStars   = 0,
    peakCombo    = 0,
    fails        = 0,
}

-- Per-player station stats for Employee of the Shift
-- { [userId] = { name=str, mix={total,count}, oven={total,count}, frost={total,count}, dough=0, boxes=0 } }
local stationData = {}

local function getStationEntry(player)
    local uid = player.UserId
    if not stationData[uid] then
        stationData[uid] = {
            name  = player.Name,
            mix   = {0, 0},
            oven  = {0, 0},
            frost = {0, 0},
            dough = 0,
            boxes = 0,
        }
    end
    return stationData[uid]
end

function SessionStats.RecordFail()
    data.fails += 1
end

function SessionStats.RecordDelivery(stars, coins, comboStreak, cookieCount)
    data.orders       += 1
    data.coins        += (coins or 0)
    data.cookiesBaked += (cookieCount or 1)
    data.totalStars   += (stars or 0)
    if (comboStreak or 0) > data.peakCombo then
        data.peakCombo = comboStreak
    end
end

-- Called by MinigameServer after each completed station session.
function SessionStats.RecordStationScore(player, station, score)
    local d = getStationEntry(player)
    if     station == "mix"   then d.mix[1]   += score; d.mix[2]   += 1
    elseif station == "oven"  then d.oven[1]  += score; d.oven[2]  += 1
    elseif station == "frost" then d.frost[1] += score; d.frost[2] += 1
    elseif station == "dough" then d.dough    += 1
    elseif station == "dress" then d.boxes    += 1
    end
end

-- Returns one winner per station role for the shift.
-- { Mixer={name,value}, Baller={name,value}, Baker={name,value}, Glazer={name,value}, Decorator={name,value} }
function SessionStats.GetEmployeeOfShift()
    local best = {
        Mixer     = { name="—", value=0 },
        Baller    = { name="—", value=0 },
        Baker     = { name="—", value=0 },
        Glazer    = { name="—", value=0 },
        Decorator = { name="—", value=0 },
    }
    for _, d in pairs(stationData) do
        local mixAvg   = d.mix[2]   > 0 and math.floor(d.mix[1]   / d.mix[2]   + 0.5) or 0
        local ovenAvg  = d.oven[2]  > 0 and math.floor(d.oven[1]  / d.oven[2]  + 0.5) or 0
        local frostAvg = d.frost[2] > 0 and math.floor(d.frost[1] / d.frost[2] + 0.5) or 0

        if mixAvg   > best.Mixer.value     then best.Mixer.name     = d.name; best.Mixer.value     = mixAvg   end
        if d.dough  > best.Baller.value    then best.Baller.name    = d.name; best.Baller.value    = d.dough  end
        if ovenAvg  > best.Baker.value     then best.Baker.name     = d.name; best.Baker.value     = ovenAvg  end
        if frostAvg > best.Glazer.value    then best.Glazer.name    = d.name; best.Glazer.value    = frostAvg end
        if d.boxes  > best.Decorator.value then best.Decorator.name = d.name; best.Decorator.value = d.boxes  end
    end
    return best
end

-- Returns the single overall top player this shift (for the back-room board).
-- Weighted: boxes*30 + dough*20 + quality averages. Returns { name, userId } or nil.
function SessionStats.GetTopEmployee()
    local best, bestScore = nil, -1
    for uid, d in pairs(stationData) do
        local mixAvg   = d.mix[2]   > 0 and (d.mix[1]   / d.mix[2])   or 0
        local ovenAvg  = d.oven[2]  > 0 and (d.oven[1]  / d.oven[2])  or 0
        local frostAvg = d.frost[2] > 0 and (d.frost[1] / d.frost[2]) or 0
        local score = d.boxes * 30 + d.dough * 20 + mixAvg + ovenAvg + frostAvg
        if score > bestScore then
            bestScore = score
            -- Find which station contributed most to this player's score.
            local stationScores = {
                Mixer     = mixAvg,
                Baller    = d.dough * 20,
                Baker     = ovenAvg,
                Glazer    = frostAvg,
                Decorator = d.boxes * 30,
            }
            local topStation, topVal = "Baker", -1
            for sName, sVal in pairs(stationScores) do
                if sVal > topVal then topStation = sName; topVal = sVal end
            end
            best = { name = d.name, userId = uid, station = topStation }
        end
    end
    return best
end

-- Returns S/A/B/C/D grade based on shift performance.
-- score = quality(0-40) + volume(0-30) + combo(0-20) - fail_penalty(8 each)
function SessionStats.GetShiftGrade(s)
    local score = 0
    score += math.min((s.avgStars or 0) / 5 * 40, 40)  -- quality component
    score += math.min((s.orders  or 0) * 3,        30)  -- volume component  (10 orders = max)
    score += math.min((s.combo   or 0) * 2,        20)  -- combo component
    score -= (s.fails  or 0) * 8                         -- fail penalty
    score  = math.max(0, math.floor(score + 0.5))
    local grade
    if     score >= 90 then grade = "S"
    elseif score >= 75 then grade = "A"
    elseif score >= 60 then grade = "B"
    elseif score >= 45 then grade = "C"
    else                     grade = "D"
    end
    return { grade = grade, score = score }
end

function SessionStats.GetSummary()
    local avgStars = data.orders > 0
        and math.floor((data.totalStars / data.orders) * 10 + 0.5) / 10
        or  0
    return {
        orders       = data.orders,
        coins        = data.coins,
        cookiesBaked = data.cookiesBaked,
        combo        = data.peakCombo,
        avgStars     = avgStars,
        fails        = data.fails,
    }
end

function SessionStats.Reset()
    data.orders       = 0
    data.coins        = 0
    data.cookiesBaked = 0
    data.totalStars   = 0
    data.peakCombo    = 0
    stationData       = {}
end

return SessionStats
