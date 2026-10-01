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
local pose = Matrix()
pose:SetTranslation(Vector(7, 8, 9))
pose:SetAngles(Angle(23, 41, 67))
pose:SetScale(Vector(1.2, 0.9, 1.1))
local original = Vector(1, 2, 3):GetNormalized()
local localDirection = WorldToLocal(original, angle_zero, vector_origin, Angle(23, 41, 67))
for _, desired in ipairs({original, -original, Vector(0, 0, 1), Vector(1, 0, 0), Vector(0, -1, 0)}) do
    local rotated = base:RotateTPIKBone(pose, original, desired)
    local normalized = Matrix(rotated)
    normalized:SetScale(Vector(1, 1, 1))
    local aligned = LocalToWorld(localDirection, angle_zero, vector_origin, normalized:GetAngles())
    Check(aligned:GetNormalized():Dot(desired:GetNormalized()) > 0.9999, "Bone axes follow the solved limb without assuming its local X axis")
    Check(rotated:GetTranslation():Distance(pose:GetTranslation()) < 0.001, "Bone rotation preserves its position")
    Check(rotated:GetScale():Distance(pose:GetScale()) < 0.001, "Bone rotation preserves player rig scale")
end
for yaw = -180, 180, 30 do
    for pitch = -85, 85, 17 do
        local target = shoulder + Angle(pitch, yaw, 0):Forward() * 7
        local elbow, wrist = base:SolveTPIKArm(shoulder, target, shoulder + Vector(0, 5, -4), 5, 3)
        Check(math.abs(shoulder:Distance(elbow) - 5) < 0.001 and math.abs(elbow:Distance(wrist) - 3) < 0.001, "Aim sweep preserves both limb lengths")
    end
end
local grips = setmetatable({TPIKHandAngles = {left = Angle(0, 0, 25), right = Angle(10, 0, 0)}}, {__index = base})
local sourceAngle = Angle(20, 50, 70)
for _, side in ipairs({"L", "R"}) do
    local result = grips:GetTPIKHandAngle(side, sourceAngle)
    local _, offset = WorldToLocal(vector_origin, result, vector_origin, sourceAngle)
    local expected = grips.TPIKHandAngles[side == "L" and "left" or "right"]
    Check(math.abs(math.AngleDifference(offset.p, expected.p)) < 0.001 and math.abs(math.AngleDifference(offset.r, expected.r)) < 0.001, "Each grip adjustment rotates in its own animated hand axes")
end
grips.TPIKHandAngles = nil
Check(grips:GetTPIKHandAngle("L", sourceAngle) == sourceAngle, "Unconfigured hand angles preserve the animation")
local body = {}
function body:GetRenderAngles() return angle_zero end
function body:GetForward() return Vector(1, 0, 0) end
function body:GetRight() return Vector(0, -1, 0) end
function body:GetUp() return Vector(0, 0, 1) end
local arms = setmetatable({}, {__index = base})
local defaultHint = arms:GetTPIKElbowHint(body, "L", shoulder, 5)
arms.TPIKElbowOffsets = {left = Vector(2, -3, 4)}
local adjustedHint = arms:GetTPIKElbowHint(body, "L", shoulder, 5)
Check((adjustedHint - defaultHint):Distance(Vector(2, 3, 4)) < 0.001, "Elbow offsets use body forward, right and up axes")
local target = shoulder + Vector(6, 0, 0)
local beforeElbow, beforeWrist = arms:SolveTPIKArm(shoulder, target, defaultHint, 5, 3)
local afterElbow, afterWrist = arms:SolveTPIKArm(shoulder, target, adjustedHint, 5, 3)
Check(beforeElbow:Distance(afterElbow) > 0.1, "Elbow offset changes arm posture")
Check(beforeWrist:Distance(afterWrist) < 0.001, "Changing elbow posture leaves the wrist target fixed")
Check(math.abs(shoulder:Distance(afterElbow) - 5) < 0.001 and math.abs(afterElbow:Distance(afterWrist) - 3) < 0.001, "Elbow tuning retains both limb lengths")
Check(arms:GetTPIKElbowHint(body, "R", shoulder, 5):Distance(shoulder + Vector(0, -5, -3.75)) < 0.001, "One arm's offset does not affect the other")
local head = setmetatable({HeadAimOffset = Angle(5, -8, 12)}, {__index = base})
local look = Angle(20, 110, 0)
local adjusted = head:GetHeadAimAngle(look)
local _, relative = WorldToLocal(vector_origin, adjusted, vector_origin, look)
Check(math.abs(math.AngleDifference(relative.p, 5)) < 0.001 and math.abs(math.AngleDifference(relative.y, -8)) < 0.001 and math.abs(math.AngleDifference(relative.r, 12)) < 0.001, "Head offsets apply in the tracked look direction's local axes")
Check(look == Angle(20, 110, 0), "Head offsets do not mutate the aim angle")
head.HeadAimOffset = nil
Check(head:GetHeadAimAngle(look) == look, "Missing head offsets preserve aim tracking")
arms.TPIKElbowOffsets = {
    left = Vector(1, 2, 3),
    raised = {right = Vector(0, 4, 0)},
    lowered = {left = Vector(5, 6, 7)},
}
arms.tpikLoweredAmount = 0
Check(arms:GetTPIKElbowOffset("L") == Vector(1, 2, 3), "Raised elbow states inherit legacy per-hand offsets")
arms.tpikLoweredAmount = 0.5
Check(arms:GetTPIKElbowOffset("L") == Vector(3, 4, 5), "Elbow state offsets blend with weapon lowering")
Check(arms:GetTPIKElbowOffset("R") == Vector(0, 4, 0), "Missing lowered elbow offsets inherit raised values")
arms.tpikLoweredAmount = 1
Check(arms:GetTPIKElbowOffset("L") == Vector(5, 6, 7), "Fully lowered elbows use the lowered state")
arms.TPIKElbowOffsets = {left = Vector(2, -3, 4), right = Vector(-1, 3, -2)}
arms.tpikLoweredAmount = 0
for _, side in ipairs({"L", "R"}) do
    local reference = arms:GetTPIKElbowHint(body, side, vector_origin, 5)
    for yaw = -180, 180, 30 do
        local rendered = Angle(0, yaw, 0)
        local turningBody = {}
        function turningBody:GetRenderAngles() return rendered end
        function turningBody:GetForward() error("Elbow target must not use player entity aim axes") end
        function turningBody:GetRight() error("Elbow target must not use player entity aim axes") end
        function turningBody:GetUp() error("Elbow target must not use player entity aim axes") end
        local rotated = arms:GetTPIKElbowHint(turningBody, side, shoulder, 5)
        local expected = LocalToWorld(reference, angle_zero, shoulder, rendered)
        Check(rotated:Distance(expected) < 0.001, "Elbow posture follows rendered body yaw independently of aim direction")
        local target = LocalToWorld(Vector(6, 0, 0), angle_zero, shoulder, rendered)
        local elbow, wrist = arms:SolveTPIKArm(shoulder, target, rotated, 5, 3)
        local originalElbow = arms:SolveTPIKArm(vector_origin, Vector(6, 0, 0), reference, 5, 3)
        local expectedElbow = LocalToWorld(originalElbow, angle_zero, shoulder, rendered)
        Check(elbow:Distance(expectedElbow) < 0.001 and wrist:Distance(target) < 0.001, "Turning preserves the solved elbow posture and grip")
    end
end
print("Native TPIK: " .. passed .. " checks passed")
