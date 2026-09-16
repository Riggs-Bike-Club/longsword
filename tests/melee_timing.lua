--- Runs the melee scheduling regression checks in Lua 5.4 from the addon root.
local sourceFile = assert(io.open("lua/weapons/ls_base/common/melee.lua", "r"))
local source = sourceFile:read("*a")
sourceFile:close()
source = source:gsub("!=", "~="):gsub("!", "not ")
local pending = {}
local methods = {}
local env = {
    SWEP = methods,
    SERVER = true,
    CLIENT = false,
    PLAYER_ATTACK1 = 1,
    timer = {
        Simple = function(delay, callback)
            pending[#pending + 1] = {
                delay = delay,
                callback = callback
            }
        end,
    },
    CurTime = function()
        return 100
    end,
    IsValid = function(value)
        return value ~= nil and not value.removed
    end,
    istable = function(value)
        return type(value) == "table"
    end,
    Lerp = function(fraction, low, high)
        return low + fraction * (high - low)
    end,
    util = {
        SharedRandom = function(seed, low, high)
            assert(seed == "longsword.melee.animation" and low == 1 and high == 3)
            return 2.5
        end,
    },
    math = setmetatable({
        Clamp = function(value, low, high)
            return math.max(low, math.min(high, value))
        end,
    }, {
        __index = math
    }),
}

setmetatable(env, {
    __index = function(_, key)
        if key:match("^MAT_") then
            return key
        end
        return _G[key]
    end,
})

assert(load(source, "melee.lua", "t", env))()
local passed = 0
local function Check(value, message)
    assert(value, message)
    passed = passed + 1
end

local function Near(a, b)
    return math.abs(a - b) < 0.000001
end

