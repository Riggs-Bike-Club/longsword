function SWEP:UsesMeleeAttack()
    return self.LongswordMode == "melee"
end

function SWEP:PrimaryMeleeAttack()
    if self.PrePrimaryAttack then
        self:PrePrimaryAttack()
    end

    if self.Primary.HitDelay then
        timer.Simple( self.Primary.HitDelay, function()
            if !IsValid( self ) or !IsValid( self:GetOwner() ) then return end

            self:ClubAttack()
            self:ViewPunch()
        end )
    else
        self:ClubAttack()
        self:ViewPunch()
    end

    self:EmitSound( self.Primary.Sound )
    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
    self:PlayAnim( self.HitAnim or ACT_VM_MISSCENTER )
    self:GetOwner():SetAnimation( PLAYER_ATTACK1 )
end

function SWEP:ClubAttack()
    local owner = self:GetOwner()
    local trace = {}
    trace.start = owner:GetShootPos()
    trace.endpos = trace.start + owner:GetAimVector() * ( self.Primary.Range or 85 )
    trace.filter = owner
    trace.mask = MASK_SHOT_HULL

    local boxSize = self.Primary.HullSize or 6
    trace.mins = Vector( -boxSize, -boxSize, -boxSize )
    trace.maxs = Vector( boxSize, boxSize, boxSize )

    owner:LagCompensation( true )
    local tr = util.TraceHull( trace )
    owner:LagCompensation( false )

    if CLIENT then
        debugoverlay.BoxAngles( tr.HitPos, trace.mins, trace.maxs, owner:EyeAngles(), 5, Color( 200, 0, 0, 100 ) )
    end

    if SERVER and tr.Hit then
        hook.Run( "LongswordMeleeHit", owner )

        if self.Primary.ImpactSound and !self.Primary.ImpactSoundWorldOnly then
            owner:EmitSound( self.Primary.ImpactSound )
        end

        if self.Primary.ImpactEffect then
            local effect = EffectData()
            effect:SetStart( tr.HitPos )
            effect:SetNormal( tr.HitNormal )
            effect:SetOrigin( tr.HitPos )

            util.Effect( self.Primary.ImpactEffect, effect, true, true )
        end

        local ent = tr.Entity

        if IsValid( ent ) then
            local newDamage = hook.Run( "LongswordCalculateMeleeDamage", owner, self.Primary.Damage, ent )
            hook.Run( "LongswordHitEntity", owner, ent )

            local dmg = DamageInfo()
            dmg:SetAttacker( owner )
            dmg:SetInflictor( self )
            dmg:SetDamage( newDamage or self.Primary.Damage )
            dmg:SetDamageType( DMG_CLUB )
            dmg:SetDamagePosition( tr.HitPos )

            if ent:GetClass() != "prop_ragdoll" then
                dmg:SetDamageForce( owner:GetAimVector() * 10000 )
            end

            ent:DispatchTraceAttack( dmg, trace.start, trace.endpos )

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

            if tr.MatType == MAT_FLESH then
                ent:EmitSound( "Flesh.ImpactHard" )

                local effect = EffectData()
                effect:SetStart( tr.HitPos )
                effect:SetNormal( tr.HitNormal )
                effect:SetOrigin( tr.HitPos )

                util.Effect( "BloodImpact", effect, true, true )
            elseif tr.MatType == MAT_WOOD then
                ent:EmitSound( "Wood.ImpactHard" )
            elseif tr.MatType == MAT_CONCRETE then
                ent:EmitSound( "Concrete.ImpactHard" )
            elseif self.Primary.ImpactSoundWorldOnly then
                owner:EmitSound( self.Primary.ImpactSound )
            end
        elseif self.MeleeHitFallback and self:MeleeHitFallback( tr ) then
            return
        elseif self.Primary.ImpactSoundWorldOnly then
            owner:EmitSound( self.Primary.ImpactSound )
        end
    end
end