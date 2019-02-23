local styles = data.raw['gui-style'].default

local function make_disabled_dropdown(name, font_color)
    local dropdown_button = table.deepcopy(styles.button)
        
    dropdown_button.padding = 0
    dropdown_button.horizontal_align = 'right'
    dropdown_button.font = 'default-dropdown'
    dropdown_button.left_click_sound = {}

    dropdown_button.default_font_color = table.deepcopy(font_color)
    dropdown_button.default_graphical_set = table.deepcopy(dropdown_button.disabled_graphical_set)
    dropdown_button.hovered_font_color = table.deepcopy(font_color)
    dropdown_button.hovered_graphical_set = table.deepcopy(dropdown_button.disabled_graphical_set)
    dropdown_button.disabled_font_color = table.deepcopy(font_color)

    styles[name .. '_button'] = dropdown_button
    local dropdown = table.deepcopy(styles.dropdown)
    dropdown.button_style = {
        type = 'button_style',
        parent = name .. '_button'
    }
    styles[name] = dropdown
end

make_disabled_dropdown('controllinator_debugging_dropdown', { r = 0.5, g = 1, b = 0.5 })
make_disabled_dropdown('controllinator_editing_dropdown', { r = 1, g = 1, b = 0.5 })