local function Weapon()
    pending = {}
    local owner = {
        alive = true
    }

    local weapon = setmetatable({
        Primary = {
            Damage = 20,
            Range = 50,
            HullSize = 8,
            HitDelay = 0.1,
            Delay = 0.8,
            Sound = "swing"
        },
        selected = "quick",
        sounds = {},
        hits = {},
        picks = 0,
    }, {
        __index = methods
    })

    owner.active = weapon
    function owner:GetActiveWeapon()
        return self.active
    end

    function owner:Alive()
        return self.alive
    end

    function owner:SetAnimation(anim)
        self.animation = anim
    end

    function weapon:GetOwner()
        return owner
    end

    function weapon:GetSwingAnim()
        self.picks = self.picks + 1
        return self.selected
    end

    function weapon:WouldMeleeHit()
        return true
    end

    function weapon:ClubAttack(damage, range, hullSize)
        self.hits[#self.hits + 1] = {damage, range, hullSize}
    end

    function weapon:ViewPunch()
        self.punched = true
    end

    function weapon:EmitSound(soundName)
        self.sounds[#self.sounds + 1] = soundName
    end

    function weapon:SetNextPrimaryFire(time)
        self.nextFire = time
    end

    function weapon:PlayAnim(anim)
        self.animation = anim
        return 1.7
    end

    function weapon:QueueIdle()
        self.queuedIdle = true
    end
    return weapon, owner
end

local weapon = Weapon()
Check(weapon:PickMeleeAnim({"first", "second"}) == "second", "Swing variants use the shared prediction seed")
Check(weapon:PickMeleeAnim({}) == nil, "Empty variant lists fall back safely")
Check(weapon:PickMeleeAnim("quick") == "quick", "Single named animations are unchanged")
weapon:DoMeleeSwing()
Check(weapon.picks == 1 and weapon.animation == "quick", "Select the swing exactly once")
Check(Near(pending[1].delay, 0.1) and Near(weapon.nextFire, 100.8), "Preserve legacy Primary timings")
Check(#weapon.hits == 0, "Damage must wait for its hit delay")
pending[1].callback()
Check(#weapon.hits == 1 and weapon.punched and weapon.queuedIdle, "Delayed damage and idle still run")
Check(weapon.sounds[1] == "swing", "Legacy sounds remain immediate")
weapon = Weapon()
weapon.SwingTimings = {
    quick = {
        HitDelay = 7 / 30,
        Delay = 36 / 30
    }
}

weapon:DoMeleeSwing()
Check(Near(pending[1].delay, 7 / 30) and Near(weapon.nextFire, 101.2), "The selected hatchet chop owns its timing")
Check(weapon.Primary.HitDelay == 0.1 and weapon.Primary.Delay == 0.8, "Overrides must not mutate Primary")
weapon:DoMeleeSwing("quick", nil, nil, nil, 2)
Check(Near(weapon.nextFire, 102), "Explicit caller cooldown takes precedence")
weapon = Weapon()
weapon.SwingTimings = {
    quick = {
        HitDelay = 0,
        Delay = 0.4
    }
}

weapon:DoMeleeSwing()
Check(pending[1].delay == 0, "A zero hit delay overrides the Primary delay")
weapon = Weapon()
weapon.Primary.HitDelay = nil
weapon:DoMeleeSwing()
Check(#weapon.hits == 1 and #pending == 0, "Legacy nil hit delay stays immediate")
weapon = Weapon()
weapon.HitAnims = "hit"
weapon.GetSwingAnim = methods.GetSwingAnim
function weapon:PickAnim(anim)
    return anim
end

weapon.SwingTimings = {
    hit = {
        HitDelay = 0.3,
        Delay = 1.1
    }
}

weapon:DoMeleeSwing()
Check(weapon.animation == "hit" and Near(pending[1].delay, 0.3), "On-hit animations resolve their own timing")
weapon = Weapon()
weapon.Primary.Sound = ""
weapon:DoMeleeSwing()
Check(#weapon.sounds == 0, "Model-authored sounds must not emit an empty sound")
local owner
weapon, owner = Weapon()
weapon.SwingTimings = {
    quick = {
        HitDelay = 13 / 32,
        Delay = 35 / 32,
        SoundDelay = 10 / 32
    }
}

weapon:DoMeleeSwing()
Check(#weapon.sounds == 0 and Near(pending[2].delay, 10 / 32), "Hammer audio waits for its swing frame")
pending[2].callback()
Check(#weapon.sounds == 1, "The server emits the delayed swing once")
owner.active = nil
pending[2].callback()
Check(#weapon.sounds == 1, "Holstering cancels delayed audio")
owner.active = weapon
owner.alive = false
pending[2].callback()
Check(#weapon.sounds == 1, "Death cancels delayed audio")
owner.alive = true
weapon.removed = true
pending[2].callback()
Check(#weapon.sounds == 1, "Removing the weapon cancels delayed audio")
weapon = Weapon()
env.SERVER = false
env.CLIENT = true
weapon:EmitMeleeSwingSound("swing", 0.2)
Check(#pending == 0 and #weapon.sounds == 0, "The client must not duplicate server-owned delayed audio")
env.SERVER = true
env.CLIENT = false
weapon = Weapon()
weapon.MeleeCharge = {
    HitDelay = 8 / 30,
    Sound = "heavy",
    SoundDelay = 6 / 30,
    EndAnim = "release",
    Time = 1,
    MinMultiplier = 1.2,
    Multiplier = 2,
    RangeMultiplier = 1.15
}

weapon:ReleaseMeleeCharge(1)
Check(Near(pending[1].delay, 8 / 30) and Near(pending[2].delay, 6 / 30), "Heavy hit and sound delays are independent")
Check(weapon.animation == "release" and Near(weapon.nextFire, 101.7), "Heavy recovery follows the release animation")
pending[1].callback()
Check(Near(weapon.hits[1][1], 40) and Near(weapon.hits[1][2], 57.5), "Heavy damage and reach retain charge scaling")
weapon = Weapon()
weapon.ShoveHitDelay = 8 / 33
weapon.ShoveDelay = 1
weapon.ShoveAnim = "shove"
weapon:DoShove()
Check(Near(pending[1].delay, 8 / 33) and Near(weapon.nextFire, 101), "Shoves retain their independent timing")
print("Melee timing: " .. passed .. " checks passed")
