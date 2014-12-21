-- assumes that, when called, out_file to set to output file
local error_file

function c_safe_string (s)
    s = string.gsub(s, '"', '\\034')
    s = string.gsub(s, '\\', '\\092')
    return '"' .. s .. '"'
end

for k,v in ipairs(arg) do
   if not v:find("=")
   then return nil, "Bad options: ", arg end
   local id, val = v:match("^([^=]+)%=(.*)") -- no space around =
   if id == "out" then io.output(val)
   elseif id == "errors" then error_file = val
   else return nil, "Bad id in options: ", id end
end

-- initial piece
io.write[=[
/*
** Permission is hereby granted, free of charge, to any person obtaining
** a copy of this software and associated documentation files (the
** "Software"), to deal in the Software without restriction, including
** without limitation the rights to use, copy, modify, merge, publish,
** distribute, sublicense, and/or sell copies of the Software, and to
** permit persons to whom the Software is furnished to do so, subject to
** the following conditions:
**
** The above copyright notice and this permission notice shall be
** included in all copies or substantial portions of the Software.
**
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
** EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
** MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
** IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
** CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
** TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
** SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
**
** [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
*/

#define LUA_LIB
#include "marpa.h"
#include "lua.h"
#include "lauxlib.h"

#define EXPECTED_LIBMARPA_MAJOR 7
#define EXPECTED_LIBMARPA_MINOR 5
#define EXPECTED_LIBMARPA_MICRO 0

]=]

-- error codes

io.write[=[
struct s_libmarpa_error_code {
   int code;
   const char* mnemonic;
   const char* description;
};

]=]

do
    local f = assert(io.open(error_file, "r"))
    local code_lines = {}
    local code_mnemonics = {}
    local max_code = 0
    while true do
        local line = f:read()
        if line == nil then break end
        local i, j = string.find(line, "#")
        if (i == nil) then stripped = line
        else stripped = string.sub(line, 0, i-1)
        end
        if string.find(stripped, "%S") then
            local raw_code
            local raw_mnemonic
            local description
            _, _, raw_code, raw_mnemonic, description = string.find(stripped, "^(%d+)%sMARPA_ERR_(%S+)%s(.*)$")
            local code = tonumber(raw_code)
            if description == nil then return nil, "Bad line in error code file ", line end
            if code > max_code then max_code = code end
            local mnemonic = 'LUIF_ERR_' .. raw_mnemonic
            code_mnemonics[code] = mnemonic
            code_lines[code] = string.format( '   { %d, %s, %s },',
                code,
                c_safe_string(mnemonic),
                c_safe_string(description)
                )
        end
    end
    io.write('#define LIBMARPA_MAX_ERROR_CODE ' .. max_code .. '\n\n')
    for i = 0, max_code do
        local mnemonic = code_mnemonics[i]
        if mnemonic then
            io.write(
                   string.format('#define %s %d\n', mnemonic, i)
           )
       end
    end
    io.write('\n')
    io.write('struct s_libmarpa_error_code libmarpa_error_codes[LIBMARPA_MAX_ERROR_CODE+1] = {\n')
    for i = 0, max_code do
        local code_line = code_lines[i]
        if code_line then
           io.write(code_line .. '\n')
        else
           io.write(
               string.format(
                   '    { %d, "LUIF_ERROR_RESERVED", "Unknown Libmarpa error %d" },\n',
                   i, i
               )
           )
        end
    end
    io.write('};\n\n');
    f:close()
end

