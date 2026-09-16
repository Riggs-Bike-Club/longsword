function SWEP:UsesMeleeAttack()
    return self.LongswordMode == "melee"
end

--- Selects the same swing variant in both predicted realms so its animation and hit timing agree.
---@param anim string|number|table|nil
---@return string|number|nil
function SWEP:PickMeleeAnim(anim)
    if !istable( anim ) then return anim end
    if #anim == 0 then return nil end

    local index = math.Clamp( math.floor( util.SharedRandom( "longsword.melee.animation", 1, #anim + 1 ) ), 1, #anim )
    return anim[index]
end

-- Returns the sequence for a light swing: HitAnims when the swing connected and the weapon defines a set for it, SwingAnims otherwise, falling back to ACT_VM_MISSCENTER. Both fields take an activity, a raw sequence name or a list of either.
function SWEP:GetSwingAnim(bHit)
    if bHit then
        local hitAnim = self:PickMeleeAnim( self.HitAnims )
        if hitAnim then return hitAnim end
    end

    return self:PickMeleeAnim( self.SwingAnims ) or ACT_VM_MISSCENTER
end

-- True when this weapon defines on-hit swing sequences (SWEP.HitAnims), so a swing only pays for the extra hull sweep that tells a hit from a miss when there is a second set to pick from.
function SWEP:UsesHitAnims()
    return self.HitAnims != nil
end

-- True when this weapon defines the hold-to-charge heavy attack (SWEP.MeleeCharge.Enabled).
function SWEP:UsesMeleeCharge()
    return self.MeleeCharge != nil and self.MeleeCharge.Enabled == true
end

-- True when this weapon defines a shove (SWEP.ShoveEnabled + a ShoveAnim).
function SWEP:UsesShove()
    return self.ShoveEnabled == true and self.ShoveAnim != nil
end

function SWEP:PrimaryMeleeAttack()
    -- A swing mid-charge would fight the wind-up on the viewmodel, so the light attack waits until the charge resolves.
    if self.Charging then return end

    self:DoMeleeSwing()
end

--- Performs a light swing using the selected animation's SwingTimings overrides, falling back to Primary timing; an explicit delay takes precedence over both.
function SWEP:DoMeleeSwing(anim, damage, range, hullSize, delay)
    if self.PrePrimaryAttack then
        self:PrePrimaryAttack()
    end

    local bHit = self:UsesHitAnims() and self:WouldMeleeHit( range, hullSize )
    anim = anim or self:GetSwingAnim( bHit )

    local timing = self.SwingTimings and self.SwingTimings[anim] or {}
    local hitDelay = timing.HitDelay or self.Primary.HitDelay
    if hitDelay then
        timer.Simple( hitDelay, function()
            if !IsValid( self ) or !IsValid( self:GetOwner() ) then return end

            self:ClubAttack( damage, range, hullSize )
            self:ViewPunch()
        end )
    else
        self:ClubAttack( damage, range, hullSize )
        self:ViewPunch()
    end

    self:EmitMeleeSwingSound( self.Primary.Sound, timing.SoundDelay or self.Primary.SoundDelay )
    self:SetNextPrimaryFire( CurTime() + ( delay or timing.Delay or self.Primary.Delay ) )
    self:PlayAnim( anim )
    self:GetOwner():SetAnimation( PLAYER_ATTACK1 )
    self:QueueIdle()
end

--- Plays a swing sound immediately or schedules server-owned audio for animations without embedded sound events.
---@param soundName string|nil
---@param delay number|nil
function SWEP:EmitMeleeSwingSound(soundName, delay)
    if !soundName or soundName == "" then return end

    if !delay or delay <= 0 then
        self:EmitSound( soundName )
        return
    end

    if !SERVER then return end

    local owner = self:GetOwner()
    timer.Simple( delay, function()
        if !IsValid( self ) or !IsValid( owner ) then return end
        if self:GetOwner() != owner or owner:GetActiveWeapon() != self or !owner:Alive() then return end

        self:EmitSound( soundName )
    end )
end

-- Right-click drives both the shove (tap) and the charged heavy (hold): the engine only calls SecondaryAttack on the press, so the hold/release edges are read here off IN_ATTACK2. Melee weapons never ironsight (CanIronsight is false), so the key is free.
function SWEP:MeleeThink()
    if !self:UsesMeleeAttack() then return end

    local owner = self:GetOwner()
    if !IsValid( owner ) then return end

    local hasShove = self:UsesShove()
    local hasCharge = self:UsesMeleeCharge()
    if !hasShove and !hasCharge then
        self.SecondaryDown = false
        return
    end

    local down = owner:KeyDown( IN_ATTACK2 )
    local pressed = down and !self.SecondaryDown
    local released = !down and self.SecondaryDown
    self.SecondaryDown = down

    if released then
        return self:OnMeleeSecondaryReleased( hasShove, hasCharge )
    end

    if pressed then
        return self:OnMeleeSecondaryPressed( hasShove, hasCharge )
    end

    -- Held: once the wind-up sequence has finished, settle into the looping charge idle so the pose holds until release.
    if down and self.Charging and !self.ChargeIdlePlayed and CurTime() >= ( self.ChargeBeginEnd or 0 ) then
        self:PlayAnim( self.MeleeCharge.IdleAnim or ACT_VM_ATTACK_CHARGE_IDLE, true )
        self.ChargeIdlePlayed = true
    end
end

function SWEP:OnMeleeSecondaryPressed(hasShove, hasCharge)
    if self:GetNextPrimaryFire() > CurTime() then return end

    self.SecondaryPressTime = CurTime()

    -- With no charge to build, the shove is immediate; the press cooldown keeps a held key from repeating it.
    if !hasCharge then
        if hasShove then
            self:DoShove()
        end

        return
    end

    self:BeginMeleeCharge()
end

function SWEP:OnMeleeSecondaryReleased(hasShove, hasCharge)
    if !hasCharge or !self.Charging then return end

    -- A charge let go before it has wound up is read as a shove instead, so a quick right-click still does something useful.
    local held = CurTime() - ( self.SecondaryPressTime or CurTime() )
    if held < ( self.MeleeCharge.Threshold or 0.2 ) then
        self:CancelMeleeCharge()

        if hasShove then
            self:DoShove()
        end

        return
    end

    self:ReleaseMeleeCharge( held )
end

-- Starts the charge wind-up: plays the begin sequence and holds the attack locked for its duration. MeleeThink swaps to the looping charge idle once it ends.
function SWEP:BeginMeleeCharge()
    self.Charging = true
    self.ChargeIdlePlayed = false

    local dur = self:PlayAnim( self.MeleeCharge.BeginAnim or ACT_VM_ATTACK_CHARGE_BEGIN ) or 0
    self.ChargeBeginEnd = CurTime() + dur
    self:SetNextPrimaryFire( CurTime() + dur )
end

-- Aborts a charge that was released before it wound up, clearing the lock so the follow-up shove/swing can fire immediately.
function SWEP:CancelMeleeCharge()
    self.Charging = false
    self.ChargeIdlePlayed = false
    self:SetNextPrimaryFire( CurTime() )
end

-- Resolves a completed charge: the strength scales from MinMultiplier to Multiplier across MeleeCharge.Time, driving a heavier, longer-reaching hit than the light swing.
function SWEP:ReleaseMeleeCharge(held)
    self.Charging = false
    self.ChargeIdlePlayed = false

    local charge = self.MeleeCharge
    local frac = math.Clamp( ( held or 0 ) / ( charge.Time or 1 ), 0, 1 )

    local damage = self.Primary.Damage * Lerp( frac, charge.MinMultiplier or 1, charge.Multiplier or 2 )
    local range = ( self.Primary.Range or 85 ) * ( charge.RangeMultiplier or 1 )
    local hullSize = charge.HullSize or self.Primary.HullSize

    local hitDelay = charge.HitDelay or self.Primary.HitDelay or 0
    timer.Simple( hitDelay, function()
        if !IsValid( self ) or !IsValid( self:GetOwner() ) then return end

        self:ClubAttack( damage, range, hullSize )
        self:ViewPunch()
    end )

    self:EmitMeleeSwingSound( charge.Sound or self.Primary.Sound, charge.SoundDelay or self.Primary.SoundDelay )

    local dur = self:PlayAnim( charge.EndAnim or ACT_VM_ATTACK_CHARGE_END ) or 0
    self:GetOwner():SetAnimation( PLAYER_ATTACK1 )
    self:SetNextPrimaryFire( CurTime() + dur )
    self:QueueIdle()
end

-- A quick shove: a short-range, low-damage hit that mainly staggers and shoves whatever it lands on.
function SWEP:DoShove()
    local hitDelay = self.ShoveHitDelay or 0.05
    timer.Simple( hitDelay, function()
        if !IsValid( self ) or !IsValid( self:GetOwner() ) then return end

        self:ClubAttack( self.ShoveDamage or 0, self.ShoveRange or 45, self.ShoveHullSize or self.Primary.HullSize )
    end )

    if self.ShoveSound then
        self:EmitSound( self.ShoveSound )
    end

    local dur = self:PlayAnim( self.ShoveAnim ) or 0
    self:GetOwner():SetAnimation( PLAYER_ATTACK1 )
    self:SetNextPrimaryFire( CurTime() + ( self.ShoveDelay or dur ) )
    self:QueueIdle()
end

-- Maps the surface material a trace reports (tr.MatType) onto an ImpactSounds category key. Anything unmapped (dirt, sand, snow, water -- no fitting stock impact sound) falls through to the "default" entry.
local MATERIAL_IMPACT_KEY = {
    [MAT_FLESH] = "flesh",
    [MAT_BLOODYFLESH] = "flesh",
    [MAT_ALIENFLESH] = "flesh",
    [MAT_ANTLION] = "flesh",
    [MAT_METAL] = "metal",
    [MAT_VENT] = "metal",
    [MAT_GRATE] = "grate",
    [MAT_COMPUTER] = "computer",
    [MAT_WOOD] = "wood",
    [MAT_CONCRETE] = "concrete",
    [MAT_TILE] = "concrete",
    [MAT_GLASS] = "glass",
    [MAT_PLASTIC] = "plastic",
}

-- Returns a single sound from an ImpactSounds entry, choosing at random when the entry is a list.
function SWEP:PickImpactSound(entry)
    if istable( entry ) then
        if #entry == 0 then return nil end

        return entry[math.random(#entry)]
    end

    return entry
end

-- Resolves the impact sound for a melee hit from SWEP.ImpactSounds, most specific first: the kind of entity struck (player / npc / ragdoll), then the surface material for props and world, then a "default" catch-all, and finally the flat Primary.ImpactSound. Returns nil when nothing matches and there is no default.
function SWEP:GetImpactSound(tr)
    local sounds = self.ImpactSounds
    if !istable( sounds ) then
        return self.Primary.ImpactSound
    end

    local ent = tr.Entity
    if IsValid( ent ) then
        if ent:IsPlayer() and sounds.player then
            return self:PickImpactSound( sounds.player )
        end

        if ( ent:IsNPC() or ent:IsNextBot() ) and sounds.npc then
            return self:PickImpactSound( sounds.npc )
        end

        if ent:GetClass() == "prop_ragdoll" and sounds.ragdoll then
            return self:PickImpactSound( sounds.ragdoll )
        end
    end

    local key = MATERIAL_IMPACT_KEY[tr.MatType]
    if key and sounds[key] then
        return self:PickImpactSound( sounds[key] )
    end

    return self:PickImpactSound( sounds.default ) or self.Primary.ImpactSound
end

-- Builds the hull-sweep trace table for a melee attack, so the damage trace and the hit/miss animation read the exact same volume. range/hullSize override the Primary defaults.
function SWEP:GetMeleeTraceData(range, hullSize)
    range = range or self.Primary.Range or 85
    hullSize = hullSize or self.Primary.HullSize or 6

    local owner = self:GetOwner()
    local trace = {}
    trace.start = owner:GetShootPos()
    trace.endpos = trace.start + owner:GetAimVector() * range
    trace.filter = owner
    trace.mask = MASK_SHOT_HULL

    trace.mins = Vector( -hullSize, -hullSize, -hullSize )
    trace.maxs = Vector( hullSize, hullSize, hullSize )

    return trace
end

-- Sweeps the melee hull without applying anything, reporting whether the swing would connect so DoMeleeSwing can pick between SwingAnims and HitAnims.
function SWEP:WouldMeleeHit(range, hullSize)
    local owner = self:GetOwner()
    if !IsValid( owner ) then return false end

    owner:LagCompensation( true )
    local tr = util.TraceHull( self:GetMeleeTraceData( range, hullSize ) )
    owner:LagCompensation( false )

    return tr.Hit
end

-- Sweeps a hull in front of the player and applies damage/effects to whatever it hits. damage/range/hullSize override the Primary defaults, letting the charged swing and the shove reuse the same trace with their own reach and power.
function SWEP:ClubAttack(damage, range, hullSize)
    damage = damage or self.Primary.Damage

    local owner = self:GetOwner()
    local trace = self:GetMeleeTraceData( range, hullSize )

    owner:LagCompensation( true )
    local tr = util.TraceHull( trace )
    owner:LagCompensation( false )

    if CLIENT then
        debugoverlay.BoxAngles( tr.HitPos, trace.mins, trace.maxs, owner:EyeAngles(), 5, Color( 200, 0, 0, 100 ) )
    end

    if SERVER and tr.Hit then
        if ( hook.Run("LongswordCanMeleeHit", owner, self, tr, damage) == false ) then return end

        hook.Run( "LongswordMeleeHit", owner )

        -- The categorised ImpactSounds table, when present, picks by target (player/npc/ragdoll) or surface and plays for every hit; the legacy flat ImpactSound keeps its "world only" toggle for weapons that never opted in.
        if istable( self.ImpactSounds ) then
            local snd = self:GetImpactSound( tr )
            if snd then
                owner:EmitSound( snd )
            end
        elseif self.Primary.ImpactSound and !self.Primary.ImpactSoundWorldOnly then
            owner:EmitSound( self.Primary.ImpactSound )
        end

        local effectdata = EffectData()
        effectdata:SetOrigin(tr.HitPos)
        effectdata:SetStart(tr.StartPos)
        effectdata:SetSurfaceProp(tr.SurfaceProps)
        effectdata:SetEntity(tr.Entity)
        effectdata:SetHitBox(tr.HitBoxBone or 0)
        effectdata:SetDamageType(DMG_BULLET)
        util.Effect("Impact", effectdata)

        if self.Primary.ImpactEffect then
            local effect = EffectData()
            effect:SetStart( tr.HitPos )
            effect:SetNormal( tr.HitNormal )
            effect:SetOrigin( tr.HitPos )

            util.Effect( self.Primary.ImpactEffect, effect, true, true )
        end

        local ent = tr.Entity

        if IsValid( ent ) then
            local newDamage = hook.Run( "LongswordCalculateMeleeDamage", owner, damage, ent )
            hook.Run( "LongswordHitEntity", owner, ent )

            local dmg = DamageInfo()
            dmg:SetAttacker( owner )
            dmg:SetInflictor( self )
            dmg:SetDamage( newDamage or damage )
            dmg:SetDamageType( DMG_CLUB )
            dmg:SetDamagePosition( tr.HitPos )

            if ent:GetClass() != "prop_ragdoll" then
                dmg:SetDamageForce( owner:GetAimVector() * 10000 )
            end

            ent:DispatchTraceAttack( dmg, trace.start, trace.endpos )

            if self.OnMeleeHit then
                self:OnMeleeHit( tr, dmg )
            end

            if ent:IsPlayer() then
                if self.Primary.FlashTime then
                    ent:ScreenFade( SCREENFADE.IN, self.Primary.FlashColour or color_white, self.Primary.FlashTime, 0 )
                    ent.StunTime = CurTime() + self.Primary.FlashTime
                    ent.StunStartTime = CurTime()
                elseif self.Primary.StunTime then
                    ent.StunTime = CurTime() + self.Primary.StunTime
                    ent.StunStartTime = CurTime()
                end
            end

            if ( tr.MatType == MAT_FLESH ) then
                local effect = EffectData()
                effect:SetStart(tr.HitPos)
                effect:SetNormal(tr.HitNormal)
                effect:SetOrigin(tr.HitPos)

                util.Effect("BloodImpact", effect, true, true)
            end
        elseif self.MeleeHitFallback and self:MeleeHitFallback( tr ) then
            return
        elseif !istable( self.ImpactSounds ) and self.Primary.ImpactSoundWorldOnly then
            owner:EmitSound( self.Primary.ImpactSound )
        end
    end
end
