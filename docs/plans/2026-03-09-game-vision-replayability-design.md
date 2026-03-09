# Cookie Empire: Master Bakery — Game Vision & Replayability Design
**Date:** 2026-03-09
**Status:** Approved ✅
**Scope:** Additive systems only — no changes to core minigame gameplay or existing station flow

---

## Design Philosophy

**Primary pull:** Progression grind (unlocking new things)
**Secondary:** Numbers going up, economy grind, collection
**Tertiary:** Social co-op, leaderboard rivalry
**Session feel:** Pick-up-and-play immediately, with deep meta-progression for grinders

---

## Ownership Model

All progression is split between player-owned (follows you everywhere) and bakery-owned (belongs to the host):

| System | Owned By |
|--------|----------|
| Coins | ✅ Player |
| Cookie catalog | ✅ Player |
| Station mastery / roles | ✅ Player |
| Cosmetics, titles, uniforms | ✅ Player |
| Character customization | ✅ Player |
| Badges & Customer Book | ✅ Player |
| Cookie Collection Book | ✅ Player |
| Leaderboard stats | ✅ Player (accumulate across all servers) |
| Station upgrades | 🏠 Bakery host |
| Named bakery | 🏠 Bakery host |
| Bakery level & star rating | 🏠 Bakery host |

**When visiting a friend's server:** You play using their bakery's upgrades and cookie menu. You earn your own coins, XP, mastery, and badges. You do not permanently unlock anything they own. Seeing their Tier 3 cookies creates natural desire to grind for them yourself.

---

## Section 1: Cookie Catalog System

### 60-Cookie Database
All 60 cookies share the same minigame mechanics. The difference is visuals, name, revenue, and a small difficulty modifier on existing timing windows. Player creates models.

**Tier structure:**

| Tier | Count | Base Revenue | Difficulty Modifier |
|------|-------|-------------|---------------------|
| 1 — Common | 20 | ~120 coins | Standard |
| 2 — Premium | 20 | ~220 coins | 10% tighter windows |
| 3 — Specialty | 15 | ~380 coins | 20% tighter, slightly faster |
| 4 — Legendary | 5 | ~600 coins | Hardest version of each minigame |

**Unlock path:**
- Start: 4 Tier 1 cookies (existing core cookies)
- Bakery Level 3 & 5: unlock 2 more Tier 1 cookies automatically
- Remaining Tier 1 + all Tier 2: unlock by Bakery Level OR buy with in-game coins
- Tier 3: Bakery Level gate only (cannot buy past the grind)
- Tier 4 Legendary: Prestige-only unlocks (one per prestige cycle, max 5)

**Menu Selection (PreOpen phase):**
- Team selects 4–6 active cookies for the shift from their unlocked catalog
- Active count scales with warmer slots: 6 base → 7 with Extra Warmer I → 8 with Extra Warmer II
- Warmers and NPC order pool update to match the selection each shift
- Higher tier menu = harder shift, bigger payout

**Solo vs Shared unlock:** Permanently unlocked per player account. Visiting a server where a cookie is available lets you use it that session but does not unlock it for your account.

---

## Section 2: Station Roles & Mastery

### The 5 Roles

| Role | Station | Mechanical Bonus (max) |
|------|---------|----------------------|
| **Mixer** | Mix | Faster ring completion speed (more throughput) |
| **Baller** | Dough | More forgiving dough hit zones |
| **Baker** | Oven | Wider oven perfect-timing window |
| **Glazer** | Frost | More time on frost checkpoint spiral |
| **Decorator** | Dress | Small flat quality bonus on dress score |

### How Roles Work
- No role selection required — mastery grows automatically at whichever station you use most
- All 5 mastery tracks exist simultaneously on your account at different levels
- Zero friction: just play your preferred station and it grows naturally

### Mastery Level Progression (1–10 per role)

| Level | XP Needed | Cumulative | Approx. Time (focused play) |
|-------|-----------|------------|------------------------------|
| 1→2 | 400 | 400 | ~1 session |
| 2→3 | 800 | 1,200 | ~1 week |
| 3→4 | 1,500 | 2,700 | ~2 weeks |
| 4→5 | 3,000 | 5,700 | ~3 weeks |
| 5→6 | 5,500 | 11,200 | ~5 weeks |
| 6→7 | 9,000 | 20,200 | ~7 weeks |
| 7→8 | 14,000 | 34,200 | ~10 weeks |
| 8→9 | 18,000 | 52,200 | ~3 months |
| 9→10 | 22,000 | 74,200 | ~4 months |

