local parse_abbrs = require('abbremand.parse_abbrs')
local hooks = require('abbremand.hooks')

-- note: nk = non-keyword (which can expand abbrevations. but can also be part of abbreviation values)
-- functions exposed for unit tests prefixed with _. else local, or part of `abbremand`
local abbremand = {
    _keylogger = '',
    _backspace_data = {
        consecutive_backspaces = 0,
        saved_keylogger = '',
        potential_trigger = '',
    },
    _clients = {
        forgotten = {},
        remembered = {},
        on_change = {},
    },
    _enabled = false,
}

function abbremand.clear_keylogger()
    -- doing this on bufread fixes bug where characters C> are part of keylogger string
    abbremand._keylogger = ''
end

-- @Summary tracks backspacing. more complex than logic might initially seem
--   because on abbreviation expansion, vim backspaces the trigger.
--   so must differentiate between user vs expansion backspacing
local function handle_backspacing(backspace_typed)
    if backspace_typed then
        if abbremand._backspace_data.consecutive_backspaces == 0 then
            abbremand._backspace_data.saved_keylogger = abbremand._keylogger
            abbremand._backspace_data.potential_trigger = ''
        end

        abbremand._keylogger = abbremand._keylogger:sub(1, -2)
        abbremand._backspace_data.consecutive_backspaces = abbremand._backspace_data.consecutive_backspaces + 1
        return
    end

    if abbremand._backspace_data.consecutive_backspaces == 0 then
        return
    end

    -- when abbr expanded, it deletes the trigger
    -- so later in @see check_abbrev_remembered, compare with actual trigger
    abbremand._backspace_data.potential_trigger = string.sub(
        abbremand._backspace_data.saved_keylogger,
        #abbremand._backspace_data.saved_keylogger - abbremand._backspace_data.consecutive_backspaces + 1
    )

    abbremand._backspace_data.consecutive_backspaces = 0
    abbremand._backspace_data.saved_keylogger = ''
end

-- @return {boolean} if anything is using the plugin
local function has_subscribers()
    local clients = abbremand._clients
    return vim.tbl_count(clients.forgotten) > 0 or vim.tbl_count(clients.remembered) > 0
end

function abbremand.start()
    vim.api.nvim_buf_attach(0, false, {

        on_detach = abbremand.clear_keylogger,

        on_bytes = function(
            byte_str,
            buf,
            changed_tick,
            start_row,
            start_col,
            byte_offset,
            old_end_row,
            old_end_col,
            old_length,
            new_end_row,
            new_end_col,
            new_length
        )

            if not has_subscribers() then
                abbremand.disable()
                return true
            end

            -- if don't have this, then the nvim_buf_get_lines will throw out of bounds error
            -- even if not actually accessing an index of it, even though start_row is a valid index
            if vim.api.nvim_get_mode().mode ~= 'i' then
                -- allows for reminders to take into account normal mode changes
                -- using nvim_get_current_line gives out of bounds error for some reason
                abbremand._keylogger = vim.fn.getline('.')
                return false
            end

            local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, true)[1]

            local cur_char = line:sub(start_col + 1, start_col + 1)
            abbremand._keylogger = abbremand._keylogger .. cur_char

            local cursor_col = start_col + new_end_col
            local line_until_cursor = line:sub(0, cursor_col)

            local user_backspaced = cur_char == ''
                and new_end_col == old_end_col - 1
                and new_end_row == old_end_row
                and new_length == 0

            if user_backspaced then
                handle_backspacing(true)
            else
                abbremand._find_abbrev(cur_char, line_until_cursor)
                handle_backspacing(false)
            end
        end,
    })
end