-- for Kollos's own (that is, non-Libmarpa) error codes
do
    local code_lines = {}
    local code_mnemonics = {}
    local min_code = 200
    local max_code = 200

    -- Should add some checks on the errors, checking for
    -- 1.) duplicate mnenomics
    -- 2.) duplicate error codes

    function luif_error_add (code, mnemonic, description)
        code_mnemonics[code] = mnemonic
        code_lines[code] = string.format( '   { %d, %s, %s },',
            code,
            c_safe_string(mnemonic),
            c_safe_string(description)
            )
        if code > max_code then max_code = code end
    end

    -- LUIF_ERR_RESERVED_200 is a place-holder , not expected to be actually used
    luif_error_add( 200, "LUIF_ERR_RESERVED_200", "Unexpected Kollos error: 200")
    luif_error_add( 201, "LUIF_ERR_LUA_VERSION", "Bad Lua version")
    luif_error_add( 202, "LUIF_ERR_LIBMARPA_HEADER_VERSION_MISMATCH", "Libmarpa header does not match expected version")
    luif_error_add( 203, "LUIF_ERR_LIBMARPA_LIBRARY_VERSION_MISMATCH", "Libmarpa library does not match expected version")

    io.write('#define LUIF_MIN_ERROR_CODE ' .. min_code .. '\n')
    io.write('#define LUIF_MAX_ERROR_CODE ' .. max_code .. '\n\n')
    for i = min_code, max_code
    do
        local mnemonic = code_mnemonics[i]
        if mnemonic then
            io.write(
                   string.format('#define %s %d\n', mnemonic, i)
           )
       end
    end

    io.write('\n')
    io.write('struct s_libmarpa_error_code kollos_error_codes[(LUIF_MAX_ERROR_CODE-LUIF_MIN_ERROR_CODE)+1] = {\n')
    for i = min_code, max_code do
        local code_line = code_lines[i]
        if code_line then
           io.write(code_line .. '\n')
        else
           io.write(
               string.format(
                   '    { %d, "LUIF_ERROR_RESERVED", "Unknown Kollos error %d" },\n',
                   i, i
               )
           )
        end
    end
    io.write('};\n\n');

end

-- functions
io.write[=[
#if 0

void
new( ... )
PPCODE:
{
  Marpa_Grammar g;
  G_Wrapper *g_wrapper;
  int throw = 1;
  Marpa_Config marpa_configuration;
  Marpa_Error_Code error_code;

      {
	I32 retlen;
	char *key;
	SV *arg_value;
	SV *arg = ST (1);
	HV *named_args;
	if (!SvROK (arg) || SvTYPE (SvRV (arg)) != SVt_PVHV)
	  croak ("Problem in $g->new(): argument is not hash ref");
	named_args = (HV *) SvRV (arg);
	hv_iterinit (named_args);
	while ((arg_value = hv_iternextsv (named_args, &key, &retlen)))
	  {
	    if ((*key == 'i') && strnEQ (key, "if", (unsigned) retlen))
	      {
		interface = SvIV (arg_value);
		if (interface != 1)
		  {
		    croak ("Problem in $g->new(): interface value must be 1");
		  }
		continue;
	      }
	    croak ("Problem in $g->new(): unknown named argument: %s", key);
	  }
	if (interface != 1)
	  {
	    croak
	      ("Problem in $g->new(): 'interface' named argument is required");
	  }
      }

  /* Make sure the header is from the version we want */
  if (MARPA_MAJOR_VERSION != EXPECTED_LIBMARPA_MAJOR
      || MARPA_MINOR_VERSION != EXPECTED_LIBMARPA_MINOR
      || MARPA_MICRO_VERSION != EXPECTED_LIBMARPA_MICRO)
    {
      croak
	("Problem in $g->new(): want Libmarpa %d.%d.%d, header was from Libmarpa %d.%d.%d",
	 EXPECTED_LIBMARPA_MAJOR, EXPECTED_LIBMARPA_MINOR,
	 EXPECTED_LIBMARPA_MICRO,
	 MARPA_MAJOR_VERSION, MARPA_MINOR_VERSION,
	 MARPA_MICRO_VERSION);
    }

  {
    /* Now make sure the library is from the version we want */
    int version[3];
    error_code = marpa_version (version);
    if (error_code != MARPA_ERR_NONE
	|| version[0] != EXPECTED_LIBMARPA_MAJOR
	|| version[1] != EXPECTED_LIBMARPA_MINOR
	|| version[2] != EXPECTED_LIBMARPA_MICRO)
      {
	croak
	  ("Problem in $g->new(): want Libmarpa %d.%d.%d, using Libmarpa %d.%d.%d",
	   EXPECTED_LIBMARPA_MAJOR, EXPECTED_LIBMARPA_MINOR,
	   EXPECTED_LIBMARPA_MICRO, version[0], version[1], version[2]);
      }
  }

  marpa_c_init (&marpa_configuration);
  g = marpa_g_new (&marpa_configuration);

  /* force valued !!!! */
  if (g)
    {
      SV *sv;
      Newx (g_wrapper, 1, G_Wrapper);
      g_wrapper->throw = throw;
      g_wrapper->g = g;
      g_wrapper->message_buffer = NULL;
      g_wrapper->libmarpa_error_code = MARPA_ERR_NONE;
      g_wrapper->libmarpa_error_string = NULL;
      g_wrapper->message_is_marpa_thin_error = 0;
      sv = sv_newmortal ();
      sv_setref_pv (sv, grammar_c_class_name, (void *) g_wrapper);
      XPUSHs (sv);
    }
  else
    {
      error_code = marpa_c_error (&marpa_configuration, NULL);
    }

  if (error_code != MARPA_ERR_NONE)
    {
      const char *error_description = "Error code out of bounds";
      if (error_code >= 0 && error_code < MARPA_ERROR_COUNT)
	{
	  error_description = marpa_error_description[error_code].name;
	}
      if (throw)
	croak ("Problem in Marpa::R2->new(): %s", error_description);
      if (GIMME != G_ARRAY)
	{
	  XSRETURN_UNDEF;
	}
      XPUSHs (&PL_sv_undef);
      XPUSHs (sv_2mortal (newSViv (error_code)));
    }
}

#endif

]=]

