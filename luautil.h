/*
 *
 * Copyright (C) 2010-2012 <reyalp (at) gmail dot com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
/*
misc helper functions to simplify lua API code
*/
void *lu_table_checkudata(lua_State *L, int narg, const char *fname, const char *tname);

void *lu_table_optudata(lua_State *L, int narg, const char *fname, const char *tname, void *d);
lua_Number lu_table_checknumber(lua_State *L, int narg, const char *fname);
lua_Number lu_table_optnumber(lua_State *L, int narg, const char *fname, lua_Number d);
int lu_table_checkoption(lua_State *L, int narg, const char *fname, const char *def, const char *lst[]);
const char *lu_table_checkstring(lua_State *L, int narg, const char *fname);
const char *lu_table_optlstring(lua_State *L, int narg, const char *fname, const char *d, size_t *l);
void lu_pusharray_raw_u32(lua_State *L, int count, uint32_t *values);
void lu_pusharray_raw_u16(lua_State *L, int count, uint16_t *values);
//void lu_rawsetfield(lua_State *L, int index, const char *key);

// optional number, cast to int rather than erroring if number is non-integer
#define lu_optnumber_as_int(L, narg, d) (int)luaL_optnumber(L, narg, (lua_Number)(d))

#if LUA_VERSION_NUM >= 503
LUALIB_API void (luaL_register) (lua_State *L, const char *libname, const luaL_Reg *l);
#define luaL_optint(L, narg, d) (int)luaL_optinteger(L, narg, (lua_Integer)(d))
#endif
