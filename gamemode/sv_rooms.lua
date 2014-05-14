print("\n\nLoading rooms!\n\n")

--[[
    NOTE:
        Most of the entity copy stuff is from advanced duplicator
        https://github.com/wiremod/advduplicator
]]

--[[
    Rooms Class
]]
Rooms = Rooms or {}

function Rooms:New()
    local r = {
        ["players"] = {},
        ["running"] = false,
        ["ents"] = {}
    }
    setmetatable(r, {__index = Rooms})
    return r
end

-- Adds a player to a room
function Rooms:AddPlayer(ply)
    -- Check if the player is already in a room
    local oldRoom = ply:GetRoom()
    if oldRoom then
        -- Remove them from that room
        oldRoom:RemovePlayer(ply)
    end

    -- Add them to this room
    table.insert(self.players, ply)

    -- Store this room as their room on the player
    ply:SetRoom(self)

    -- Send them the room's running state
    net.Start("roomRunning")
    net.WriteBit(self:GetRunning())
    net.Send(ply)
end

-- Removes a player from a room
function Rooms:RemovePlayer(ply)
    for k,v in pairs(self.players) do
        if ply == v then
            table.remove(self.players, k)
            return true
        end
    end

    return false
end

-- Adds an entity to a room
function Rooms:AddEnt(ent)
    -- Check if the player is already in a room
    local oldRoom = ent:GetRoom()
    if oldRoom then
        -- Remove them from that room
        oldRoom:RemoveEnt(ent)
    end

    -- Add them to this room
    table.insert(self.ents, ent)

    -- Store this room as their room on the player
    ent:SetRoom(self)

    -- Change ent based on stuff
    if self:GetRunning() then
        -- Enable damage
        ent:enableDamage()
    else
        -- Freeze entitiy
        freezeEntity(ent)

        -- Disable Damage
        ent:disableDamage()
    end
end

-- Removes an entity from a room
function Rooms:RemoveEnt(ent)
    for k,v in pairs(self.ents) do
        if ent == v then
            table.remove(self.ents, k)
            return true
        end
    end

    return false
end

local KeyLookup = {
    pos = "Pos",
    position = "Pos",
    ang = "Angle",
    Ang = "Angle",
    angle = "Angle",
    model = "Model",
}

-- from http://lua-users.org/wiki/StringRecipes
function split(str, pat)
   local t = {}
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
     table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function GetsaveableConst(constraintEntity, offset)
    if not constraintEntity then
        return {}
    end

    local saveableConst = {}
    local constTable = constraintEntity:GetTable()

    local factory = duplicator.ConstraintType[constTable.Type]
    if factory then
        saveableConst.Type = constTable.Type

        for k, key in pairs(factory.Args) do
            if (not string.find(key, 'Ent') or string.len(key) ~= 4)
            and (not string.find(key, 'Bone') or string.len(key) ~= 5)
            and key ~= 'Ent' and (key ~= 'Bone')
            and constTable[key] and constTable[key] ~= false then
                saveableConst[key] = constTable[key]
            end
        end

    else
        table.Merge(saveableConst, constraintEntity:GetTable())
    end

    if constTable.Type == 'Elastic' or constTable.length then
        saveableConst.length = constTable.length
    end

    saveableConst.Entity = {}
    local ents = {}

    if constTable[ "Ent" ] and (constTable['Ent']:IsWorld() or IsValid(constTable['Ent'])) then
        saveableConst.Entity[1] = {}
        saveableConst.Entity[1].Index = constTable['Ent']:EntIndex()
        if constTable['Ent']:IsWorld() then
            saveableConst.Entity[1].World = true
        end
        saveableConst.Entity[1].Bone = constTable['Bone']

    else
        for i=1, 6 do
            local entn = "Ent"..i
            if constTable[ entn ] and ( constTable[entn]:IsWorld() or IsValid(constTable[entn])) then
                saveableConst.Entity[i] = {}
                saveableConst.Entity[i].Index     = constTable[entn ]:EntIndex()
                saveableConst.Entity[i].Bone      = constTable['Bone'..i]
                saveableConst.Entity[i].WPos      = constTable['WPos'..i]
                saveableConst.Entity[i].Length    = constTable['Length'..i]
                if constTable[ entn ]:IsWorld() then
                    saveableConst.Entity[i].World = true
                    if constTable['LPos'..i] then
                        saveableConst.Entity[i].LPos = constTable['LPos'..i] - offset
                    else
                        saveableConst.Entity[i].LPos = offset
                    end
                else
                    saveableConst.Entity[i].LPos = constTable['LPos'..i]
                end
                table.insert(ents, constTable[entn])
            end
        end
    end

    return saveableConst, ents
