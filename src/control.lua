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

script.on_event(defines.events.on_force_created, function (event)
    local force = event.force
    local contraption = make_metatable({}, contraption)
    global.contraptions[force.name] = {
        contraption
    }
    contraption:new(force, 'all', 'ALL')
end)

script.on_event(defines.events.on_forces_merging, function (event)
    local force = event.source
    global.contraptions[force.name] = {}
end)

script.on_event(defines.events.on_player_changed_force, function (event)
    local player = game.players[event.player_index]
    global.interfaces[player.index]:destroy()
    global.interfaces[player.index] = nil

    global.interfaces[player.index] = make_metatable({}, interface)
    global.interfaces[player.index]:new(player)
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
    log('[controllinator] creating surface: ' .. surface.name)
    for force, contraption in iter_contraptions() do
        contraption:on_surface_created(surface)
    end
end)

script.on_event(defines.events.on_pre_surface_deleted, function (event)
    local surface = game.surfaces[event.surface_index]
    log('[controllinator] destroying surface: ' .. surface.name)
    for force, contraption in iter_contraptions() do
        contraption:on_pre_surface_destroyed(surface)
    end
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function (event)
    global.interfaces[event.player_index]:on_player_cursor_stack_changed()
end)

script.on_event(defines.events.on_player_selected_area, function (event)
    global.interfaces[event.player_index]:on_player_selected_area(false, event.item, event.entities)
end)
script.on_event(defines.events.on_player_alt_selected_area, function (event)
    global.interfaces[event.player_index]:on_player_selected_area(true, event.item, event.entities)
end)

local function tick_debug_sessions()
    for _, debug_session in ipairs(global.debug_sessions) do
        debug_session:on_tick()
    end
end
local function tick_debug_sessions_error(err)
    local remove_count = 0
    for _, contraption in iter_contraptions() do
        remove_count = remove_count + contraption:check_entities()
    end

    if remove_count > 0 then
        local message = ('[controllinator] invalid entities detected, did a mod/script incorrectly destoy some entities?'):format(remove_count)
        for _, player in pairs(game.players) do
            player.print(message)
        end
    end
end

script.on_event(defines.events.on_tick, function (event)
    for force, contraption in iter_contraptions() do
        contraption:on_tick()
    end

    local _, obj = xpcall(tick_debug_sessions, tick_debug_sessions_error)
    if obj and obj.tag == tick_debug_sessions_error_tag then
        error(obj.err)
    end
end)

do
    local function on_entity_built(event)
        local entity = event.created_entity
        if not entity then return end
        local force = entity.force
        local player = event.player_index and game.players[event.player_index] or nil
        local contraptions = global.contraptions[force.name] or {}
        for _, contraption in ipairs(contraptions) do
            contraption:on_entity_created(entity, player)
        end
    end

    script.on_event(defines.events.on_built_entity, on_entity_built)
    script.on_event(defines.events.on_robot_built_entity, on_entity_built)
    script.on_event(defines.events.script_raised_built, on_entity_built)
end
do
    local function on_entity_destroyed(event)
        local entity = event.entity
        if not entity then return end
        local force = entity.force
        local player = event.player_index and game.players[event.player_index] or nil
        local contraptions = global.contraptions[force.name] or {}
        for _, contraption in ipairs(contraptions) do
            contraption:on_entity_destroyed(entity, player)
        end
    end

    script.on_event(defines.events.on_player_mined_entity, on_entity_destroyed)
    script.on_event(defines.events.on_robot_mined_entity, on_entity_destroyed)
    script.on_event(defines.events.script_raised_destroy, on_entity_built)
end

script.on_event('controllinator-debug-toggle', function (event)
    global.interfaces[event.player_index]:on_gui_debug_toggle()
end)
script.on_event('controllinator-debug-pause', function (event)
    global.interfaces[event.player_index]:on_gui_debug_pause()
end)
script.on_event('controllinator-debug-step', function (event)
    global.interfaces[event.player_index]:on_gui_debug_step()
end)
script.on_event('controllinator-toggle-gui', function (event)
    global.interfaces[event.player_index]:toggle_main_gui()
end)
script.on_event('controllinator-toggle-edit', function (event)
    global.interfaces[event.player_index]:toggle_edit()
end)
script.on_event('controllinator-toggle-new', function (event)
    global.interfaces[event.player_index]:toggle_new_gui()
end)

-- Stop a player's debug session when a player leaves a multiplayer game
script.on_event(defines.events.on_player_left_game, function (event)
    local player = game.players[event.player_index]
    local interface = global.interfaces[player.index]
    if interface:get_debug_session() then interface:on_gui_debug_toggle() end
    if player.cursor_stack.valid_for_read and player.cursor_stack.name == 'combinator-select-tool' then
        player.cursor_stack.clear()
    end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function (event)
    if event.setting ~= 'controllinator-show-icon' then
        return
    end
    global.interfaces[event.player_index]:update_top_gui()
end)

commands.add_command('controllinator_rescan_all_chunks', 'Rescans all chunks for combinators. Use this if for some reason not all combinators are being paused.', function ()
    for _, player in pairs(game.players) do
        player.print('[controllinator] rescanning started, will finish in the background')
    end
    for force, contraption in iter_contraptions() do
        contraption:rescan_all_chunks()
    end
end)

commands.add_command('controllinator_update_gui', 'Debug utility. Forces the gui to be updated for all players.', function ()
    for _, player in pairs(game.players) do
        global.interfaces[player.index]:update_gui()
    end
end)