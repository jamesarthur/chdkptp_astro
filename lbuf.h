/*
 *
 * Copyright (C) 2010-2021 <reyalp (at) gmail dot com>
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
 *  with chdkptp. If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifndef LBUF_H
#define LBUF_H
#define LBUF_META "lbuf.lbuf_meta"
#define LBUF_METHODS "lbuf.lbuf_methods"
#define LBUF_FL_FREE 0x1
#define LBUF_FL_READONLY 0x2
typedef struct {
	unsigned len;
	unsigned flags;
	char *bytes;
} lBuf_t;
/*
create a new lbuf and push it on the stack
*/
int lbuf_create(lua_State *L,void *data,unsigned len,unsigned flags);

/*
check whether given stack index is an lbuf, and if so, return it
*/
lBuf_t* lbuf_getlbuf(lua_State *L,int i);

/*
For use with with things like video frames, where same sized data repeatedly used

check for lbuf at index
if present and size == len, push onto stack
otherwise, create a new lbuf of size
returns lbuf->bytes (typically what you want, actual lbuf can be retrieved from stack)
NOTE: lbufs with mismatched size are not re-allocated, will be gc'd in due course
*/
void *lbuf_reuse_or_create(lua_State *L, int index, unsigned len);

int luaopen_lbuf(lua_State *L);
#endif

