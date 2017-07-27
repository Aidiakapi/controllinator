return function (condition, message, level)
    if condition then
        return
    end

    if not message then
        message = 'assertion failed'
    end
    if not level then
        level = 2
    elseif level <= 0 then
        level = 1
    end

    local caller = debug.traceback(nil, 2):match('\t(.*)')
    error(('%s at %s'):format(message, caller), level + 1)
end