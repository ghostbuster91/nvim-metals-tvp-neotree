M = {}

M.error = function(msg)
    vim.notify("error: " .. vim.inspect(msg), vim.log.levels.ERROR, { title = "kasper" })
end

return M
