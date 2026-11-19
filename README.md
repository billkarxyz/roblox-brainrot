# Brainrot Bazaar

![make.fun bounty](https://make.fun/badge/roblox-brainrot-01.svg)
![rank](https://make.fun/badge/roblox-brainrot-01/billkarxyz/roblox-brainrot/rank.svg)
![reward](https://make.fun/badge/roblox-brainrot-01/billkarxyz/roblox-brainrot/reward.svg)

A 3D brainrot game in the Steal a Brainrot genre, built for make.fun's
[Make the best AI Roblox brainrot game](https://make.fun/bounty/roblox-brainrot-01)
bounty (roblox-brainrot-01). The whole 3D world is built procedurally at
runtime by Luau server scripts — every part of the bazaar, every brainrot
character, is made of Parts, so the game needs no Studio-saved geometry.

## How it plays

You spawn in a green bazaar crossed by a central conveyor belt. Absurd
brainrot characters walk the belt from one end to the other — click one to
buy it (if you can afford it) and it moves to a slot on your base plot,
where it earns cash every second. Climb the ladder from Common to Mythic,
steal brainrots off other players' bases and dash home with them, lock your
own base to stop thieves, dodge the falling durians of the Durian Storm,
and rebirth for a permanent x2 income multiplier each time.

- **Buy:** click a brainrot walking the conveyor. It costs cash and needs a
  free slot on your base (8 slots per base).
- **Earn:** every brainrot on your base pays its $/s every second, times
  your rebirth multiplier. Cash ticks up live in the HUD.
- **Steal:** click another player's brainrot to grab it — it floats above
  you while you run home. Reach your own base to keep it. Each brainrot has
  a 15-second steal cooldown, and a base lock (30 seconds, 60-second
  cooldown) blocks steals completely.
- **Events:** every ~3 minutes a Durian Storm warning sounds, then spiky
  durians rain on the bazaar for ~20 seconds and knock players flying.
- **Rebirth:** at a cash threshold, reset your cash and brainrots for a
  permanent x2 income multiplier. The cost grows fivefold per rebirth.

## The cast

Twelve original characters themed on Indonesian street food, across five
rarities (Common, Rare, Epic, Legendary, Mythic):

| Character | Rarity | Cost | Income |
| --- | --- | --- | --- |
| Kopi Kenyal | Common | $50 | $1/s |
| Kerupuk King | Common | $100 | $2/s |
| Sate Samurai | Rare | $400 | $6/s |
| Cendol Centurion | Rare | $750 | $10/s |
| Nasi Goreng Ninja | Epic | $2,000 | $25/s |
| Martabak Mage | Epic | $3,500 | $40/s |
| Durian Diva | Legendary | $9,000 | $100/s |
| Rendang Ranger | Legendary | $15,000 | $160/s |
| Gado-Gado Guardian | Legendary | $20,000 | $220/s |
| Becak Baron | Mythic | $35,000 | $350/s |
| Es Teh Emperor | Mythic | $50,000 | $500/s |
| Bakso Behemoth | Mythic | $75,000 | $750/s |

Every character is built from Parts in its own silhouette (round, tall,
wide, spiky, winged, or hatted), with a floating label showing its name,
rarity in its rarity color, and income per second. The in-game
Brainrotpedia panel lists the whole cast with rarities and rates.

## Layout

- `src/shared/BrainrotDefs.luau` — the cast: characters, rarities, spawn
  weights, and the rarity-weighted random picker.
- `src/server/WorldBuilder.luau` — builds the world at server start:
  baseplate, spawn pad, conveyor belt, 8 fenced base plots with 8 slots
  each, trees, lamps, and market stalls; owns plot assignment and slots.
- `src/server/BrainrotFactory.luau` — builds each brainrot Model from
  Parts per its shape tag, with its label and ClickDetector.
- `src/server/Economy.luau` — server-authoritative cash (leaderstats),
  the 1-second income tick, and the owned-brainrot registry.
- `src/server/BrainrotSpawner.luau` — spawns a random brainrot on the
  conveyor every ~8 seconds, walks it along the belt, and validates buys.
- `src/server/StealSystem.luau` — stealing (follow-the-thief loop),
  per-brainrot steal cooldown, and the base lock.
- `src/server/RebirthSystem.luau` — rebirth thresholds and the permanent
  income multiplier.
- `src/server/EventSystem.luau` — the Durian Storm hazard event.
- `src/server/init.server.luau` — bootstrap: RemoteEvents, module wiring,
  player join/leave, and the brainrot click router.
- `src/client/Game.client.luau` — the HUD: cash/income/multiplier top bar,
  Lock Base and Rebirth buttons, storm banner, toasts, Brainrotpedia.
- `main.ts` (Node 22, standard library only) hands the game in: it copies
  `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output` and
  writes `/output/dossier.json` with `vendor/makefun-roblox.ts`, the kit's
  copy, unchanged.

## Build it

    rojo build default.project.json --output game.rbxl

Run it as the grader does, writing `out/` in place of `/output`:

    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

The rules are on the bounty's page (/bounty/roblox-brainrot-01) and in the
kit's RULES.txt, which gives every command in order (Before you submit,
then Enter).
