local styles = data.raw['gui-style'].default
--[[
local dropdown = table.deepcopy(styles.dropdown_style)
dropdown.disabled_graphical_set = table.deepcopy(dropdown.clicked_graphical_set)
dropdown.disabled_font_color = { 1, 0.5, 0.5 }

styles.controllinator_dropdown_style = dropdown
]]

local disabled_dropdown = table.deepcopy(styles.dropdown_style)
disabled_dropdown.default_graphical_set, disabled_dropdown.default_font_color = disabled_dropdown.clicked_graphical_set, { r = 0.5, g = 1, b = 0.5 }

styles.controllinator_disabled_dropdown_style = disabled_dropdown

-- styles.controllinator_disabled_dropdown_style = {
--     bottom_padding = 3,
--     clicked_graphical_set = {
--         corner_size = {
--             3,
--             3
--         },
--         filename = "__core__/graphics/gui.png",
--         position = {
--             0,
--             16
--         },
--         priority = "extra-high-no-scale",
--         type = "composition"
--     },
--     default_font_color = {
--         b = 0,
--         g = 1,
--         r = 1
--     },
--     default_graphical_set = {
--         corner_size = {
--             3,
--             3
--         },
--         filename = "__core__/graphics/gui.png",
--         position = {
--             0,
--             0
--         },
--         priority = "extra-high-no-scale",
--         type = "composition"
--     },
--     font = "default",
--     hovered_font_color = {
--         b = 1,
--         g = 0,
--         r = 0
--     },
--     hovered_graphical_set = {
--         corner_size = {
--             3,
--             3
--         },
--         filename = "__core__/graphics/gui.png",
--         position = {
--             0,
--             8
--         },
--         priority = "extra-high-no-scale",
--         type = "composition"
--     },
--     disabled_graphical_set = {
--         corner_size = {
--             3,
--             3
--         },
--         filename = "__core__/graphics/gui.png",
--         position = {
--             0,
--             16
--         },
--         priority = "extra-high-no-scale",
--         type = "composition"
--     },
--     disabled_font_color = {
--         b = 0.5,
--         g = 0,
--         r = 1
--     },
--     left_padding = 6,
--     listbox_style = {
--         font = "default"
--     },
--     right_padding = 6,
--     top_padding = 3,
--     triangle_image = {
--         filename = "__core__/graphics/gui.png",
--         height = 5,
--         priority = "extra-high-no-scale",
--         width = 10,
--         x = 36,
--         y = 6
--     },
--     type = "dropdown_style"
-- }