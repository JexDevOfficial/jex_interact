# jex_interact

> **One way to interact with everything on your server.**
> Hold a key, pick what you want, let go.

Free, open source, MIT. No dependencies.

---

## Where it came from

The hold-to-open model and drawing at a world point rather than on the HUD
come from PolyCode's **pc_interaction** (GPL-3.0). It solved those problems
first and it is worth saying so.

This is not a fork. Every line and every texture is ours. What we took were
approaches, which is why the licence is not a problem:

- `SetDrawOrigin` around a draw call, so a menu tracks a world point with no
  projection maths of ours. There is no other way to do this in RAGE.
- Sorting candidates by distance from the centre of the screen, so what you
  are looking at is what opens.
- A proximity list on a slow thread, a draw thread that only exists while the
  key is held.

**ox_target** is MIT, and the compatibility layer reproduces its export names
and argument order. Interfaces are not the protected part, and ox_target
itself ships the same thing for qtarget and rsg-target.

---

## How it draws

- A streamed `.ytd`, `jex_interaction`, loaded with
  `RequestStreamedTextureDict`. Eight textures, all ours.
- `SetDrawOrigin(x, y, z, 0)` around every draw, `ClearDrawOrigin()` after.
  **Four arguments** - three silently fails.
- Sprite heights multiplied by `GetAspectRatio()` or they stretch.
- Text through `DisplayText(CreateVarString(10, 'LITERAL_STRING', s), x, y)`,
  with every piece of text state set again before each call.
- **The engine allows 32 `SetDrawOrigin` calls a frame.** Past that
  everything silently stops drawing. `Config.MaxDrawn` keeps us under it.
- A draw thread at `Wait(0)` only while the key is held. A scan thread at
  200ms while held, 250ms otherwise.

### Focus

Proximity finds candidates; the raycast decides. Both matter:

- Screen distance from centre, sorted, nearest under `FocusThreshold` opens.
- Once you are close enough to use it, that threshold is multiplied by
  `FocusNear`, because in third person a thing you are stood next to is
  pushed to the side of the screen.
- For entities, a **swept sphere from the player's head bone** along the
  camera's forward vector confirms it. From the camera it fails in third
  person, where the camera sits behind you.

### Where the marker sits

`GetEntityCoords` returns an entity's root, which on a ped is between the feet
and on a prop is the authored pivot - usually the base, sometimes below the
mesh entirely. A marker drawn there reads as belonging to the floor, and the
confirming raycast hits whatever the thing is standing behind.

An explicit `offset` always wins. With none, placement is resolved every frame
by what the entity actually is:

| | |
|---|---|
| living ped | flat `Config.Lift.ped` |
| dead ped | model bounding-box centre, falling back to `Config.Lift.pedDead` |
| object | model bounding-box centre, falling back to `Config.Lift.object` |
| vehicle | flat `Config.Lift.vehicle` |

The bounding-box centre is taken through `GetOffsetFromEntityInWorldCoords`,
not added as a world-space Z, so it **rides the entity's rotation** and lands
mid-body whichever way a carcass fell. `GetModelDimensions` is memoised per
model - it is otherwise a native call per marker per frame.

A fixed lift cannot serve a rabbit and a bear, and a ragdoll's root height
depends on how it came to rest. That is why two dead animals side by side used
to draw at different heights.

**Distance is measured from `Registry.Reach`, never from the drawn marker.**
Lifting a wagon's marker 0.8m so it sits on the bed must not quietly cost the
option 0.8m of reach.

### The layout

```
        SAY HELLO
(E) >   STABLE
        BUY FEED
```

- The badge never moves. The list slides through it, so the live row is
  always in the same place and your eye stops travelling.
- One column. Nothing moves sideways.
- The marker says what selecting will do: `arrow_right` into a submenu,
  `ring` for something that acts, `arrow_left` for Back.
- A rule runs beside the rows, broken at the selected one. One option gets
  no rule at all.
- Plates size to the longest label, measured letter by letter. RDR3 has no
  native that measures a string, so the widths in `init.lua` are real advance
  widths rasterised from a slab serif at 64px and normalised so the mean letter
  is 1.0 - not guesses. The string is walked by UTF-8 glyph, not by byte, or a
  label with an accent counts one letter three times and the plate overshoots.
- Unselected rows dim rather than hide.
- Submenus sort to the bottom of their level, always.

---

## The API

Plain exports, one table argument, the same option shape everywhere.

| | |
|---|---|
| `AddPoint` | a place |
| `AddEntity` | something that moves |
| `AddModel` | every instance of a model |
| `AddPeds` `AddPlayers` | everyone nearby |
| `AddZone` | an area, sphere or box |
| `AddPropsInZone` | models in an area, optionally capped |
| `AddContext` `AddWhile` `AddWhileInWater` | because of what you are doing |
| `DefineState` | name a condition other scripts can use |
| `Remove` `RemoveAll` | rarely needed, cleanup is automatic |
| `Disable` `IsOpen` `Focused` | state |
| `Reload` | re-read config without restarting |