-- @return value if val_after_nk points to abbr value, else false
function abbremand._contains_nk_abbr(text, val_after_nk)
    local value_to_trigger, last_chunk_to_full_values = parse_abbrs.get_abbr_maps()
    if not last_chunk_to_full_values[val_after_nk] then
        return false
    end

    local potential_values = last_chunk_to_full_values[val_after_nk]

    for _, value in ipairs(potential_values) do
        if value_to_trigger[value] and string.find(text, value, #text - #value, true) then
            return value
        end
    end

    return false
end

-- @Summary searches through what has been typed since the user last typed
-- an abbreviation-expanding character, to see if an abbreviation has been used
-- @return trigger, value. or -1 if not found
function abbremand._find_abbrev(cur_char, line_until_cursor)
    local keyword_regex = vim.regex('[[:keyword:]]')
    local not_trigger_char = keyword_regex:match_str(cur_char)

    if not_trigger_char then
        return -1
    end

    local value_regex = vim.regex('[[:keyword:]]\\+[^[:keyword:]]\\+$')
    local val_start, val_end = value_regex:match_str(line_until_cursor)
    if not val_start then
        return -1
    end

    val_start = val_start + 1
    val_end = val_end - 1
    local potential_value = line_until_cursor:sub(val_start, val_end)

    local value_to_trigger = parse_abbrs.get_abbr_maps()
    local potential_trigger = value_to_trigger[potential_value]

    -- potential_value only contains characters after last non-keyword char
    local nk_value = abbremand._contains_nk_abbr(line_until_cursor, potential_value)
    if nk_value then
        local nk_trigger = value_to_trigger[nk_value]
        abbremand._check_abbrev_remembered(nk_trigger, nk_value, line_until_cursor)
        return nk_trigger, nk_value
    elseif potential_trigger then
        abbremand._check_abbrev_remembered(potential_trigger, potential_value, line_until_cursor)
        return potential_trigger, potential_value
    end

    return -1
end

-- @Summary checks if abbreviation functionality was used.
--   if value was manually typed, notify user
-- @return {-1, 0, 1} - if no abbreviation found (0), if user typed out the full value
--   instead of using trigger (0), if it was triggered properly (1)
function abbremand._check_abbrev_remembered(trigger, value, line_until_cursor)
    local value_trigger = parse_abbrs.get_abbr_maps()
    local abbr_exists = value_trigger[value] == trigger
    if not abbr_exists then
        return -1
    end

    local expanded_pat = vim.regex(trigger .. '[^[:keyword:]]' .. value)
    local abbr_remembered = expanded_pat:match_str(abbremand._keylogger)

    local expanded_midline_pat = vim.regex(trigger .. '[[:keyword:]]\\{' .. #trigger .. '}' .. value)
    local abbr_remembered_midline = expanded_midline_pat:match_str(abbremand._keylogger)

    if abbr_remembered or abbremand._backspace_data.potential_trigger == trigger or abbr_remembered_midline then
        abbremand.clear_keylogger()
        hooks.trigger_callbacks(trigger, value, abbremand._clients, abbremand._clients.remembered)
        abbremand._backspace_data.potential_trigger = ''
        return 1
    end

    local forgotten_pat = vim.regex(value .. '[^[:keyword:]]')
    local abbr_forgotten = forgotten_pat:match_str(line_until_cursor)

    local val_in_logger = string.find(abbremand._keylogger, value, 1, true)

    if abbr_forgotten and val_in_logger then
        abbremand.clear_keylogger()
        hooks.trigger_callbacks(trigger, value, abbremand._clients, abbremand._clients.forgotten)
        return 0
    end

    return -1
end

function abbremand.disable()
    -- setting this makes `nvim_buf_attach` return true,
    -- detaching from buffer and clearing keylogger
    -- @see abbremand.start
    abbremand._enabled = false
end

local function create_autocmds()

    vim.cmd[[
    augroup Abbremand
    autocmd!
    autocmd TextChanged,TextChangedI * :lua require('abbremand.hooks').monitor_abbrs(require('abbremand')._clients)
    augroup END
    ]]
end

function abbremand.enable()
    abbremand.start()
    create_autocmds()
    abbremand._enabled = true
end

-- @param callback: function which will receive as arguments:
-- function({trigger, value, row, col, col_end, on_change})
--   as arguments when abbreviation was forgotten
--   on_change will be fired if value is modified later
-- If callback returns `false` it is unsubscribed from future forgotten events
function abbremand.on_abbr_forgotten(callback)
    if not abbremand._enabled then
        abbremand.enable()
    end
    table.insert(abbremand._clients.forgotten, callback)
end

-- @param callback: function which will receive as arguments:
-- function({trigger, value, row, col, col_end, on_change})
--   as arguments when abbreviation was expanded
--   on_change will be fired if value is modified later
-- If callback returns `false` it is unsubscribed from future remembered events
function abbremand.on_abbr_remembered(callback)
    if not abbremand._enabled then
        abbremand.enable()
    end
    table.insert(abbremand._clients.remembered, callback)
end

return abbremand
