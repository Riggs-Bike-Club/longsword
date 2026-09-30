--- Runs weapon action timing regression checks in Lua 5.4 from the addon root.
local methods = {}
local now = 100
local env = setmetatable( {
    SWEP = methods,
    CLIENT = false,
    IN_SPEED = 1,
    IN_WALK = 2,
    IN_ATTACK = 3,
    IN_ATTACK2 = 4,
    IN_USE = 5,
    ACT_VM_IDLE = "idle",
    CurTime = function()
        return now
    end,
    IsValid = function(value)
        return type( value ) == "table" and not value.removed
    end,
    isstring = function(value)
        return type( value ) == "string"
    end,
    istable = function(value)
        return type(value) == "table"
    end,
    math = setmetatable( {
        Rand = function(low, high)
            return ( low + high ) / 2
        end,
    }, { __index = math } ),
}, { __index = _G } )

for _, name in ipairs( { "conditions", "animation", "reload", "think" } ) do
    local path = "lua/weapons/ls_base/common/" .. name .. ".lua"
    local file = assert( io.open( path, "r" ) )
    local source = file:read( "*a" )
    file:close()
    source = source:gsub( "!=", "~=" ):gsub( "!", "not " )
    assert( load( source, path, "t", env ) )()
end

local passed = 0
local function Check(value, message)
    assert( value, message )
    passed = passed + 1
end

local function Weapon()
    local owner = {
        keys = {},
        speed = 300,
        grounded = true,
    }
    function owner:KeyDown(key)
        return self.keys[key] == true
    end
    function owner:GetVelocity()
        return { Length2D = function() return self.speed end }
    end
    function owner:GetRunSpeed()
        return 300
    end
    function owner:IsOnGround()
        return self.grounded
    end
    function owner:Crouching()
        return self.crouched == true
    end

    local viewModel = { duration = 3 }
    function viewModel:LookupSequence(anim)
        return anim
    end
    function viewModel:ResetSequenceInfo()
    end
    function viewModel:SendViewModelMatchingSequence(anim)
        self.anim = anim
    end
    function viewModel:SequenceDuration()
        return self.duration
    end
    function viewModel:GetCycle()
        return 0.5
    end
    function viewModel:SetCycle(cycle)
        self.cycle = cycle
    end

    local weapon = setmetatable( {
        Primary = { ClipSize = 12 },
        LoweredPos = true,
        InspectArmed = true,
        InspectAnimation = "inspect",
        AutoInspect = false,
        nextFire = 0,
        nextIdle = 0,
        reloadTime = 0,
        clip = 12,
    }, { __index = methods } )
    function weapon:GetOwner()
        return owner
    end
    function weapon:GetOwnerViewModel()
        return viewModel
    end
    function weapon:GetBursting()
        return self.bursting == true
    end
    function weapon:GetReloading()
        return self.reloading == true
    end
    function weapon:GetReloadTime()
        return self.reloadTime
    end
    function weapon:GetLowered()
        return false
    end
    function weapon:GetIronsights()
        return self.aiming == true
    end
    function weapon:GetNextPrimaryFire()
        return self.nextFire
    end
    function weapon:GetNextIdle()
        return self.nextIdle
    end
    function weapon:SetNextIdle(value)
        self.nextIdle = value
    end
    function weapon:Clip1()
        return self.clip
    end
    function weapon:UsesMeleeAttack()
        return false
    end
    function weapon:UsesShotgunReload()
        return false
    end
    function weapon:Ammo1()
        return 24
    end
    return weapon, owner, viewModel
end

local weapon, owner, viewModel = Weapon()
owner.keys[env.IN_SPEED] = true
Check( weapon:IsSprinting() and not weapon:CanShoot(), "Active sprint must still block firearm shots" )
owner.keys[env.IN_SPEED] = false
Check( not weapon:IsSprinting() and weapon:CanShoot(), "Sprint release must allow firing before velocity decays" )
Check( weapon:CanIronsight(), "Sprint release must immediately allow aiming" )
owner.keys[env.IN_SPEED] = true
owner.keys[env.IN_WALK] = true
Check( not weapon:IsSprinting(), "Walking must override sprint input" )
owner.keys[env.IN_WALK] = false
owner.crouched = true
Check( not weapon:IsSprinting(), "Crouching must not retain sprint lock" )
owner.crouched = false
owner.speed = 0
Check( not weapon:IsSprinting(), "Holding sprint while stationary must not block actions" )
weapon.reloadTime = now + 1
Check( not weapon:CanShoot(), "Reload recovery must still block shooting" )
Check( not weapon:CanInspect(), "Inspect must not interrupt reload recovery" )
weapon.reloadTime = 0
weapon.bursting = true
Check( not weapon:CanShoot(), "An active burst must not allow a second burst" )

