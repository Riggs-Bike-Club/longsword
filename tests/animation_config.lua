--- Runs unified animation configuration regression checks in Lua 5.4 from the addon root.
local methods = {}
local env = setmetatable({
    SWEP = methods,
    SERVER = true,
    CLIENT = false,
    CurTime = function()
        return 100
    end,
    istable = function(value)
        return type(value) == "table"
    end,
    isstring = function(value)
        return type(value) == "string"
    end,
    IsValid = function(value)
        return type(value) == "table" and not value.removed
    end,
    Material = function(value)
        return value
    end,
    util = {
        SharedRandom = function(_, low)
            return low
        end,
    },
    math = setmetatable({
        Clamp = function(value, low, high)
            return math.max(low, math.min(high, value))
        end,
    }, { __index = math }),
    longsword = {
        debugPrint = function()
        end,
    },
}, {
    __index = function(_, key)
        if ( key:match("^ACT_") or key:match("^MAT_") or key == "PLAYER_ATTACK1" ) then
            return key
        end

        return _G[key]
    end,
})

for _, name in ipairs({ "animation", "effects", "reload", "shotgun", "think", "melee", "projectile", "firemode" }) do
    local path = "lua/weapons/ls_base/common/" .. name .. ".lua"
    local file = assert(io.open(path, "r"))
    local source = file:read("*a"):gsub("!=", "~="):gsub("!", "not ")
    file:close()
    assert(load(source, path, "t", env))()
end

local passed = 0
local function Check(value, message)
    assert(value, message)
    passed = passed + 1
end

local owner = {}
function owner:SetAnimation(animation)
    self.animation = animation
end

function owner:LookupSequence(sequence)
    return sequence == "missing" and -1 or 1
end

function owner:ForceSequence(sequence)
    self.sequence = sequence
end

function owner:DoReloadEvent()
    self.reloadEvent = true
end

local viewModel = { cycle = 0.7 }
function viewModel:LookupSequence(sequence)
    self.lookedUp = sequence
    return sequence == "missing" and -1 or 3
end

function viewModel:SelectWeightedSequence(activity)
    self.activity = activity
    return 4
end

function viewModel:GetCycle()
    return self.cycle
end

function viewModel:SetCycle(cycle)
    self.cycle = cycle
end

function viewModel:ResetSequenceInfo()
end

function viewModel:SendViewModelMatchingSequence(sequence)
    self.sequence = sequence
end

function viewModel:SequenceDuration()
    return 2
end

local weapon = setmetatable({ Animations = {}, clip = 5 }, { __index = methods })
function weapon:GetOwner()
    return owner
end

function weapon:GetClass()
    return "test_weapon"
end

function weapon:GetOwnerViewModel()
    return viewModel
end

function weapon:Clip1()
    return self.clip
end

function weapon:GetIronsights()
    return self.bAimed == true
end

function weapon:GetMoveState()
    return self.moveState or "idle"
end

Check(weapon:GetDrawAnim() == "ACT_VM_DRAW", "Draw retains its default activity")
Check(weapon:GetIdleAnim() == "ACT_VM_IDLE", "Idle retains its default activity")
Check(weapon:GetFireAnimation() == "ACT_VM_PRIMARYATTACK", "Fire retains its default activity")
Check(weapon:GetDryFireAnim() == "ACT_VM_DRYFIRE", "Dry fire retains its default activity")
Check(weapon:GetHolsterAnim() == nil and not weapon:ShouldAnimateHolster(), "Holster remains opt-in")
Check(weapon:GetAnimation("unknown") == nil, "Unknown actions do not invent defaults")
weapon.DrawAnim = "legacyDraw"
Check(weapon:GetDrawAnim() == "legacyDraw", "Legacy fields remain compatible")
weapon.Animations.draw = "draw"
Check(weapon:GetDrawAnim() == "draw", "Unified entries override legacy fields")
weapon.Animations.drawEmpty = "drawEmpty"
weapon.clip = 0
Check(weapon:GetDrawAnim() == "drawEmpty", "Empty draw selects its counterpart")
weapon.Animations.drawEmpty = false
Check(weapon:GetDrawAnim() == nil, "Disabled empty variants do not fall back")
weapon.Animations.drawEmpty = nil
Check(weapon:GetDrawAnim() == "draw", "Missing empty variants retain the loaded action")
weapon.Animations.holster = "holster"
Check(weapon:ShouldAnimateHolster(), "Explicit holster enables the action")
weapon.Animations.holster = false
Check(not weapon:ShouldAnimateHolster(), "False disables holster")
weapon.Animations.fire = { "fire1", "fire2" }
for _ = 1, 10 do
    local animation = weapon:GetAnimation("fire")
    Check(animation == "fire1" or animation == "fire2", "Variant lists resolve one valid source")
