/*
 *
 * Copyright (C) 2010-2019 <reyalp (at) gmail dot com>
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
#include <stdint.h>
#include <lua.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "luautil.h"
/*
functions to get fields from a table at a specified stack index, similar to luaL_check* and luaL_opt*
throw error on incorrect type, return C value and pop off the stack
*/
void *lu_table_checkudata(lua_State *L, int narg, const char *fname, const char *tname) {
	lua_getfield(L, narg, fname);
	void *r = luaL_checkudata(L,-1,tname);
	lua_pop(L,1);
	return r;
}

void *lu_table_optudata(lua_State *L, int narg, const char *fname, const char *tname, void *d) {
	void *r;
	lua_getfield(L, narg, fname);
	if(lua_isnil(L,-1)) {
		r=d;
	}
	else {
		r = luaL_checkudata(L,-1,tname);
	}
	lua_pop(L,1);
	return r;
}


lua_Number lu_table_checknumber(lua_State *L, int narg, const char *fname) {
	lua_getfield(L, narg, fname);
	lua_Number r = luaL_checknumber(L,-1);
	lua_pop(L,1);
	return r;
}

lua_Number lu_table_optnumber(lua_State *L, int narg, const char *fname, lua_Number d) {
	lua_getfield(L, narg, fname);
	lua_Number r = luaL_optnumber(L,-1,d);
	lua_pop(L,1);
	return r;
}

const char *lu_table_checkstring(lua_State *L, int narg, const char *fname) {
	lua_getfield(L, narg, fname);
	const char *r = luaL_checkstring(L,-1);
	lua_pop(L,1);
	return r;
}

int lu_table_checkoption(lua_State *L, int narg, const char *fname, const char *def, const char *lst[]) {
	lua_getfield(L, narg, fname);
	int r = luaL_checkoption(L,-1, def, lst);
	lua_pop(L,1);
	return r;
}

const char *lu_table_optlstring(lua_State *L, int narg, const char *fname, const char *d, size_t *l) {
	lua_getfield(L, narg, fname);
	const char *r = luaL_optlstring(L,-1,d,l);
	lua_pop(L,1);
	return r;
}

void lu_pusharray_raw_u32(lua_State *L, int count, uint32_t *values) {
	lua_createtable(L,count,0);
	int i;
	for(i=0;i<count;i++) {
// may be out of range if LUA_INTEGER is 32 bits
#if (LUA_MAXINTEGER > UINT32_MAX)
		lua_pushinteger(L,values[i]);
#else
		lua_pushnumber(L,values[i]);
#endif
		lua_rawseti(L,-2,i+1);
	}
}
void lu_pusharray_raw_u16(lua_State *L, int count, uint16_t *values) {
	lua_createtable(L,count,0);
	int i;
	for(i=0;i<count;i++) {
		lua_pushinteger(L,values[i]);
		lua_rawseti(L,-2,i+1);
	}
}

/*
like lua_setfield but raw
*/
/*
void lu_rawsetfield(lua_State *L, int index, const char *k) {
	// going to push another value
	// psuedoindexes start below -LUAI_MAXSTACK
	if(index < 0 && index > -LUAI_MAXSTACK)
		index--;
	lua_pushstring(L,k);
	// move key above value for rawset
	lua_insert(L,-2);
	lua_rawset(L,index);
}
*/

#if LUA_VERSION_NUM >= 503
#include <string.h>

static const char *luaL_findtable (lua_State *L, int idx, const char *fname, int szhint) {
  const char *e;
  if (idx) lua_pushvalue(L, idx);
  do {
    e = strchr(fname, '.');
    if (e == NULL) e = fname + strlen(fname);
    lua_pushlstring(L, fname, e - fname);
    lua_rawget(L, -2);
    if (lua_isnil(L, -1)) {  /* no such field? */
      lua_pop(L, 1);  /* remove this nil */
      lua_createtable(L, 0, (*e == '.' ? 1 : szhint)); /* new table for field */
      lua_pushlstring(L, fname, e - fname);
      lua_pushvalue(L, -2);
      lua_settable(L, -4);  /* set new table into field */
    }
    else if (!lua_istable(L, -1)) {  /* field has a non-table value? */
      lua_pop(L, 2);  /* remove table and value */
      return fname;  /* return problematic part of the name */
    }
    lua_remove(L, -2);  /* remove previous table */
    fname = e + 1;
  } while (*e == '.');
  return NULL;
}


/*
** Count number of elements in a luaL_Reg list.
*/
static int libsize (const luaL_Reg *l) {
  int size = 0;
  for (; l && l->name; l++) size++;
  return size;
}

LUALIB_API void luaL_pushmodule (lua_State *L, const char *modname, int sizehint) {
  luaL_findtable(L, LUA_REGISTRYINDEX, "_LOADED", 1);  /* get _LOADED table */
  lua_getfield(L, -1, modname);  /* get _LOADED[modname] */
  if (!lua_istable(L, -1)) {  /* not found? */
    lua_pop(L, 1);  /* remove previous result */
    /* try global variable (and create one if it does not exist) */
    lua_pushglobaltable(L);
    if (luaL_findtable(L, 0, modname, sizehint) != NULL)
      luaL_error(L, "name conflict for module " LUA_QS, modname);
    lua_pushvalue(L, -1);
    lua_setfield(L, -3, modname);  /* _LOADED[modname] = new table */
  }
  lua_remove(L, -2);  /* remove _LOADED table */
}

LUALIB_API void luaL_register (lua_State *L, const char *libname, const luaL_Reg *l) {
  luaL_checkversion(L);
  if (libname) {
    luaL_pushmodule(L, libname, libsize(l));  /* get/create library table */
    lua_insert(L, -1);  /* move library table to below upvalues */
  }
  if (l)
    luaL_setfuncs(L, l, 0);
  else
    lua_pop(L, 0);  /* remove upvalues */
}
#endif
