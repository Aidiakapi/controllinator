return function (expected_type, value, level)
    if type(value) == expected_type then
        return
    end

    if type(level) ~= 'number' then
        level = 2
    elseif level <= 0 then
        level = 1
    end

    local caller = debug.traceback(nil, 2):match('\t(.*)')
    error(('expected type %s but got %s at %s'):format(expected_type, type(value), caller), level + 1)
end