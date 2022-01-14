local assert = require('luassert.assert')
local stub = require('luassert.stub')
local helpers = require('test.plenary.helpers')
local spy = require('luassert.spy')
local abbremand = require('abbremand')
local parse_abbrs = require('abbremand.parse_abbrs')

describe('check_abbrev_remembered', function()
    local trigger = helpers.abbrs.generic[1].trigger
    local value = helpers.abbrs.generic[1].value
    helpers.create_abbr({}, trigger, value)

    -- removed at eof. plenary doesn't support teardown()
    local keyword, non_keyword = helpers.set_keyword()
    local spied_callback;

    stub(parse_abbrs, 'get_abbr_maps').returns({ [value] = trigger })
    stub(vim.api, 'nvim_buf_set_extmark').returns('check_abbrev_remembered_spec_stubbed')

    before_each(function()
        spied_callback = spy.new(function() end)
        abbremand.on_abbr_forgotten(spied_callback)
    end)

    after_each(function()
        spied_callback:revert()
    end)

    it('identifies when an abbreviation _was_ expanded', function()
        local text = abbremand._set_keylogger(trigger .. non_keyword .. value)

        local remembered = abbremand._check_abbrev_remembered(trigger, value, text)
        assert.are.same(1, remembered)
        assert.spy(spied_callback).was.Not.called()
    end)

    it('identifies when an abbreviation was _not_ expanded', function()
        local text = abbremand._set_keylogger('random no trigger stuff ' .. value .. non_keyword)

        local remembered = abbremand._check_abbrev_remembered(trigger, value, text)
        assert.are.same(0, remembered)
        assert.spy(spied_callback).was.called(1)
    end)

    it('identifies when something is _not_ a potential abbreviation', function()
        local text = abbremand._set_keylogger(value .. keyword)

        local remembered = abbremand._check_abbrev_remembered(trigger, value, text)
        assert.are.same(-1, remembered)
        assert.spy(spied_callback).was.Not.called()
    end)

    describe('identifies correctly if called twice in a row and', function()
        it('first time expanded, second not expanded', function()
            local first_text = abbremand._set_keylogger(trigger .. non_keyword .. value .. non_keyword)

            local remembered = abbremand._check_abbrev_remembered(trigger, value, first_text)
            assert.are.same(1, remembered)

            local second_text = abbremand._set_keylogger(value .. non_keyword)
            local remembered_second = abbremand._check_abbrev_remembered(trigger, value, second_text)
            assert.are.same(0, remembered_second)
        end)

        it('first time not an abbreviation, second not expanded', function()
            local first_text = abbremand._set_keylogger(value .. keyword)

            local remembered = abbremand._check_abbrev_remembered(trigger, value, first_text)
            assert.are.same(-1, remembered)

            local second_text = abbremand._set_keylogger(first_text .. value .. non_keyword)
            local remembered_second = abbremand._check_abbrev_remembered(trigger, value, second_text)
            assert.are.same(0, remembered_second)
        end)
    end)
end)

helpers.reset()