end
weapon.Animations.fireLast = "last"
Check(weapon:GetFireAnimation() == "last", "Last-shot definitions enable last-shot selection")
weapon.bAimed = true
Check(weapon:GetFireAnimation() == "ACT_VM_PRIMARYATTACK_1", "Missing aimed last shot retains aimed fire")
weapon.Animations.fireAimedLast = "aimedLast"
Check(weapon:GetFireAnimation() == "aimedLast", "Aimed last shot has its own action")
weapon.Animations.bAnimateAimedFire = false
Check(not weapon:ShouldAnimateFire(), "Aimed playback can be disabled explicitly")
weapon.Animations.bAnimateAimedFire = true
Check(weapon:ShouldAnimateFire(), "Aimed playback can be enabled explicitly")
weapon.Animations.dryFireAimed = "aimedDry"
Check(weapon:GetDryFireAnim() == "aimedDry", "Aimed dry fire resolves its dedicated action")
weapon.Animations.cycle = "cycle"
weapon.Animations.cycleAimed = "aimedCycle"
Check(weapon:GetPullbackAnimation() == "aimedCycle", "Mechanical cycling supports aimed variants")
weapon.bAimed = false
Check(weapon:GetPullbackAnimation() == "cycle", "Mechanical cycling supports hip variants")
weapon.Animations.reloadStart = "start"
weapon.Animations.reloadStartEmpty = "emptyStart"
Check(weapon:GetShotgunReloadStartAnim() == "emptyStart", "Empty shotgun starts select the empty action")
weapon.Animations.reloadStartEmpty = nil
weapon.CanChamberShotgun = true
Check(weapon:GetShotgunReloadStartAnim() == "ACT_VM_RELOAD_EMPTY", "Chambering shotguns retain their legacy opening")
weapon.Animations.reloadFinish = "finish"
weapon.Animations.reloadFinishEmpty = "emptyFinish"
weapon.ReloadStartedEmpty = true
weapon.clip = 5
Check(weapon:GetShotgunReloadEndAnim() == "emptyFinish", "Finishing depends on the starting magazine state")
weapon.Animations.walk = "walk"
weapon.moveState = "walk"
Check(weapon:GetIdleAnim() == "walk", "Movement selects its dedicated loop")
weapon.bAimed = true
Check(weapon:GetIdleAnim() == "ACT_VM_IDLE", "Aiming without a dedicated idle suppresses movement loops")
weapon.Animations.idleAimed = "aimedIdle"
Check(weapon:GetIdleAnim() == "aimedIdle", "Aiming selects its dedicated idle")
weapon.Charging = true
weapon.MeleeCharge = {}
weapon.Animations.meleeChargeIdle = "chargeIdle"
Check(weapon:GetIdleAnim() == "chargeIdle", "Charge idle owns looping playback")
weapon.Animations.meleeSwing = { "swing1", "swing2" }
Check(weapon:GetSwingAnim(false) == "swing1", "Melee variants retain shared predicted selection")
weapon.Animations.meleeHit = "hit"
Check(weapon:GetSwingAnim(true) == "hit" and weapon:UsesHitAnims(), "Melee hits select their dedicated action")
weapon.Animations.playerAttack = 7
weapon:PlayPlayerAnimation("playerAttack")
Check(owner.animation == 7, "Player activities are configurable")
weapon.Animations.playerAttack = "playerSwing"
weapon:PlayPlayerAnimation("playerAttack")
Check(owner.sequence == "playerSwing", "Player sequence names use the supported framework path")
weapon.Animations.playerAttack = false
owner.animation = nil
weapon:PlayPlayerAnimation("playerAttack")
Check(owner.animation == nil, "Player playback can be disabled")
weapon:PlayReloadGesture()
Check(owner.reloadEvent, "Unconfigured reload gestures retain the engine event")
weapon.Animations.playerReload = false
owner.reloadEvent = nil
weapon:PlayReloadGesture()
Check(owner.reloadEvent == nil, "Reload gestures can be disabled")
Check(weapon:PlayAnimation("draw", true) == 2 and viewModel.sequence == 3 and viewModel.cycle == 0.7, "Named sources resolve on the viewmodel and retain loop phase")
weapon.Animations.draw = false
viewModel.sequence = nil
Check(weapon:PlayAnimation("draw") == nil and viewModel.sequence == nil, "Disabled actions never reach sequence lookup")
weapon.Animations.draw = "missing"
Check(weapon:PlayAnimation("draw") == nil, "Missing sequences are rejected safely")
weapon.Animations.bUseProjectileFire = true
Check(weapon:ShouldAnimateProjectileFire(), "Projectile firing can be configured in the unified table")
weapon.Animations.bUseProjectileFire = false
weapon.DoFireAnim = true
Check(not weapon:ShouldAnimateProjectileFire(), "Projectile configuration overrides legacy flags")
weapon.Animations.bUseProjectileFire = nil
Check(weapon:ShouldAnimateProjectileFire(), "Legacy projectile firing flags remain supported")
weapon.Animations.reloadEmpty = "emptyReload"
Check(weapon:GetAnimation("reloadEmpty") == "emptyReload", "Empty reload sources resolve through the unified table")
weapon.Animations.fireMode = false
Check(weapon:GetAnimation("fireMode") == nil, "Fire-mode animation can be disabled")
weapon.Animations.worldFire = "worldShot"
Check(weapon:GetAnimation("worldFire") == "worldShot", "World firing sources are configurable")
print("Animation configuration: " .. passed .. " checks passed")