end

function GetSaveableEntity(ent, offset)
    if ent.PreEntityCopy then
        ent:PreEntityCopy()
    end

    local tab = table.Copy(ent:GetTable())

    if ent.PostEntityCopy then
        ent:PostEntityCopy()
    end

    tab.Angle = ent:GetAngles()
    tab.Pos = ent:GetPos()
    tab.CollisionGroup = ent:GetCollisionGroup()

    -- Physics Objects
    tab.PhysicsObjects =  tab.PhysicsObjects or {}
    local iNumPhysObjects = ent:GetPhysicsObjectCount()
    for bone = 0, iNumPhysObjects-1 do
        local physObj = ent:GetPhysicsObjectNum( bone )
        if IsValid(physObj) then
            tab.PhysicsObjects[bone] = tab.PhysicsObjects[ bone ] or {}
            tab.PhysicsObjects[bone].Pos = physObj:GetPos()
            tab.PhysicsObjects[bone].Angle = physObj:GetAngles()
            tab.PhysicsObjects[bone].Frozen = ent.isWireFrozen or false--not physObj:IsMoveable()
            if physObj:IsGravityEnabled() == false then
                tab.PhysicsObjects[ bone ].NoGrav = true
            end
        end
    end

    -- Flexes (WTF are these?)
    local flexNum = ent:GetFlexNum()
    for i = 0, flexNum do
        tab.Flex = tab.Flex or {}
        tab.Flex[i] = ent:GetFlexWeight(i)
    end
    tab.FlexScale = ent:GetFlexScale()

    -- Let the ent fuckup our nice new table if it wants too
    if ent.OnEntityCopytableFinish then
        ent:OnEntityCopytableFinish(tab)
    end

    tab.Pos = tab.Pos - offset
    tab.LocalPos = tab.Pos * 1
    tab.LocalAngle = tab.Angle * 1
    if ( tab.PhysicsObjects ) then
        for num, object in pairs(tab.PhysicsObjects) do
            object.Pos = object.Pos - offset
            object.LocalPos = object.Pos * 1
            object.LocalAngle = object.Angle * 1
            object.Pos = nil
            object.Angle = nil
        end
    end

    --Save CollisionGroupMod
    if ( tab.CollisionGroup ) then
        tab.EntityMods = tab.EntityMods or {}
        tab.EntityMods.CollisionGroupMod = tab.CollisionGroup
    end

    --fix for saving key on camera
    if (ent:GetClass() == "gmod_cameraprop") then
        tab.key = ent:GetNetworkedInt("key")
    end

    --Saveablity
    local saveableEntity = {}
    saveableEntity.Class = ent:GetClass()

    -- escape the model string properly cause something out there rapes it sometimes
    saveableEntity.Model = table.concat(split(ent:GetModel(), '\\+'), '/')

    saveableEntity.Skin             = ent:GetSkin()
    saveableEntity.LocalPos         = tab.LocalPos
    saveableEntity.LocalAngle       = tab.LocalAngle
    saveableEntity.BoneMods         = table.Copy(tab.BoneMods)
    saveableEntity.EntityMods       = table.Copy(tab.EntityMods)
    saveableEntity.PhysicsObjects   = table.Copy(tab.PhysicsObjects)
    if ent.GetNetworkVars then
        saveableEntity.DT = ent:GetNetworkVars()
    end

    if IsValid(ent:GetParent()) then
        saveableEntity.SavedParentIdx = ent:GetParent():EntIndex()
    end

    -- Wire Challenge stuff
    if ent.isWireFrozen then
        saveableEntity.isWireFrozen = true
    end

    local entityClass = duplicator.FindEntityClass(saveableEntity.Class)
    if not entityClass then
        return saveableEntity
    end -- This class is unregistered. Just save what we have so far

    -- Filter functions, we only want to save what will be used
    for iNumber, key in pairs( entityClass.Args ) do
        -- We dont need this crap, it's already added
        if key ~= 'pos' and key ~= 'position' and key ~= 'Pos' and key ~= 'model' and key ~= 'Model'
        and key ~= 'ang' and key ~= 'Ang' and key ~= 'angle' and key ~= 'Angle' and key ~= 'Class' then
            saveableEntity[key] = tab[key]
        end
    end

    return saveableEntity
end

