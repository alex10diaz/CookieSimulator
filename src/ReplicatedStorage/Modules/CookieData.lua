local CookieData = {}

-- ============================================================
-- COOKIE DEFINITIONS
-- needsFrost: true = goes frost → dress after oven
--             false = goes directly to dress after oven
-- fridgeId: which fridge this cookie type is stored in after dough
-- steps: ordered list of minigame stations
-- price tiers: 4 = Classic, 5 = Standard, 6 = Premium, 7 = Ultra Premium
-- NOTE: new cookie types require matching fridge/warmer models in workspace
-- ============================================================

local STEPS_PLAIN  = { "mix", "dough", "oven", "dress" }
local STEPS_FROST  = { "mix", "dough", "oven", "frost", "dress" }

CookieData.Cookies = {

    -- ── TIER 1 — Classic (4 coins) ──────────────────────────────────
    {
        id = "chocolate_chip", name = "Chocolate Chip",
        fridgeId = "fridge_chocolate_chip", needsFrost = false,
        doughColor = Color3.fromRGB(210, 170, 100), bakedColor = Color3.fromRGB(180, 130, 70),
        frosting = nil, dress = nil, price = 4, steps = STEPS_PLAIN,
    },
    {
        id = "snickerdoodle", name = "Snickerdoodle",
        fridgeId = "fridge_snickerdoodle", needsFrost = false,
        doughColor = Color3.fromRGB(230, 200, 150), bakedColor = Color3.fromRGB(200, 160, 90),
        frosting = nil,
        dress = { label = "Cinnamon Sugar", toppingColor = Color3.fromRGB(180, 100, 40) },
        price = 4, steps = STEPS_PLAIN,
    },
    {
        id = "oatmeal_raisin", name = "Oatmeal Raisin",
        fridgeId = "fridge_oatmeal_raisin", needsFrost = false,
        doughColor = Color3.fromRGB(210, 185, 145), bakedColor = Color3.fromRGB(185, 155, 110),
        frosting = nil, dress = nil, price = 4, steps = STEPS_PLAIN,
    },
    {
        id = "peanut_butter", name = "Peanut Butter",
        fridgeId = "fridge_peanut_butter", needsFrost = false,
        doughColor = Color3.fromRGB(230, 195, 140), bakedColor = Color3.fromRGB(200, 160, 95),
        frosting = nil, dress = nil, price = 4, steps = STEPS_PLAIN,
    },
    {
        id = "double_chocolate", name = "Double Chocolate",
        fridgeId = "fridge_double_chocolate", needsFrost = false,
        doughColor = Color3.fromRGB(80, 50, 35), bakedColor = Color3.fromRGB(55, 30, 15),
        frosting = nil, dress = nil, price = 4, steps = STEPS_PLAIN,
    },
    {
        id = "white_choc_macadamia", name = "White Choc Macadamia",
        fridgeId = "fridge_white_choc_macadamia", needsFrost = false,
        doughColor = Color3.fromRGB(245, 235, 215), bakedColor = Color3.fromRGB(220, 200, 170),
        frosting = nil, dress = nil, price = 4, steps = STEPS_PLAIN,
    },
    {
        id = "butterscotch_chip", name = "Butterscotch Chip",
        fridgeId = "fridge_butterscotch_chip", needsFrost = false,
        doughColor = Color3.fromRGB(240, 210, 140), bakedColor = Color3.fromRGB(210, 175, 95),
        frosting = nil, dress = nil, price = 4, steps = STEPS_PLAIN,
    },
    {
        id = "ginger_snap", name = "Ginger Snap",
        fridgeId = "fridge_ginger_snap", needsFrost = false,
        doughColor = Color3.fromRGB(200, 140, 70), bakedColor = Color3.fromRGB(170, 105, 45),
        frosting = nil, dress = nil, price = 4, steps = STEPS_PLAIN,
    },
    {
        id = "sugar_plain", name = "Classic Sugar",
        fridgeId = "fridge_sugar_plain", needsFrost = false,
        doughColor = Color3.fromRGB(255, 245, 230), bakedColor = Color3.fromRGB(240, 220, 190),
        frosting = nil, dress = nil, price = 4, steps = STEPS_PLAIN,
    },
    {
        id = "shortbread", name = "Shortbread",
        fridgeId = "fridge_shortbread", needsFrost = false,
        doughColor = Color3.fromRGB(250, 235, 190), bakedColor = Color3.fromRGB(220, 200, 150),
        frosting = nil, dress = nil, price = 4, steps = STEPS_PLAIN,
    },

    -- ── TIER 2 — Standard (5 coins) ─────────────────────────────────
    {
        id = "pink_sugar", name = "Pink Sugar",
        fridgeId = "fridge_pink_sugar", needsFrost = true,
        doughColor = Color3.fromRGB(255, 210, 220), bakedColor = Color3.fromRGB(240, 185, 195),
        frosting = { color = Color3.fromRGB(255, 150, 180), label = "Pink Almond Frosting" },
        dress = nil, price = 5, steps = STEPS_FROST,
    },
    {
        id = "lemon_blackraspberry", name = "Lemon Black Raspberry",
        fridgeId = "fridge_lemon_blackraspberry", needsFrost = true,
        doughColor = Color3.fromRGB(200, 220, 255), bakedColor = Color3.fromRGB(175, 195, 230),
        frosting = { color = Color3.fromRGB(130, 80, 180), label = "Purple Frosting" },
        dress = nil, price = 5, steps = STEPS_FROST,
    },
    {
        id = "red_velvet", name = "Red Velvet",
        fridgeId = "fridge_red_velvet", needsFrost = true,
        doughColor = Color3.fromRGB(180, 35, 40), bakedColor = Color3.fromRGB(150, 25, 30),
        frosting = { color = Color3.fromRGB(240, 240, 240), label = "Cream Cheese Frosting" },
        dress = nil, price = 5, steps = STEPS_FROST,
    },
    {
        id = "mint_chocolate_chip", name = "Mint Chocolate Chip",
        fridgeId = "fridge_mint_chocolate_chip", needsFrost = false,
        doughColor = Color3.fromRGB(185, 235, 200), bakedColor = Color3.fromRGB(155, 200, 165),
        frosting = nil,
        dress = { label = "Mini Choc Chips", toppingColor = Color3.fromRGB(60, 35, 20) },
        price = 5, steps = STEPS_PLAIN,
    },
    {
        id = "smores", name = "S'mores",
        fridgeId = "fridge_smores", needsFrost = false,
        doughColor = Color3.fromRGB(120, 80, 45), bakedColor = Color3.fromRGB(90, 55, 25),
        frosting = nil,
        dress = { label = "Marshmallow Crumble", toppingColor = Color3.fromRGB(245, 240, 230) },
        price = 5, steps = STEPS_PLAIN,
    },
    {
        id = "strawberry", name = "Strawberry",
        fridgeId = "fridge_strawberry", needsFrost = true,
        doughColor = Color3.fromRGB(255, 190, 200), bakedColor = Color3.fromRGB(235, 160, 175),
        frosting = { color = Color3.fromRGB(255, 150, 175), label = "Strawberry Frosting" },
        dress = nil, price = 5, steps = STEPS_FROST,
    },
    {
        id = "blueberry_cheesecake", name = "Blueberry Cheesecake",
        fridgeId = "fridge_blueberry_cheesecake", needsFrost = true,
        doughColor = Color3.fromRGB(200, 185, 225), bakedColor = Color3.fromRGB(175, 155, 200),
        frosting = { color = Color3.fromRGB(235, 230, 225), label = "Cream Cheese Frosting" },
        dress = nil, price = 5, steps = STEPS_FROST,
    },
    {
        id = "pumpkin_spice", name = "Pumpkin Spice",
        fridgeId = "fridge_pumpkin_spice", needsFrost = false,
        doughColor = Color3.fromRGB(220, 140, 60), bakedColor = Color3.fromRGB(190, 110, 40),
        frosting = nil,
        dress = { label = "Cinnamon Dust", toppingColor = Color3.fromRGB(160, 80, 30) },
        price = 5, steps = STEPS_PLAIN,
    },
    {
        id = "cinnamon_roll", name = "Cinnamon Roll",
        fridgeId = "fridge_cinnamon_roll", needsFrost = true,
        doughColor = Color3.fromRGB(245, 225, 190), bakedColor = Color3.fromRGB(215, 190, 150),
        frosting = { color = Color3.fromRGB(255, 252, 245), label = "Vanilla Glaze" },
        dress = nil, price = 5, steps = STEPS_FROST,
    },
    {
        id = "maple_pecan", name = "Maple Pecan",
        fridgeId = "fridge_maple_pecan", needsFrost = false,
        doughColor = Color3.fromRGB(225, 195, 140), bakedColor = Color3.fromRGB(195, 160, 100),
        frosting = nil,
        dress = { label = "Pecan Bits", toppingColor = Color3.fromRGB(130, 80, 35) },
        price = 5, steps = STEPS_PLAIN,
    },
    {
        id = "key_lime", name = "Key Lime",
        fridgeId = "fridge_key_lime", needsFrost = true,
        doughColor = Color3.fromRGB(215, 235, 200), bakedColor = Color3.fromRGB(185, 210, 165),
        frosting = { color = Color3.fromRGB(185, 225, 175), label = "Lime Cream Frosting" },
        dress = nil, price = 5, steps = STEPS_FROST,
    },
    {
        id = "funfetti", name = "Funfetti",
        fridgeId = "fridge_funfetti", needsFrost = true,
        doughColor = Color3.fromRGB(255, 240, 220), bakedColor = Color3.fromRGB(235, 215, 185),
        frosting = { color = Color3.fromRGB(255, 250, 245), label = "White Vanilla Frosting" },
        dress = { label = "Rainbow Sprinkles", toppingColor = Color3.fromRGB(200, 150, 200) },
        price = 5, steps = STEPS_FROST,
    },
    {
        id = "banana_cream", name = "Banana Cream",
        fridgeId = "fridge_banana_cream", needsFrost = true,
        doughColor = Color3.fromRGB(255, 245, 195), bakedColor = Color3.fromRGB(235, 220, 160),
        frosting = { color = Color3.fromRGB(255, 245, 190), label = "Banana Cream Frosting" },
        dress = nil, price = 5, steps = STEPS_FROST,
    },
    {
        id = "peach_cobbler", name = "Peach Cobbler",
        fridgeId = "fridge_peach_cobbler", needsFrost = false,
        doughColor = Color3.fromRGB(255, 210, 170), bakedColor = Color3.fromRGB(230, 180, 130),
        frosting = nil,
        dress = { label = "Brown Sugar Crumble", toppingColor = Color3.fromRGB(170, 110, 55) },
        price = 5, steps = STEPS_PLAIN,
    },
    {
        id = "caramel_apple", name = "Caramel Apple",
        fridgeId = "fridge_caramel_apple", needsFrost = false,
        doughColor = Color3.fromRGB(195, 215, 160), bakedColor = Color3.fromRGB(165, 185, 130),
        frosting = nil,
        dress = { label = "Caramel Drizzle", toppingColor = Color3.fromRGB(190, 140, 55) },
        price = 5, steps = STEPS_PLAIN,
    },

    -- ── TIER 3 — Premium (6 coins) ───────────────────────────────────
    {
        id = "birthday_cake", name = "Birthday Cake",
        fridgeId = "fridge_birthday_cake", needsFrost = true,
        doughColor = Color3.fromRGB(255, 230, 240), bakedColor = Color3.fromRGB(245, 210, 220),
        frosting = { color = Color3.fromRGB(255, 180, 210), label = "Pink Vanilla Frosting" },
        dress = { label = "Sprinkles", toppingColor = Color3.fromRGB(255, 100, 150) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "cookies_and_cream", name = "Cookies & Cream",
        fridgeId = "fridge_cookies_and_cream", needsFrost = true,
        doughColor = Color3.fromRGB(60, 50, 45), bakedColor = Color3.fromRGB(40, 35, 30),
        frosting = { color = Color3.fromRGB(240, 240, 240), label = "White Cream Frosting" },
        dress = { label = "Oreo Crumbles", toppingColor = Color3.fromRGB(30, 25, 20) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "salted_caramel", name = "Salted Caramel",
        fridgeId = "fridge_salted_caramel", needsFrost = true,
        doughColor = Color3.fromRGB(225, 185, 110), bakedColor = Color3.fromRGB(195, 150, 70),
        frosting = { color = Color3.fromRGB(200, 145, 55), label = "Salted Caramel Frosting" },
        dress = { label = "Sea Salt Flakes", toppingColor = Color3.fromRGB(230, 225, 220) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "chocolate_peanut_butter", name = "Choc Peanut Butter",
        fridgeId = "fridge_chocolate_peanut_butter", needsFrost = true,
        doughColor = Color3.fromRGB(100, 65, 35), bakedColor = Color3.fromRGB(70, 40, 20),
        frosting = { color = Color3.fromRGB(200, 155, 70), label = "Peanut Butter Frosting" },
        dress = { label = "Chocolate Drizzle", toppingColor = Color3.fromRGB(50, 30, 15) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "lavender_honey", name = "Lavender Honey",
        fridgeId = "fridge_lavender_honey", needsFrost = true,
        doughColor = Color3.fromRGB(215, 200, 235), bakedColor = Color3.fromRGB(185, 165, 210),
        frosting = { color = Color3.fromRGB(190, 165, 225), label = "Lavender Cream Frosting" },
        dress = { label = "Honey Drizzle", toppingColor = Color3.fromRGB(215, 165, 55) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "strawberry_shortcake", name = "Strawberry Shortcake",
        fridgeId = "fridge_strawberry_shortcake", needsFrost = true,
        doughColor = Color3.fromRGB(255, 210, 215), bakedColor = Color3.fromRGB(235, 180, 190),
        frosting = { color = Color3.fromRGB(255, 250, 250), label = "Whipped Cream Frosting" },
        dress = { label = "Strawberry Crumble", toppingColor = Color3.fromRGB(220, 90, 110) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "churro", name = "Churro",
        fridgeId = "fridge_churro", needsFrost = false,
        doughColor = Color3.fromRGB(245, 220, 165), bakedColor = Color3.fromRGB(215, 185, 120),
        frosting = nil,
        dress = { label = "Cinnamon Sugar & Caramel", toppingColor = Color3.fromRGB(175, 120, 45) },
        price = 6, steps = STEPS_PLAIN,
    },
    {
        id = "brown_butter_toffee", name = "Brown Butter Toffee",
        fridgeId = "fridge_brown_butter_toffee", needsFrost = true,
        doughColor = Color3.fromRGB(200, 160, 90), bakedColor = Color3.fromRGB(170, 125, 55),
        frosting = { color = Color3.fromRGB(195, 140, 55), label = "Caramel Frosting" },
        dress = { label = "Toffee Bits", toppingColor = Color3.fromRGB(180, 130, 50) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "raspberry_cheesecake", name = "Raspberry Cheesecake",
        fridgeId = "fridge_raspberry_cheesecake", needsFrost = true,
        doughColor = Color3.fromRGB(250, 235, 235), bakedColor = Color3.fromRGB(225, 205, 200),
        frosting = { color = Color3.fromRGB(240, 235, 230), label = "Cream Cheese Frosting" },
        dress = { label = "Raspberry Jam", toppingColor = Color3.fromRGB(200, 60, 90) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "matcha_white_choc", name = "Matcha White Chocolate",
        fridgeId = "fridge_matcha_white_choc", needsFrost = true,
        doughColor = Color3.fromRGB(175, 210, 175), bakedColor = Color3.fromRGB(145, 180, 145),
        frosting = { color = Color3.fromRGB(250, 248, 240), label = "White Chocolate Frosting" },
        dress = { label = "Matcha Dust", toppingColor = Color3.fromRGB(120, 175, 120) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "cherry_cordial", name = "Cherry Cordial",
        fridgeId = "fridge_cherry_cordial", needsFrost = true,
        doughColor = Color3.fromRGB(160, 40, 50), bakedColor = Color3.fromRGB(130, 25, 35),
        frosting = { color = Color3.fromRGB(60, 30, 20), label = "Dark Chocolate Frosting" },
        dress = { label = "Cherry Pieces", toppingColor = Color3.fromRGB(200, 45, 60) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "orange_creamsicle", name = "Orange Creamsicle",
        fridgeId = "fridge_orange_creamsicle", needsFrost = true,
        doughColor = Color3.fromRGB(255, 185, 110), bakedColor = Color3.fromRGB(230, 155, 75),
        frosting = { color = Color3.fromRGB(255, 190, 120), label = "Orange Cream Frosting" },
        dress = { label = "Orange Zest", toppingColor = Color3.fromRGB(230, 130, 40) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "caramel_pretzel", name = "Caramel Pretzel",
        fridgeId = "fridge_caramel_pretzel", needsFrost = true,
        doughColor = Color3.fromRGB(220, 185, 120), bakedColor = Color3.fromRGB(190, 150, 80),
        frosting = { color = Color3.fromRGB(195, 145, 55), label = "Caramel Frosting" },
        dress = { label = "Pretzel Bits", toppingColor = Color3.fromRGB(170, 130, 70) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "almond_joy", name = "Almond Joy",
        fridgeId = "fridge_almond_joy", needsFrost = true,
        doughColor = Color3.fromRGB(85, 55, 35), bakedColor = Color3.fromRGB(60, 35, 18),
        frosting = { color = Color3.fromRGB(55, 30, 18), label = "Dark Chocolate Frosting" },
        dress = { label = "Coconut & Almond", toppingColor = Color3.fromRGB(240, 220, 185) },
        price = 6, steps = STEPS_FROST,
    },
    {
        id = "lemon_blueberry", name = "Lemon Blueberry",
        fridgeId = "fridge_lemon_blueberry", needsFrost = true,
        doughColor = Color3.fromRGB(255, 250, 200), bakedColor = Color3.fromRGB(235, 225, 165),
        frosting = { color = Color3.fromRGB(255, 245, 150), label = "Lemon Cream Frosting" },
        dress = { label = "Blueberry Jam", toppingColor = Color3.fromRGB(80, 65, 155) },
        price = 6, steps = STEPS_FROST,
    },

    -- ── TIER 4 — Ultra Premium (7 coins) ────────────────────────────
    {
        id = "hazelnut_nutella", name = "Hazelnut Nutella",
        fridgeId = "fridge_hazelnut_nutella", needsFrost = true,
        doughColor = Color3.fromRGB(175, 125, 70), bakedColor = Color3.fromRGB(145, 95, 45),
        frosting = { color = Color3.fromRGB(115, 70, 35), label = "Nutella Frosting" },
        dress = { label = "Hazelnuts", toppingColor = Color3.fromRGB(160, 110, 55) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "cotton_candy", name = "Cotton Candy",
        fridgeId = "fridge_cotton_candy", needsFrost = true,
        doughColor = Color3.fromRGB(255, 205, 230), bakedColor = Color3.fromRGB(235, 175, 210),
        frosting = { color = Color3.fromRGB(255, 180, 220), label = "Cotton Candy Frosting" },
        dress = { label = "Rainbow Sugar", toppingColor = Color3.fromRGB(200, 155, 200) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "watermelon_sugar", name = "Watermelon Sugar",
        fridgeId = "fridge_watermelon_sugar", needsFrost = true,
        doughColor = Color3.fromRGB(195, 235, 195), bakedColor = Color3.fromRGB(165, 205, 165),
        frosting = { color = Color3.fromRGB(240, 90, 100), label = "Watermelon Frosting" },
        dress = { label = "Seed Pattern", toppingColor = Color3.fromRGB(30, 30, 30) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "tropical_mango", name = "Tropical Mango",
        fridgeId = "fridge_tropical_mango", needsFrost = true,
        doughColor = Color3.fromRGB(255, 215, 120), bakedColor = Color3.fromRGB(230, 185, 75),
        frosting = { color = Color3.fromRGB(255, 185, 60), label = "Mango Cream Frosting" },
        dress = { label = "Toasted Coconut", toppingColor = Color3.fromRGB(215, 185, 130) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "blood_orange", name = "Blood Orange",
        fridgeId = "fridge_blood_orange", needsFrost = true,
        doughColor = Color3.fromRGB(210, 80, 40), bakedColor = Color3.fromRGB(180, 55, 20),
        frosting = { color = Color3.fromRGB(225, 80, 35), label = "Blood Orange Frosting" },
        dress = { label = "Zest Crystals", toppingColor = Color3.fromRGB(235, 120, 50) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "creme_brulee", name = "Crème Brûlée",
        fridgeId = "fridge_creme_brulee", needsFrost = true,
        doughColor = Color3.fromRGB(255, 245, 210), bakedColor = Color3.fromRGB(235, 220, 170),
        frosting = { color = Color3.fromRGB(255, 240, 190), label = "Custard Cream Frosting" },
        dress = { label = "Caramel Sugar", toppingColor = Color3.fromRGB(200, 150, 45) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "biscoff_lotus", name = "Biscoff Lotus",
        fridgeId = "fridge_biscoff_lotus", needsFrost = true,
        doughColor = Color3.fromRGB(205, 155, 85), bakedColor = Color3.fromRGB(175, 120, 50),
        frosting = { color = Color3.fromRGB(185, 130, 65), label = "Biscoff Frosting" },
        dress = { label = "Lotus Crumbles", toppingColor = Color3.fromRGB(175, 120, 50) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "galaxy", name = "Galaxy",
        fridgeId = "fridge_galaxy", needsFrost = true,
        doughColor = Color3.fromRGB(45, 30, 60), bakedColor = Color3.fromRGB(25, 15, 40),
        frosting = { color = Color3.fromRGB(30, 10, 50), label = "Midnight Frosting" },
        dress = { label = "Cosmic Glitter", toppingColor = Color3.fromRGB(140, 100, 200) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "rainbow_sherbet", name = "Rainbow Sherbet",
        fridgeId = "fridge_rainbow_sherbet", needsFrost = true,
        doughColor = Color3.fromRGB(255, 210, 220), bakedColor = Color3.fromRGB(230, 180, 195),
        frosting = { color = Color3.fromRGB(255, 160, 200), label = "Sherbet Frosting" },
        dress = { label = "Rainbow Sprinkles", toppingColor = Color3.fromRGB(200, 150, 200) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "tiramisu", name = "Tiramisu",
        fridgeId = "fridge_tiramisu", needsFrost = true,
        doughColor = Color3.fromRGB(235, 215, 180), bakedColor = Color3.fromRGB(205, 180, 140),
        frosting = { color = Color3.fromRGB(235, 225, 205), label = "Mascarpone Frosting" },
        dress = { label = "Cocoa Dust", toppingColor = Color3.fromRGB(80, 50, 30) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "tres_leches", name = "Tres Leches",
        fridgeId = "fridge_tres_leches", needsFrost = true,
        doughColor = Color3.fromRGB(255, 245, 225), bakedColor = Color3.fromRGB(235, 220, 190),
        frosting = { color = Color3.fromRGB(255, 252, 248), label = "Cream Soak Frosting" },
        dress = { label = "Cinnamon Dust", toppingColor = Color3.fromRGB(165, 85, 35) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "black_forest", name = "Black Forest",
        fridgeId = "fridge_black_forest", needsFrost = true,
        doughColor = Color3.fromRGB(65, 35, 25), bakedColor = Color3.fromRGB(40, 20, 10),
        frosting = { color = Color3.fromRGB(40, 20, 10), label = "Dark Chocolate Frosting" },
        dress = { label = "Cherry Pieces", toppingColor = Color3.fromRGB(195, 45, 55) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "ube_coconut", name = "Ube Coconut",
        fridgeId = "fridge_ube_coconut", needsFrost = true,
        doughColor = Color3.fromRGB(175, 130, 210), bakedColor = Color3.fromRGB(145, 95, 185),
        frosting = { color = Color3.fromRGB(155, 95, 200), label = "Ube Cream Frosting" },
        dress = { label = "Toasted Coconut", toppingColor = Color3.fromRGB(210, 180, 130) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "pistachio_rosewater", name = "Pistachio Rosewater",
        fridgeId = "fridge_pistachio_rosewater", needsFrost = true,
        doughColor = Color3.fromRGB(200, 225, 195), bakedColor = Color3.fromRGB(170, 195, 165),
        frosting = { color = Color3.fromRGB(240, 175, 185), label = "Rose Cream Frosting" },
        dress = { label = "Pistachio Dust", toppingColor = Color3.fromRGB(130, 175, 120) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "brown_sugar_boba", name = "Brown Sugar Boba",
        fridgeId = "fridge_brown_sugar_boba", needsFrost = true,
        doughColor = Color3.fromRGB(215, 175, 120), bakedColor = Color3.fromRGB(185, 140, 80),
        frosting = { color = Color3.fromRGB(175, 120, 55), label = "Brown Sugar Frosting" },
        dress = { label = "Tapioca Pearls", toppingColor = Color3.fromRGB(55, 35, 15) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "golden_oreo", name = "Golden Oreo",
        fridgeId = "fridge_golden_oreo", needsFrost = true,
        doughColor = Color3.fromRGB(245, 225, 165), bakedColor = Color3.fromRGB(215, 190, 125),
        frosting = { color = Color3.fromRGB(255, 248, 220), label = "Vanilla Cream Frosting" },
        dress = { label = "Golden Oreo Crumbles", toppingColor = Color3.fromRGB(220, 190, 120) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "strawberry_basil", name = "Strawberry Basil",
        fridgeId = "fridge_strawberry_basil", needsFrost = true,
        doughColor = Color3.fromRGB(245, 195, 205), bakedColor = Color3.fromRGB(220, 165, 178),
        frosting = { color = Color3.fromRGB(255, 140, 165), label = "Strawberry Frosting" },
        dress = { label = "Basil Crumble", toppingColor = Color3.fromRGB(90, 140, 90) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "caramel_apple_pie", name = "Caramel Apple Pie",
        fridgeId = "fridge_caramel_apple_pie", needsFrost = true,
        doughColor = Color3.fromRGB(200, 165, 105), bakedColor = Color3.fromRGB(170, 130, 65),
        frosting = { color = Color3.fromRGB(185, 140, 65), label = "Brown Butter Frosting" },
        dress = { label = "Apple Chip", toppingColor = Color3.fromRGB(175, 110, 55) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "raspberry_lemonade", name = "Raspberry Lemonade",
        fridgeId = "fridge_raspberry_lemonade", needsFrost = true,
        doughColor = Color3.fromRGB(255, 215, 225), bakedColor = Color3.fromRGB(235, 185, 200),
        frosting = { color = Color3.fromRGB(255, 150, 190), label = "Raspberry Lemon Frosting" },
        dress = { label = "Lemon Zest", toppingColor = Color3.fromRGB(235, 210, 100) },
        price = 7, steps = STEPS_FROST,
    },
    {
        id = "neapolitan", name = "Neapolitan",
        fridgeId = "fridge_neapolitan", needsFrost = true,
        doughColor = Color3.fromRGB(245, 215, 215), bakedColor = Color3.fromRGB(220, 185, 185),
        frosting = { color = Color3.fromRGB(255, 165, 180), label = "Tri-Color Frosting" },
        dress = { label = "Chocolate Shavings", toppingColor = Color3.fromRGB(65, 40, 25) },
        price = 7, steps = STEPS_FROST,
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

-- Returns a random cookie restricted to the provided menu list (array of cookieIds).
-- Falls back to GetRandom() if the list is empty or invalid.
function CookieData.GetRandomFromMenu(menuList)
    if not menuList or #menuList == 0 then
        return CookieData.GetRandom()
    end
    local pool = {}
    for _, id in ipairs(menuList) do
        local cookie = CookieData.GetById(id)
        if cookie then table.insert(pool, cookie) end
    end
    if #pool == 0 then return CookieData.GetRandom() end
    return pool[math.random(1, #pool)]
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

-- ============================================================
-- UNLOCK / OWNERSHIP
-- ============================================================

-- The 4 cookies players receive for free at the start.
CookieData.StarterIds = {
    "chocolate_chip", "snickerdoodle", "pink_sugar", "birthday_cake",
}

local _STARTER_SET = {}
for _, id in ipairs(CookieData.StarterIds) do _STARTER_SET[id] = true end

-- Special pricing for the remaining "original 6" cookies (not tier-based).
local _SPECIAL_COSTS = {
    cookies_and_cream    = 100,
    lemon_blackraspberry = 100,
}

-- Default unlock cost by price tier (for all other cookies).
local _TIER_COSTS = { [4] = 100, [5] = 250, [6] = 500, [7] = 1000 }

-- Returns the coin cost to unlock this cookie (0 = starter/free).
function CookieData.GetUnlockCost(cookieId)
    if _STARTER_SET[cookieId] then return 0 end
    if _SPECIAL_COSTS[cookieId] then return _SPECIAL_COSTS[cookieId] end
    local cookie = CookieData.GetById(cookieId)
    return cookie and (_TIER_COSTS[cookie.price] or 100) or 100
end

return CookieData