io.write[=[

static void luif_err_throw(lua_State *L, int error_code) {

#if 0
    const char *where;
    luaL_where(L, 1);
    where = lua_tostring(L, -1);
#endif

    if (error_code < 0 || error_code > LIBMARPA_MAX_ERROR_CODE) {
        luaL_error(L, "Libmarpa returned invalid error code %d", error_code);
    }
    luaL_error(L, "%s", libmarpa_error_codes[error_code].description );
}

static void luif_err_throw2(lua_State *L, int error_code, const char *msg) {

#if 0
    const char *where;
    luaL_where(L, 1);
    where = lua_tostring(L, -1);
#endif

    if (error_code < 0 || error_code > LIBMARPA_MAX_ERROR_CODE) {
        luaL_error(L, "%s\n    Libmarpa returned invalid error code %d", msg, error_code);
    }
    luaL_error(L, "%s\n    %s", msg, libmarpa_error_codes[error_code].description);
}

struct s_kollos_grammar {
    int dummy;
};

static int grammar_new(lua_State *L)
{
   struct s_kollos_grammar *g;
   luaL_checkany(L, 1); /* expecting a table */

   {
       const char * const header_mismatch =
           "Header version does not match expected version";
       /* Make sure the header is from the version we want */
       if (MARPA_MAJOR_VERSION != EXPECTED_LIBMARPA_MAJOR)
           luif_err_throw2(L, LUIF_ERR_MAJOR_VERSION_MISMATCH, header_mismatch);
       if (MARPA_MINOR_VERSION != EXPECTED_LIBMARPA_MINOR)
           luif_err_throw2(L, LUIF_ERR_MINOR_VERSION_MISMATCH, header_mismatch);
       if (MARPA_MICRO_VERSION != EXPECTED_LIBMARPA_MICRO)
          luif_err_throw2(L, LUIF_ERR_MICRO_VERSION_MISMATCH, header_mismatch);
  }

  {
      /* Now make sure the library is from the version we want */
      const char * const library_mismatch =
          "Library version does not match expected version";
      int version[3];
      const Marpa_Error_Code error_code = marpa_version (version);
      if (error_code != MARPA_ERR_NONE) luif_err_throw2(L, error_code, "marpa_version() failed");
      if (version[0] != EXPECTED_LIBMARPA_MAJOR)
          luif_err_throw2(L, LUIF_ERR_MAJOR_VERSION_MISMATCH, library_mismatch);
      if (version[1] != EXPECTED_LIBMARPA_MINOR)
          luif_err_throw2(L, LUIF_ERR_MINOR_VERSION_MISMATCH, library_mismatch);
      if (version[2] != EXPECTED_LIBMARPA_MICRO)
          luif_err_throw2(L, LUIF_ERR_MICRO_VERSION_MISMATCH, library_mismatch);
  }

   luif_err_throw(L, LUIF_ERR_I_AM_NOT_OK);
   g = (struct s_kollos_grammar *)lua_newuserdata(L, sizeof(*g));
   return 1;
}

static const struct luaL_Reg kollos_core_funcs[] = {
  { "grammar", grammar_new },
  { NULL, NULL }
};

static const struct luaL_Reg kollos_core_methods[] = {
  { NULL, NULL }
};

LUALIB_API int luaopen_kollos_core(lua_State *L);
LUALIB_API int luaopen_kollos_core(lua_State *L)
{
  /* Fail if not 5.1 ? */
  luaL_newmetatable(L, "kollos-core-grammar");
  lua_pushvalue(L, -1);
  luaL_register(L, NULL, kollos_core_methods);
  luaL_register(L, "kollos", kollos_core_funcs);
  return 1;
}

/* vim: expandtab shiftwidth=4:
 */
]=]