function CopyEntity(ent, entTable, constrainttable, offset)
    if not IsValid(ent) or entTable[ent:EntIndex()] or (ent:GetClass() == "prop_physics" and ent:GetVar("IsPlug", nil) == 1) then
        return entTable, constrainttable
    end

    entTable[ent:EntIndex()] = GetSaveableEntity(ent, offset)
    if not constraint.HasConstraints(ent) then
        return entTable, constrainttable
    end

    for key,constraintEntity in pairs(ent.Constraints) do
        if not constrainttable[constraintEntity] and constraintEntity.Type != "" then
            local constTable, ents = GetsaveableConst(constraintEntity, offset)
            constrainttable[constraintEntity] = constTable
            for k,e in pairs(ents) do
                if (e and (e:IsWorld() or IsValid(e))) and (not entTable[e:EntIndex()]) then
                    CopyEntity(e, entTable, constrainttable, offset )
                end
            end
        end
    end
end

function PasteEntity(entTable, entID, offset, holdAngle)
    -- Validate entity type here

    local ent = CreateEntityFromTable(entTable, entID, offset, holdAngle)

    if IsValid(ent) then
        ent.BoneMods = table.Copy(entTable.BoneMods)
        ent.EntityMods = table.Copy(entTable.EntityMods)
        ent.PhysicsObjects = table.Copy(entTable.PhysicsObjects)

        local success, result = xpcall(duplicator.ApplyEntityModifiers, debug.traceback, nil, ent)
        if not success then
            MsgN("AdvDupeERROR: ApplyEntityModifiers, Error: ", tostring(result))
        end

        local success, result = xpcall(duplicator.ApplyBoneModifiers, debug.traceback, nil, ent)
        if not success then
            MsgN("AdvDupeERROR: ApplyBoneModifiers Error: ", tostring(result))
        end

        if entTable.Skin then
            ent:SetSkin(entTable.Skin)
        end

        if ent.RestoreNetworkVars then
            ent:RestoreNetworkVars(entTable.DT)
        end

        if ent:GetClass() == 'prop_vehicle_prisoner_pod' and ent:GetModel() ~= 'models/vehicles/prisoner_pod_inner.mdl' and not ent.HandleAnimation then
            local function FixChair(vehicle, ply)
                return ply:SelectWeightedSequence( ACT_GMOD_SIT_ROLLERCOASTER )
            end
            table.Merge(ent, {HandleAnimation = FixChair})
        end

        -- Wire Challenge Stuff
        if entTable.isWireFrozen then
            ent.isWireFrozen = true
        end

        return ent

    else
        MsgN("AdvDupeERROR:Created Entity Bad! Class: ",(entTable.Class or "NIL")," Ent: ",entID)
    end
end

function GenericDuplicatorFunction(data, entID)
    if not data or not data.Class then
        return false
    end

    local entity = NULL
    if data.Class ~= 'lua_run' and data.Class:Left(5) ~= 'base_' and scripted_ents.GetList()[data.Class] then
        entity = ents.Create( data.Class )
    end

    if not IsValid(entity) then
        MsgN("AdvDupeError: Unknown class \"",data.Class,"\", making prop instead for ent: ", entID)
        entity = ents.Create('prop_physics')
        entity:SetCollisionGroup( COLLISION_GROUP_WORLD )
    end

    duplicator.DoGeneric(entity, data)
    entity:Spawn()
    entity:Activate()
    duplicator.DoGenericPhysics(entity, nil, data)

    table.Add(entity:GetTable(), data)

    return entity
end

function MakeProp(Pos, Ang, Model, PhysicsObjects, Data )
    -- Uck.
    Data.Pos = Pos
    Data.Angle = Ang
    Data.Model = Model

    local Prop = ents.Create( "prop_physics" )
        duplicator.DoGeneric( Prop, Data )
    Prop:Spawn()
    Prop:Activate()

    duplicator.DoGenericPhysics( Prop, nil, Data )
    duplicator.DoFlex( Prop, Data.Flex, Data.FlexScale )

    return Prop

end

