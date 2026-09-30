--- Verifies directional recoil strength and prediction filtering without moving a real player's view.
local angleMeta = {}
angleMeta.__index = angleMeta
function angleMeta.__mul(angle, amount)
    return setmetatable({p = angle.p * amount, y = angle.y * amount, r = angle.r * amount}, angleMeta)
end
function angleMeta.__add(a, b)
    return setmetatable({p = a.p + b.p, y = a.y + b.y, r = a.r + b.r}, angleMeta)
end
local function MakeAngle(p, y, r)
    return setmetatable({p = p or 0, y = y or 0, r = r or 0}, angleMeta)
end
local methods = {}
local bPredicted = true
local env = setmetatable({
    SWEP = methods,
    SERVER = false,
    CLIENT = true,
    Angle = MakeAngle,
    IsFirstTimePredicted = function() return bPredicted end,
    game = {SinglePlayer = function() return false end},
    hook = {Run = function() end},
    util = {SharedRandom = function(_, low, high) return (low + high) / 2 end},
}, {__index = _G})
local file = assert(io.open("lua/weapons/ls_base/common/effects.lua"))
local source = file:read("*a")
file:close()
source = assert(source:match("(function SWEP:ViewPunch%(%)%s*.-)function SWEP:ShouldResetCustomRecoil"))
assert(load(source:gsub("!=", "~="):gsub("!", "not "), "ViewPunch", "t", env))()
local owner = {eyes = MakeAngle(), punches = 0}
function owner:Crouching() return self.bCrouching end
function owner:EyeAngles() return self.eyes end
function owner:SetEyeAngles(angle) self.eyes = angle end
function owner:ViewPunch(angle)
    self.punch = angle
    self.punches = self.punches + 1
end
local weapon = setmetatable({
    Primary = {Recoil = 0.1},
    Recoil = {Up = 12.5, Side = 1.5, RandomUp = 0.9, HipFireMultiplier = 1.25, CrouchMultiplier = 0.9, Kick = 0.6},
}, {__index = methods})
function weapon:GetOwner() return owner end
function weapon:GetIronsights() return self.bAimed end
weapon:ViewPunch()
assert(math.abs(owner.eyes.p + 1.61875) < 0.00001, "Hip recoil must not round to zero")
assert(math.abs(owner.punch.p + 0.97125) < 0.00001, "Camera kick uses its own multiplier")
owner.eyes = MakeAngle()
owner.bCrouching = true
weapon:ViewPunch()
assert(math.abs(owner.eyes.p + 1.456875) < 0.00001, "Crouching scales recoil")
owner.eyes = MakeAngle()
owner.bCrouching = false
weapon.bAimed = true
weapon:ViewPunch()
assert(math.abs(owner.eyes.p + 1.295) < 0.00001, "Aimed recoil omits the hip multiplier")
local count = owner.punches
bPredicted = false
weapon:ViewPunch()
assert(owner.punches == count, "Prediction replays do not double recoil")
env.SERVER = true
bPredicted = true
weapon:ViewPunch()
assert(owner.punches == count, "Server does not also move the predicted view")
print("Directional recoil: 6 checks passed")
