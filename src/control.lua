local interface = require('interface')
local contraption = require('contraption')
local debug_session = require('debug_session')

local make_metatable = require('object_metatable').make_metatable

local function iter_contraptions()
    -- TODO: Optimize this
    local d = { {}, {} }
    do
        local i = 1
        for force_name, contraptions in pairs(global.contraptions) do
            local force = game.forces[force_name]
            for _, contraption in ipairs(contraptions) do
                d[1][i], d[2][i] = force, contraption
                i = i + 1
            end
        end
    end
    local i = 1
    return function ()
        local f, c = d[1][i], d[2][i]
        i = i + 1
        return f, c
    end
end

script.on_init(function ()
    -- Create necessary tables
    global.interfaces = {}
    global.contraptions = {}
    global.debug_sessions = {}
    global.controlled_entities = {}
    for _, player in pairs(game.players) do
        global.interfaces[player.index] = make_metatable({}, interface)
    end
    for _, force in pairs(game.forces) do
        global.contraptions[force.name] = {
            make_metatable({}, contraption)
        }
        
    end

    -- Instantiate the objects
    for _, player in pairs(game.players) do
        global.interfaces[player.index]:new(player)
    end
    for _, force in pairs(game.forces) do
        for _, contraption in ipairs(global.contraptions[force.name]) do
            contraption:new(force, 'all', 'ALL')
        end
    end
end)

script.on_load(function ()
    -- Resetup the metatables
    for _, data in pairs(global.interfaces) do
        make_metatable(data, interface)
    end
    for _, contraptions in pairs(global.contraptions) do
        for _, data in ipairs(contraptions) do
            make_metatable(data, contraption)
        end
    end
    for _, data in ipairs(global.debug_sessions) do
        make_metatable(data, debug_session)
    end
end)

script.on_event(defines.events.on_player_created, function (event)
    local player = game.players[event.player_index]
    global.interfaces[player.index] = make_metatable({}, interface)
    global.interfaces[player.index]:new(player)
end)

script.on_event(defines.events.on_player_removed, function (event)
    local player = game.players[event.player_index]
    global.interfaces[player.index]:destroy()
    global.interfaces[player.index] = nil
end)

script.on_event(defines.events.on_gui_click, function (event)
    global.interfaces[event.player_index]:on_gui_click(event.element, event.button, event.alt, event.control, event.shift)
end)

script.on_event(defines.events.on_gui_selection_state_changed, function (event)
    global.interfaces[event.player_index]:on_gui_selection_state_changed(event.element)
end)

script.on_event(defines.events.on_surface_created, function (event)
    local surface = game.surfaces[event.surface_index]
    for force, contraption in iter_contraptions() do
        contraption:on_surface_created(surface)
    end
end)

script.on_event(defines.events.on_pre_surface_deleted, function (event)
    local surface = game.surfaces[event.surface_index]
    for force, contraption in iter_contraptions() do
        contraption:on_pre_surface_destroyed(surface)
    end
end)

script.on_event(defines.events.on_tick, function (event)
    for force, contraption in iter_contraptions() do
        contraption:on_tick()
    end

    for _, debug_session in ipairs(global.debug_sessions) do
        debug_session:on_tick()
    end
end)

do
    local function on_entity_built(event)
        local entity = event.created_entity
        local force = entity.force
        local player = event.player_index and game.players[event.player_index] or nil
        local contraptions = global.contraptions[force.name] or {}
        for _, contraption in ipairs(contraptions) do
            contraption:on_entity_created(entity, player)
        end
    end

    script.on_event(defines.events.on_built_entity, on_entity_built)
    script.on_event(defines.events.on_robot_built_entity, on_entity_built)
end
do
    local function on_entity_destroyed(event)
        local entity = event.entity
        local force = entity.force
        local player = event.player_index and game.players[event.player_index] or nil
        local contraptions = global.contraptions[force.name] or {}
        for _, contraption in ipairs(contraptions) do
            contraption:on_entity_destroyed(entity, player)
        end
    end

    script.on_event(defines.events.on_player_mined_entity, on_entity_destroyed)
    script.on_event(defines.events.on_robot_mined_entity, on_entity_destroyed)
end

script.on_event('controllinator_debug_toggle', function (event)
    global.interfaces[event.player_index]:on_gui_debug_toggle()
end)
script.on_event('controllinator_debug_pause', function (event)
    global.interfaces[event.player_index]:on_gui_debug_pause()
end)
script.on_event('controllinator_debug_step', function (event)
    global.interfaces[event.player_index]:on_gui_debug_step()
end)

-- Stop a player's debug session when a player leaves a multiplayer game
script.on_event(defines.events.on_player_left_game, function (event)
    local interface = global.interfaces[event.player_index]
    if interface:get_debug_session() then interface:on_gui_debug_toggle() end
end)