-- Muzzle flash particle systems from the FA:S 2.0 muzzleflashes_test PCFs shipped by this addon.
local PARTICLE_FILES = {
    "particles/muzzleflashes_test.pcf",
    "particles/muzzleflashes_test_b.pcf",
    "particles/csgo_fx.pcf",
    "particles/tfa_ballistics.pcf",
    "particles/tfa_ins2_ejectionsmoke.pcf",
    "particles/tfa_ins2_muzzlesmoke.pcf",
    "particles/tfa_ins2_shellsmoke.pcf",
    "particles/tfa_muzzleflashes.pcf",
    "particles/tfa_smoke.pcf",
}

local PARTICLE_SYSTEMS = {
    "muzzleflash_smg",
    "muzzleflash_smg_bizon",
    "muzzleflash_shotgun",
    "muzzleflash_slug",
    "muzzleflash_slug_flame",
    "muzzleflash_pistol",
    "muzzleflash_pistol_cleric",
    "muzzleflash_pistol_deagle",
    "muzzleflash_suppressed",
    "muzzleflash_mp5",
    "muzzleflash_MINIMI",
    "muzzleflash_m79",
    "muzzleflash_m14",
    "muzzleflash_ak47",
    "muzzleflash_ak74",
    "muzzleflash_m82",
    "muzzleflash_m3",
    "muzzleflash_famas",
    "muzzleflash_g3",
    "muzzleflash_1",
    "muzzleflash_3",
    "muzzleflash_4",
    "muzzleflash_5",
    "muzzleflash_6",
    "tfa_muzzle_rifle",
    "tfa_muzzle_sniper",
    "tfa_muzzle_energy",
    "tfa_muzzle_gauss",
    "tfa_ins2_weapon_muzzle_smoke",
    "tfa_ins2_weapon_shell_smoke",
    "tfa_ins2_shell_eject",
    "tfa_bullet_smoke_tracer",
    "tfa_bullet_fire_tracer",
    "smoke_trail_tfa",
    "smoke_trail_controlled",
    "weapon_muzzle_smoke",
    "weapon_muzzle_smoke_long",
}

-- game.AddParticles at autorun time is wiped when the engine initialises the map's own particle manifest, so the files must be (re)loaded after the map is up.
local function LoadParticles()
    for _, fileName in ipairs( PARTICLE_FILES ) do
        game.AddParticles( fileName )
    end

    for _, systemName in ipairs( PARTICLE_SYSTEMS ) do
        PrecacheParticleSystem( systemName )
    end
end

LoadParticles()

hook.Add( "InitPostEntity", "Longsword.LoadParticles", function()
    LoadParticles()
end )
