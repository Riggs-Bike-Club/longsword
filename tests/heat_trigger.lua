--- Exercises trigger, heat and reserve-fed firing through the real base methods with a simulated clock.
local now = 10
local methods = {}
local env = setmetatable({
    SWEP = methods,
    SERVER = true,
    CLIENT = false,
    IN_ATTACK = 1,
    IN_USE = 2,
    CurTime = function() return now end,
    IsValid = function(value) return type(value) == "table" and not value.removed end,
    istable = function(value) return type(value) == "table" end,
    isstring = function(value) return type(value) == "string" end,
    Lerp = function(fraction, a, b) return a + fraction * (b - a) end,
    math = setmetatable({Clamp = function(value, low, high)
        return math.max(low, math.min(high, value))
    end}, {__index = math}),
}, {__index = _G})

for _, name in ipairs({"heat", "trigger", "fire", "conditions", "reload", "bash"}) do
    local path = "lua/weapons/ls_base/common/" .. name .. ".lua"
    local file = assert(io.open(path))
    local source = file:read("*a"):gsub("!=", "~="):gsub("!", "not ")
    file:close()
    assert(load(source, path, "t", env))()
end

local passed = 0
local function Check(value, message)
    assert(value, message)
    passed = passed + 1
end

local function NewWeapon()
    local owner = {ammo = 200, bHeld = true}
    local weapon = setmetatable({
        Primary = {Automatic = true, Delay = 60 / 700, Damage = 8, DamageMin = 6, RangeMin = 10 / 0.0254, RangeMax = 100 / 0.0254, NumShots = 1},
        TriggerDelay = true,
        TriggerDelayTime = 1.25,
        TriggerReleaseAnimation = true,
        BottomlessClip = true,
        Overheat = true,
        HeatCapacity = 75,
        HeatDissipation = 25,
        HeatPerShot = 1,
        HeatDelayTime = 0.25,
        HeatFix = true,
        shots = 0,
        animations = {},
        values = {},
    }, {__index = methods})
    for _, name in ipairs({"TriggerReadyTime", "HeatAmount", "HeatDecayTime", "HeatFixTime", "HeatRecoveryEnd", "NextPrimaryFire", "ReloadTime", "NextIdle", "SprintReadyTime"}) do
        weapon["Get" .. name] = function(self) return self.values[name] or 0 end
        weapon["Set" .. name] = function(self, value) self.values[name] = value end
    end
    for _, name in ipairs({"TriggerFired", "Overheated", "HeatLocked", "SemiAutomatic", "Ironsights", "Reloading", "Lowered", "Bursting"}) do
        weapon["Get" .. name] = function(self) return self.values[name] == true end
        weapon["Set" .. name] = function(self, value) self.values[name] = value end
    end
    function owner:Alive() return not self.dead end
    function owner:KeyDown(key) return key == env.IN_ATTACK and self.bHeld end
    function owner:GetActiveWeapon() return self.weapon end
    function owner:RemoveAmmo(count) self.ammo = self.ammo - count end
    owner.weapon = weapon
    function weapon:GetOwner() return owner end
    function weapon:Ammo1() return owner.ammo end
    function weapon:Clip1() return self.clip or -1 end
    function weapon:GetPrimaryAmmoType() return 1 end
    function weapon:TakePrimaryAmmo(count) self.clip = self.clip - count end
    function weapon:UsesMeleeAttack() return false end
    function weapon:UsesProjectileAttack() return false end
    function weapon:IsSprinting() return self.bSprinting == true end
    function weapon:HasAnimation(name) return name == "fix" end
    function weapon:PlayAnimation(name)
        self.animations[#self.animations + 1] = name
        return name == "fix" and 5 / 3 or 1
    end
    function weapon:QueueIdle() self:SetNextIdle(now + 1) end
    function weapon:ShootBullet() self.shots = self.shots + 1 end
    function weapon:CalculateSpread() return 0 end
    function weapon:AddRecoil() end
    function weapon:ViewPunch() end
    function weapon:GetDryFireAnim() return nil end
    function weapon:EmitWeaponSound() end
    return weapon, owner
end

local weapon, owner = NewWeapon()
weapon:PrimaryAttack()
Check(weapon.shots == 0 and owner.ammo == 200, "Wind-up consumes no ammunition")
Check(weapon:GetTriggerReadyTime() == 11.25 and weapon.animations[1] == "trigger", "Wind-up uses its configured deadline and animation")
now = 10.5
owner.bHeld = false
weapon:TriggerThink()
Check(weapon:GetTriggerReadyTime() == 0 and weapon.animations[2] == "untrigger", "Releasing during wind-up cancels and spins down")
now = 12
weapon:TriggerThink()
Check(weapon.shots == 0, "Cancelled wind-ups never fire later")
owner.bHeld = true
weapon:PrimaryAttack()
now = 13.24
weapon:TriggerThink()
Check(weapon.shots == 0, "No early shot")
now = 13.25
weapon:TriggerThink()
Check(weapon.shots == 1 and owner.ammo == 199, "First shot fires at 1.25 seconds and consumes reserve ammo")
Check(weapon:GetCurrentHeat() == 1, "One shot adds one heat")
for _ = 2, 75 do
    now = now + 60 / 700 + 0.00001
    weapon:PrimaryAttack()
end
Check(weapon.shots == 75 and owner.ammo == 125, "Automatic fire continues without repeated wind-up")
Check(weapon:GetCurrentHeat() == 75 and weapon:GetOverheated(), "The 75th uninterrupted shot overheats")
Check(not weapon:GetHeatLocked(), "HeatLockout false retains animated recovery")
weapon:HeatThink()
Check(weapon.animations[#weapon.animations] == "fix" and now < weapon:GetHeatDecayTime(), "Heat recovery starts immediately before the cooling delay expires")
local animationCount = #weapon.animations
owner.bHeld = false
weapon:TriggerThink()
weapon:HeatThink()
Check(#weapon.animations == animationCount, "Trigger release cannot replace or restart overheat recovery")
owner.bHeld = true
now = now + 0.1
weapon:PrimaryAttack()
Check(weapon.shots == 75, "Overheating prevents the next shot")
Check(weapon:IsHeatBlocked(), "Recovery blocks actions")
local recoveryEnd = weapon:GetHeatRecoveryEnd()
now = weapon:GetHeatFixTime() + 0.001
weapon:HeatThink()
Check(weapon:GetCurrentHeat() == 0 and not weapon:GetOverheated(), "Heat clears at 80 percent of recovery")
Check(weapon:IsHeatBlocked(), "The final recovery frames still block firing")
now = recoveryEnd + 0.001
weapon:PrimaryAttack()
Check(weapon.shots == 75 and weapon.animations[#weapon.animations] == "trigger", "Firing after overheating starts a fresh wind-up")

weapon, owner = NewWeapon()
weapon:SetSemiAutomatic(true)
weapon:PrimaryAttack()
now = now + 1.25
weapon:TriggerThink()
Check(weapon.shots == 1, "Semi-auto completes its delayed shot")
now = now + 1
weapon:PrimaryAttack()
weapon:TriggerThink()
Check(weapon.shots == 1, "Holding semi-auto does not repeat")
owner.bHeld = false
weapon:TriggerThink()
Check(weapon.animations[#weapon.animations] == "untrigger", "Releasing after firing plays wind-down")
owner.bHeld = true
weapon:PrimaryAttack()
now = now + 1.25
weapon:TriggerThink()
Check(weapon.shots == 2, "The next semi-auto press requires another wind-up")

weapon, owner = NewWeapon()
weapon:PrimaryAttack()
weapon.bSprinting = true
weapon.SprintToFireTime = 0.35
weapon:TriggerThink()
Check(weapon:GetTriggerReadyTime() == 0, "Sprint interrupts charging")
weapon.bSprinting = false
Check(not weapon:CanShoot(), "Sprint recovery blocks firing")
now = now + 0.351
Check(weapon:CanShoot(), "Sprint recovery expires")
weapon:PrimaryAttack()
owner.dead = true
now = now + 2
weapon:TriggerThink()
Check(weapon.shots == 0 and weapon:GetTriggerReadyTime() == 0, "Death cancels delayed firing")

weapon, owner = NewWeapon()
weapon:PrimaryAttack()
owner.weapon = nil
now = now + 2
weapon:TriggerThink()
Check(weapon.shots == 0 and weapon:GetTriggerReadyTime() == 0, "Weapon switching cancels delayed firing")
owner.weapon = weapon
weapon:PrimaryAttack()
weapon.HolsterAnimEnd = now + 1
weapon:TriggerThink()
Check(weapon:GetTriggerReadyTime() == 0 and not weapon:CanShoot(), "Animated holstering cancels and blocks firing")

weapon, owner = NewWeapon()
weapon:SetHeatAmount(50)
weapon:SetHeatDecayTime(now + 0.25)
now = now + 0.2
Check(weapon:GetCurrentHeat() == 50, "Cooling waits for its delay")
now = now + 1.05
Check(math.abs(weapon:GetCurrentHeat() - 25) < 0.0001, "Cooling loses 25 heat per second")
now = now + 20
Check(weapon:GetCurrentHeat() == 0, "Elapsed cooling clamps at zero without active Think")
weapon:SetHeatLocked(true)
weapon:HeatThink()
Check(not weapon:GetHeatLocked(), "Full cooling clears heat lockout")
Check(weapon:GetDamageAtRange(0) == 8, "Near damage is eight")
Check(weapon:GetDamageAtRange(10000) == 6, "Far damage is six")
Check(math.abs(weapon:GetDamageAtRange(55 / 0.0254) - 7) < 0.0001, "Damage interpolates between ten and one hundred metres")
owner.ammo = 0
weapon:PrimaryAttack()
Check(weapon.shots == 0 and weapon:GetTriggerReadyTime() == 0, "No ammunition never spins up")
Check(not weapon:CanReload(), "Bottomless weapons cannot reload")
weapon:Reload()
Check(#weapon.animations == 0, "Bottomless reload does not play a magazine animation")

weapon, owner = NewWeapon()
weapon.TriggerDelay = false
weapon.Overheat = false
weapon.BottomlessClip = false
weapon.clip = 5
weapon:PrimaryAttack()
Check(weapon.shots == 1 and weapon.clip == 4 and owner.ammo == 200, "Existing magazine weapons fire immediately and retain their ammunition path")
Check(weapon:GetCurrentHeat() == 0, "Existing weapons have no heat")
weapon, owner = NewWeapon()
weapon.clip = 12
owner.ammo = 0
Check(weapon:GetAvailablePrimaryAmmo() == 12, "Ammo already loaded before a bottomless conversion remains usable")
weapon:Shoot()
Check(weapon.clip == 11 and owner.ammo == 0, "Bottomless weapons use retained clip rounds after reserve ammo runs out")
weapon.Bash = true
weapon.BashSecondary = true
weapon.NoIronsights = false
Check(not weapon:CanIronsight(), "Optional secondary bash replaces ironsights")
local bBashed = false
function weapon:BashAttack() bBashed = true end
now = now + 1
weapon:SecondaryAttack()
Check(bBashed, "Secondary attack invokes enabled bashing")
bBashed = false
weapon.BashSecondary = false
weapon:SecondaryAttack()
Check(not bBashed, "Secondary bashing remains opt-in")
local baseFile = assert(io.open("lua/weapons/ls_base/base.lua"))
local baseSource = baseFile:read("*a")
baseFile:close()
local setup = assert(baseSource:match("(function SWEP:SetupDataTables%(%)%s*.-)function SWEP:ResetValues"))
assert(load(setup:gsub("!=", "~="):gsub("!", "not "), "SetupDataTables", "t", env))()
local registered = {}
function weapon:NetworkVar(kind, slot, name)
    local key = kind .. tostring(slot)
    Check(registered[key] == nil, "Network slots do not overlap: " .. name)
    registered[key] = name
end
function weapon:ExtraDataTables(slots) self.slots = slots end
weapon.TriggerDelay = false
weapon.Overheat = false
weapon.SprintToFireTime = nil
weapon:SetupDataTables()
Check(weapon.slots.Bool == 3 and weapon.slots.Float == 4, "Unchanged weapons keep their existing derived network slots")
registered = {}
weapon.TriggerDelay = true
weapon.Overheat = true
weapon.SprintToFireTime = 0.35
weapon:SetupDataTables()
Check(weapon.slots.Bool == 7 and weapon.slots.Float == 10, "Enabled features reserve their slots before derived weapons")
registered = {}
weapon.TPIK = true
weapon:SetupDataTables()
Check(weapon.slots.Float == 11 and weapon.slots.String == 2, "TPIK reserves animation state before derived weapon slots")
weapon, owner = NewWeapon()
weapon.Bash = true
weapon.BashSecondary = true
local bashTimer
local hitCount = 0
local hitDamage
function weapon:ClubAttack(damage)
    hitCount = hitCount + 1
    hitDamage = damage
end
env.timer = {Simple = function(delay, callback)
    Check(delay == 0.5, "Bash impact uses its separate delay")
    bashTimer = callback
end}
weapon:SecondaryAttack()
Check(hitCount == 0 and weapon.animations[#weapon.animations] == "bash", "Bash animation starts before damage")
Check(owner.ammo == 200 and weapon.shots == 0, "Bashing does not consume ammunition or fire")
bashTimer()
Check(hitCount == 1 and hitDamage == 50, "Bash deals its own configured damage")
owner.weapon = nil
bashTimer()
Check(hitCount == 1, "A switched weapon cannot deal a delayed bash hit")
print("Heat and trigger: " .. passed .. " checks passed")
