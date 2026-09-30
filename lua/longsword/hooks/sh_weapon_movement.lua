--- Applies optional weapon movement multipliers without changing the player's stored walk or run speeds.
---@param client Player
---@param movement CMoveData
local function ApplyWeaponMovement(client, movement)
    local weapon = client:GetActiveWeapon()
    if ( !IsValid(weapon) or !weapon.IsLongsword or !weapon.SpeedMultSights ) then return end

    local multiplier = weapon:GetIronsights() and weapon.SpeedMultSights or 1
    if ( weapon:GetNextPrimaryFire() > CurTime() and client:KeyDown(IN_ATTACK) ) then
        multiplier = multiplier * (weapon.SpeedMultShooting or 1)
    end
    movement:SetMaxSpeed(movement:GetMaxSpeed() * multiplier)
    movement:SetMaxClientSpeed(movement:GetMaxClientSpeed() * multiplier)
end

hook.Add("SetupMove", "longsword.WeaponMovement", ApplyWeaponMovement)