weapon, owner, viewModel = Weapon()
owner.speed = 0
weapon:Inspect()
Check( weapon.Inspecting and viewModel.anim == "inspect", "Manual inspect must still play its animation" )
Check( weapon.nextFire == 0 and weapon:CanShoot(), "Inspect must not impose an attack delay" )
weapon.clip = 10
Check( weapon:CanReload(), "Inspect must not prevent reloading" )
Check( weapon.NextInspectAllowed == now + 3 and not weapon.InspectArmed, "Manual inspect must retain its retrigger guard" )
owner.keys[env.IN_ATTACK] = true
weapon:InspectThink()
Check( not weapon.Inspecting and viewModel.anim == "idle", "Attack must cancel manual inspect with auto inspect disabled" )

for _, bClient in ipairs( { false, true } ) do
    env.CLIENT = bClient
    for _, key in ipairs( { env.IN_ATTACK, env.IN_ATTACK2, env.IN_USE } ) do
        weapon, owner, viewModel = Weapon()
        owner.speed = 0
        weapon:DoInspect()
        owner.keys[key] = true
        weapon:InspectThink()
        Check( not weapon.Inspecting and viewModel.anim == "idle", "Action input must interrupt inspect in both realms" )
    end
end
env.CLIENT = false

for _, anim in ipairs( { "fire", "reload", "holster" } ) do
    weapon, owner, viewModel = Weapon()
    owner.speed = 0
    weapon:DoInspect()
    weapon:PlayAnim( anim )
    weapon:QueueIdle()
    weapon:InspectThink()
    Check( not weapon.Inspecting and viewModel.anim == anim, "Inspect cancellation must not overwrite " .. anim )
end

weapon, owner, viewModel = Weapon()
owner.speed = 0
weapon:DoInspect()
now = now + 3
weapon:InspectThink()
Check( not weapon.Inspecting and viewModel.anim == "idle", "Uninterrupted inspect must finish normally" )
weapon:QueueIdle()
Check( weapon.nextIdle == now + viewModel.duration, "Idle must not add dead time after an animation" )
Check( weapon:GetDrawDelay( 3 ) == 0.25, "Long draws must permit actions after a short recovery" )
Check( weapon:GetDrawDelay( 0.1 ) == 0.1, "Short draws must not gain a delay" )
weapon.DrawDelay = 0.5
Check( weapon:GetDrawDelay( 3 ) == 0.5, "Weapon-specific draw timing must be supported" )

weapon, owner, viewModel = Weapon()
owner.speed = 0
weapon.nextFire = now + 1
weapon:Inspect()
Check( not weapon.Inspecting, "Manual inspect must respect an existing action cooldown" )
weapon:DoInspect()
owner.keys[env.IN_ATTACK] = true
weapon:InspectThink()
Check( weapon.nextFire == now + 1, "Cancelling inspect must never clear a real attack cooldown" )

weapon, owner, viewModel = Weapon()
weapon.WalkAnim = "walk"
weapon.SprintAnim = "sprint"
weapon.LastMoveState = "sprint"
owner.speed = 150
weapon:MovementThink()
Check( viewModel.anim == "walk", "Sprint exit must not wait for movement debounce" )
weapon.LastMoveState = "sprint"
weapon.nextIdle = now + 1
viewModel.anim = "reload"
weapon:MovementThink()
Check( viewModel.anim == "reload", "Sprint exit must preserve an active action animation" )
weapon.nextIdle = 0
weapon.LastMoveState = "idle"
weapon.PendingMoveState = nil
weapon:MovementThink()
Check( viewModel.anim == "reload", "Other movement changes must retain debounce" )
now = now + 0.11
weapon:MovementThink()
Check( viewModel.anim == "walk", "Other movement loops must switch after debounce" )

print( "Passed " .. passed .. " weapon action timing checks" )
