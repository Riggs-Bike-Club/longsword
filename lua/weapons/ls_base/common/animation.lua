--- Default activities and legacy field aliases for the unified weapon animation configuration.
local ANIMATION_DEFAULTS = {
    draw = ACT_VM_DRAW,
    idle = ACT_VM_IDLE,
    fire = ACT_VM_PRIMARYATTACK,
    fireAimed = ACT_VM_PRIMARYATTACK_1,
    fireLast = ACT_VM_PRIMARYATTACK_EMPTY,
    dryFire = ACT_VM_DRYFIRE,
    reload = ACT_VM_RELOAD,
    reloadEmpty = ACT_VM_RELOAD_EMPTY,
    reloadStart = ACT_SHOTGUN_RELOAD_START,
    reloadChamber = ACT_VM_RELOAD_EMPTY,
    reloadInsert = ACT_VM_RELOAD,
    reloadFinish = ACT_SHOTGUN_RELOAD_FINISH,
    cycle = ACT_VM_PULLBACK,
    fireMode = ACT_VM_FIREMODE,
    meleeSwing = ACT_VM_MISSCENTER,
    meleeChargeStart = ACT_VM_ATTACK_CHARGE_BEGIN,
    meleeChargeIdle = ACT_VM_ATTACK_CHARGE_IDLE,
    meleeChargeRelease = ACT_VM_ATTACK_CHARGE_END,
    projectileFire = ACT_VM_PRIMARYATTACK,
    projectileThrow = ACT_VM_THROW,
    projectileDraw = ACT_VM_DRAW,
    worldFire = ACT_VM_PRIMARYATTACK,
    playerAttack = PLAYER_ATTACK1,
}

local ANIMATION_ALIASES = {
    draw = {"DrawAnim"},
    drawEmpty = {"EmptyDrawAnim"},
    holster = {"HolsterAnim"},
    holsterEmpty = {"EmptyHolsterAnim"},
    idle = {"IdleAnim"},
    idleEmpty = {"EmptyIdleAnim"},
    idleAimed = {"IronsightsIdleAnim"},
    idleAimedEmpty = {"EmptyIronsightsIdleAnim"},
    walk = {"WalkAnim"},
    walkEmpty = {"EmptyWalkAnim"},
    sprint = {"SprintAnim"},
    sprintEmpty = {"EmptySprintAnim"},
    fire = {"FireAnims", "FireAnim"},
    fireAimed = {"IronsightsAnimation"},
    fireLast = {"LastFireAnims", "LastFireAnim"},
    fireAimedLast = {"IronsightsLastFireAnims", "IronsightsLastFireAnim"},
    dryFire = {"DryFireAnim"},
    dryFireAimed = {"IronsightsDryFireAnim"},
    reload = {"ReloadAnimation"},
    reloadEmpty = {"EmptyReloadAnimation"},
    reloadStart = {"ShotgunReloadStartAnim"},
    reloadStartEmpty = {"ShotgunReloadStartEmptyAnim"},
    reloadInsert = {"ShotgunReloadInsertAnim"},
    reloadFinish = {"ShotgunReloadEndAnim"},
    reloadFinishEmpty = {"ShotgunReloadEndEmptyAnim"},
    inspect = {"InspectAnimations", "InspectAnimation"},
    cycle = {"Pullback.Anims", "Pullback.Anim", "PumpAnimation"},
    meleeSwing = {"SwingAnims"},
    meleeHit = {"HitAnims"},
    meleeShove = {"ShoveAnim"},
    meleeChargeStart = {"MeleeCharge.BeginAnim"},
    meleeChargeIdle = {"MeleeCharge.IdleAnim"},
    meleeChargeRelease = {"MeleeCharge.EndAnim"},
}

--- Returns an explicitly configured animation, preserving false as a disabled action and honoring legacy aliases.
---@realm shared
---@param name string Animation action key.
---@return string|number|table|boolean|nil definition Explicit configuration, before defaults.
function SWEP:GetAnimationDefinition(name)
    if ( self.Animations and self.Animations[name] != nil ) then
        return self.Animations[name]
    end
    for _, alias in ipairs(ANIMATION_ALIASES[name] or {}) do
        local parent, field = alias:match("^([^.]+)%.(.+)$")
        local value = self[alias]
        if ( parent and self[parent] ) then
            value = self[parent][field]
        end
        if ( value != nil and (!istable(value) or #value > 0) ) then
            return value
        end
    end
end

--- Reports whether an action has an explicit enabled animation rather than only a default activity.
---@realm shared
---@param name string Animation action key.
---@return boolean configured Whether the action is explicitly enabled.
function SWEP:HasAnimation(name)
    local definition = self:GetAnimationDefinition(name)
    return definition ~= nil and definition ~= false and (not istable(definition) or #definition > 0)
end

--- Resolves one animation variant, using centralized defaults only when the action is unset; false disables playback.
---@realm shared
---@param name string Animation action key.
---@return string|number|nil animation Sequence name or activity.
function SWEP:GetAnimation(name)
    local definition = self:GetAnimationDefinition(name)
    if ( definition == false ) then
        return
    end
    local animation
    if ( name:sub(1, 5) == "melee" and self.PickMeleeAnim ) then
        animation = self:PickMeleeAnim(definition)
    else
        animation = self:PickAnim(definition)
    end

    if ( animation != nil ) then
        return animation
    end
    return ANIMATION_DEFAULTS[name]
end

--- Resolves an optional variant before its fallback without overriding an explicitly disabled variant.
---@realm shared
---@param name string Primary action key.
---@param variant string Optional variant action key.
---@param bVariant boolean Whether to select the variant.
---@return string|number|nil animation Sequence name or activity.
function SWEP:GetAnimationVariant(name, variant, bVariant)
    if ( bVariant and self:GetAnimationDefinition(variant) != nil ) then
        return self:GetAnimation(variant)
    end
    return self:GetAnimation(name)
end

--- Plays a configured viewmodel action.
---@realm shared
---@param name string Animation action key.
---@param bKeepCycle? boolean Preserve the loop phase.
---@return number|nil duration Sequence duration in seconds.
function SWEP:PlayAnimation(name, bKeepCycle)
    return self:PlayAnim(self:GetAnimation(name), bKeepCycle)
end

--- Plays a configured player activity, or a supported forced sequence when the framework provides it.
---@realm shared
---@param name string Animation action key.
function SWEP:PlayPlayerAnimation(name)
    local owner = self:GetOwner()
    local animation = self:GetAnimation(name)
    if ( !IsValid(owner) or animation == nil ) then
        return
    end
    if ( isstring(animation) ) then
        if ( SERVER and owner.ForceSequence and owner:LookupSequence(animation) >= 0 ) then
            owner:ForceSequence(animation)
        end
        return
    end

    owner:SetAnimation(animation)
end

--- Plays the configured reload gesture or the engine's standard reload event when no override is provided.
---@realm shared
function SWEP:PlayReloadGesture()
    if ( self:GetAnimationDefinition("playerReload") != nil ) then
        self:PlayPlayerAnimation("playerReload")
        return
    end

    self:GetOwner():DoReloadEvent()
end

--- Plays an activity or sequence on the owner's viewmodel, optionally preserving its normalized loop phase.
---@realm shared
---@param act string|number|nil Sequence name or activity.
---@param bKeepCycle? boolean Preserve the loop phase.
---@return number|nil duration Sequence duration in seconds.
function SWEP:PlayAnim(act, bKeepCycle)
    if ( act == nil or act == false ) then
        return
    end
    local vmodel = self:GetOwnerViewModel()
    if ( !vmodel ) then
        return
    end
    local seq = isstring(act) and vmodel:LookupSequence(act) or vmodel:SelectWeightedSequence(act)
    if ( !seq or seq == -1 ) then
        return longsword.debugPrint("Attempting to play invalid sequence " .. tostring(act) .. " on " .. self:GetClass() .. "!")
    end
    local cycle = bKeepCycle and vmodel:GetCycle() or nil
    self.Inspecting = false
    vmodel:ResetSequenceInfo()
    vmodel:SendViewModelMatchingSequence(seq)
    if ( cycle ) then
        vmodel:SetCycle(cycle)
    end
    self:StartAnimationEvents(act, cycle)
    return vmodel:SequenceDuration(seq)
end

--- Emits animation audio locally for the predicted owner and to other listeners from the server.
---@realm shared
---@param owner Player
---@param event table
function SWEP:EmitAnimationEventSound(owner, event)
    local soundName = event.sound
    if ( istable(soundName) ) then
        if ( #soundName == 0 ) then return end
        soundName = soundName[math.random(#soundName)]
    end
    if ( !isstring(soundName) ) then return end

    local recipients
    if ( SERVER and !game.SinglePlayer() and owner:IsPlayer() ) then
        recipients = RecipientFilter()
        recipients:AddPAS(self:GetPos())
        recipients:RemovePlayer(owner)
    end
    self:EmitSound(soundName, event.level or 60, event.pitch or 100, event.volume or 1, CHAN_AUTO, 0, 0, recipients)
end

--- Dispatches animation audio in its playback realm and callbacks only on the server.
---@realm shared
---@param owner Player
---@param serial number
---@param event table Timed sound or callback definition.
function SWEP:RunAnimationEvent(owner, serial, event)
    if ( !IsValid(self) or self.animationEventSerial != serial ) then return end
    if ( !IsValid(owner) or !owner:Alive() or self:GetOwner() != owner ) then return end
    if ( owner:GetActiveWeapon() != self ) then return end

    if ( event.stopSound ) then
        for _, soundName in ipairs(istable(event.stopSound) and event.stopSound or {event.stopSound}) do
            self:StopSound(soundName)
        end
    end
    if ( event.sound ) then
        self:EmitAnimationEventSound(owner, event)
    end
    if ( SERVER and isfunction(event.callback) ) then
        event.callback(self, event)
    end
end

--- Schedules AnimationEvents keyed by the selected sequence name or activity; preserved loops cancel without replaying events.
---@realm shared
---@param animation string|number Selected sequence name or activity constant.
---@param cycle? number Preserved loop phase.
function SWEP:StartAnimationEvents(animation, cycle)
    if ( CLIENT ) then
        if ( game.SinglePlayer() or self:GetOwner() != LocalPlayer() or !IsFirstTimePredicted() ) then return end
    elseif ( !SERVER ) then
        return
    end

    self.animationEventSerial = (self.animationEventSerial or 0) + 1
    if ( cycle != nil or !self.AnimationEvents ) then return end

    local serial = self.animationEventSerial
    local owner = self:GetOwner()
    for _, event in ipairs(self.AnimationEvents[animation] or {}) do
        local delay = math.max(event.time or 0, 0)
        if ( delay == 0 ) then
            self:RunAnimationEvent(owner, serial, event)
        else
            timer.Simple(delay, function()
                if ( IsValid(self) ) then
                    self:RunAnimationEvent(owner, serial, event)
                end
            end)
        end
    end
end

--- Reports whether a magazine is empty; clipless weapons report -1 and are never empty.
function SWEP:IsClipEmpty()
    return self:Clip1() == 0
end

--- Resolves a single activity or sequence name, selecting one entry when supplied with a variant list.
function SWEP:PickAnim(anim)
    if ( istable(anim) ) then
        if ( #anim == 0 ) then
            return nil
        end
        return anim[math.random(#anim)]
    end
    return anim
end

--- Selects the legacy empty-clip variant when explicitly configured.
function SWEP:ResolveEmptyAnim(anim, emptyAnim)
    if ( emptyAnim and self:IsClipEmpty() ) then
        return emptyAnim
    end
    return anim
end

--- Resolves the draw action for the current magazine state.
function SWEP:GetDrawAnim()
    return self:GetAnimationVariant("draw", "drawEmpty", self:IsClipEmpty())
end

--- Caps draw recovery independently of the cosmetic animation without extending short sequences.
---@param duration number Draw sequence duration in seconds.
---@return number delay Seconds before the weapon can fire.
function SWEP:GetDrawDelay(duration)
    return math.min(duration, math.max(self.DrawDelay or 0.25, 0))
end

--- Resolves the holster action for the current magazine state.
function SWEP:GetHolsterAnim()
    return self:GetAnimationVariant("holster", "holsterEmpty", self:IsClipEmpty())
end

--- Enables holstering for unified definitions while respecting the legacy opt-in flag.
---@realm shared
---@return boolean enabled Whether holstering is configured.
function SWEP:ShouldAnimateHolster()
    if ( self.Animations and (self.Animations.holster != nil or self.Animations.holsterEmpty != nil) ) then
        return self:HasAnimation("holster") or self:HasAnimation("holsterEmpty")
    end
    return self.DoHolsterAnim == true
end

--- Enables last-round animation variants through explicit definitions or the legacy opt-in flag.
---@realm shared
---@return boolean enabled Whether last-round animation selection is enabled.
function SWEP:ShouldAnimateLastShot()
    return self.DoLastFireAnim == true or self:HasAnimation("fireLast") or self:HasAnimation("fireAimedLast")
end

--- Chooses projectile firing instead of throwing when configured, retaining the legacy DoFireAnim flag.
---@realm shared
---@return boolean enabled Whether the projectile uses its firing action.
function SWEP:ShouldAnimateProjectileFire()
    if ( self.Animations and self.Animations.bUseProjectileFire != nil ) then
        return self.Animations.bUseProjectileFire
    end
    return self.DoFireAnim == true
end

--- Resolves dry firing, preferring the aimed variant when explicitly configured.
function SWEP:GetDryFireAnim()
    return self:GetAnimationVariant("dryFire", "dryFireAimed", self:GetIronsights())
end

--- Plays a supported activity or named sequence on the worldmodel.
---@realm shared
---@param act string|number|nil Sequence name or activity.
function SWEP:PlayAnimWorld(act)
    if ( act == nil or act == false ) then
        return
    end
    local wmodel = self
    local seq = isstring(act) and wmodel:LookupSequence(act) or wmodel:SelectWeightedSequence(act)
    if ( !seq or seq < 0 ) then
        return
    end
    self:ResetSequence(seq)
end

--- Resumes the current idle or movement loop as soon as the active animation ends.
function SWEP:QueueIdle()
    local viewModel = self:GetOwnerViewModel()
    if ( !viewModel ) then
        return
    end
    self:SetNextIdle(CurTime() + viewModel:SequenceDuration())
end
