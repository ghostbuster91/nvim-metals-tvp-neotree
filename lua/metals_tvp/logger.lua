M = {}

M.error = function(msg)
    vim.notify("error: " .. vim.inspect(msg), vim.log.levels.ERROR, { title = "metals-tvp" })
end

return M
