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
}

function SessionStats.RecordDelivery(stars, coins, comboStreak, cookieCount)
    data.orders       += 1
    data.coins        += (coins or 0)
    data.cookiesBaked += (cookieCount or 1)
    data.totalStars   += (stars or 0)
    if (comboStreak or 0) > data.peakCombo then
        data.peakCombo = comboStreak
    end
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
    }
end

function SessionStats.Reset()
    data.orders       = 0
    data.coins        = 0
    data.cookiesBaked = 0
    data.totalStars   = 0
    data.peakCombo    = 0
end

return SessionStats
