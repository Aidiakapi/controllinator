--[[

An interface is associated with a single player, and responsible for all
user interaction of the mod. An instance is created for each player, and
destroyed when a player is pruned.

]]

local wrap_style = require('style_wrapper')
local contraption_functions = require('contraption')
local debug_session_functions = require('debug_session')
local make_metatable = require('object_metatable').make_metatable

local interface = {}

local function get_contraptions(self)
    local contraptions =  global.contraptions[self.player.force.name]
    if not contraptions then
        log('[controllinator] warning: global.contraptions was not created for force ' .. self.player.force.name)
        contraptions = {}
        global.contraptions[self.player.force.name] = contraptions
    end
    return contraptions
end

function interface:new(player)
    self.player = player

    self.buttons = {}
    self.active_contraption = (get_contraptions(self) or {})[1]
    self:update_top_gui()
end

function interface:destroy()
    if self.player.valid then
        self:destroy_new_gui()
        self:destroy_top_gui()
        self:destroy_main_gui()
    end
    
    self:destroy_debug_session()

    for k, v in pairs(self) do
        rawset(self, k, nil)
    end
end

function interface:print(...)
    local first = ('[controllinator] %s'):format(select(1, ...))
    print(first, select(2, ...))

    local msg
    if select('#', ...) == 1 then
        msg = first
    else
        msg = { first }
        for i = 2, select('#', ...) do
            msg[i] = tostring(select(i, ...))
        end
        msg = table.concat(msg, ', ')
    end
    self.player.print(msg)
end

function interface:get_debug_session()
    local player = self.player
    for _, debug_session in ipairs(global.debug_sessions) do
        if debug_session.player == player then
            return debug_session
        end
    end
end

function interface:destroy_debug_session()
    local index
    local player = self.player
    for i, debug_session in ipairs(global.debug_sessions) do
        if debug_session.player == player then
            index = i
            break
        end
    end
    if index == nil then return end
    global.debug_sessions[index]:destroy()
    table.remove(global.debug_sessions, index)
    self:update_gui()
end