Options take `label` (string or function), `canInteract`, `onSelect`,
`event`, `serverEvent`, `args`, nested `options`, and anything else you add
comes back on `self`.

**`label` and `canInteract` are evaluated live**, throttled to
`Config.RefreshRate`. That is the thing neither competitor does.

**Cleanup is by invoking resource.** Stop a script and its interactions go.

---

## Compatibility

Answers on `ox_target`'s exports by handling `__cfx_export_ox_target_*`.
No stub resource, no renaming.

Covered: `addLocalEntity`, `removeLocalEntity`, `addEntity`, `removeEntity`,
`addModel`, `removeModel`, `addGlobalPed`, `addGlobalPlayer`, their removes,
`addSphereZone`, `addBoxZone`, `removeZone`, `disableTargeting`, `isActive`.

Not covered, warns once: `addPolyZone`, `addGlobalVehicle`,
`addGlobalObject`.

Three things their API does that had to be matched exactly, and which
guessing would have got wrong:

- **`onSelect` receives a response table**, not the entity - a clone of the
  option with `entity`, `coords` and `distance` added and the functions
  stripped.
- **`canInteract(entity, distance, coords, name, bone)`** - five arguments.
- **Re-adding an option with the same name replaces it.**

`groups` and `items` need framework knowledge this resource does not have,
so they **fail closed** until a server supplies `SetGroupCheck` /
`SetItemCheck`. Hiding is the safe way to be wrong.

It refuses to claim anything while ox_target is running, and claims on its
`onClientResourceStop` so stopping it mid-session is enough.

---

## What is left

**Before it ships**

- `client/dev.lua` must not ship. Every player would get `/jexdemo`,
  `/jexui`, `/jexcol`.
- A `LICENSE` file, and the GitHub repo.

**What has actually been run**

| | |
|---|---|
| `AddPoint` | yes, `/jexdemo` |
| `AddEntity` | yes, a live server's barbers, stables and shops through the shim |
| `AddModel` | yes, water pumps and inventory drops through the shim |
| `AddPlayers` | yes, inventory trading and banking through the shim |
| `AddZone` | yes, `/jexzone` |
| `AddPropsInZone` | yes, `/jexprops` |
| `AddWhileInWater` | yes, but it jitters - see below |
| `AddPeds` | **never** |

The water menu is drawn in world space at the player, which means it is
projected through a camera that moves with them. Damping the position did
not fix it because the position is not the problem. Drawing it at a fixed
place on screen does, since a context menu has no world anchor by
definition - that was built, reverted, and is waiting on a decision about
where on screen it should sit.

**Known gaps, documented**

- No server-side exports. A server script has to go through a client event.
- No icons. ox_target options carry them and we drop them silently.
- Text width is estimated from per-character widths, not measured. Close,
  not exact.
- No controller support.
- No qtarget or rsg-target layer.

**Ideas not built**

- Point markers visible without holding the key - always, when close, while
  holding, never. Murphy does this and it helps discovery.
- A glyph font, so text is measured rather than estimated and the whole
  interface can be reskinned including the type.

---

## Things that will bite

- **Restarting jex_interact drops everything other resources registered
  through it.** They registered once at their own start and have no idea to
  ask again. `/jexreload` exists for config so this is rarely needed.
- **`rsg-shops` and `rsg-weaponcomp` hard-depend on ox_target** in their
  fxmanifest. Removing ox_target stops them until that line goes.
- **Do not leave a stub named `ox_target`.** The takeover checks for it.
- **A sprite name that is not in the dictionary draws nothing, silently.**
  Every art change means checking the names in `JX.sprite`.
- **Never aspect-correct the row plates.** They are soft bars with no corner
  detail; the numbers that look right were set by eye.
- **`JX.Coords` still rejects a vector4.** It tests for `vector3` then `table`;
  a vec4 is neither, so it returns the world origin silently and the point is
  culled by render distance with no error. RedM config tables store points as
  vec4 with the heading in `.w` constantly. Not yet fixed.
- **A `BlockWhile` probe is asked by name and pcall'd**, so a resource that is
  not running is skipped rather than being a dependency. An export that exists
  but throws warns once and is treated as not blocking - fail open, because
  failing closed here means an eye that never opens.
- **Do not reach for `_UI_PROMPT_DISABLE_PROMPTS_THIS_FRAME`**
  (`0xF1622CE88A1946FB`). It latches: one call killed every native prompt on
  the client until a game restart. Suppressing a control also greys out any
  prompt bound to it, which is the same trap by a slower route.

---

## House rules

- RedM natives only.
- No comments in the client files. The config carries one line per setting
  and that is where explanation belongs; everything else is on the site.
- Every action a script takes is the script's business - `canInteract`
  decides what a player *sees* and is not security.
- Published exports keep their names and signatures once released.
