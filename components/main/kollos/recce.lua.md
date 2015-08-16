<!--

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

-->

# Kollos "mid-level" recognizer code

This is the code for the "middle layer" recognizer
of Kollos.
Below it is Libmarpa, a library written in
the C language which contains the actual parse engine.

## Constructor

    -- luatangle: section Constructor

    local function recce_new(grammar)
        local recce = {
             down_history = {},
             grammar = grammar,
             throw = grammar.throw,
             down_pos = 0
        }
        local r = wrap.recce(grammar.libmarpa_g)
        recce.libmarpa_r = r
        setmetatable(recce, {
                __index = recce_class,
            })
        return recce
    end

## Declare the recce class

    -- luatangle: section Declare recce_class
    local recce_class = {}

## The start() method

    -- luatangle: section start() recce method

    function recce_class.start(recce)
        local r = recce.libmarpa_r
        return r:start_input()
    end

## The "down history"

This is the history of the downward position.
It is an array of entries.
Each entry is a duple `<dpos1, lexer>`,
where `dpos1` is the first down position to be used
for `lexer`.

Since the down positions are an integer sequence without
gaps, the `dpos1` duple elements of the next down-history
entry is one after the last down position of the current one.
For the last down-history entry, the last down position
is the current value of `down_pos` for the recce.

Down-history entries are added prospectively,
so that the most recent may never have been used.
This is the case if and only if
`down_pos < down_history[#down_history][1]`.

If a new down history entry is to be added
to a down history whose most recent entry is
unused,
the unused (most recent) entry must be deleted
first.

## The lexer_set() method

    -- luatangle: section lexer_set() recce method

    function recce_class.lexer_set(recce, lexer)
        recce.lexer = lexer
        local down_history = recce.down_history

        -- Set the down history index for a new
        -- entry.
        local down_history_ix = #down_history

        -- The entry must be incremented, unless the most
        -- recent entry has never been used -- in that case,
        -- the most recent entry is replaced
        if down_history_ix > 0 and
                recce.down_pos >= down_history[down_history_ix][1] then
             down_history_ix = down_history_ix + 1
        end

        -- This lexer's positions will
        -- start *after* down_pos is incremented.
        down_history[down_history_ix] = { recce.down_pos + 1, lexer }
    end

## The current_pos() method

Return the current down position.
Among other uses,
it allows the lexer's access to this datum.

    -- luatangle: section current_pos() recce method

    function recce_class.current_pos(lexer)
        return recce.down_pos
    end

## The read() method

Requires a lexer to be set.
Reads for as long as it returns symbols
or, in other words,
until an event occurs.

    -- luatangle: section read() recce method

    function recce_class.read(recce)
        local lexer = recce.lexer
        if not lexer then
            return nil, lexer:development_error(
                "recce:read(): No lexer\n"
                .. "  Lexer must be set before calling read() method\n"
                )
        end
        while true do
            local symbols, error_object = lexer.next_lexeme()
            if symbols == nil then return nil, error_object end
            if #symbols < 1 then return recce.down_pos end
            -- Note: recce current pos is set only *after success*
            -- of next() method call
            recce.down_pos = recce.down_pos + 1
            -- luatangle: insert print results
        end
    end

    -- luatangle: section print results
    -- TODO to be deleted after development

    for _,symbol in ipairs(symbols) do
         print("@" .. recce.down_pos,  symbol, lexer.value(recce.down_pos))
    end

## Finish and return the recce static class

    -- luatangle: section Finish return object

    local recce_static_class = {
        new = recce_new
    }
    return recce_static_class

## Development errors

    -- luatangle: section Development error methods

    local function development_error_stringize(error_object)
        return
        "recce error at line "
        .. error_object.line
        .. " of "
        .. error_object.file
        .. ":\n "
        .. error_object.string
    end

    local function development_error(recce, string)
        local blob = 'No blob'
        if recce.lexer then
             blob = recce.lexer.blob()
        end
        local error_object
        = kollos_c.error_new{
            stringize = development_error_stringize,
            code = luif_err_development,
            file = blob,
            line = debug.getinfo(2, 'l').currentline,
            string = string
        }
        if recce.throw then error(tostring(error_object)) end
        return error_object
    end

## Output file

    -- luatangle: section main

    -- luacheck: std lua51
    -- luacheck: globals bit
    -- luacheck: globals __FILE__ __LINE__

    local wrap = require "kollos.wrap"
    local a8lex = require "kollos.a8lex"

    -- luatangle: insert Declare recce_class
    -- luatangle: insert Development error methods
    -- luatangle: insert Constructor
    -- luatangle: insert start() recce method
    -- luatangle: insert lexer_set() recce method
    -- luatangle: insert current_pos() recce method
    -- luatangle: insert read() recce method
    -- luatangle: insert Finish return object
    -- luatangle: write stdout main

<!--
vim: expandtab shiftwidth=4:
-->
