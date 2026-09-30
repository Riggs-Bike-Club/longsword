# longsword: Remastered

A remastered, actively maintained version of [longsword](https://github.com/vingard/longsword), developed by Gateway Networks.

This version of longsword is designed for compatibility with more than just the impulse Framework.

## Required content
Workshop content is required for this version of LS to work.
https://steamcommunity.com/sharedfiles/filedetails/?id=3092301722

## Features
* Realistic weapon movements
* Several attachments allowed instead of just 1
* New scope system
* ArcCW muzzle flash
* Firemode support
* Convars to control several aspects of the weapon.
* Custom crosshair that changes based on spread
* Custom WorldModel support (use SWEP.WMOffset as a table with `Position` and `Angles`)
* Custom recoil effects
* Gnomes?

## Firing sound layers

`SWEP.Primary.SoundLayers` supports sound names, random variant lists, callbacks,
and configuration tables with independent controls:

```lua
SWEP.Primary.SoundLayers = {
    {
        sound = {
            "weapons/example/body_01.wav",
            "weapons/example/body_02.wav",
        },
        level = 60,
        pitch = 100,
        volume = 0.8,
        delay = 0.02,
    },
}
```

`level` defaults to 60 and `pitch` defaults to 100. `volume` defaults to
`SWEP.SoundLayerVol` or 1, and `delay` defaults to `SWEP.Primary.SoundLayerDelay`
or 0. Explicit zero values override the shared defaults. Volume ranges from 0 to 1;
delay is measured in seconds. Variant lists play one randomly selected sound per
shot. Delayed layers are skipped if the weapon has been removed. Callback sounds
retain their existing behavior: they are called without arguments and manage their
own emission controls.

## Animation configuration

Define weapon animations in one `SWEP.Animations` table. Each action accepts an
activity constant, a model sequence name, a list of either for random selection,
or `false` to disable it. Omitted actions retain their base defaults. Replace the
whole table in derived weapons rather than modifying the shared base table.

```lua
SWEP.Animations = {
    draw = "draw",
    drawEmpty = "draw_empty",
    holster = "holster",
    idle = "idle",
    idleAimed = "idle_sighted",
    walk = "walk",
    sprint = "sprint",
    fire = { "fire1", "fire2" },
    fireLast = "fire_last",
    fireAimed = "fire_sighted",
    reload = "reload",
    reloadEmpty = "reload_empty",
    dryFire = false,
    inspect = { "inspect1", "inspect2" },
    bAnimateAimedFire = true,
}
```

| Group | Action keys |
| --- | --- |
| Equip | `draw`, `drawEmpty`, `holster`, `holsterEmpty` |
| Loops | `idle`, `idleEmpty`, `idleAimed`, `idleAimedEmpty`, `walk`, `walkEmpty`, `sprint`, `sprintEmpty` |
| Firing | `fire`, `fireAimed`, `fireLast`, `fireAimedLast`, `dryFire`, `dryFireAimed`, `worldFire` |
| Magazine reload | `reload`, `reloadEmpty` |
| Shell reload | `reloadStart`, `reloadStartEmpty`, `reloadChamber`, `reloadInsert`, `reloadFinish`, `reloadFinishEmpty` |
| Cycling | `cycle`, `cycleAimed` |
| Other actions | `inspect`, `fireMode` |
| Melee | `meleeSwing`, `meleeHit`, `meleeShove`, `meleeChargeStart`, `meleeChargeIdle`, `meleeChargeRelease` |
| Projectiles | `projectileFire`, `projectileThrow`, `projectileDraw` |
| Player | `playerAttack`, `playerReload` |

An explicit holster action enables delayed holstering. Explicit last-shot and
empty-reload actions enable their corresponding state variants. Missing optional
empty/aimed variants fall back to the normal action; `false` disables that variant
instead. Shotgun finishing selects its empty counterpart based on whether the
reload **started** empty. `bAnimateAimedFire` overrides the recoil-driven aimed
animation decision. `bUseProjectileFire` selects firing instead of throwing.

Melee variant selection remains synchronized through the existing shared random
picker. Player activities use `SetAnimation`; named player sequences require the
host framework's `ForceSequence` support and run server-side. Unconfigured
`playerReload` uses the engine's standard reload event.

Use `GetAnimation(action)` to resolve a source and `PlayAnimation(action)` to
play it. Custom weapons may add their own action keys, including player sequences
and activity maps. Legacy animation fields remain supported, but explicit unified
entries take priority. Action timing, sound, damage, and movement tuning remain in
their existing behavior settings; animation sources belong only in this table.

Regression checks can be run from the addon root with Lua 5.4:

```text
lua tests/animation_config.lua
lua tests/action_timing.lua
lua tests/melee_timing.lua
```