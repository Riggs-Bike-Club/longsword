AddCSLuaFile()

SWEP.Base = "ls_base"
SWEP.LongswordMode = "melee"
SWEP.CSMuzzleFlashes = false

local FIREARM_ANIMATION_EVENTS = {
    [20] = true,
    [21] = true,
    [22] = true,
    [5001] = true,
    [5003] = true,
    [5011] = true,
    [5021] = true,
    [5031] = true,
    [6001] = true
}

--- Suppresses model-authored muzzle flashes and shell ejection while preserving melee sounds and other animation events.
---@realm client
---@param pos Vector
---@param ang Angle
---@param event number
---@param options string
---@param source Entity
---@return boolean|nil
function SWEP:FireAnimationEvent(pos, ang, event, options, source)
    return FIREARM_ANIMATION_EVENTS[event]
end

SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1

SWEP.Primary.Sound = Sound("WeaponFrag.Roll")
SWEP.Primary.ImpactSound = Sound("Canister.ImpactHard")

-- Per-target impact sounds, resolved most-specific first by SWEP:GetImpactSound.
-- Entity keys (player / npc / ragdoll) are matched before the surface material of
-- whatever was struck (flesh / metal / wood / concrete / glass / grate / computer
-- / plastic -- see MATERIAL_IMPACT_KEY in melee.lua), and "default" is the
-- catch-all for materials with no entry. Each value is a sound name or a list
-- (one picked at random). Left nil, ClubAttack keeps the flat Primary.ImpactSound
-- (and its ImpactSoundWorldOnly toggle) untouched.
SWEP.ImpactSounds = {
    player = {
        "Flesh_Bloody.ImpactHard",
        "Flesh.ImpactHard"
    },
    npc = {
        "Flesh.ImpactHard",
        "Flesh_Bloody.ImpactHard"
    },
    ragdoll = "Flesh.ImpactHard",
    flesh = "Flesh.ImpactHard",
    metal = "SolidMetal.ImpactHard",
    grate = "MetalGrate.ImpactHard",
    computer = "Computer.ImpactHard",
    wood = "Wood_Solid.ImpactHard",
    concrete = "Concrete.ImpactHard",
    glass = "Glass.ImpactHard",
    plastic = "Plastic_Box.ImpactHard",
    default = "Default.ImpactHard"
}

-- Light-attack swing sequences: an activity, a raw sequence name, or a list of either (one picked at random each swing). Left nil, the swing falls back to ACT_VM_MISSCENTER.
SWEP.SwingAnims = nil

-- Swing sequences played instead of SwingAnims when the swing actually connects, in the same activity / sequence name / list forms. Left nil, a hit looks no different from a miss; set it and every light swing sweeps its hull once before the animation is chosen.
SWEP.HitAnims = nil

-- Shove: a quick right-click tap that plays ShoveAnim and lands a short-range,
-- mostly-cosmetic hit (ShoveDamage defaults to 0 -- it staggers and shoves more
-- than it hurts). Off until ShoveEnabled is set with a ShoveAnim. When the weapon
-- also charges, the tap that would shove and the hold that would charge share the
-- right mouse button.
SWEP.ShoveEnabled = false
SWEP.ShoveAnim = nil
SWEP.ShoveDamage = 0
SWEP.ShoveRange = 45
SWEP.ShoveHullSize = nil    -- falls back to Primary.HullSize
SWEP.ShoveDelay = nil       -- cooldown; falls back to the shove animation's length
SWEP.ShoveHitDelay = 0.05   -- wind-up before the hit is traced
SWEP.ShoveSound = nil

-- Charged heavy attack: hold right-click to wind up (BeginAnim into a looping
-- IdleAnim) and release to swing (EndAnim). Strength scales with how long it was
-- held, from MinMultiplier at Threshold seconds up to Multiplier at Time seconds,
-- against a reach of Primary.Range * RangeMultiplier. A charge let go before
-- Threshold falls back to a shove. Override the WHOLE table in your weapon (like
-- SWEP.Spread) so you don't mutate the shared default.
SWEP.MeleeCharge = {}
SWEP.MeleeCharge.Enabled = false
SWEP.MeleeCharge.BeginAnim = ACT_VM_ATTACK_CHARGE_BEGIN
SWEP.MeleeCharge.IdleAnim = ACT_VM_ATTACK_CHARGE_IDLE
SWEP.MeleeCharge.EndAnim = ACT_VM_ATTACK_CHARGE_END
SWEP.MeleeCharge.Threshold = 0.2   -- seconds held below which the release is treated as a shove
SWEP.MeleeCharge.Time = 1          -- seconds to reach a full-strength charge
SWEP.MeleeCharge.MinMultiplier = 1 -- damage multiplier at Threshold
SWEP.MeleeCharge.Multiplier = 2    -- damage multiplier at a full charge
SWEP.MeleeCharge.RangeMultiplier = 1
SWEP.MeleeCharge.HullSize = nil    -- falls back to Primary.HullSize
SWEP.MeleeCharge.HitDelay = nil    -- wind-up before the hit; falls back to Primary.HitDelay
SWEP.MeleeCharge.Sound = nil       -- falls back to Primary.Sound
