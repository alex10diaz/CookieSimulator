-- ReplicatedStorage/Modules/EconomyManager
-- All payout formulas. Rebalance by changing numbers in this one file.

local RECIPE_VALUES = {
    pink_sugar           = { coins = 10,  timeLimitSecs = 90  },
    chocolate_chip       = { coins = 15,  timeLimitSecs = 90  },
    snickerdoodle        = { coins = 25,  timeLimitSecs = 120 },
    birthday_cake        = { coins = 40,  timeLimitSecs = 120 },
    cookies_and_cream    = { coins = 65,  timeLimitSecs = 150 },
    lemon_blackraspberry = { coins = 100, timeLimitSecs = 150 },
}

local MULTIPLIER_CAP = 3.0

local EconomyManager = {}

function EconomyManager.GetRecipeValue(cookieId)
    return RECIPE_VALUES[cookieId] or { coins = 10, timeLimitSecs = 90 }
end

--[[
    CalculatePayout — returns { coins, xp, multiplier }
    @param cookieId      string
    @param quantity      number
    @param stars         number 1-5
    @param timeRemaining number  (seconds left; pass 0 if not tracked)
    @param totalTime     number  (original limit; pass 1 if not tracked)
    @param comboStreak   number  (0-20, capped)
    @param isVIP         boolean
]]
function EconomyManager.CalculatePayout(cookieId, quantity, stars, timeRemaining, totalTime, comboStreak, isVIP)
    local recipe  = EconomyManager.GetRecipeValue(cookieId)
    local base    = recipe.coins * math.max(1, quantity)

    local speedMult    = 1 + (math.max(0, timeRemaining) / math.max(1, totalTime)) * 0.5
    local accuracyMult = 0.5 + ((stars - 1) / 4)          -- 1★=0.5 … 5★=1.5
    local comboMult    = 1 + 0.05 * math.min(comboStreak or 0, 20)
    local vipMult      = isVIP and 1.75 or 1.0

    local totalMult = math.min(speedMult * accuracyMult * comboMult * vipMult, MULTIPLIER_CAP)
    local coins     = math.max(1, math.floor(base * totalMult))
    local xp        = math.max(1, math.floor(base * 0.6 * accuracyMult * (stars == 5 and 1.2 or 1.0)))

    return { coins = coins, xp = xp, multiplier = totalMult }
end

--[[
    CalculateStars — weighted 1-5 star rating
    @param correctness  0-1   (use quality/100 as proxy)
    @param speedRatio   0-1   (pass 1.0 if not tracked)
    @param doneness     string ("Perfect"|"SlightlyBrown"|"Underbaked"|"Burned")
    @param mixQuality   0-100
    @param decorScore   0-1   (nil → treated as 1.0)
]]
function EconomyManager.CalculateStars(correctness, speedRatio, doneness, mixQuality, decorScore)
    local donenessMap = {
        Perfect       = 1.0,
        SlightlyBrown = 0.7,
        Underbaked    = 0.5,
        Burned        = 0.0,
    }
    local d = donenessMap[doneness] or 0.5

    local raw = (correctness           * 0.35)
              + (speedRatio            * 0.30)
              + (d                     * 0.20)
              + ((mixQuality / 100)    * 0.10)
              + ((decorScore or 1.0)   * 0.05)

    return math.clamp(math.floor(raw * 5) + 1, 1, 5)
end

print("[EconomyManager] Ready.")
return EconomyManager
