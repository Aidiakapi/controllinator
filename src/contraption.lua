--[[

A contraption is a set of entities that are considered to be of the same
network. A contraption can be made from multiple sources and are shared
amongst all players. There are 3 types of contraption sources:

 - all      A unique type that includes all combinator related entities
            in the world (all surfaces).
 - region   Marked by a rectangle, and all combinator related entities
            inside of the area are part of this contraption.
 - custom   Using a selection tool, the user can specifically choose
            which entities are part of a contraption.

The output for each contraption is a set of all entities inside of it,
a contraption can then be used by a debug session to perform operations
like pausing, stepping, and running till a specific condition is met.

Upon placing an entity in the world, it is automatically determined
to which contraptions it should be added. Because a single entity is
not allowed to be in multiple debug sessions at once, there are some
restrictions placed on the contraptions sources. The debug session for
"all" cannot be in progress with any other debug session, therefore it
is always safe to add to this contraption. A "region" source may not
overlap with other regions, because it could result in this automatic
addition taking place in multiple "region" based contraptions at the
same time, and as a result also multiple debug sessions. When a player
with an active "custom"-contraption based debug session created an
entity, it'll be automatically added to the contraption, unless it's
added to a "region" based contraption prior, in which case a warning
is issued to make the player aware.

Destruction of an entity will remove it from any contraption it is in.

Contraptions are isolated per force, and a single contraption cannot
cover entities from different forces.

When forces are merging, all debug sessions for either force are
destroyed, and any "region" based contraption in the source force is
removed and a warning is printed.

]]

local param_assert, type_check = require('param_assert'), require('type_check')
local contraption = {}

local function is_combinator(entity)
    if not entity then return false end
    if not entity.valid then return false end

    if entity.type == 'arithmetic-combinator' then return true end
    if entity.type == 'decider-combinator' then return true end
    if entity.type == 'selector-combinator' then return true end

    -- assembling machines (including chemical plants, etc.) are now wireable
    -- they can, for instance, be used to get the ingredients for a recipe
    --if entity.type == 'assembling-machine' then return true end
    -- alas, debug_session.lua sets power to 0 to pause, but assemblers continue to process signals with no power

    return false
end

