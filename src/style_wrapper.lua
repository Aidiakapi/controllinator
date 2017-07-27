return function (style)
    local getters, setters = {
        width = function () return { style.minimal_width, style.maximal_width } end,
        height = function () return { style.minimal_height, style.maximal_height } end,
        padding = function () return { style.top_padding, style.right_padding, style.bottom_padding, style.left_padding } end,
        spacing = function () return { style.vertical_spacing, style.horizontal_spacing } end,
        title_padding = function () return { style.title_top_padding, style.title_right_padding, style.title_bottom_padding, style.title_left_padding } end,
        scrollbar_spacing = function () return { style.vertical_scrollbar_spacing, style.horizontal_scrollbar_spacing } end
    }, {
        width = function (value)
            local t = type(value)
            if t == 'table' and #value == 2 then
                style.minimal_width, style.maximal_width = value[1], value[2]
            elseif t == 'number' then
                style.minimal_width, style.maximal_width = value, value
            else
                error('height requires an array with two values or a single number', 2)
            end
        end,
        height = function (value)
            local t = type(value)
            if t == 'table' and #value == 2 then
                style.minimal_height, style.maximal_height = value[1], value[2]
            elseif t == 'number' then
                style.minimal_height, style.maximal_height = value, value
            else
                error('height requires an array with two values or a single number', 2)
            end
        end,
        padding = function (value)
            local t = type(value)
            if t == 'table' then
                if #value == 2 then
                    style.top_padding, style.right_padding, style.bottom_padding, style.left_padding = value[1], value[2], value[1], value[2]
                elseif #value == 4 then
                    style.top_padding, style.right_padding, style.bottom_padding, style.left_padding = value[1], value[2], value[3], value[4]
                else
                    error('padding table must have 2 or 4 values', 2)
                end
            elseif t == 'number' then
                style.top_padding, style.right_padding, style.bottom_padding, style.left_padding = value, value, value, value
            else
                error('padding requires a table with 2 or 4 values or a single number', 2)
            end
        end,
        spacing = function (value)
            local t = type(value)
            if t == 'table' and #value == 2 then
                style.vertical_spacing, style.horizontal_spacing = value[1], value[2]
            elseif t == 'number' then
                style.vertical_spacing, style.horizontal_spacing = value, value
            else
                error('spacing requires a table with 2 values or a single number', 2)
            end
        end,
        title_padding = function (value)
            local t = type(value)
            if t == 'table' then
                if #value == 2 then
                    style.title_top_padding, style.title_right_padding, style.title_bottom_padding, style.title_left_padding = value[1], value[2], value[1], value[2]
                elseif #value == 4 then
                    style.title_top_padding, style.title_right_padding, style.title_bottom_padding, style.title_left_padding = value[1], value[2], value[3], value[4]
                else
                    error('title_padding table must have 2 or 4 values', 2)
                end
            elseif t == 'number' then
                style.title_top_padding, style.title_right_padding, style.title_bottom_padding, style.title_left_padding = value, value, value, value
            else
                error('title_padding requires a table with 2 or 4 values or a single number', 2)
            end
        end,
        scrollbar_spacing = function (value)
            local t = type(value)
            if t == 'table' and #value == 2 then
                style.vertical_scrollbar_spacing, style.horizontal_scrollbar_spacing = value[1], value[2]
            elseif t == 'number' then
                style.vertical_scrollbar_spacing, style.horizontal_scrollbar_spacing = value, value
            else
                error('scrollbar_spacing requires a table with 2 values or a single number', 2)
            end
        end
    }

    return setmetatable({}, {
        __index = function (self, key)
            local getter = getters[key]
            if getter then return getter() end
            return style[key]
        end,
        __newindex = function (self, key, value)
            local setter = setters[key]
            if setter then return setter(value) end
            style[key] = value
        end
    })
end