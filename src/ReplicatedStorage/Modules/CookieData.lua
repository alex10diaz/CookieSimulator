local CookieData = {}

-- ============================================================
-- COOKIE DEFINITIONS
-- needsFrost: true = goes frost → warmers after oven
--             false = goes directly to warmers after oven
-- fridgeId: which fridge this cookie type is stored in after dough
-- steps: ordered list of minigame stations (used for display/reference)
-- ============================================================

CookieData.Cookies = {
    {
        id         = "pink_sugar",
        name       = "Pink Sugar",
        fridgeId   = "fridge_pink_sugar",
        needsFrost = true,
        doughColor = Color3.fromRGB(255, 210, 220),
        bakedColor = Color3.fromRGB(240, 185, 195),
        frosting   = { color = Color3.fromRGB(255, 150, 180), label = "Pink Almond Frosting" },
        dress      = nil,
        price      = 5,
        steps      = { "mix", "dough", "oven", "frost", "dress" },
    },
    {
        id         = "chocolate_chip",
        name       = "Chocolate Chip",
        fridgeId   = "fridge_chocolate_chip",
        needsFrost = false,
        doughColor = Color3.fromRGB(210, 170, 100),
        bakedColor = Color3.fromRGB(180, 130, 70),
        frosting   = nil,
        dress      = nil,
        price      = 4,
        steps      = { "mix", "dough", "oven", "dress" },
    },
    {
        id         = "birthday_cake",
        name       = "Birthday Cake",
        fridgeId   = "fridge_birthday_cake",
        needsFrost = true,
        doughColor = Color3.fromRGB(255, 230, 240),
        bakedColor = Color3.fromRGB(245, 210, 220),
        frosting   = { color = Color3.fromRGB(255, 180, 210), label = "Pink Vanilla Frosting" },
        dress      = { label = "Sprinkles", toppingColor = Color3.fromRGB(255, 100, 150) },
        price      = 6,
        steps      = { "mix", "dough", "oven", "frost", "dress" },
    },
    {
        id         = "cookies_and_cream",
        name       = "Cookies & Cream",
        fridgeId   = "fridge_cookies_and_cream",
        needsFrost = true,
        doughColor = Color3.fromRGB(60, 50, 45),
        bakedColor = Color3.fromRGB(40, 35, 30),
        frosting   = { color = Color3.fromRGB(240, 240, 240), label = "White Cream Frosting" },
        dress      = { label = "Oreo Crumbles", toppingColor = Color3.fromRGB(30, 25, 20) },
        price      = 6,
        steps      = { "mix", "dough", "oven", "frost", "dress" },
    },
    {
        id         = "snickerdoodle",
        name       = "Snickerdoodle",
        fridgeId   = "fridge_snickerdoodle",
        needsFrost = false,
        doughColor = Color3.fromRGB(230, 200, 150),
        bakedColor = Color3.fromRGB(200, 160, 90),
        frosting   = nil,
        dress      = { label = "Cinnamon Sugar", toppingColor = Color3.fromRGB(180, 100, 40) },
        price      = 4,
        steps      = { "mix", "dough", "oven", "dress" },
    },
    {
        id         = "lemon_blackraspberry",
        name       = "Lemon Black Raspberry",
        fridgeId   = "fridge_lemon_blackraspberry",
        needsFrost = true,
        doughColor = Color3.fromRGB(200, 220, 255),
        bakedColor = Color3.fromRGB(175, 195, 230),
        frosting   = { color = Color3.fromRGB(130, 80, 180), label = "Purple Frosting" },
        dress      = nil,
        price      = 5,
        steps      = { "mix", "dough", "oven", "frost", "dress" },
    },
}

-- ============================================================
-- HELPERS
-- ============================================================

function CookieData.GetById(id)
    for _, cookie in ipairs(CookieData.Cookies) do
        if cookie.id == id then return cookie end
    end
    return nil
end

function CookieData.GetRandom()
    return CookieData.Cookies[math.random(1, #CookieData.Cookies)]
end

function CookieData.NeedsStep(cookieId, step)
    local cookie = CookieData.GetById(cookieId)
    if not cookie then return false end
    for _, s in ipairs(cookie.steps) do
        if s == step then return true end
    end
    return false
end

function CookieData.NeedsFrost(cookieId)
    local cookie = CookieData.GetById(cookieId)
    return cookie and cookie.needsFrost or false
end

function CookieData.GetFridgeId(cookieId)
    local cookie = CookieData.GetById(cookieId)
    return cookie and cookie.fridgeId or nil
end

return CookieData