function CreateEntityFromTable(entTable, entID, offset, holdAngle)
    local entityClass = duplicator.FindEntityClass(entTable.Class)

    local NewPos, NewAngle = LocalToWorld(entTable.LocalPos, entTable.LocalAngle, offset, holdAngle)
    entTable.Pos = NewPos
    entTable.Angles = NewAngle
    entTable.Angle = NewAngle
    if (entTable.PhysicsObjects) then
        for Num, Object in pairs(entTable.PhysicsObjects) do
            local NewPos, NewAngle = LocalToWorld(Object.LocalPos, Object.LocalAngle, offset, holdAngle)
            Object.Pos = NewPos
            Object.Angles = NewAngle
            Object.Angle = NewAngle
        end
    end

    -- This class is unregistered. Instead of failing try using a generic
    -- Duplication function to make a new copy..
    if not entityClass then
        return GenericDuplicatorFunction(entTable, entID)
    end

    -- Build the argument list
    local arglist = {}

    for index, Key in ipairs(entityClass.Args) do
        -- Translate keys from old system
        local Arg = entTable[KeyLookup[Key] or Key]

        -- Special keys
        if Key == "Data" then
            Arg = entTable
        end

        arglist[index] = Arg or false -- If there's a missing argument, replace it by false, because unpack would stop on nil
    end
    entTable.arglist = arglist

    -- Create and return the entity
    local ok, result
    if entTable.Class == 'prop_physics' then
        ok, result = xpcall(MakeProp, debug.traceback, unpack(entTable.arglist))
    elseif entTable.Class == 'gmod_thruster' then
        if entTable.arglist[10] == false and entTable.arglist[11] == true then
            entTable.arglist[10] = ''
            entTable.arglist[11] = false
        end
        ok, result = xpcall(entityClass.Func, debug.traceback, nil, unpack(entTable.arglist))
    else
        ok, result = xpcall(entityClass.Func, debug.traceback, nil, unpack(entTable.arglist))
    end
    if not ok then
        MsgN("AdvDupeERROR: Createentity failed to make \"",(entTable.Class or "NIL" ),"\", Error: ",tostring(result))
        return
    else
        return result
    end

end

function CreateConstraintFromTable(constraint, entityList, offset, holdAngle)
    if not constraint then return end

    local factory = duplicator.ConstraintType[constraint.Type]
    if not factory then return end

    local Args = {}
    for k, Key in pairs( factory.Args ) do
        local Val = constraint[Key]

        if Key == 'pl' then
            Val = nil
        end

        for i=1, 6 do
            if constraint.Entity[i] then
                if Key == "Ent"..i or Key == 'Ent' then
                    if constraint.Entity[i].World then
                        Val = game.GetWorld()
                    else
                        Val = entityList[constraint.Entity[i].Index]
                        if not Val or not IsValid(Val) then
                            MsgN("AdvDupeERROR: Problem with = ",(constraint.Type or "NIL")," constraint. Could not find Ent: ", constraint.Entity[i].Index)
                            return
                        end
                    end
                end
                if Key == 'Bone'..i or Key == 'Bone' then
                    Val = constraint.Entity[i].Bone
                end
                if Key == 'LPos'..i then
                    if constraint.Entity[i].World and constraint.Entity[i].LPos then
                        local NewPos, NewAngle = LocalToWorld(constraint.Entity[ i ].LPos, Angle(0,0,0), offset, holdAngle)
                        Val = NewPos
                    else
                        Val = constraint.Entity[i].LPos
                    end
                end
                if Key == 'WPos'..i then
                    Val = constraint.Entity[i].WPos
                end
                if Key == 'Length'..i then
                    Val = constraint.Entity[i].Length
                end
            end
        end

        -- If there's a missing argument then unpack will stop sending at that argument
        if Val == nil then
            Val = false
        end

        table.insert( Args, Val )
    end

    local ok, result = xpcall( factory.Func, debug.traceback, unpack(Args) )
    if ( !ok ) then
        MsgN("AdvDupeERROR: Createconstraint failed to make \"",(constraint.Type or "NIL"),"\", Error: ",tostring(result))
        return
    else

        if (constraint.Type == 'Elastic' or constraint.length) and isnumber(constraint.length) then --fixed?
            result:Fire('SetSpringLength', constraint.length, 0)
            result.length = constraint.length
        end

        return result
    end
end

function AfterPasteApply(ent, createdEntities )
    if ent.PostEntityPaste then
        ent:PostEntityPaste(nil, ent, createdEntities)
    end

    -- clean up
    if ent.EntityMods then
        if ent.EntityMods.RDDupeInfo then -- fix: RDDupeInfo leak
            ent.EntityMods.RDDupeInfo = nil
        end
        if ent.EntityMods.WireDupeInfo then
            ent.EntityMods.WireDupeInfo = nil
        end
    end
end

