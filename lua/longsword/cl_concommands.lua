concommand.Add("longsword_debug_attachments", function()
    local vm = LocalPlayer():GetViewModel()

    PrintTable(vm:GetAttachments())
end)

longsword.debugIronsights = longsword.debugIronsights or {}
local debugIronsights = longsword.debugIronsights

--- Toggles held aim input for the active Longsword weapon; an optional zero or one explicitly disables or enables it.
---@param client Player
---@param commandName string
---@param arguments string[]
local function ToggleDebugIronsights(client, commandName, arguments)
    if ( arguments[1] and arguments[1] != "0" and arguments[1] != "1" ) then
        print("Usage: longsword_debug_ironsights [0|1]")
        return
    end

    local owner = LocalPlayer()
    if ( !IsValid(owner) ) then return end
    local weapon = owner:GetActiveWeapon()
    local bEnabled = arguments[1] == "1" or (arguments[1] == nil and debugIronsights.weapon != weapon)

    if ( !bEnabled ) then
        debugIronsights.weapon = nil
        debugIronsights.bRelease = true
        print("[Longsword] Debug ironsights disabled.")
        return
    end

    if ( !owner:Alive() or !IsValid(weapon) or !weapon.IsLongsword ) then
        print("[Longsword] Equip a Longsword weapon first.")
        return
    end

    if ( weapon.NoIronsights or weapon:UsesMeleeAttack() or weapon:UsesProjectileAttack() ) then
        print("[Longsword] This weapon does not support debug ironsights.")
        return
    end

    debugIronsights.weapon = weapon
    debugIronsights.bRelease = false
    print("[Longsword] Debug ironsights enabled. Run longsword_debug_ironsights again to release aim.")
end

--- Holds the normal aim button until toggled off, the weapon changes, or the player dies.
---@param command CUserCmd
local function ApplyDebugIronsights(command)
    if ( debugIronsights.bRelease ) then
        command:RemoveKey(IN_ATTACK2)
        debugIronsights.bRelease = false
        return
    end

    if ( !IsValid(debugIronsights.weapon) ) then return end

    local owner = LocalPlayer()
    if ( !IsValid(owner) or !owner:Alive() or owner:GetActiveWeapon() != debugIronsights.weapon ) then
        debugIronsights.weapon = nil
        command:RemoveKey(IN_ATTACK2)
        return
    end

    command:SetButtons(bit.bor(command:GetButtons(), IN_ATTACK2))
end

concommand.Add("longsword_debug_ironsights", ToggleDebugIronsights, nil, "Toggle held ironsights on the active Longsword weapon, or pass 0/1.")
hook.Add("CreateMove", "longsword.DebugIronsights", ApplyDebugIronsights)

concommand.Add("longsword_debug_bones", function()
    local vm = LocalPlayer():GetViewModel()

    for i = 1, vm:GetBoneCount() do
        print(vm:GetBoneName(i), i)
    end
end)
