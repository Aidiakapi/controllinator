--[[

An interface is associated with a single player, and responsible for all
user interaction of the mod. An instance is created for each player, and
destroyed when a player is pruned.

]]

local wrap_style = require('style_wrapper')
local debug_session_functions = require('debug_session')
local make_metatable = require('object_metatable').make_metatable

local interface = {}

local function get_contraptions(self)
    return global.contraptions[self.player.force.name] or {}
end

function interface:new(player)
    self.player = player

    self.buttons = {}
    self.active_contraption = (get_contraptions(self) or {})[1]
    self:create_top_gui()
end

function interface:destroy()
    if self.player.valid then
        self:destroy_top_gui()
        self:destroy_main_interface()
    end

    for k, v in pairs(self) do
        self[k] = nil
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

function interface:create_top_gui()
    if self.buttons.main_toggle then self:destroy_top_gui() end

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
    if not self.buttons.main_toggle.valid then
        self.buttons.main_toggle = nil
        return
    end
    self.buttons.main_toggle.destroy()
end

function interface:create_main_interface()
    if self.main_interface then self:destroy_main_interface() end

    local main = {}
    self.main_interface = main

    -- Root frame
    main.root = self.player.gui.left.add({
        type = 'frame',
        name = 'controllinator-main',
        direction = 'vertical',
        caption = 'Controllinator'
    })
    local root = main.root.add({
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

        label.style.right_padding = 20
        main.contraption_dropdown = flow.add({
            type = 'drop-down',
            name = 'controllinator-main-contraption'
        })

        local edit_button = flow.add({
            type = 'button',
            name = 'controllinator-main-contraptions-edit',
            caption = 'Edit'
        })
        local style = wrap_style(edit_button.style)
        style.font = 'default'
        style.padding = { 0, 3 }
        main.edit_contraptions = edit_button
        edit_button.tooltip = 'Mod is still in development, editing contraptions is not yet implemented.'
        edit_button.enabled = false
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

function interface:destroy_main_interface()
    if not self.main_interface then return end
    if self.main_interface.root.valid then
        self.main_interface.root.destroy()
    end
    self.main_interface = nil
end

function interface:toggle_main_interface()
    if self.main_interface then self:destroy_main_interface()
    else self:create_main_interface() end
end

function interface:on_gui_click(element, button, alt, control, shift)
    if element == self.buttons.main_toggle then
        self:toggle_main_interface()
    elseif self.main_interface then
        local main = self.main_interface
        if element == main.debug_toggle then
            self:on_gui_debug_toggle()
        elseif element == main.debug_pause then
            self:on_gui_debug_pause()
        elseif element == main.debug_step then
            self:on_gui_debug_step()
        end
    end
end

function interface:on_gui_selection_state_changed(element)
    if self.main_interface then
        local main = self.main_interface
        if element == main.contraption_dropdown then
            interface:on_gui_contraption_selection_changed()
        end
    end
end

function interface:on_gui_debug_toggle()
    -- print('debug toggle')
    local debug_session = self:get_debug_session()

    if debug_session then
        local index
        for i, v in ipairs(global.debug_sessions) do
            if v == debug_session then
                index = i
                break
            end
        end
        assert(index)
        debug_session:destroy()
        table.remove(global.debug_sessions, index)
    else
        local contraption = self.active_contraption
        local overlap = false
        for _, entity in ipairs(contraption.entities) do
            if global.controlled_entities[entity.unit_number] then
                overlap = true
                break
            end
        end

        if overlap then
            self:print('Cannot start debug session, because some entities are already being debugged (perhaps by another players?)')
            return
        end
        debug_session = make_metatable({}, debug_session_functions)
        global.debug_sessions[#global.debug_sessions + 1] = debug_session
        debug_session:new(self.player, contraption)
    end

    self:update_gui()
end

function interface:on_gui_debug_pause()
    -- print('debug pause')
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
    -- print('debug step')
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
    print('contraption selection changed')
    local contraptions = get_contraptions(self)
    self.active_contraption = contraptions[self.main_interface.contraption_dropdown.selected_index]
end

function interface:on_contraption_list_changed()
    print('contraption list changed')

end

function interface:update_gui()
    local contraptions = get_contraptions(self)
    local debug_session = self:get_debug_session()

    if not self.main_interface then
        return
    end

    local main = self.main_interface
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
        if debug_session then
            main.contraption_dropdown.enabled, main.contraption_dropdown.style = false, 'controllinator_disabled_dropdown_style'
            main.debug_toggle.caption = 'Stop'
            main.debug_pause.caption = is_paused and 'Resume' or 'Pause'
            main.debug_pause.enabled = true
            main.debug_step.enabled = is_paused
        else
            main.contraption_dropdown.enabled, main.contraption_dropdown.style = true, 'dropdown_style'
            main.debug_toggle.caption = 'Start'
            main.debug_pause.caption = 'Pause'
            main.debug_pause.enabled = false
            main.debug_step.enabled = false
        end
    end
end

return interface
