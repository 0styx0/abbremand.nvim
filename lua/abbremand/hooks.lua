local utils = require('abbremand.utils')

-- [id] = {[abbr_data] = abbr_data}
local ext_data = {}


-- @return zero indexed {row, col, col_end} of value. assumes value ends at cursor pos
local function get_coordinates(value)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    local line_num = row - 1
    local value_start = col - #value - 1
    local value_end = col - 1

    return {
	    row = line_num,
	    col = value_start,
	    col_end = value_end
    }
end

-- @Summary sets extmark at abbr_data coordinates and sets ext_data[ext_id] = abbr_data
-- @return ext_id
local function set_extmark(abbr_data)

    local ns_id = utils.get_namespace()

    local ext_id = vim.api.nvim_buf_set_extmark(0, ns_id, abbr_data.row, abbr_data.col + 1, {
        end_col = abbr_data.col_end + 1,
    })

    ext_data[ext_id] = {
        abbr_data = abbr_data,
    }

    return ext_id
end

-- @Summary triggers callbacks, passing a table consisting of:
--   { trigger, value, row, col, col_end, on_change: Function}
-- @param clients - @see abbremend._clients
-- @param callbacks - @see abbremand._clients.(forgotten|remembered)
local function trigger_callbacks(trigger, value, clients, callbacks)

	local coordinates = get_coordinates(value)
	local abbr = { trigger = trigger, value = value }
	local abbr_data = vim.tbl_extend('error', abbr, coordinates)

    local ext_id = set_extmark(abbr_data)
    clients.on_change[ext_id] = {}


	abbr_data.on_change = function(change_callback)
        table.insert(clients.on_change[ext_id], change_callback)
	end

    for key, callback in ipairs(callbacks) do
        local cb_result = callback(abbr_data)

        if cb_result == false then
            table.remove(callbacks, key)
        end
    end
end

-- @Summary checks if abbr value was changed after typed. if so, calls on_change
--   handlers registered through abbr_data.on_change with param `new_text`
-- @param clients - @see abbremand._clients
local function monitor_abbrs(clients)

    local row = unpack(vim.api.nvim_win_get_cursor(0))

    local ns_id = utils.get_namespace()

    local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, { row - 1, 0 }, { row + 1, 0 }, { details = true })

    if vim.tbl_isempty(marks) then
        return
    end

    for _, value in ipairs(marks) do
        local ext_id, row, col, details = unpack(value)

        local line = vim.api.nvim_get_current_line()
        local ext_contents = string.sub(line, col + 1, details.end_col)

        local cur_ext_data = ext_data[ext_id]

        if cur_ext_data.abbr_data.value ~= ext_contents then
            for _, callback in ipairs(clients.on_change[ext_id]) do
                callback(ext_contents)
            end
            vim.api.nvim_buf_del_extmark(0, ns_id, ext_id)
        end
    end
end

return {
    trigger_callbacks = trigger_callbacks,
    monitor_abbrs = monitor_abbrs,
    _get_coordinates = get_coordinates,
}

