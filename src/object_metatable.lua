return {
    make_metatable = function (data, functions)
        return setmetatable(data, {
            __index = function (self, key)
                return functions[key]
                -- local fn = functions[key]
                -- if fn then return fn end
                -- return rawget(self, key)
            end,
            __newindex = function (self, key, value)
                local fn = functions[key]
                if fn then error(('cannot assign to %q because it is a function'):format(key), 2) end
                rawset(self, key, value)
            end
        })
    end
}