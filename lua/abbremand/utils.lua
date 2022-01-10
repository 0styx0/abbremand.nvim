
local function get_namespace()
    local ns_name = 'abbremand'
    local ns_id = vim.api.nvim_create_namespace(ns_name)
    return ns_id
end

return {
    get_namespace = get_namespace
}