function Paste(room, entityList, constraintList, offset, holdAngle)
    local createdEntities = {}
    local createdConstraints = {}

    -- Create entities
    for entID, entTable in pairs(entityList) do
        createdEntities[entID] = PasteEntity(entTable, entID, offset, holdAngle)

        -- Add entity to this room
        room:AddEnt(createdEntities[entID])
    end

    -- Apply modifiers to the created entities
    for entntID, ent in pairs( createdEntities ) do
        local noFail, result = xpcall(AfterPasteApply, debug.traceback, ent, createdEntities )
        if not noFail then
            MsgN("AdvDupeERROR: AfterPasteApply, Error: ", tostring(result))
        end
    end

    -- Create constraints
    if constraintList then
        for k, constraint in pairs( constraintList ) do
            if constraint.Type and constraint.Type != '' then
                local entity = CreateConstraintFromTable(constraint, createdEntities, offset, holdAngle )

                if IsValid(entity) then
                    table.insert(createdConstraints, entity)
                else
                    MsgN("AdvDupeERROR:Could not make constraint type: ",(constraint.Type or "NIL"))
                end
            end

        end
    end
end

-- Gets a save of the current room
function Rooms:GetSave()
    -- Create new save
    local savedEntities = {}
    local savedConstraints = {}

    -- Copy all ents
    for k,v in pairs(self.ents) do
        if IsValid(v) then
            if not savedEntities[v:EntIndex()] then
                CopyEntity(v, savedEntities, savedConstraints, Vector(0, 0, 0))
            end

            -- Get key info
            --[[local ent = {
                ["class"] = v:GetClass(),
                ["pos"] = v:GetPos(),
                ["angles"] = v:GetAngles(),
                ["model"] = v:GetModel()
            }

            -- Store ent
            table.insert(save, ent)]]
        end
    end

    -- Return the save
    return {
        ['ents'] = savedEntities,
        ['consts'] = savedConstraints,
        ['offset'] = Vector(0, 0, 0),
        ['holdAngle'] = Angle(0, 0, 0)
    }
end

-- Removes all ents in a room
function Rooms:Cleanup()
    for k,v in pairs(self.ents) do
        if IsValid(v) then
            v:Remove()
        end
    end

    self.ents = {}
end

-- Starts simulating a room
function Rooms:Start()
    -- Create a save of this room
    self.save = self:GetSave()

    -- Clean the room up
    self:Cleanup()

    -- Enable running
    self:SetRunning(true)

    -- Load the room
    self:LoadRoom(self.save)
end

-- Stops simulating a room
function Rooms:Stop()
    -- Cleanup the room
    self:Cleanup()

    -- Stop running
    self:SetRunning(false)

    -- Load the room
    self:LoadRoom(self.save)
end

function Rooms:SetRunning(state)
    -- Check if it even changed
    if self.running ~= state then
        -- Store change
        self.running = state

        -- Start net message
        net.Start("roomRunning")
        net.WriteBit(state)

        -- Update players
        for k,v in pairs(self.players) do
            if IsValid(v) then
                -- Send to this player
                net.Send(v)
            end
        end
    end
end

function Rooms:GetRunning()
    return self.running
end

-- Loads a room
function Rooms:LoadRoom(save)
    --[[for k,v in pairs(save) do
        -- Create the entity
        local ent = ents.Create(v.class)
        ent:SetPos(v.pos)
        ent:SetAngles(v.angles)
        ent:SetModel(v.model)
        ent:Spawn()

        -- Add entity to this room
        self:AddEnt(ent)

        -- Freeze the ent if we're not running
        if not self.running then
            -- Freeze prop
            freezeEntity(ent)

            -- Disable damage
            ent:disableDamage()
        else
            -- Enable damage
            ent:enableDamage()
        end
    end]]

    --PrintTable(save)

    Paste(self, save.ents, save.consts, save.offset, save.holdAngle)
end

-- Hook entity creation
local oldAdd = oldAdd or cleanup.Add
function cleanup.Add(ply, type, ent)
    -- Make sure the player is in a room
    local room = ply:GetRoom()
    if not room then
        ent:Remove()
        return false
    end

    -- Check if the room is running
    if room.running then
        ent:Remove()
        return false
    end

    -- Validate what they are creating

    -- Check if we can add it to the room
    if type ~= 'constraints' and type ~= 'stacks' and type ~= 'AdvDupe2' then
        -- Add it to this room
        room:AddEnt(ent)
    end

    -- Freeze it
    --freezeEntity(ent)

    -- Stop damage
    ent:disableDamage()

    -- Add it to the list of deletables
    return oldAdd(ply, type, ent)
end

--[[
    Extend entity class to interact with rooms
]]
local Entity = FindMetaTable("Entity")

function Entity:GetRoom()
    return self.wc_room
end

function Entity:SetRoom(room)
    self.wc_room = room
end

print("Done loading rooms!")