XP per station use: ~15 XP average, ~25 XP for a perfect quality run. Quality-weighted.

### Rewards at Every Level (using Mixer as example — all roles follow same pattern)

| Level | Reward |
|-------|--------|
| 1 | Role badge + *"Apprentice Mixer"* title |
| 2 | Uniform trim color (role color) |
| 3 | 300 coins + *"Junior Mixer"* title |
| 4 | Tool skin #1 (role-specific accessory) |
| 5 | ⚡ Mechanical bonus unlocks (5%) + *"Mixer"* title |
| 6 | 800 coins + subtle station particle effect |
| 7 | ⚡ Bonus bumps to 8% + *"Senior Mixer"* title + role outfit piece |
| 8 | 1,500 coins + rare cosmetic (role-themed hat or apron) |
| 9 | 2,500 coins + *"Expert Mixer"* title |
| 10 | ⚡ Bonus at max (10%) + *"Master Mixer"* legendary cosmetic + permanent station aura |

### Employee of the Shift
End-of-shift spotlight — all 5 highlighted simultaneously, one per station:

| Station | Highlighted Stat |
|---------|-----------------|
| Mixer | Highest average mix quality score |
| Baller | Most dough batches shaped |
| Baker | Fastest average oven cycle time |
| Glazer | Longest frost checkpoint streak without a miss |
| Decorator | Most boxes dressed + delivered |

---

## Section 3: Bakery Level, Station Upgrades & Prestige

### Bakery Level (host-owned, 1–50)
Earned through shifts played and orders delivered — not coins. Displayed as a star rating above the bakery entrance and on the leaderboard. Gates what upgrades the host can purchase and which NPC rarities can appear.

| Stars | Level | Effect |
|-------|-------|--------|
| ⭐ | 1–9 | Starting bakery, standard NPCs |
| ⭐⭐ | 10–19 | Better tips, Uncommon NPCs appear |
| ⭐⭐⭐ | 20–34 | Better NPC pool, higher average order value |
| ⭐⭐⭐⭐ | 35–49 | Rare NPCs appear, premium orders |
| ⭐⭐⭐⭐⭐ | 50 | Prestige available, Legendary NPC pool unlocked |

### Station Upgrade Shop (host buys with own coins — main economy sink)

| Upgrade | Level Gate | Cost | Effect |
|---------|-----------|------|--------|
| Fridge Expansion I | 5 | 2,000 coins | Fridge 4→6 per type |
| Tip Boost I | 10 | 3,000 coins | +10% NPC tips |
| NPC Patience I | 10 | 2,500 coins | +10s patience |
| Extra Warmer I | 15 | 5,000 coins | 6→7 warmer slots + 7th menu slot |
| Oven Speed | 20 | 4,000 coins | 10% faster bake cycle |
| Tip Boost II | 25 | 6,000 coins | +20% tips total |
| Extra Warmer II | 25 | 8,000 coins | 7→8 warmer slots + 8th menu slot |
| NPC Patience II | 30 | 5,000 coins | +20s patience total |
| Fridge Expansion II | 35 | 10,000 coins | 6→8 per type |
| VIP NPC Magnet | 40 | 15,000 coins | Slight rare NPC spawn boost |

Coins spent on upgrades are permanent investments in the bakery — they do not travel with the host as a visitor to other servers.

### Prestige — Grand Re-Opening (unlocks at Bakery Level 50)
Voluntarily resets bakery to Level 1. All personal progression kept (mastery, cosmetics, catalog, badges). Bakery upgrades are lost and must be re-earned.

| Prestige | Title | Coin Multiplier | Bonus |
|----------|-------|----------------|-------|
| 1st | *"Grand Baker"* | +8% permanent | Tier 4 Legendary cookie #1 |
| 2nd | *"Elite Baker"* | +16% total | Legendary cookie #2 |
| 3rd | *"Cookie Baron"* | +24% total | Legendary cookie #3 |
| 4th | *"Cookie Tycoon"* | +32% total | Legendary cookie #4 |
| 5th (max) | *"Cookie Emperor"* | +40% total | Legendary cookie #5 + exclusive bakery aura |

---

## Section 4: NPC Rarity System & Customer Book

### 5 Rarity Tiers

| Rarity | Spawn Weight | Tip Bonus | Visual Style |
|--------|-------------|-----------|--------------|
| Common | 60% | +0% | Casual clothes, basic walk |
| Uncommon | 25% | +5% | Business casual, slightly animated |
| Rare | 10% | +15% | Stylish outfits, unique walk animation |
| Epic | 4% | +30% | Distinctive character design, special entrance |
| Legendary | 1% | +50% + special event | Full unique character, spotlight entrance |

