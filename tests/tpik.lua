--- Runs against Garry's Mod's native Vector math after the Longsword client base loads.
local base = weapons.GetStored("ls_base")
assert(base and base.SolveTPIKArm, "Load the updated Longsword client base first")
local passed = 0

local function Check(value, message)
    assert(value, message)
    passed = passed + 1
end

local shoulder = Vector(10, 20, 30)
for _, target in ipairs({Vector(16, 20, 30), Vector(10, 20, 36), Vector(100, 20, 30), Vector(10.1, 20, 30)}) do
    local elbow, wrist = base:SolveTPIKArm(shoulder, target, Vector(10, 25, 30), 5, 3)
    Check(elbow and wrist, "Nondegenerate targets produce finite joints")
    Check(math.abs(shoulder:Distance(elbow) - 5) < 0.001, "Upper-arm length is preserved")
    Check(math.abs(elbow:Distance(wrist) - 3) < 0.001, "Forearm length is preserved")
    Check(shoulder:Distance(wrist) <= 8, "Unreachable targets cannot stretch the arm")
end
local elbow, wrist = base:SolveTPIKArm(shoulder, Vector(16, 20, 30), Vector(10, 25, 30), 5, 3)
Check(wrist:Distance(Vector(16, 20, 30)) < 0.001, "Reachable hands meet their animation target")
Check(elbow.y > shoulder.y, "The bend hint chooses the elbow side")
Check(base:SolveTPIKArm(shoulder, shoulder, shoulder, 5, 3) == nil, "Coincident targets are rejected safely")
Check(base:SolveTPIKArm(shoulder, Vector(16, 20, 30), shoulder, 0, 3) == nil, "Zero-length skeleton segments are rejected safely")
local parallel = base:SolveTPIKArm(shoulder, Vector(10, 20, 36), Vector(10, 20, 33), 5, 3)
Check(parallel and parallel.x == parallel.x, "Collinear vertical bend hints have a finite fallback")
local weapon = setmetatable({
    TPIKOffset = {Pos = Vector(1, 2, 3), Ang = Angle(10, 20, 30), Scale = 2},
    TPIKOffsets = {
        raised = {Pos = Vector(4, 5, 6)},
        lowered = {Pos = Vector(7, 8, 9), Ang = Angle(40, 50, 60)},
    },
    TPIKTransitionTime = 0.2,
}, {__index = base})
function weapon:GetLowered() return self.bLowered == true end
function weapon:GetOwner() return NULL end
local position, angle, scale = weapon:GetTPIKOffset()
Check(position == Vector(4, 5, 6) and math.abs(math.AngleDifference(angle.p, 10)) < 0.001 and math.abs(math.AngleDifference(angle.y, 20)) < 0.001 and math.abs(math.AngleDifference(angle.r, 30)) < 0.001 and scale == 2, "Raised fields inherit legacy angle and scale")
weapon.bLowered = true
weapon:GetTPIKOffset()
Check(weapon.tpikLoweredAmount == 0, "Repeated render passes do not advance the transition")
weapon.tpikOffsetFrame = nil
weapon.tpikOffsetTime = RealTime() - 0.1
position = weapon:GetTPIKOffset()
Check(position.x > 4 and position.x < 7, "Lowering interpolates between the two states")
weapon.tpikOffsetFrame = nil
weapon.tpikOffsetTime = RealTime() - 1
position, angle, scale = weapon:GetTPIKOffset()
Check(position == Vector(7, 8, 9) and math.abs(math.AngleDifference(angle.p, 40)) < 0.001 and math.abs(math.AngleDifference(angle.y, 50)) < 0.001 and math.abs(math.AngleDifference(angle.r, 60)) < 0.001 and scale == 2, "Lowered state reaches its offset and inherits scale")
weapon.bLowered = false
weapon.TPIKTransitionTime = 0
weapon.tpikOffsetFrame = nil
position = weapon:GetTPIKOffset()
Check(position == Vector(4, 5, 6), "Zero transition time snaps back to raised")
weapon.TPIKOffsets = nil
weapon.tpikOffsetFrame = nil
position = weapon:GetTPIKOffset()
Check(position == Vector(1, 2, 3), "Legacy single offsets remain supported")
local owner = LocalPlayer()
if ( IsValid(owner) and isfunction(owner.IsWeaponRaised) ) then
    function weapon:GetOwner() return owner end
    weapon.bLowered = owner:IsWeaponRaised()
    Check(weapon:IsTPIKLowered() == !owner:IsWeaponRaised(), "Framework raise state overrides conflicting standalone state")
end
print("Native TPIK: " .. passed .. " checks passed")