function interface:new_debug_session()
    local contraption = self.active_contraption
    local overlap = false
    for _, entity in ipairs(contraption.entities) do
        if global.controlled_entities[entity.unit_number] then
            overlap = true
            break
        end
    end

    if overlap then
        self:print('Cannot start debug session, because some entities are already being debugged (ask some other player?)')
        return
    end
    debug_session = make_metatable({}, debug_session_functions)
    global.debug_sessions[#global.debug_sessions + 1] = debug_session
    debug_session:new(self.player, contraption)
    self:update_gui()
end

function interface:update_top_gui()
    local should_show = settings.get_player_settings(self.player).controllinator_show_icon.value
    local is_shown = not not self.buttons.main_toggle
    log(('should: %s  is: %s'):format(should_show, is_shown))
    if should_show == is_shown then return end
    if should_show then self:create_top_gui()
    else self:destroy_top_gui() end
end

function interface:create_top_gui()
    if self.buttons.main_toggle then return end

    -- Create GUI button
    local toggle_button = self.player.gui.top.add({
        type = 'sprite-button',
        name = 'controllinator-toggle',
        sprite = 'entity/constant-combinator'
    })

    local style = wrap_style(toggle_button.style)
    style.width, style.height, style.padding = 30, 30, 0

    self.buttons.main_toggle = toggle_button
end

function interface:destroy_top_gui()
    if not self.buttons.main_toggle then return end
    if self.buttons.main_toggle.valid then
        self.buttons.main_toggle.destroy()
    end
    self.buttons.main_toggle = nil
end

function interface:create_main_gui()
    if self.main_interface then return end

    local main = {}
    self.main_interface = main

    -- Root frame
    main.root = self.player.gui.left.add({
        type = 'flow',
        name = 'controllinator-main-root',
        direction = 'horizontal'
    })
    local root = main.root.add({
        type = 'frame',
        name = 'controllinator-main',
        direction = 'vertical',
        caption = 'Controllinator'
    }).add({
        type = 'flow',
        name = 'controllinator-main-flow',
        direction = 'vertical'
    })
    root.style.max_on_row = 1

    -- Contraption row
    do
        local flow = root.add({
            type = 'flow',
            name = 'controllinator-main-contraption-flow',
            direction = 'horizontal'
        })
        local label = flow.add({
            type = 'label',
            name = 'controllinator-main-label-contraption',
            caption = 'Contraption'
        })

        label.style.right_padding = 10
        main.contraption_dropdown = flow.add({
            type = 'drop-down',
            name = 'controllinator-main-contraption'
        })

        local new_button = flow.add({
            type = 'button',
            name = 'controllinator-main-contraptions-new',
            caption = 'New'
        })
        local edit_button = flow.add({
            type = 'button',
            name = 'controllinator-main-contraptions-edit',
            caption = 'Edit'
        })
        local delete_button = flow.add({
            type = 'button',
            name = 'controllinator-main-contraptions-delete',
            caption = 'Delete'
        })
        for _, button in pairs({ new_button, edit_button, delete_button }) do
            local style = wrap_style(button.style)
            style.font = 'default'
            style.padding = { 0, 3 }
        end
        main.new_contraption = new_button
        main.edit_contraption = edit_button
        main.delete_contraption = delete_button
    end

    -- Debug session UI
    do
        root.add({
            type = 'label',
            name = 'controllinator-main-debug-heading',
            style = 'bold_label_style',
            caption = 'Debug controls'
        })
        local flow = root.add({
            type = 'flow',
            name = 'controllinator-main-debug-flow',
            direction = 'horizontal'
        })
        flow.style.resize_row_to_width = true

        main.debug_toggle = flow.add({
            type = 'button',
            name = 'controllinator-main-debug-session-toggle',
            caption = 'Start'
        })
        main.debug_pause = flow.add({
            type = 'button',
            name = 'controllinator-main-debug-session-pause',
            caption = 'Pause'
        })
        main.debug_step = flow.add({
            type = 'button',
            name = 'controllinator-main-debug-session-step',
            caption = 'Step'
        })
    end

    self:update_gui()
end

function interface:destroy_main_gui()
    if not self.main_interface then return end
    self:destroy_new_gui()
    if self.main_interface.root.valid then
        self.main_interface.root.destroy()
    end
    self.main_interface = nil
    self:update_gui()
end

function interface:toggle_main_gui()
    if self.main_interface then self:destroy_main_gui()
    else self:create_main_gui() end
end

function interface:create_new_gui()
    local main = self.main_interface
    assert(main, 'cannot create new_contrap_ui without main_interface')
    if main.new_contrap_ui then return end

    local new_contrap_ui = {}
    main.new_contrap_ui = new_contrap_ui

    new_contrap_ui.root = main.root.add({
        type = 'frame',
        name = 'controllinator-new-contrap-root',
        caption = 'New contraption',
        direction = 'vertical'
    })
    local root = new_contrap_ui.root.add({
        type = 'flow',
        name = 'controllinator-new-contrap-flow',
        direction = 'vertical'
    })
    root.style.max_on_row = 1

    new_contrap_ui.name = root.add({
        type = 'textfield',
        name = 'controllinator-new-contrap-name'
    })

    new_contrap_ui.create_button = root.add({
        type = 'button',
        name = 'controllinator-new-contrap-button',
        caption = 'Create'
    })

    self:update_gui()
end

function interface:destroy_new_gui()
    local main = self.main_interface
    if not main or not main.new_contrap_ui then return end
    if main.new_contrap_ui.root.valid then
        main.new_contrap_ui.root.destroy()
    end

    main.new_contrap_ui = nil
    self:update_gui()
end

function interface:toggle_new_gui()
    local debug_session = self:get_debug_session()
    
    if debug_session then
        self:print('cannot create a new contraption while debugging')
        return
    end
    if self.is_editing then
        self:print('cannot create a new contraption while editing')
        return
    end
    self:create_main_gui()
    if self.main_interface.new_contrap_ui then self:destroy_new_gui()
    else self:create_new_gui() end
end

function interface:on_gui_click(element, button, alt, control, shift)
    if element == self.buttons.main_toggle then
        self:toggle_main_gui()
    end
    local main = self.main_interface
    if not self.main_interface then
        return 
    end

    if element == main.debug_toggle then
        self:on_gui_debug_toggle()
    elseif element == main.debug_pause then
        self:on_gui_debug_pause()
    elseif element == main.debug_step then
        self:on_gui_debug_step()
    elseif element == main.new_contraption then
        self:on_gui_new_contraption()
    elseif element == main.edit_contraption then
        self:on_gui_edit_contraption()
    elseif element == main.delete_contraption then
        self:on_gui_delete_contraption()
    end

    local new_contrap_ui = main.new_contrap_ui
    if not new_contrap_ui then
        return
    end

    if element == new_contrap_ui.create_button then
        self:on_gui_create_contraption()
    end
end

function interface:on_gui_selection_state_changed(element)
    if self.main_interface then
        local main = self.main_interface
        if element == main.contraption_dropdown then
            self:on_gui_contraption_selection_changed()
        end
    end
end

function interface:on_gui_debug_toggle()
    if self.main_interface and not self.main_interface.debug_toggle.enabled then return end
    local debug_session = self:get_debug_session()

    if debug_session then
        self:destroy_debug_session()
    else
        self:new_debug_session()
    end
end

function interface:on_gui_debug_pause()
    if self.main_interface and not self.main_interface.debug_pause.enabled then return end
    local debug_session = self:get_debug_session()
    if not debug_session then
        self:on_gui_debug_toggle()
        debug_session = self:get_debug_session()
    end

    if debug_session:is_paused() then
        debug_session:resume()
    else
        debug_session:pause()
    end

    self:update_gui()
end

function interface:on_gui_debug_step()
    if self.main_interface and not self.main_interface.debug_step.enabled then return end
    local debug_session = self:get_debug_session()
    if not debug_session then
        self:on_gui_debug_toggle()
        debug_session = self:get_debug_session()
    end
    if not debug_session:is_paused() then
        debug_session:pause()
        self:update_gui()
    end
    
    debug_session:step()
end

function interface:on_gui_contraption_selection_changed()
    assert(not self:get_debug_session(), 'cannot change contraption while a debug_session is active')
    assert(not self.is_editing, 'cannot change contraption while editing another contraption')
    local contraptions = get_contraptions(self)
    self.active_contraption = contraptions[self.main_interface.contraption_dropdown.selected_index]
    self:update_gui()
end

function interface:on_contraption_list_changed()
    local contraptions = get_contraptions(self)
    assert(#contraptions >= 1, 'there must be at least one contraption')
    local active_contraption = self.active_contraption
    local active_exists = false
    for _, contraption in ipairs(contraptions) do
        if active_contraption == contraption then
            active_exists = true
            break
        end
    end

    if not active_exists then
        assert(not self:get_debug_session(), 'contraption that was being debugged got removed')
        self.active_contraption = contraptions[1]
    end
    self:update_gui()
end

function interface:on_player_cursor_stack_changed()
    if not self.is_editing then return end
    
    if self.player.cursor_stack.valid_for_read and self.player.cursor_stack.name == 'combinator-select-tool' then
        return
    end

    local remove_stack = { name = 'combinator-select-tool', count = 100000 }
    for _, inventory in ipairs({
        self.player.get_inventory(defines.inventory.player_main) or
        self.player.get_inventory(defines.inventory.god_main),
        self.player.get_quickbar()
    }) do
        inventory.remove(remove_stack)
    end
    self.is_editing = false
    self:update_gui()
end

function interface:toggle_edit()
    if not self.active_contraption or self.active_contraption.contraption_type == 'all' then
        self:print('cannot edit the selected contraption')
        return
    end
    self:on_gui_edit_contraption()
end

function interface:on_gui_edit_contraption()
    assert(self.active_contraption and self.active_contraption.contraption_type ~= 'all', 'cannot edit a contraption of type all')
    if self.is_editing then
        -- Will trigger event that stops editing
        if self.player.cursor_stack.valid_for_read and self.player.cursor_stack.name == 'combinator-select-tool' then
            self.player.cursor_stack.clear()
        end
        return
    end

    if not self.player.clean_cursor() then
        self:print('player cursor must be empty to edit a contraption')
        return
    end

    self.player.cursor_stack.set_stack({ name = 'combinator-select-tool' })
    self.is_editing = true
    self:print('drag around combinators to include them, and shift-drag to exclude them')
    self:update_gui()
end

function interface:on_gui_delete_contraption()
    local active_contraption = self.active_contraption
    assert(active_contraption.type ~= 'all', [[cannot delete the contraption of type 'all']])
    for _, debug_session in ipairs(global.debug_sessions) do
        if debug_session.contraption == active_contraption then
            assert(debug_session.player ~= self.player, 'cannot delete contraption that is being debugged')
            self:print(('cannot delete contraption %s because it is being debugged by player %q'):format(active_contraption.name, debug_session.player.name))
            return
        end
    end

    for _, interface in pairs(global.interfaces) do
        if active_contraption == interface.active_contraption and interface.is_editing then
            assert(interface ~= self, 'cannot delete a contraption that is being edited')
            self:print(('cannot delete contraption %s because it is being edited by player %q'):format(active_contraption.name, interface.player.name))
            return
        end
    end

    local contraptions = get_contraptions(self)
    
    local index
    for i, contraption in ipairs(contraptions) do
        if contraption == active_contraption then
            index = i
        end
    end
    assert(index, 'cannot find active_contraption in list')

    table.remove(contraptions, index)

    for _, interface in pairs(global.interfaces) do
        interface:on_contraption_list_changed()
    end
end

function interface:on_gui_new_contraption()
    local main = self.main_interface
    assert(main, 'button not created')
    if main.new_contrap_ui then self:destroy_new_gui()
    else self:create_new_gui() end
end

function interface:on_gui_create_contraption()
    local main = self.main_interface
    assert(main, 'button does not exist')
    local new_contrap_ui = main.new_contrap_ui
    assert(new_contrap_ui, 'button does not exist')

    local name = (new_contrap_ui.name.text or ''):match('^%s*(.-)%s*$')
    if #name == 0 then
        self:print('contraption name may not be empty')
        return
    end
    local contraptions = get_contraptions(self)
    local lowered_name = string.lower(name)
    for _, contraption in ipairs(contraptions) do
        if string.lower(contraption.name) == lowered_name then
            self:print(('a contraption with the name %q already exists'):format(name))
            return
        end
    end

    local contraption = make_metatable({}, contraption_functions)
    contraptions[#contraptions + 1] = contraption
    contraption:new(self.player.force, 'custom', name)

    table.sort(contraptions, function (a, b)
        if a.type == b.type then return a.name < b.name end
        return a.type == 'all'
    end)

    self.active_contraption = contraption
    self:destroy_new_gui()

    for _, interface in pairs(global.interfaces) do
        interface:on_contraption_list_changed()
    end

    self:on_gui_edit_contraption()
end

function interface:on_player_selected_area(alt, item, entities)
    if item ~= 'combinator-select-tool' then return end

    local contraption = self.active_contraption
    local already_contained_entities = {}
    for _, entity in ipairs(contraption.entities) do
        already_contained_entities[entity.unit_number] = true
    end

    local not_added_count = 0
    for _, entity in ipairs(entities) do
        local contained = already_contained_entities[entity.unit_number]
        if contained and alt then
            contraption:try_remove_entity(entity)
        elseif not contained and not alt then
            if global.controlled_entities[entity.unit_number] then
                not_added_count = not_added_count + 1
            else
                contraption:try_add_entity(entity)
            end
        end
    end

    if not_added_count >= 1 then
        self:print(('%d combinators could not be added, because they are used by another player'):format(not_added_count))
    end
end

function interface:update_gui()
    local contraptions = get_contraptions(self)
    local debug_session = self:get_debug_session()

    local main = self.main_interface
    if not main then
        return
    end

    do -- Update contraption dropdown
        local dropdown = main.contraption_dropdown
        local new_items, new_index = {}
        for index, contraption in ipairs(contraptions) do
            local name
            if contraption.contraption_type == 'all' then
                name = 'All combinators'
            else
                name = contraption.name
            end
            new_items[#new_items + 1] = name
            if contraption == self.active_contraption then
                new_index = index
            end
        end

        assert(new_index, 'contraption was removed without notifying interfaces')

        dropdown.selected_index = 0
        dropdown.items = new_items
        dropdown.selected_index = new_index
    end

    do -- Update button states
        local is_paused = debug_session and debug_session:is_paused() or false

        if debug_session or self.is_editing then
            main.contraption_dropdown.enabled, main.contraption_dropdown.style = false,
                self.is_editing
                    and 'controllinator_editing_dropdown_style'
                    or 'controllinator_debugging_dropdown_style'
            main.new_contraption.enabled = false
            main.delete_contraption.enabled = false
        else
            main.contraption_dropdown.enabled, main.contraption_dropdown.style = true, 'dropdown_style'
            main.new_contraption.enabled = true
            main.delete_contraption.enabled = true
                and self.active_contraption and self.active_contraption.contraption_type ~= 'all'
        end

        if debug_session then
            main.debug_toggle.caption = 'Stop'
            main.debug_pause.caption = is_paused and 'Resume' or 'Pause'
            main.debug_pause.enabled = true
            main.debug_step.enabled = true
        else
            main.debug_toggle.caption = 'Start'
            main.debug_pause.caption = 'Pause'
            main.debug_pause.enabled = false
            main.debug_step.enabled = false
        end

        main.edit_contraption.enabled = self.active_contraption
            and self.active_contraption.contraption_type ~= 'all'
    end

    local new_contrap_ui = main.new_contrap_ui
    main.debug_toggle.enabled = not new_contrap_ui
    if new_contrap_ui then
        main.edit_contraption.enabled = false
        return
    end
end

return interface
