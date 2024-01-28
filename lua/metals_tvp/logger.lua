local Level = vim.log.levels

-- inspired by https://github.com/lewis6991/gitsigns.nvim/blob/main/lua/gitsigns/debug/log.lua
M = {
    current_level = Level.WARN,
    messages = {}, --- @type string[]
}

local should_log = function(level)
    if M.current_level == Level.DEBUG then
        return level ~= Level.TRACE
    elseif M.current_level == Level.INFO then
        return level ~= Level.TRACE and level ~= Level.DEBUG
    elseif M.current_level == Level.WARN then
        return level == Level.WARN or level == Level.ERROR
    elseif M.current_level == Level.ERROR then
        return level == Level.ERROR
    else
        return false
    end
end

M.error = function(msg, data)
    vim.notify(vim.inspect(msg), vim.log.levels.ERROR, { title = "metals-tvp" })
    M.log(Level.ERROR, msg)
    if data then
        M.log(Level.ERROR, vim.inspect(data))
    end
end

M.info = function(msg)
    M.log(Level.INFO, msg)
end

M.warn = function(msg)
    M.log(Level.WARN, msg)
end

M.log = function(level, msg)
    if should_log(level) then
        msg = string.format("(%s): %s", level, msg)
        M.messages[#M.messages + 1] = msg
    end
end

return M
