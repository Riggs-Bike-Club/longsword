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

### Animation events

Define `SWEP.AnimationEvents` using the actual sequence name or activity constant
passed to `PlayAnim`, including sources selected through `SWEP.Animations`:

```lua
SWEP.AnimationEvents = {
    reload_empty = {
        {time = 20 / 30, sound = "weapons/rifle/magout.wav"},
        {time = 53 / 30, sound = "weapons/rifle/magin.wav", volume = 0.8},
    },
    [ACT_VM_DRAW] = {
        {time = 0, sound = "weapons/rifle/draw.wav"},
    },
}
```

`time` is seconds from playback start (default zero). Sounds accept a path or a
random-choice list, with optional `level`, `pitch`, and `volume`. An optional
`callback = YourNamedFunction` receives `(weapon, event)` at the same time.
Sounds play once on the predicting owner; the server sends audio to other nearby
players. Singleplayer audio and all callbacks run on the server. Both server and
clients need the model. Prediction replays do not restart the event scheduler.
Starting another valid animation cancels pending events. Events also check that
the original owner is alive and still holding the weapon. Preserving a loop's
cycle cancels pending events without replaying them. Timings assume normal
playback speed. Existing model-authored events and generic deploy sounds remain
enabled; avoid defining duplicates (override `GetDeploySound` when needed).
This is Longsword's event format, not a drop-in ARC9/TFA table parser.

Regression checks can be run from the addon root with Lua 5.4:

```text
lua tests/animation_config.lua
lua tests/action_timing.lua
lua tests/melee_timing.lua
```

## Trigger delay, heat and gun bashing

These features are opt-in and use predicted network state. Define them in the
weapon alongside `Animations` and `AnimationEvents`:

```lua
SWEP.BottomlessClip = true
SWEP.Primary.ClipSize = -1
SWEP.TriggerDelay = true
SWEP.TriggerDelayTime = 1.25
SWEP.TriggerReleaseAnimation = true
SWEP.Overheat = true
SWEP.HeatPerShot = 1
SWEP.HeatCapacity = 75
SWEP.HeatDissipation = 25
SWEP.HeatDelayTime = 0.25
SWEP.HeatLockout = false
SWEP.HeatFix = true
SWEP.HeatFixProgress = 0.8
SWEP.Bash = true
SWEP.BashSecondary = true
SWEP.BashDamage = 50
SWEP.BashRange = 64
SWEP.PreBashTime = 0.5
SWEP.PostBashTime = 0.5
SWEP.Animations = {
    trigger = "spinup",
    untrigger = "spindown",
    fix = "heat",
    bash = "melee",
}
```

Bottomless weapons consume reserve ammo directly, then any rounds left in an old
magazine after conversion. They cannot reload. Trigger delay starts once per
hold; release, sprinting, lowering, holstering and death cancel it. Set
`TriggerReleaseAnimation` to play wind-down after firing as well as after a
cancelled wind-up. `SetSemiAutomatic(true)` limits this system to one shot per
hold without modifying the shared `Primary` table.

Heat starts cooling after the shot cooldown plus `HeatDelayTime`. Cooling also
accounts for time spent holstered. At capacity, `fix` plays after this delay and
blocks firing through the animation; `HeatFix` clears heat at `HeatFixProgress`.
`HeatLockout` additionally blocks until completely cool. `GetCurrentHeat()`
returns cooled heat; `GetHeatAmount()` is the last stored snapshot. Holstering
cancels the recovery animation without clearing a pending overheat.

`Bash` enables use-plus-primary bashing. `BashSecondary` additionally assigns bash
to secondary attack and disables ironsights; leave it unset for normal ADS.
`BashMinProgress` sets the fraction of the bash animation required before another
action, bounded by `PreBashTime + PostBashTime`.

Animation events can set `stopSound` to a sound path or list, for example to stop
wind-up audio when wind-down begins. Primary firing audio accepts `SoundLevel`,
`SoundPitch` and `SoundVolume`. New features reserve network slots only on weapons
that enable them; existing weapons retain their original slots. Respawn weapons
after enabling/disabling features that change their network table.

