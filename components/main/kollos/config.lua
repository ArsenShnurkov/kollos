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

-- Kollos top-level config objects

-- luacheck: std lua51
-- luacheck: globals bit

local function here() return -- luacheck: ignore here
    debug.getinfo(2,'S').source .. debug.getinfo(2, 'l').currentline
end

local inspect = require "kollos.inspect" -- luacheck: ignore
local grammar = require "kollos.grammar"
local kollos_c = require "kollos_c"
local error_throw = kollos_c.error_throw

local config_class = {
    grammar_new = grammar._config_grammar_new
}

local function config_new(kollos, args)
    local config_object = { _type = "config" }
    -- 'alpha' means anything is OK
    -- it is the only acceptable if, at this point
    if type(args) ~= 'table' then
        -- error_throw(MARPA_ERR_DEVELOPMENT, [[argument of config_new() must be a table of named arguments]])
        error_throw(9, [[argument of config_new() must be a table of named arguments]])
    end

    local throw = args.throw or true
    -- config_object.throw = throw
    -- 'if' is also a keyword, so it must be used in quoted form
    if type(args['if']) ~= 'string' then
        if throw then
            error_throw(MARPA_ERR_DEVELOPMENT, [["if" named argument is required and must be string]])
        end
        return
    end
    if args['if'] ~= 'alpha' then
        if throw then
            error_throw(MARPA_ERR_DEVELOPMENT, [["if = 'alpha'" is required]])
        end
        return
    end
    setmetatable(config_object, {
            __index = config_class,
        })
    return config_object
end

return {
    new = config_new,
}

-- vim: expandtab shiftwidth=4:
