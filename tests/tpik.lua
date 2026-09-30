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
print("Native TPIK solver: " .. passed .. " checks passed")
