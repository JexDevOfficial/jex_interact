<div align="center">

# jex_interact

**One way to interact with everything on your server.**
Hold a key, pick what you want, let go.

[![Release](https://img.shields.io/github/v/release/JexDevOfficial/jex_interact?style=flat-square&color=B7FF3C)](../../releases/latest)
[![License](https://img.shields.io/badge/license-MIT-B7FF3C?style=flat-square)](LICENSE)

[Download the latest release](../../releases/latest) · [Documentation](https://jex-dev.com/docs.html#sys-jex-interact-about) · [jex-dev.com](https://jex-dev.com)

</div>

---

Free, open source, MIT. No dependencies.

Hold the key and everything you can use nearby gets a marker. Look at one
and its options open beside it, drawn in the world, not pinned to your HUD.
Scroll, let go, done.

It also answers on **ox_target's exports**, so scripts written for
ox_target work through it with no edits — including escrowed ones nobody
can open.

## Install

1. Grab **`jex_interact.zip`** from the [latest release](../../releases/latest)
2. Unzip it into your `resources` folder
3. Ensure it

```cfg
ensure jex_interact
```

To take over from ox_target, stop ox_target and ensure this in its place.
Every script that calls `exports.ox_target` now draws through
jex_interact.

> Take the zip from the release, not the green **Code → Download ZIP**
> button. That one gives you a folder named `jex_interact-main`, which you
> would have to rename.

## What it does

**Draws where the thing is.** Menus sit on the object, ped or place they
belong to and track it as it moves.

**Opens what you are looking at.** Candidates are sorted by distance from
the centre of the screen, then confirmed with a raycast from your head, so
it works in first and third person.

**Puts the marker in the right place.** Dead animals and props are marked
at the middle of their model, not at their feet or pivot, and it rides the
entity's rotation. A rabbit and a bear both get it right.

**Keeps the selected row still.** The list slides through the badge, so
your eye stays in one place.

**Stays live.** Labels and `canInteract` are re-evaluated while the menu is
open, so "The hour is 9" turns into "The hour is 10" without reopening.

**Cleans up after itself.** Stop a script and everything it registered
goes with it.

**Costs nothing while you are not holding the key.** The draw thread only
exists while it is held.

## Using it

> The full guide — every export, option, state and setting, with
> examples — is on the **[documentation site](https://jex-dev.com/docs.html#sys-jex-interact-about)**.
> What follows is the short version.

Plain exports, one table, the same option shape everywhere.

```lua
exports.jex_interact:AddPoint {
    coords = vec3(-178.9, 626.7, 114.1),
    options = {
        {
            label = 'Buy feed',
            onSelect = function() TriggerServerEvent('stable:buyFeed') end,
        },
        {
            label = 'Stable',
            options = {
                { label = 'Stable your horse', event = 'stable:store' },
                { label = 'Retrieve a horse', event = 'stable:retrieve' },
            },
        },
    },
}
```

```lua
exports.jex_interact:AddModel {
    models = { `p_waterpump01x` },
    options = {
        {
            label = 'Drink',
            canInteract = function(self, entity) return not IsPedOnMount(PlayerPedId()) end,
            serverEvent = 'thirst:drink',
        },
    },
}
```

### Exports

| | |
|---|---|
| `AddPoint` | A place |
| `AddEntity` | Something that moves |
| `AddModel` | Every instance of a model |
| `AddPeds` / `AddPlayers` | Everyone nearby |
| `AddZone` | An area — `radius` for a sphere, `size` for a box |
| `AddPropsInZone` | Models inside an area, optionally capped with `max` |
| `AddContext` | Because of what you are doing, not where you are |
| `AddWhile(state, data)` / `AddWhileInWater` | While a named state is true |
| `DefineState(name, check)` | Name a condition other scripts can use |
| `Remove(id)` / `RemoveAll()` | Rarely needed, cleanup is automatic |
| `Disable(bool)` / `IsOpen()` / `Focused()` | State |
| `Reload()` | Re-read `config.lua` without restarting |

Every `Add*` returns an id.

### Fields

On the registration: `coords`, `entity`, `models`, `options`, `distance`
(how close to use it), `render` (how close to see it), `offset`, `bone`,
`ignoreLos`, `id`.

On each option:

| | |
|---|---|
| `label` | A string, or a function returning one |
| `canInteract` | `function(self, entity)` — return false to hide it |
| `onSelect` | `function(self, entity)`, called on select |
| `event` | Client event, triggered with `(self, entity)` |
| `serverEvent` | Server event, triggered with `args` |
| `options` | A submenu |

Anything else you put on an option comes back on `self`.

`canInteract` decides what a player **sees**. It is not security — check
again on the server.

## ox_target

Handled by answering `__cfx_export_ox_target_*` directly. No stub resource,
no renaming.

**Covered:** `addLocalEntity`, `removeLocalEntity`, `addEntity`,
`removeEntity`, `addModel`, `removeModel`, `addGlobalPed`,
`addGlobalPlayer` and their removes, `addSphereZone`, `addBoxZone`,
`removeZone`, `disableTargeting`, `isActive`.

**Not covered,** warns once: `addPolyZone`, `addGlobalVehicle`,
`addGlobalObject`.

Options using `groups` or `items` stay hidden until your server tells
jex_interact how to check them — hiding is the safe way to be wrong:

```lua
exports.jex_interact:SetGroupCheck(function(groups) ... return true end)
exports.jex_interact:SetItemCheck(function(items) ... return true end)
```

It will not claim anything while ox_target itself is running.

> Some scripts list `ox_target` as a hard `dependency` in their
> fxmanifest — `rsg-shops` and `rsg-weaponcomp` among them. Remove that
> line or they will not start without it. Do not leave an empty resource
> named `ox_target` behind either; the takeover checks for it.

## Config

Everything lives in `config.lua`, one line of explanation per setting.

| | |
|---|---|
| `Config.Key` | The hold key |
| `Config.SubMenu` | `'menu'` to open submenus in place, `'inline'` to nest them |
| `Config.InteractDistance` / `RenderDistance` | Use and see ranges |
| `Config.LineOfSight` | Hide anything behind a wall |
| `Config.Colours` / `Config.Palette` | Colours, by name or `{ r, g, b }` |
| `Config.Scale` | Raise on 1440p and up |
| `Config.Disable` | When it stays shut — dead, mounted, cuffed… |
| `Config.BlockWhile` | Stay shut while an inventory or progress bar is up |
| `Config.Takeover` | Which scripts' exports to answer on |

Changed something? `/jexreload` applies it without a restart.

## Credits

The hold-to-open model and drawing at a world point come from PolyCode's
**pc_interaction** (GPL-3.0). It solved those problems first and it is
worth saying so. This is not a fork — every line and every texture here is
ours; what we took were approaches.

**ox_target** (MIT) — the compatibility layer reproduces its export names
and argument order.

## License

[MIT](LICENSE). Use it, change it, ship it.
