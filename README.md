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