# Fridge → Oven Carry System Design

**Date:** 2026-02-25

## Overview

Players pull dough trays from cookie-type fridges and physically carry them to an oven, where depositing the tray transitions into the oven minigame. This is a mid-workflow step: Mix → Dough → **Fridge → Carry → Oven** → Frost → Warmer.

## Context

- 6 fridges, one per cookie type (pink_sugar, chocolate_chip, birthday_cake, cookies_and_cream, snickerdoodle, lemon_blackraspberry)
- Each fridge starts at 0 stock, max 4 batches
- Stock is filled upstream by the dough station
- 2 ovens (Oven1, Oven2), each has an InsideRack and OvenPrompt
- Pan/PanWithCookie models already exist in Workspace as visual references

## Scripts & Assets

| Path | Purpose |
|------|---------|
| `ServerScriptService/FridgeOvenSystem.server.lua` | All server logic |
| `ReplicatedStorage/Remotes/GrabTray` | RemoteEvent: client → server to grab tray |
| `ReplicatedStorage/Remotes/DepositTray` | RemoteEvent: client → server to deposit tray |
| `ServerStorage/PanTemplate` | Pan model cloned per carry instance |
| `ServerStorage/Events/DoughBatchComplete` | BindableEvent fired by dough system with cookieType |

## Fridge Stock

- Server table: `fridgeStock[cookieType] = 0` for all 6 types at game start
- Max stock: 4 per fridge
- `FridgeDisplay` BillboardGui updated on every stock change
- `FridgePrompt` enabled only when stock > 0 and no player is already carrying from it

## Dough → Fridge Interface

The dough station fires `ServerStorage/Events/DoughBatchComplete` with `cookieType` as argument. `FridgeOvenSystem` listens and increments that fridge's stock (capped at 4), then updates the display and enables the prompt if it was at 0.

## Grab Flow

1. Player walks up → `FridgePrompt` triggers → client fires `GrabTray` with `cookieType`
2. Server validates: player not already carrying + stock > 0
3. Server clones `PanTemplate`, welds to player HumanoidRootPart (offset: forward + up)
4. Server raises both arms via Motor6D on Right Shoulder + Left Shoulder joints
5. Decrement stock, update FridgeDisplay, disable FridgePrompt

## Carry State

```lua
carryState = {
  [player] = {
    cookieType = "pink_sugar",
    panModel   = Model
  }
}
```

Cleaned up on `Players.PlayerRemoving`.

## Deposit Flow

1. `OvenPrompt` enabled only when player's carry state is set
2. Player triggers `OvenPrompt` → client fires `DepositTray` with `ovenId`
3. Server validates carry state exists
4. Server un-welds pan, positions it on oven's `InsideRack`
5. Server resets arm Motor6D joints to default angles
6. Clears carry state, re-enables fridge prompt if stock > 0
7. Fires hook for oven minigame to begin

## Arm Animation

Uses Motor6D joint manipulation on the server (replicates to all clients):
- `Right Shoulder` and `Left Shoulder` rotated to raise arms into carrying position
- Stored original angles restored on deposit or disconnect

## Out of Scope

- Oven minigame logic (hook only — separate system)
- Warmer/display fridge (end of workflow, separate system)
- Multiple tray carry (one tray per player at a time)
