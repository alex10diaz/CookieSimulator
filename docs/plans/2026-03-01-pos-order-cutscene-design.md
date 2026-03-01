# POS Order Cutscene — Design Doc

**Date:** 2026-03-01
**Milestone:** M3 Step 2

---

## Goal

Replace the broken POS order list with a proper order-intake flow: NPC waits at the counter, player interacts, a speech-bubble cutscene plays, and the order officially starts when the cutscene is dismissed.

---

## User Flow

1. NPC walks to POS counter and waits (E-prompt on NPC)
2. Player presses E → server generates order data, fires `StartOrderCutscene` to that player only
3. Client shows modal: NPC speech bubble + cookie name + earnings preview
4. Player clicks X **or** 5-second auto-dismiss → client fires `ConfirmNPCOrder` to server
5. Server: NPC moves to waiting area, patience timer starts, `HUDUpdate` fires to player
6. Player's HUD ActiveOrderLabel shows active order; player heads to kitchen

---

## Architecture

### Two-step order split in PersistentNPCSpawner

**Step 1 — NPC prompt triggered (existing `takeOrder`):**
- Generate: random cookie, packSize, price, isVIP
- Store order data on NPC's data entry (`data.order`)
- Set NPC state → `"cutscene_pending"` (NPC stays at POS counter)
- Disable NPC's OrderPrompt so no second trigger
- Fire `StartOrderCutscene:FireClient(player, payload)`

**Step 2 — Player confirms (`confirmOrder`):**
- Called when `ConfirmNPCOrder` remote fires from client
- Creates OrderManager entry (`OrderManager.AddNPCOrder(...)`)
- Sets `data.order.orderId`
- Starts patience ticker
- Moves NPC to waiting area spot (`NPCSpawner.MoveTo`)
- Fires `HUDUpdate:FireClient(player, ...)` with order name

### New remote: `StartOrderCutscene` (Server → Client)
Payload:
```lua
{
    npcId      = number,
    npcName    = string,
    cookieId   = string,
    cookieName = string,
    packSize   = number,
    baseCoins  = number,   -- packSize × cookie.price
    isVIP      = boolean,
}
```

### New remote: `ConfirmNPCOrder` (Client → Server)
Payload: `npcId` (number)

---

## UI — POSClient Modal

Triggered by `StartOrderCutscene`. Built entirely in code (no Studio pre-build needed).

```
┌─────────────────────────────────────┐
│  [NPC Name] says:                   │
│  "I'd like [N]x [Cookie Name]!"     │
│                                  [X]│
├─────────────────────────────────────┤
│  🍪  [Cookie Name]  ×[packSize]     │
├─────────────────────────────────────┤
│  Base earnings:   [baseCoins] coins │
│  VIP bonus: ×1.75            (VIP)  │  ← only shown if isVIP
├─────────────────────────────────────┤
│  (Auto-dismisses in 5s...)          │
└─────────────────────────────────────┘
```

- X button and 5-second countdown both: destroy modal + fire `ConfirmNPCOrder:FireServer(npcId)`
- Speed/accuracy earning breakdowns deferred to M4 (full economy pass)

---

## Files Changed

| File | Change |
|------|--------|
| `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua` | Split `takeOrder` into step 1 (cutscene fire) + step 2 (`confirmOrder`); add `"cutscene_pending"` state; wire `ConfirmNPCOrder.OnServerEvent` |
| `src/StarterGui/POSGui/POSClient.client.lua` | Remove broken `refreshPOS()`; add `StartOrderCutscene.OnClientEvent`; build modal UI; fire `ConfirmNPCOrder` on dismiss |
| Studio (MCP) | Register `StartOrderCutscene` and `ConfirmNPCOrder` RemoteEvents in `ReplicatedStorage/GameEvents` |

---

## Out of Scope (M3 Step 2)

- Speed/accuracy bonus breakdown in earnings preview → M4
- Cookie icon assets → M7 polish
- Multiplayer "order claimed by X player" coordination → M6
- Patience countdown shown in POSGui → timer already visible on NPC head billboard
