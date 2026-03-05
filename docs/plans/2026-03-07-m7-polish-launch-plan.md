# M7: Polish + Launch Prep — Plan

> **Goal:** Ship a complete, polished, publicly-listed game on Roblox.
> Split into two tracks: **Creator Hub** (platform config, no code) and **In-Game Polish** (code/Studio).

---

## Track A: Creator Hub Setup
> Done at create.roblox.com → your game → Configure

### A1: Basic Settings
- [ ] **Name:** `Cookie Empire: Master Bakery`
- [ ] **Description:** 2–3 sentences covering the hook. Suggested:
  > *Run your own Crumbl-inspired cookie bakery! Mix, bake, frost, and deliver 6 unique cookie types to hungry customers. Work solo or co-op with up to 6 players in this fast-paced baking simulator.*
- [ ] **Genre:** `All Genres` (or `Town and City`)
- [ ] **Max Players:** `6`
- [ ] **Server Size:** `6`

### A2: Icon
- [ ] Design a 512×512 PNG — bright colors, cookie/bakery imagery, NO text
- [ ] Upload via Configure → Icon
- [ ] Check thumbnail preview at small sizes (64px) to confirm it reads well

### A3: Thumbnails & Videos
Upload up to 10 thumbnails (1920×1080 PNG). Suggested shots:
- [ ] Mixer minigame in action
- [ ] Frosting minigame close-up
- [ ] Fridge → delivery carry sequence
- [ ] Full bakery overhead / establishing shot
- [ ] EndOfDay summary screen showing stars + coins
- [ ] (Optional) Short screen-recorded gameplay clip, max 30s

### A4: Access & Age
- [ ] **Playability:** Private during final testing → flip to Public on launch day
- [ ] **Age Recommendation:** All Ages (no violence/mature content)
- [ ] **Paid Access:** Off

### A5: Avatar Settings
- [ ] **Avatar Type:** R15
- [ ] **Body Scale:** All (lets players use their own proportions)
- [ ] **Gear:** All gear types OFF
- [ ] **Accessories:** All ON (players can wear their own hats/faces)

### A6: Permissions & Collaborators
- [ ] Add any trusted testers as Collaborators with Edit or Play access
- [ ] Keep Universe private until launch-ready

### A7: VIP Servers
- [ ] Enable VIP Servers
- [ ] Price: **100 Robux/month** (standard for simulators)
- [ ] Good passive income and great for friend groups

### A8: Developer Products (Coins)
Create in Creator Hub → Monetization → Developer Products:
- [ ] `coins_500`  — 500 coins — **25 Robux**
- [ ] `coins_1500` — 1,500 coins — **65 Robux**
- [ ] `coins_5000` — 5,000 coins — **200 Robux**

Note their **Product IDs** — you'll need them when wiring `MarketplaceService:ProcessReceipt` in-game (M7 code task).

### A9: Game Passes
Create in Creator Hub → Monetization → Passes:
- [ ] **2× Coins** — 149 Robux — doubles all coin payouts permanently
- [ ] **Speed Boost** — 99 Robux — 15% faster movement while carrying
- [ ] **Exclusive Cosmetic Pack** — 199 Robux — unlocks a unique hat/apron set

Note their **Pass IDs** — needed for `MarketplaceService:UserOwnsGamePassAsync` checks in-game.

### A10: Social Links
- [ ] Discord invite link (if you have a server)
- [ ] Twitter/X (optional)

### A11: Version History Checkpoint
- [ ] Before publishing publicly, note the current version number in Creator Hub → Version History
- [ ] This is your rollback point if a bad update ships

---

## Track B: In-Game Polish (Code / Studio)

### B1: Monetization wiring
**Files to create:**
- `src/ServerScriptService/Core/MonetizationService.server.lua`

Wire up `MarketplaceService:ProcessReceipt` for coin packs and `UserOwnsGamePassAsync` for passes. Check passes on PlayerAdded and apply multipliers via PlayerDataManager. This is the only M7 task with significant new code.

### B2: Sound effects pass
Add ambient + interaction sounds in Studio:
- [ ] Mixer: whirring sound while minigame runs
- [ ] Oven: ding when timer completes
- [ ] Fridge open/close: refrigerator door sound
- [ ] Delivery success: cash register / cheer
- [ ] Coin pickup: satisfying chime
- [ ] Rush Hour start: upbeat jingle

Use free Roblox audio assets (search in Creator Hub Marketplace). Wire via `Sound:Play()` in existing client scripts.

### B3: Particle effects pass
- [ ] Delivery success: star burst or coin shower particle at counter
- [ ] Perfect order (5 stars): sparkle effect on the box
- [ ] Rush Hour start: confetti or speed lines effect on HUD

### B4: UI polish
- [ ] EndOfDay summary: animate stats counting up (tween from 0 to final value)
- [ ] HUD coin counter: brief scale pulse on coin gain
- [ ] Rush Hour HUD banner: flashing red/orange banner with timer
- [ ] Loading screen: simple branded splash with game name + icon

### B5: Balancing pass
Play 5 full sessions and tune:
- [ ] NPC patience timer feels fair but creates urgency
- [ ] Coin rewards feel satisfying but not overpowered
- [ ] Rush Hour timing (3–7 min window) feels well-paced in 10-min Open
- [ ] Tutorial length — does it overstay its welcome?

### B6: Pre-launch testing checklist
- [ ] Solo play: all 6 cookie types complete full pipeline without errors
- [ ] 2-player co-op: no session conflicts, no carry state desyncs
- [ ] Tutorial: first-time player flow is clear end-to-end
- [ ] EndOfDay summary: displays correct stats
- [ ] DataStore: coins/level persist across rejoin
- [ ] No warnings/errors in Studio output after a full 10-min session
- [ ] Mobile test: UI is readable and prompts are reachable on phone screen size

### B7: Launch day
- [ ] Flip game to **Public** in Creator Hub
- [ ] Post in your Discord / social channels
- [ ] Monitor output logs for the first hour via Studio → Live Game testing
- [ ] Check Creator Hub analytics after 24h (visits, retention, revenue)

---

## Notes
- **Monetization code (B1)** is the only task requiring a new script. Everything else in Track B is Studio tweaks or platform config.
- **Track A** can be done any time — it doesn't require a code session. Do it before launch day.
- **Cosmetics** from the M6 unlock shop are separate from Game Pass cosmetics — M6 cosmetics are earned in-game with coins, Game Pass cosmetics are Robux purchases.
