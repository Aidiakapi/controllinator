--[[

A debug session is created when a player starts debugging a specific
contraption. Although multiple debug session can be active at the same
time, a single player can only have one debug session enabled, and any
entity can only be inside one debug session.

Modifications to a contraption whilst a debug session is in progress are
possible, but it is the responsibility of a contraption to avoid a single
entity being added to two debug session at the same time, since that'll
cause conflict.

During a debug session, all entities in it are automatically powered to
full, even when not in an electronic network, and pausing is achieved
by stripping all energy away from an entity.

When a player's force changes, any assocaited debug session is destroyed.

]]

local debug_session = {}

function debug_session:new(player, contraption)
    self.player, self.contraption = player, contraption
    self.paused, self.step_next = true, false

    for _, entity in ipairs(contraption.entities) do
        if global.controlled_entities[entity.unit_number] then
            error('cannot start a debug session because entities overlap')
        else
            global.controlled_entities[entity.unit_number] = true
        end
    end
end

function debug_session:destroy()
    for _, entity in ipairs(self.contraption.entities) do
        global.controlled_entities[entity.unit_number] = nil
    end

    for k, v in pairs(self) do
        self[k] = nil
    end
end

function debug_session:on_entity_added(entity)
    assert(not global.controlled_entities[entity.unit_number], 'cannot add an entity to a contraption with \
        an active debug_session when the entity is already controlled by another debug_session')
    global.controlled_entities[entity.unit_number] = true
end

function debug_session:on_entity_removed(entity)
    assert(global.controlled_entities[entity.unit_number], 'cannot remove an entity that is not controlled')
    global.controlled_entities[entity.unit_number] = nil
end

function debug_session:is_paused()
    return self.paused
end

function debug_session:pause()
    assert(not self.paused, 'cannot pause an already paused debug_session')
    self.paused = true
end

function debug_session:resume()
    assert(self.paused, 'cannot resume a debug_session that is not paused')
    self.paused = false
end

function debug_session:step()
    assert(self.paused, 'a debug_session must be paused before stepping')
    self.step_next = true
end

function debug_session:on_tick()
    if not self.paused or self.step_next then
        for _, entity in ipairs(self.contraption.entities) do
            entity.energy = entity.electric_buffer_size
        end
    else
        for _, entity in ipairs(self.contraption.entities) do
            entity.energy = 0
        end
    end
    self.step_next = false
end

return debug_session
