--[[

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

[ MIT license: http://www.opensource.org/licenses/mit-license.php ]

--]]

--[[

The primary aim of this parser is to test Kollos as a platform for
arbitrary grammars. Speed is also an aim, but secondary.

In keeping with these priorities, JSON is treated as if there were no
existing code for it -- after all, if I wanted a fast JSON parser I could
just grab a very fast C language recursive descent parser from somewhere.
Everything is created "from scratch" using tools which generalize to
other parsers. For example, I'm sure there is code out there in both
Lua and C to crunch JSON strings, code which is both better and faster
than what is here, but I do not use it.

--]]

-- luacheck: std lua51
-- luacheck: globals bit

local function here() return -- luacheck: ignore here
    debug.getinfo(2,'S').source .. debug.getinfo(2, 'l').currentline
end

local inspect = require "kollos.inspect" -- luacheck: ignore

-- eventually most of this code becomes part of kollos
-- for now we bring the already written part in as a
-- module
local kollos = require "kollos"

local json_kir = {
    -- tokens in l0 are at a lower level than
    -- "tokens" as defined in RFC 7159, section 2
    -- RFC 7159 does not separate semantics from syntax --
    -- if you assume either top-down parsing (as in recursive
    -- descent) or a dedicated lexer (as in yacc) there's no
    -- need to make the separation.
    l0 = {
        irule = {
            -- ws before and after <value>, see RFC 7159, section 2
            { lhs='ws_before', rhs={ 'ws' } },
            { lhs='ws_after', rhs={ 'ws' } },
            -- next rules are ws ::= ws_char*
            { lhs='ws', rhs={ 'ws_seq' } },
            { lhs='ws_seq', rhs={ 'ws_seq', 'ws_char' } },
            { lhs='ws_seq', rhs={ 'ws_char' } },
            { lhs='ws_seq', rhs={ } }, -- empty
            { lhs='begin_array', rhs = { 'ws', 'lsquare', 'ws' } },
            { lhs='begin_object', rhs = { 'ws', 'lcurly', 'ws' }},
            { lhs='end_array', rhs = { 'ws', 'rsquare', 'ws' }},
            { lhs='end_object', rhs = { 'ws', 'rcurly', 'ws' }},
            { lhs='name_separator', rhs = { 'ws', 'colon', 'ws' }},
            { lhs='value_separator', rhs = { 'ws', 'comma', 'ws' }},
            { lhs='false', rhs = { 'char_f', 'char_a', 'char_l', 'char_s', 'char_e' }},
            { lhs='true', rhs = { 'char_t', 'char_r', 'char_u', 'char_e' }},
            { lhs='null', rhs = { 'char_n', 'char_u', 'char_l', 'char_l' }},
            { lhs='minus', rhs = { 'char_minus' }},

            -- Lua number format seems to be compatible with JSON,
            -- so we treat a JSON number as a full token
            { lhs='number', rhs = { 'opt_minus', 'int', 'opt_frac', 'opt_exp' }},
            { lhs='opt_minus', rhs = { 'char_minus' } },
            { lhs='opt_minus', rhs = { } },
            { lhs='opt_exp', rhs = { 'exp' } },
            { lhs='opt_exp', rhs = { } },
            { lhs='exp', rhs = { 'e_or_E', 'opt_sign', 'digit_seq' } },
            { lhs='e_or_E', rhs = { 'char_e' } },
            { lhs='e_or_E', rhs = { 'char_E' } },
            { lhs='opt_sign', rhs = { } },
            { lhs='opt_sign', rhs = { 'char_minus' } },
            { lhs='opt_sign', rhs = { 'char_plus' } },
            { lhs='opt_frac', rhs = { } },
            { lhs='opt_frac', rhs = { 'frac' } },
            { lhs='frac', rhs = { 'dot', 'digit_seq' } },
            { lhs='int', rhs = { 'char_nonzero', 'digit_seq' } },
            { lhs='digit_seq', rhs = { 'digit_seq', 'char_digit' } },
            { lhs='digit_seq', rhs = { 'char_digit' } },

            -- we divide up the standards string token, because we
            -- need to do semantic processing on its pieces
            { lhs='quote', rhs = { 'char_escape', 'char_quote' } },
            { lhs='backslash', rhs = { 'char_escape', 'char_backslash' } },
            { lhs='slash', rhs = { 'char_escape', 'char_slash' } },
            { lhs='backspace', rhs = { 'char_escape', 'char_b' } },
            { lhs='formfeed', rhs = { 'char_escape', 'char_f' } },
            { lhs='linefeed', rhs = { 'char_escape', 'char_n' } },
            { lhs='carriage_return', rhs = { 'char_escape', 'char_r' } },
            { lhs='tab', rhs = { 'char_escape', 'char_t' } },
            { lhs='hex_char', rhs = { 'char_escape', 'char_u', 'hex_digit', 'hex_digit', 'hex_digit', 'hex_digit' } },
            { lhs='simple_string', rhs = { 'char_escape', 'unescaped_char_seq' } },
            { lhs='unescaped_char_seq', rhs = { 'unescaped_char_seq', 'unescaped_char' } },
            { lhs='unescaped_char_seq', rhs = { 'unescaped_char' } }
        },

        isym = {
            ['ws_before'] = { lexeme = true },
            ['ws_after'] = { lexeme = true },
            ['begin_array'] = { lexeme = true },
            ['begin_object'] = { lexeme = true },
            ['end_array'] = { lexeme = true },
            ['end_object'] = { lexeme = true },
            ['name_separator'] = { lexeme = true },
            ['value_separator'] = { lexeme = true },
            ['false'] = { lexeme = true },
            ['true'] = { lexeme = true },
            ['null'] = { lexeme = true },
            ['minus'] = { lexeme = true },
            ['number'] = { lexeme = true },
            ['quote'] = { lexeme = true },
            ['backslash'] = { lexeme = true },
            ['slash'] = { lexeme = true },
            ['backspace'] = { lexeme = true },
            ['formfeed'] = { lexeme = true },
            ['linefeed'] = { lexeme = true },
            ['carriage_return'] = { lexeme = true },
            ['tab'] = { lexeme = true },
            ['hex_char'] = { lexeme = true },
            ['simple_string'] = { lexeme = true },
            ['digit_seq'] = {},
            ['exp'] = {},
            ['frac'] = {},
            ['int'] = {},
            ['e_or_E'] = {},
            ['opt_exp'] = {},
            ['opt_frac'] = {},
            ['opt_minus'] = {},
            ['opt_sign'] = {},
            ['unescaped_char_seq'] = {},
            ['ws'] = {},
            ['ws_seq'] = {},
            ['char_slash'] = { charclass = "[\047]" },
            ['char_backslash'] = { charclass = "[\092]" },
            ['char_escape'] = { charclass = "[\092]" },
            ['unescaped_char'] = { charclass = "[ !\035-\091\093-\255]" },
            ['ws_char'] = { charclass = "[\009\010\013\032]" },
            ['lsquare'] = { charclass = "[\091]" },
            ['lcurly'] = { charclass = "[{]" },
            ['hex_digit'] = { charclass = "[%x]" },
            ['rsquare'] = { charclass = "[\093]" },
            ['rcurly'] = { charclass = "[}]" },
            ['colon'] = { charclass = "[:]" },
            ['comma'] = { charclass = "[,]" },
            ['dot'] = { charclass = "[.]" },
            ['char_quote'] = { charclass = '["]' },
            ['char_nonzero'] = { charclass = "[1-9]" },
            ['char_digit'] = { charclass = "[0-9]" },
            ['char_minus'] = { charclass = '[-]' },
            ['char_plus'] = { charclass = '[+]' },
            ['char_a'] = { charclass = "[a]" },
            ['char_b'] = { charclass = "[b]" },
            ['char_E'] = { charclass = "[E]" },
            ['char_e'] = { charclass = "[e]" },
            ['char_f'] = { charclass = "[f]" },
            ['char_l'] = { charclass = "[l]" },
            ['char_n'] = { charclass = "[n]" },
            ['char_r'] = { charclass = "[r]" },
            ['char_s'] = { charclass = "[s]" },
            ['char_t'] = { charclass = "[t]" },
            ['char_u'] = { charclass = "[u]" },
        }

    },

}

local json_lex_g = kollos.lo_g.kir_compile(json_kir).l0

local json_example = [===[
[
{
    "precision": "zip",
    "Latitude": 37.7668,
    "Longitude": -122.3959,
    "Address": "",
    "City": "SAN FRANCISCO",
    "State": "CA",
    "Zip": "94107",
    "Country": "US"
},
{
    "precision": "zip",
    "Latitude": 37.371991,
    "Longitude": -122.026020,
    "Address": "",
    "City": "SUNNYVALE",
    "State": "CA",
    "Zip": "94085",
    "Country": "US"
}
]
]===] -- end of JSON example

-- local err_none = kollos.error.code_by_name['LUIF_ERR_NONE']
local err_unexpected_token_id = kollos.error.code_by_name['LUIF_ERR_UNEXPECTED_TOKEN_ID'] -- luacheck: ignore
print(inspect(kollos.event))
local symbol_completed_event = kollos.event.code_by_name['LIBMARPA_EVENT_SYMBOL_COMPLETED']

local function describe_character(byte)
    local printable_description = ''
    local char = string.char(byte)
    if char:find('^[^%c%s]') then
        printable_description = '"' .. char .. '", '
    end
    return printable_description .. string.format("0x%.2X", byte)
end

local function show_rule(rule_props, dot_position)
    local pieces = {
        rule_props.lhs.symbol.name,
    "::="}
    for dot_ix = 1,#rule_props.rhs do
        pieces[#pieces+1] = rule_props.rhs[dot_ix].symbol.name
    end
    if dot_position then
        table.insert(pieces, dot_position+3, '.')
    end
    return table.concat(pieces, ' ')
end

local function klol_progress_report(klol_r, earley_set)
    local libmarpa_r = klol_r.libmarpa_r
    local latest_earley_set =
        earley_set or libmarpa_r:latest_earley_set()
    print("Earley set " .. latest_earley_set)
    libmarpa_r:progress_report_start(latest_earley_set)
    while true do
        local rule_id, position, origin = libmarpa_r:progress_item()
        if not rule_id then break end
        print("@" .. origin .. '-' .. latest_earley_set ..
            "; " .. show_rule(klol_r.klol_g.rule_by_libmarpa_id[rule_id], position))
    end
    libmarpa_r:progress_report_finish()
end

local function result_for_events(lexer, last_events, last_events_cursor)
    print("Events!", #last_events)
    local result_table = { lexer.cursor, last_events_cursor }
    for event_ix = 0, #last_events-1, 2 do
        local base_index = event_ix*2 + 1
        local event_type = last_events[base_index]
        local event_value = last_events[base_index+1]
        if event_type ~= symbol_completed_event then
            error("Unknown event #" .. event_type)
        end
        do
            local lex_g = lexer.klol_g
            print("Symbol completed event, symbol = "
                .. lex_g.symbol_by_libmarpa_id[event_value].name)
        end
        result_table[#result_table + 1] = event_value
    end
    lexer.cursor = last_events_cursor + 1
    return result_table
end

local function recce_new(klol_g)
    local klol_r = { klol_g = klol_g }
    klol_r.libmarpa_r = kollos.wrap.recce(klol_g.libmarpa_g)
    return klol_r
end

local function default_lexer_token_next(lexer)
    local lex_g = lexer.klol_g
    local klol_r = recce_new(lex_g)
    local last_events
    local last_events_cursor
    klol_r.libmarpa_r:start_input()
    -- klol_progress_report(r)
    for _,lexeme_prefix in ipairs(lex_g.lexeme_prefixes) do
        -- print(lexeme_prefix.name, lexeme_prefix.libmarpa_id)
        local result = klol_r.libmarpa_r:alternative(lexeme_prefix.libmarpa_id) -- luacheck: ignore result
    end
    result = klol_r.libmarpa_r:earleme_complete() -- luacheck: ignore result
    klol_progress_report(klol_r)
    -- for id,props in ipairs(lex_g.symbol_by_libmarpa_id) do
        -- print("Completion event? ", id, props.name, lex_g.libmarpa_g:symbol_is_completion_event(id))
    -- end

    local input_string = lexer.input_string
    for cursor = lexer.cursor,#input_string do
        local byte = input_string:byte(cursor)
        local tokens = lex_g.tokens_by_char[byte]
        if #tokens <= 0 then
            local char_desc = {'Character',
                describe_character(byte),
                string.format("0x%.2X", byte),
                'is in the input, but can never be produced by the grammar'
            }
            error(table.concat(char_desc, ' '))
        end
        local tokens_accepted = 0
        for token_ix = 1,#tokens do
            if klol_r.libmarpa_r:alternative(tokens[token_ix]) then
                tokens_accepted = tokens_accepted + 1
            else
                print("Character not accepted", describe_character(byte))
            end
        end
        if tokens_accepted <= 0 then
            if not last_events then
                print("Rejection at cursor", cursor)
                return
            end
            return result_for_events(lexer, last_events, last_events_cursor)
            -- NOT REACHED --
        end
        local event_count = klol_r.libmarpa_r:earleme_complete() -- luacheck: ignore result
        if event_count > 0 then
            last_events = lex_g.libmarpa_g:events()
            last_events_cursor = cursor
        end
        -- klol_progress_report(r)
        if klol_r.libmarpa_r:is_exhausted() == 1 then
            if not last_events then
                print("Exhaustion at cursor", cursor)
                return
            end
            return result_for_events(lexer, last_events, last_events_cursor)
            -- NOT REACHED --
        end
    end
    if not last_events then
        print("EOS at cursor", #input_string)
        return
    end
    return result_for_events(lexer, last_events, last_events_cursor)
end

local default_lexer_mt = {
    __index = {
        token_next = default_lexer_token_next,
    }
}

local function default_lexer_new(lex_g, input)
    local input_string,start_cursor = input:fixed_string()
    local lexer= { input_object = input,
        input_string = input_string,
        cursor = start_cursor,
        libmarpa_g = lex_g.libmarpa_g,
        klol_g = lex_g
    }
    setmetatable(lexer, default_lexer_mt)
    return lexer
end

local reader = kollos.location.new_from_string(json_example)
local lexer = default_lexer_new(json_lex_g, reader)
while true do
   local token_data = lexer:token_next()
   if not token_data then break end
   print(inspect(token_data))
end

-- vim: expandtab shiftwidth=4:
