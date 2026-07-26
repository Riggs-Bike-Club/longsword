function SWEP:UsesShotgunReload()
    return self.Shotgun == true or self.LongswordMode == "shotgun"
end

-- The shell-by-shell reload has three stages -- an opening rack, one insert per shell, and a closing rack -- each of which the viewmodel usually animates differently depending on whether the tube started empty (bolt locked open, so the closing rack chambers a round) or not. Each getter honours a named/activity override and only reaches for an empty variant the weapon actually defines, so a shotgun that ships a single set of reload sequences keeps its original behaviour.

-- Opening rack. Falls back to the legacy ACT_VM_RELOAD_EMPTY only for chambering shotguns, which is where that activity was hardcoded before.
function SWEP:GetShotgunReloadStartAnim()
    if self:IsClipEmpty() then
        return self.ShotgunReloadStartEmptyAnim or (self.CanChamberShotgun and ACT_VM_RELOAD_EMPTY) or self.ShotgunReloadStartAnim or ACT_SHOTGUN_RELOAD_START
    end

    return self.ShotgunReloadStartAnim or ACT_SHOTGUN_RELOAD_START
end

-- Single-shell insert, replayed once per shell.
function SWEP:GetShotgunReloadInsertAnim()
    return self.ShotgunReloadInsertAnim or ACT_VM_RELOAD
end

-- Closing rack. The choice follows whether the tube was empty when the reload BEGAN (tracked in ReloadStartedEmpty), not its state now -- by the time it finishes the tube is full either way, but only the reload that started empty needs the round chambered at the end.
function SWEP:GetShotgunReloadEndAnim()
    if self.ReloadStartedEmpty and self.ShotgunReloadEndEmptyAnim then
        return self.ShotgunReloadEndEmptyAnim
    end

    return self.ShotgunReloadEndAnim or ACT_SHOTGUN_RELOAD_FINISH
end

function SWEP:ReloadShotgun()
    self.ReloadStartedEmpty = self:IsClipEmpty()

    self:PlayAnim( self:GetShotgunReloadStartAnim() )

    -- The empty-start animation loads a round straight into the chamber, so credit that shell as the rack plays. CanChamberShotgun implies this (and also raises the max by the chambered round); ShotgunEmptyChambers is the same load without changing capacity, for tubes whose clip size already counts the chamber.
    if self:IsClipEmpty() and (self.CanChamberShotgun or self.ShotgunEmptyChambers) then
        self:SetClip1( self:Clip1() + 1 )
        self:GetOwner():RemoveAmmo( 1, self:GetPrimaryAmmoType() )
    end

    self:GetOwner():DoReloadEvent()
    self:QueueIdle()

    self:SetReloading( true )
    self:SetReloadTime( CurTime() + self:GetOwner():GetViewModel():SequenceDuration() )

    if self.ReloadSound then
        self:EmitSound( self.ReloadSound )
    end

    hook.Run( "LongswordWeaponReload", self:GetOwner(), self )
end

function SWEP:InsertShell()
    self:SetClip1( self:Clip1() + 1 )
    self:GetOwner():RemoveAmmo( 1, self:GetPrimaryAmmoType() )

    self:PlayAnim( self:GetShotgunReloadInsertAnim() )
    self:QueueIdle()

    self:SetReloadTime( CurTime() + ( self.ShellInsertDelay or self:GetOwner():GetViewModel():SequenceDuration() ) )

    if self.ReloadShellSound then
        self:EmitSound( self.ReloadShellSound )
    end
end

function SWEP:ShotgunReloadThink()
    if self:GetReloadTime() > CurTime() then return end

    local clipSize = self.Primary.ClipSize

    if self.CanChamberShotgun then
        clipSize = clipSize + 1
    end

    if self:Clip1() < clipSize and self:GetOwner():GetAmmoCount( self:GetPrimaryAmmoType() ) > 0
        and !self:GetOwner():KeyDown( IN_ATTACK ) then
        self:InsertShell()
    else
        self:FinishShotgunReload()
    end
end

function SWEP:FinishShotgunReload()
    self:SetReloading( false )

    self:PlayAnim( self:GetShotgunReloadEndAnim() )
    self:SetReloadTime( CurTime() + self:GetOwner():GetViewModel():SequenceDuration() )
    self:QueueIdle()

    if self.PumpSound then
        self:EmitSound( self.PumpSound )
    end
end
