local cache = {
    -- to check if must update the maps
    abbrevs = '',
    -- tracks all values containing keyword chars, to be treated differently
    -- [last_chunk_of_value] = {full_val_i}
    last_chunk_to_full_values = {},
    -- tracks all abbreviations
    -- [full_value] = trigger
    value_to_trigger = {},
}

-- @param value - containing at least one non-keyword character
-- @return updated last_chunk_to_full_values
local function add_nk_containing_abbr(map_nk_val, value)
    local val_after_non_keyword_pat = vim.regex('[[:keyword:]]\\+$')
    local val_after_nk_start, val_after_nk_end = val_after_non_keyword_pat:match_str(value)

    local val_is_only_one_char_and_is_nk_keyword = not val_after_nk_start
    if val_is_only_one_char_and_is_nk_keyword then
        -- must be {} because last chunk could be common
        if not map_nk_val[''] then
            map_nk_val[''] = {}
        end
        table.insert(map_nk_val[''], value)

        return map_nk_val
    end

    val_after_nk_start = val_after_nk_start + 1

    local val_after_nk = value:sub(val_after_nk_start, val_after_nk_end)

    if not map_nk_val[val_after_nk] then
        map_nk_val[val_after_nk] = {}
    end
    table.insert(map_nk_val[val_after_nk], value)

    return map_nk_val
end

-- @Summary Parses neovim's list of abbrevations into a map
-- Caches results, so only runs if new iabbrevs are added during session
-- @return {[trigger] = value} and {[part_after_last_nonkeyword_in_value] = {full_values}}
local function get_abbr_maps()
    local abbrevs = vim.api.nvim_exec('iabbrev', true) .. '\n' -- the \n is important for regex

    if cache.abbrevs == abbrevs then
        return cache.value_to_trigger, cache.last_chunk_to_full_values
    end
    cache.abbrevs = abbrevs

    local cur_val_to_trig = {}
    local cur_lchunk_to_vals = {}

    for trigger, value in abbrevs:gmatch('i%s%s(.-)%s%s*(.-)\n') do
        -- support for plugins such as vim-abolish, which adds prefix
        -- see :help map /can appear
        value = string.gsub(value, '^[*&@]+', '')

        local value_contains_non_keyword_pat = vim.regex('[^[:keyword:]]')
        local value_contains_non_keyword = value_contains_non_keyword_pat:match_str(value)
        if value_contains_non_keyword then
            cur_lchunk_to_vals = add_nk_containing_abbr(cur_lchunk_to_vals, value)
        end

        cur_val_to_trig[value] = trigger
    end

    cache.value_to_trigger = cur_val_to_trig
    cache.last_chunk_to_full_values = cur_lchunk_to_vals

    return cur_val_to_trig, cur_lchunk_to_vals
end

return {
    get_abbr_maps = get_abbr_maps
}
