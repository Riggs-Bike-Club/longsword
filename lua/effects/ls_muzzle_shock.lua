-- Muzzle pressure-wave dust shock: a Lua recreation of the Synapse-era muzzle_smoke_shock_<size> PCF systems, spawned by ls_muzzleflash for weapons without NoFlashShock.

local DUST_COLOR = Color( 190, 180, 165 )

local dustMats = {
    "particle/smokesprites_0001",
    "particle/smokesprites_0002",
    "particle/smokesprites_0003",
    "particle/smokesprites_0004",
}

-- Tuning per shock size; keyed by the magnitude set in ls_muzzleflash (1 = small, 2 = medium, 3 = large).
local sizeConfigs = {
    { count = 6, speed = 26, startSize = 3, growSize = 9, life = 0.3, alpha = 26 },
    { count = 8, speed = 40, startSize = 4, growSize = 14, life = 0.42, alpha = 34 },
    { count = 12, speed = 58, startSize = 6, growSize = 22, life = 0.55, alpha = 44 },
}

---Spawns the radial dust ring and forward bore puffs at the muzzle attachment.
---@param data CEffectData Effect data carrying the entity, attachment and size magnitude.
function EFFECT:Init( data )
    local ent = data:GetEntity()
    if ( !IsValid( ent ) ) then return end

    local attData = ent:GetAttachment( data:GetAttachment() )
    if ( !attData ) then return end

    local cfg = sizeConfigs[math.Round( data:GetMagnitude() )] or sizeConfigs[1]

    local pos = attData.Pos
    local forward = attData.Ang:Forward()
    local right = attData.Ang:Right()
    local up = attData.Ang:Up()

    local emitter = ParticleEmitter( pos )
    if ( !emitter ) then return end

    -- Radial ring of dust kicked outward by the muzzle pressure wave.
    for i = 1, cfg.count do
        local theta = ( i / cfg.count ) * math.pi * 2
        local dir = right * math.cos( theta ) + up * math.sin( theta )

        local particle = emitter:Add( dustMats[math.random( #dustMats )], pos + dir * 2 )
        if ( particle ) then
            particle:SetVelocity( dir * cfg.speed * math.Rand( 0.7, 1.2 ) + forward * cfg.speed * 0.35 )
            particle:SetDieTime( cfg.life * math.Rand( 0.8, 1.2 ) )
            particle:SetStartAlpha( cfg.alpha )
            particle:SetEndAlpha( 0 )
            particle:SetStartSize( cfg.startSize )
            particle:SetEndSize( cfg.startSize + cfg.growSize )
            particle:SetRoll( math.Rand( 0, 360 ) )
            particle:SetRollDelta( math.Rand( -1.5, 1.5 ) )
            particle:SetColor( DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b )
            particle:SetAirResistance( 90 )
            particle:SetLighting( false )
        end
    end

    -- A few slower puffs drifting straight out of the bore.
    for i = 1, math.ceil( cfg.count / 3 ) do
        local particle = emitter:Add( dustMats[math.random( #dustMats )], pos + forward * i * 2 )
        if ( particle ) then
            particle:SetVelocity( forward * cfg.speed * math.Rand( 0.8, 1.4 ) )
            particle:SetDieTime( cfg.life * math.Rand( 1, 1.4 ) )
            particle:SetStartAlpha( cfg.alpha * 0.75 )
            particle:SetEndAlpha( 0 )
            particle:SetStartSize( cfg.startSize )
            particle:SetEndSize( cfg.startSize + cfg.growSize * 0.75 )
            particle:SetRoll( math.Rand( 0, 360 ) )
            particle:SetRollDelta( math.Rand( -1, 1 ) )
            particle:SetColor( DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b )
            particle:SetAirResistance( 70 )
            particle:SetLighting( false )
        end
    end

    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end