Rarer NPCs gated by bakery level — Legendary NPCs never appear at ⭐ bakeries.

### Special Legendary NPCs

| NPC | Event |
|-----|-------|
| **Food Critic** | Observes silently, posts a "review" on exit. Served well → +20% tips for 30 min |
| **Influencer** | Films bakery. Served well → short NPC mini-rush for 5 min |
| **Health Inspector** | Surprise visit — quality must meet threshold or small tip penalty that shift |
| **Local Celebrity** | Massive tip, photogenic entrance, draws extra Common NPCs |
| **Mystery Regular** | Appears at max prestige only — hints at lore, gives unique collectible badge |

### Customer Book (player-owned Pokédex)
- ~47 total unique NPCs: Common (18), Uncommon (12), Rare (8), Epic (4), Legendary (5)
- Each entry: name, rarity badge, short backstory blurb, first served date, times served counter
- Silhouette + "???" until you serve them for the first time
- Completion %: "23/47 Customers Discovered"
- 100% completion → *"People Person"* title + special badge

---

## Section 5: Engagement Loops

### 3 Daily Challenges (reset at midnight — one of each difficulty)

| Difficulty | Example | Reward |
|-----------|---------|--------|
| Easy | "Bake 8 Snickerdoodles" | 150 coins |
| Medium | "Earn 3 five-star orders in one shift" | 300 coins + mastery XP boost |
| Hard | "Serve 5 Uncommon or rarer customers" | 500 coins + badge progress |

### Weekly Challenges (Monday reset, 7 days to complete)
Bigger goals, bigger rewards — cosmetics, titles, or upgrade vouchers:
- "Bake 50 Tier 2 cookies this week" → rare cosmetic
- "Serve 3 Legendary customers" → title unlock
- "Complete 5 shifts with 3+ players" → badge
- "Earn 2,000 coins in a single shift" → upgrade voucher

### All-Time / Lifetime Challenges (permanent, never reset)
The completionist endgame layer:
- "Bake 1,000 total cookies" → badge + *"The Thousander"* title
- "Serve all 5 Legendary NPCs" → special badge
- "Max out any Station Mastery" → exclusive legendary cosmetic
- "Complete 100 daily challenges" → rare uniform set
- "Reach Prestige 5" → *"Cookie Emperor"* title (tied to prestige system)

### 7-Day Login Streak

| Day | Reward |
|-----|--------|
| 1–6 | 50 / 75 / 100 / 125 / 150 / 175 coins |
| **7** | **Streak-exclusive cosmetic from rotating pool** |

- After day 7 is claimed, streak resets to day 1 and cycles forever
- If all streak cosmetics are already owned → day 7 pays 500 coins instead
- **15-minute minimum play required** to count a day (prevents login-and-leave)
- Missing a day doesn't break the streak — it just doesn't progress. No punishment, no pressure

### Weekly Featured Cookie
One cookie type per week earns 2× coins on delivery. Rotates every Monday. May slightly increase NPC order frequency for that type.

### Starter Grace Period
First 3 minutes of any session: NPC patience is quietly +15 seconds. Subtle enough that players won't feel it as a crutch — just smoother session starts.

---

## Section 6: Social & Co-op Hooks

### Team Synergy Bonus
- Activates automatically after **2 consecutive shifts** with the same group
- Shift 3+: "Team Synergy! 🔥" banner at shift start
- Bonus: +10% NPC tips for the whole team while synergy is active
- Resets if more than 1 player leaves between shifts

### Friend Bonus (stacks with synergy)
- Each Roblox friend in the server: +5% XP and coins
- Maximum: +15% with 3+ friends

### Server Record Board (in back room — two layers)

**Session Records** (reset when server closes — drives "one more run"):
- Most cookies baked in one shift
- Most coins earned in one shift
- Highest average quality in one shift
- Most 5-star orders in one shift

**Bakery All-Time Records** (permanent — shown on leaderboard):
- Best single-shift cookie count ever
- Best single-shift coins ever

