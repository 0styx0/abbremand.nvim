local assert = require('luassert.assert')
local abbremand = require('abbremand')
local parse_abbrs = require('abbremand.parse_abbrs')
local spy = require('luassert.spy')
local stub = require('luassert.stub')
local helpers = require('test.plenary.helpers')

describe('_find_abbrev', function()
    -- removed at eof. plenary doesn't support teardown()
    local keyword, non_keyword = helpers.set_keyword()

    -- unit test, don't rely on other functionality
    stub(abbremand, '_check_abbrev_remembered').returns(nil)

    it('short circuits if abbreviation not possible', function()
        -- _create just happens to be a method used in _find_abbrev
        local spied_create = spy.on(parse_abbrs, 'get_abbr_maps')
        abbremand._find_abbrev(keyword, abbremand._keylogger)

        assert.spy(spied_create).was_not_called()
        parse_abbrs.get_abbr_maps:revert()
    end)

    -- the next three tests handle abbreviations formatted
    -- as specifed in `:h abbreviations`
    it('finds full-id (all keywords) abbreviations', function()
        local trigger = 'foo'
        local value = 'foobar'

        helpers.create_abbr({}, trigger, value)

        abbremand._keylogger = 'random text ' .. value .. non_keyword
        local actual_trigger, actual_value = abbremand._find_abbrev(non_keyword, abbremand._keylogger)

        assert.are.same(trigger, actual_trigger)
        assert.are.same(value, actual_value)
    end)

    it('finds end-id (ends in keyword, no restriction on anything else) abbreviations', function()
        local trigger = '#i'
        local value = 'import'

        helpers.create_abbr({}, trigger, value)

        abbremand._keylogger = 'random text ' .. value .. non_keyword
        local actual_trigger, actual_value = abbremand._find_abbrev(non_keyword, abbremand._keylogger)

        assert.are.same(trigger, actual_trigger)
        assert.are.same(value, actual_value)
    end)

    it('finds non-id (anything, but ends in non-keyword) abbreviations', function()
        local trigger = 'def#'
        local value = 'hi'

        helpers.create_abbr({}, trigger, value)

        abbremand._keylogger = 'random text ' .. value .. non_keyword
        local actual_trigger, actual_value = abbremand._find_abbrev(non_keyword, abbremand._keylogger)

        assert.are.same(trigger, actual_trigger)
        assert.are.same(value, actual_value)
    end)

    it('finds abbrev where value has keyword characters in it', function()
        local trigger = 'wt'
        local value = "what's"

        helpers.create_abbr({}, trigger, value)

        abbremand._keylogger = 'random text ' .. value .. non_keyword
        local actual_trigger, actual_value = abbremand._find_abbrev(non_keyword, abbremand._keylogger)

        assert.are.same(trigger, actual_trigger)
        assert.are.same(value, actual_value)
    end)

    helpers.run_multi_category_tests(non_keyword, function(category, abbr)
        it('accounts for ' .. category .. ' word abbrs', function()
            helpers.create_abbr({}, abbr.trigger, abbr.value)

            abbremand._keylogger = 'random text ' .. abbr.value .. non_keyword
            local actual_trigger, actual_value = abbremand._find_abbrev(non_keyword, abbremand._keylogger)

            assert.are.same(abbr.trigger, actual_trigger)
            assert.are.same(abbr.value, actual_value)
        end)
    end)

    it('uses most recently typed abbr, if multiple typed', function()
        abbremand._keylogger = ''

        for i = 1, 2, 1 do
            local abbr = helpers.abbrs.generic[i]
            helpers.create_abbr({}, abbr.trigger, abbr.value)

            abbremand._keylogger = abbremand._keylogger .. ' random text ' .. abbr.value .. non_keyword
            local actual_trigger, actual_value = abbremand._find_abbrev(non_keyword, abbremand._keylogger)

            assert.are.same(abbr.trigger, actual_trigger, i .. 'th abbrev')
            assert.are.same(abbr.value, actual_value)
        end
    end)
end)

helpers.reset()
