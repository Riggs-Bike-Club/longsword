local originalCol = Color(201, 165, 112)
local flashes = {
    "muzzleflash_1",
    "muzzleflash_3",
    "muzzleflash_4",
    "muzzleflash_5",
    "muzzleflash_6"
}

-- Maps SWEP.MuzzleFlashShock to the size magnitude consumed by ls_muzzle_shock.
local shockSizes = {
    small = 1,
    medium = 2,
    large = 3,
}

-- Returns the world position and angles of the muzzle attachment, with SWEP.MuzzleFlashAngle applied as a rotation around the attachment's own axes so a model that ships a mis-oriented muzzle attachment can be corrected without recompiling it.
local function GetMuzzleTransform(ent, attachment, wep)
    local att = ent:GetAttachment(attachment)
    if ( !att ) then return end

    local ang = Angle(att.Ang)
    local offset = wep.MuzzleFlashAngle

    if ( offset ) then
        ang:RotateAroundAxis(ang:Up(), offset.y)
        ang:RotateAroundAxis(ang:Right(), offset.p)
        ang:RotateAroundAxis(ang:Forward(), offset.r)
    end

    return att.Pos, ang
end

function EFFECT:Init( data )
	self.offset = data:GetOrigin() + Vector( 0, 0, 0.2 )
	self.angles = data:GetAngles()

    local ent = data:GetEntity()

    local ply = ent:GetOwner()
    local wep = ply:GetActiveWeapon()

    if not IsValid(wep) then return end

    if (game.SinglePlayer() or IsFirstTimePredicted()) then
        local pos, ang = GetMuzzleTransform(ent, data:GetAttachment(), wep)

        if ( wep.MuzzleFlashEffect ) then
            -- Engine muzzle flashes take an origin and angles rather than an attachment, so they stay aimable even when the attachment itself is rotated.
            if ( pos ) then
                local ed = EffectData()
                ed:SetOrigin(pos)
                ed:SetAngles(ang)
                ed:SetScale(data:GetScale())
                ed:SetFlags(wep.MuzzleFlashFlags or 0)

                util.Effect(wep.MuzzleFlashEffect, ed)
            end
        elseif ( wep.MuzzleFlashAngle and pos ) then
            -- PATTACH_POINT_FOLLOW inherits the attachment's rotation, so a corrected flash has to be spawned unparented. Muzzle flashes are short enough that not following the viewmodel is not noticeable.
            ParticleEffect(
                wep.MuzzleFlashName or flashes[math.random(#flashes)],
                pos,
                ang
            )
        else
            ParticleEffectAttach(
                wep.MuzzleFlashName or flashes[math.random(#flashes)],
                PATTACH_POINT_FOLLOW,
                data:GetEntity(),
                data:GetAttachment()
            )
        end
    end

    if ( !wep.NoFlashShock and ( game.SinglePlayer() or IsFirstTimePredicted() ) ) then
        local ed = EffectData()
        ed:SetEntity( data:GetEntity() )
        ed:SetAttachment( data:GetAttachment() )
        ed:SetMagnitude( shockSizes[wep.MuzzleFlashShock or "small"] or 1 )

        util.Effect( "ls_muzzle_shock", ed )
    end

    if CLIENT then
        local light = DynamicLight(ent:EntIndex())
        if not light then return longsword.debugPrint("Couldn't create dynamic light.") end

        local col = wep.LightColor or originalCol
    
        light.pos = LocalPlayer():GetShootPos()
        light.r = col.r
        light.g = col.g
        light.b = col.b
        light.brightness = 2
        light.decay = 5000
        light.dietime = 0.2
        light.size = 256
    end
end