### Named Bakery
- Set once at the end of the tutorial / first PreOpen
- Clear upfront warning: *"Choose carefully — renaming your bakery costs 50 Robux or 7,500 coins"*
- Name appears above bakery entrance and on all-time leaderboard
- 24-character limit, Roblox text filter applies
- Rename cost: **50 Robux OR 7,500 coins** (player's choice)
- 7,500 coins ≈ 5 hours of active play after upgrade spending

---

## Section 7: Collection Systems

### Badge Book
Organized by category, each badge shows name, icon, earn date, and description. Some badges hidden until discovered:

| Category | Examples |
|----------|---------|
| Milestone | "The Thousander", "5-Star Shift" |
| Station | Per-role mastery badges (Apprentice → Master per role) |
| NPC | "Starstruck" (first Legendary NPC), "People Person" (100% Customer Book) |
| Challenge | "Weekly Warrior" (10 weekly challenges complete) |
| Prestige | One unique badge per prestige level |
| Secret | Hidden — discovered through unusual in-game actions |

### Cookie Collection Book
Separate from the unlock catalog — tracks every cookie you've personally baked at least once:
- All 60 cookies shown, greyed out until baked
- Each entry: name, tier, times baked, first baked date, flavor description
- Completion %: "47/60 Cookies Baked"
- 100% completion → *"The Completionist"* title + rare badge

### Titles
Three separate sources, all equippable above head — players mix and match:

| Source | Example Progression |
|--------|-------------------|
| Player Level | Apprentice → Journeyman → Baker → Head Chef → Master Baker → Cookie Legend |
| Bakery Level | New Spot → Hidden Gem → Local Favorite → City Icon → Legendary Bakery |
| Station Mastery | Apprentice Mixer → Junior Mixer → Mixer → Senior Mixer → Expert Mixer → Master Mixer (×5 roles) |

### Uniform Collection
Earnable only — never Robux-purchasable (preserves prestige):

| Source | What You Earn |
|--------|--------------|
| Station mastery levels | Role-colored trim, role-specific apron |
| Milestone badges | Full uniform sets |
| Prestige rewards | Exclusive prestige outfits |
| Weekly/streak rewards | Limited cosmetic pieces |
| Challenge completions | Hats, gloves, accessories |

### Character Closet (in back room)
- Equip and preview all earned uniforms, hats, aprons, accessories
- ~12 hair accessory options (game-provided: hats with hair, headbands, etc.)
- Base avatar (face, skin tone, body) stays as their Roblox character
- Changes apply instantly, visible to all players in server

---

## Section 8: Monetization, Game Passes & Future Building

### Game Passes (one-time Robux purchase — never pay-to-win)

| Pass | Price | What It Does |
|------|-------|-------------|
| **VIP Baker** | ~199 R$ | VIP crown, exclusive VIP uniform, VIP chat tag, +5% coin bonus |
| **Double Mastery** | ~299 R$ | 2× Station Mastery XP gain (not coins) |
| **Jukebox** | ~99 R$ | Play curated background music in your bakery |
| **Unlimited Renames** | ~149 R$ | Change bakery name anytime for free, forever |

Not sold as passes: coin multipliers, tier skips, pay-to-win mechanics.

### Drive-Thru (Bakery Level 30 unlock)
- A window cut into the side of the existing bakery wall — no second building, no teleporting
- Locked shutter + sign visible from day one: *"Drive-Thru — Unlocks at Bakery Level 30"*
- At Level 30: shutter disappears, drive-thru NPC cars start spawning outside
- Drive-thru NPCs: less patience, smaller orders (single cookies), bigger tips per cookie (speed premium)
- Delivery via ProximityPrompt at the window — hooks into existing NPC delivery system
- Building work: cut window opening in wall, place counter, add shutter model

### Future Building Work (not game features — physical Studio construction)
- Back room expansions (upgrade board, leaderboard boards, character closet)
- Drive-thru window and car lane
- Any new areas or decorative elements as the game grows

### Long-Term Game Concepts (post-launch seeds)
| Concept | Notes |
|---------|-------|
| Outdoor seating | Extra NPC capacity, atmosphere effects |
| Catering events | Large batch timed orders |
| Farmer's market mode | Short-session popup with unique rules |
| Franchise system | Link multiple named bakeries on leaderboard |

---

## Implementation Priority Notes

These systems are additive and do not touch existing minigame gameplay. Suggested milestone order:

1. **Cookie Catalog + Menu Selection** — highest player-facing impact, drives all other grinding
2. **Bakery Level + Star Rating** — gates everything else, needs to exist first
3. **Station Mastery / Roles** — long grind loop, implement early so players start accumulating XP
4. **NPC Rarity System** — visual redesign required, can be phased in
5. **Engagement Loops** (daily/weekly challenges, streak) — can launch without these, add post-launch
6. **Collection Systems** (Badge Book, Cookie Book, Closet) — polish layer, M7+
7. **Drive-Thru** — Level 30 gate means it's naturally late-game content, implement when building is ready
8. **Game Passes** — monetization, implement before public launch
