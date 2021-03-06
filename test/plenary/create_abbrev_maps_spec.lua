local assert = require('luassert.assert')

local parse_abbrs = require('abbremand.parse_abbrs')
local abbremand = require('abbremand')
local helpers = require('test.plenary.helpers')

local abbrs = {}

describe('get_abbrevs_val_trigger works correctly if', function()
    local keyword, non_keyword = helpers.set_keyword()

    it('gets all created abbreviations', function()
        helpers.reset() -- technically not needed, but doesn't hurt
        for _, abbr in ipairs(helpers.abbrs.generic) do
            abbrs = helpers.create_abbr(abbrs, abbr.trigger, abbr.value)
        end

        local map_value_trigger = parse_abbrs.get_abbr_maps()
        assert.are.same(abbrs, map_value_trigger)
    end)

    -- technically a space might be a keyword. but _highly_ doubt that
    it('can follow values containing non-keywords to the main abbreviation map', function()
        local nk_trigger = 'pov'
        local after_last_nk = 'view'
        local nk_val = 'point of' .. non_keyword .. after_last_nk

        abbrs = helpers.create_abbr(abbrs, nk_trigger, nk_val)
        local abbrev_map_value_trigger = parse_abbrs.get_abbr_maps()

        local nk_full_val = abbremand._contains_nk_abbr(nk_val, after_last_nk)
        assert.truthy(nk_full_val)
        assert.are.same(nk_val, nk_full_val)
        assert.are.same(nk_trigger, abbrev_map_value_trigger[nk_full_val])
    end)

    it('adds abbreviations with special characters to list', function()
        local trigger = 'wts'
        local value = "what's"

        abbrs = helpers.create_abbr(abbrs, trigger, value)
        local abbrev_map_value_trigger = parse_abbrs.get_abbr_maps()

        assert.are.same(trigger, abbrev_map_value_trigger[value])
    end)

    it('adds newly defined abbreviations to the list', function()
        abbrs = helpers.create_abbr(abbrs, 'hi', 'hello')

        local map_value_trigger = parse_abbrs.get_abbr_maps()
        assert.are.same(abbrs, map_value_trigger)
    end)

    it('takes into account modified abbreviations', function()
        local old = { ['key'] = 'anth', ['value'] = 'anthropology' }

        abbrs = helpers.create_abbr(abbrs, 'anth', 'anthropology')

        local map_value_trigger = parse_abbrs.get_abbr_maps()
        assert.are.same(abbrs, map_value_trigger, 'regular abbrev created')

        abbrs[old.value] = nil -- remove from testing table
        abbrs = helpers.create_abbr(abbrs, 'anth', 'random')

        local map_value_trigger_updated = parse_abbrs.get_abbr_maps()
        assert.are.same(abbrs, map_value_trigger_updated, 'updated abbrev')
    end)

    -- implies support for vim-abolish
    it('handles prefixed abbreviations', function()
        local abbr = { trigger = 'op', value = 'operation' }
        vim.cmd('iabbrev <buffer> ' .. abbr.trigger .. ' ' .. abbr.value)

        local map_value_trigger = parse_abbrs.get_abbr_maps()

        assert.are.same(abbr.trigger, map_value_trigger[abbr.value])
    end)

    it('value consists of a single non-keyword char', function()
        local abbr = helpers.abbrs.containing_non_keyword.single_char[1]

        abbrs = helpers.create_abbr(abbrs, abbr.trigger, abbr.value)
        local abbrev_map_value_trigger = parse_abbrs.get_abbr_maps()

        -- removing because if assertion fails, would break rest of tests
        abbrs = helpers.remove_abbr(abbrs, abbr.trigger, abbr.value)

        assert.are.same(abbr.trigger, abbrev_map_value_trigger[abbr.value])
    end)

    it('two non-keyword-containing values with same ending can coexist', function()
        local after_last_nk = 'view'
        local same_ending_abbrs = {
            [1] = {
                ['trigger'] = 'pov',
                ['value'] = 'point of' .. non_keyword .. after_last_nk,
            },
            [2] = {
                ['trigger'] = 'nv',
                ['value'] = 'nice' .. non_keyword .. after_last_nk,
            },
        }

        abbrs = helpers.create_abbr(abbrs, same_ending_abbrs[1].trigger, same_ending_abbrs[1].value)
        abbrs = helpers.create_abbr(abbrs, same_ending_abbrs[2].trigger, same_ending_abbrs[2].value)
        local abbrev_map_value_trigger, last_chunk_to_full_values = parse_abbrs.get_abbr_maps()

        assert.are.same(same_ending_abbrs[1].trigger, abbrev_map_value_trigger[same_ending_abbrs[1].value])
        assert.are.same(same_ending_abbrs[2].trigger, abbrev_map_value_trigger[same_ending_abbrs[2].value])

        assert.contains_element(last_chunk_to_full_values[after_last_nk], same_ending_abbrs[1].value)
        assert.contains_element(last_chunk_to_full_values[after_last_nk], same_ending_abbrs[2].value)
    end)
end)

helpers.reset()