Additional optional port settings include `Primary.DamageMin`, `RangeMin` and
`RangeMax` (linear falloff in Source units), `Primary.ImpactEffect`,
`AimDownSightsTime`, `SprintToFireTime`, `SpeedMultSights`, `SpeedMultShooting`,
`EnterSightsSound`, `ExitSightsSound`, and `CameraAttachment` with `CameraScale`
and `CameraScaleAimed`. `Recoil.Up`, `Side`, `RandomUp`, `HipFireMultiplier`,
`CrouchMultiplier` and `Kick` enable directional recoil without integer rounding.
`Spread.Multiplicative` supports `HipFireMod`, `HipFireAdd`, `MoveMod`, `MoveAdd`
and `HeatAdd`; `Spread.Radial` selects a radial bullet distribution.

Additional regression checks:

```text
lua tests/heat_trigger.lua
lua tests/directional_recoil.lua
```

### Optional third-person IK

Set `SWEP.TPIK = true` on a compatible weapon. Other weapons retain their normal
world models. The HMG port enables this with per-weapon offsets.
Clients can use `longsword_tpik 0` to disable it, `longsword_tpik_others 0` to skip
other players, or `longsword_tpik_distance 1500` to set the distance cutoff.

```lua
SWEP.TPIK = true
SWEP.TPIKOffset = {
    Pos = Vector(-12.5, 10, -2.5),
    Ang = Angle(20, 0, 150),
    Scale = 1,
}
```

TPIK uses `ViewModel` (or `TPIKModel`) as an animated third-person model and
matches its ValveBiped hand/finger bones to the player's skeleton. Use a model
whose visible geometry is appropriate for third person: baked-in arms are not
removed automatically. `TPIKOffset` uses ARC9's right-hand axes and rotation
order, independently of `WMOffset`. `TPIKAnchor` can select another player bone;
`TPIKNoLeftHand = true` leaves the support arm alone. `TPIKIdleSequence` defaults
to `idle`. Missing bones or sequences fall back to normal world-model rendering.
Dropped weapons also use their normal world model.

Selected animation names and start times replicate through optional weapon
DataTable slots, including reload, bash, trigger and heat transitions. Respawn
weapons when changing the `TPIK` flag so their DataTables are rebuilt. Both realms
need the updated base and the animation model. Bone changes are render-only;
models are removed when the weapon becomes inactive, is removed or leaves range.

This is a Longsword implementation of [ARC9's TPIK approach](https://github.com/HaodongMo/ARC-9),
with animated hand targets and a two-segment arm solver. It does not require ARC9.
ARC9 attachment IK, custom pose layers and its animation-pack-specific offsets
are not imported. Configure and check offsets for each model and player rig.

Run the standard Lua regression scripts for replicated animation state. Run
`tests/tpik.lua` in the Garry's Mod client Lua realm for the native Vector solver
checks; it does not run in standalone Lua 5.4.

Raised and lowered weapons can use separate absolute offsets. The replicated
framework `Player:IsWeaponRaised()` state selects the target when available,
with `GetLowered()` as the standalone fallback. Transitions take `TPIKTransitionTime`
seconds (default `0.2`, or `0` to snap). Sprinting alone does not select lowered.

```lua
SWEP.TPIKOffsets = {
    raised = {Pos = Vector(-5, 10, -5), Ang = Angle(20, 0, 150), Scale = 1},
    lowered = {Pos = Vector(-8.3, 4, -6), Ang = Angle(-7, 0, 180), Scale = 1},
}
SWEP.TPIKTransitionTime = 0.2
```

`TPIKOffset` remains the fallback for existing weapons and missing raised fields.
Missing lowered fields inherit the raised values. The HMG's existing tuned offset
is its raised state; adjust `TPIKOffsets.lowered` independently.

`SWEP.HeadTracksAim = true` optionally aligns the player's head with their eye
angles, independently of the TPIK client toggle. The HMG enables this to correct
its player animation's sideways/downward head pose. It requires the standard
ValveBiped head and an `eyes` attachment; missing rigs retain their normal pose.
`HeadAimYawLimit` (default 85 degrees) and `HeadAimPitchLimit` (60 degrees) limit
neck rotation. Taunts and framework forced sequences retain their authored poses.
The correction only affects rendering and clears when switching weapons.
