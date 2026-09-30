--- Controls for one firing sound layer; omitted values inherit the weapon's existing defaults.
---@class LongswordSoundLayer
---@field sound string|string[]|function Sound name, random variant list, or callback.
---@field level? number Sound level, defaulting to 60.
---@field pitch? number Pitch percentage, defaulting to 100.
---@field volume? number Volume from 0 to 1, defaulting to SWEP.SoundLayerVol or 1.
---@field delay? number Delay in seconds, defaulting to Primary.SoundLayerDelay or 0.

--- Emits a sound layer only while the weapon remains valid.
---@realm shared
---@param soundName string|string[]|function Sound name, variant list, or callback.
---@param level? number Sound level.
---@param pitch? number Pitch percentage.
---@param volume? number Sound volume.
function SWEP:EmitFireSoundLayer(soundName, level, pitch, volume)
    if ( !IsValid(self) ) then
        return
    end

    self:EmitWeaponSound(soundName, level, pitch, volume)
end

--- Plays or schedules an individual firing layer, retaining support for legacy sound names, variant lists, and callbacks.
---@realm shared
---@param layer string|string[]|function|LongswordSoundLayer Sound layer configuration.
function SWEP:PlayFireSoundLayer(layer)
    local soundName = layer
    local level
    local pitch
    local volume = self.SoundLayerVol or 1
    local delay = self.Primary.SoundLayerDelay or 0

    if ( istable(layer) and layer.sound != nil ) then
        soundName = layer.sound
        level = layer.level
        pitch = layer.pitch
        volume = layer.volume or volume
        delay = layer.delay or delay
    end

    if ( delay > 0 ) then
        timer.Simple(delay, function()
            self:EmitFireSoundLayer(soundName, level, pitch, volume)
        end)

        return
    end

    self:EmitFireSoundLayer(soundName, level, pitch, volume)
end

--- Plays the primary firing sound and independently configured additional layers.
---@realm shared
function SWEP:PlayFireSound()
    if ( self.Primary.LoopSound ) then
        return
    end

    self:EmitWeaponSound(self.Primary.Sound, self.Primary.SoundLevel, self.Primary.SoundPitch, self.Primary.SoundVolume)

    if ( !istable(self.Primary.SoundLayers) ) then
        return
    end

    for _, layer in pairs(self.Primary.SoundLayers) do
        self:PlayFireSoundLayer(layer)
    end
end