local function add_entity_to_contraption(self, entity)
    -- Prevent duplicate entities
    for _, existing_entity in ipairs(self.entities) do
        if existing_entity == entity then
            return
        end
    end
    self.entities[#self.entities + 1] = entity

    -- Propagate information to active debug_session
    for _, debug_session in ipairs(storage.debug_sessions) do
        if debug_session.contraption == self then
            debug_session:on_entity_added(entity)
        end
    end
end

local function remove_entity_from_contraption(self, removed_entity)
    -- Find entity
    local index
    for i, entity in ipairs(self.entities) do
        if entity == removed_entity then
            index = i
            break
        end
    end

    -- Not an entity in this contraption
    if not index then return end

    -- Propagate information to active debug_session
    for _, debug_session in ipairs(storage.debug_sessions) do
        if debug_session.contraption == self then
            debug_session:on_entity_removed(removed_entity)
        end
    end

    -- Remove from table
    table.remove(self.entities, index)
end

function contraption:new(force, contraption_type, name, opt_region)
    -- TODO: Support the other types of contraptions
    type_check('userdata', force)
    type_check('string', name)
    param_assert(contraption_type == 'all' or contraption_type == 'custom', [[contraption_type must be 'all' or 'custom']])

    self.force, self.contraption_type, self.name = force, contraption_type, name
    self.entities = {}

    if contraption_type == 'all' then
        self.pending_chunks = { x = {}, y = {}, surface = {} }
    end

    for _, surface in pairs(game.surfaces) do
        self:on_surface_created(surface)
    end
end

function contraption:rescan_all_chunks()
    if self.contraption_type == 'all' then
        self.entities = {}
        self.pending_chunks = { x = {}, y = {}, surface = {} }

        for _, surface in pairs(game.surfaces) do
            self:on_surface_created(surface)
        end
    end
end

function contraption:check_entities()
    local old_entities, new_entities, new_entities_set = self.entities, {}, {}
    self.entities = new_entities
    for _, entity in ipairs(old_entities) do
        if entity and entity.valid and not new_entities_set[entity.unit_number] then
            new_entities[#new_entities + 1] = entity
            new_entities_set[entity.unit_number] = true
        end
    end
    return #old_entities - #new_entities
end

function contraption:scan_chunk(surface, chunk_x, chunk_y)
    type_check('userdata', surface)
    type_check('number', chunk_x)
    type_check('number', chunk_y)
    local left_top = { x = chunk_x * 32, y = chunk_y * 32 }
    local area = { left_top = left_top, right_bottom = { x = left_top.x +  32, y = left_top.y + 32 } }
    local entities = surface.find_entities_filtered({
        area = area,
        force = self.force
    })

    for _, entity in ipairs(entities) do
        if is_combinator(entity) then
            add_entity_to_contraption(self, entity)
        end
    end
end

function contraption:on_tick()
    if self.contraption_type == 'all' and #self.pending_chunks.x ~= 0 then
        -- Process up to 10 chunks per tick
        for i = 1, 10 do
            local xs, ys, ss = self.pending_chunks.x, self.pending_chunks.y, self.pending_chunks.surface
            local last = #xs
            local s, x, y = ss[last], xs[last], ys[last]
            ss[last], xs[last], ys[last] = nil, nil, nil
            self:scan_chunk(s, x, y)

            if #xs == 0 then
                print(('[controllinator] chunks scanned for force %s, entities found: %d'):format(self.force.name, #self.entities))
                break
            end
        end
    end
end

function contraption:on_surface_created(surface)
    type_check('userdata', surface)
    if self.contraption_type == 'all' then
        -- Add all chunks to the list of pending chunks
        local xs, ys, ss = self.pending_chunks.x, self.pending_chunks.y, self.pending_chunks.surface
        for chunk in surface.get_chunks() do
            xs[#xs + 1] = chunk.x
            ys[#ys + 1] = chunk.y
            ss[#ss + 1] = surface
        end
    end
end

function contraption:on_pre_surface_destroyed(surface)
    local old_entities, new_entities = self.entities, {}
    self.entities = new_entities
    for _, entity in ipairs(old_entities) do
        if entity.surface ~= surface then
            new_entities[#new_entities + 1] = entity
        end
    end

    if self.contraption_type ~= 'all' or #self.pending_chunks.x == 0 then return end
    local xs, ys, ss = self.pending_chunks.x, self.pending_chunks.y, self.pending_chunks.surface
    for i = #xs, 1, -1 do
        if ss[i] == surface then
            table.remove(xs, i)
            table.remove(ys, i)
            table.remove(ss, i)
        end
    end
end

function contraption:try_add_entity(entity)
    if not is_combinator(entity) then return end
    add_entity_to_contraption(self, entity)
end

function contraption:try_remove_entity(entity)
    if not is_combinator(entity) then return end
    remove_entity_from_contraption(self, entity)
end

function contraption:on_entity_created(entity, opt_player)
    type_check('userdata', entity)
    param_assert(entity.force == self.force, 'entity must belong to the same force as the contraption')

    if not is_combinator(entity) then return end

    if self.contraption_type == 'all' then
        add_entity_to_contraption(self, entity)
    elseif self.contraption_type == 'custom' then
        -- Add it automatically to the contraption if the player
        -- placing it is also currently debugging this specific
        -- custom contraption.
        if opt_player and storage.interfaces[opt_player.index] then
            local debug_session = storage.interfaces[opt_player.index]:get_debug_session()
            if debug_session ~= nil and debug_session.contraption == self then
                add_entity_to_contraption(self, entity)
            end
        end
    end
end

function contraption:on_entity_destroyed(entity, opt_player)
    type_check('userdata', entity)
    param_assert(entity.force == self.force, 'entity must belong to the same force as the contraption')

    if not is_combinator(entity) then return end

    remove_entity_from_contraption(self, entity)
end

return contraption
