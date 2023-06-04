--[[
 Copyright (C) 2010-2021 <reyalp (at) gmail dot com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  with chdkptp. If not, see <http://www.gnu.org/licenses/>.
--]]
--[[
utilities for working with lbuf objects
]]
local lbu={}
--[[
lb=lbu.loadfile("name", [offset [,len] ])
load a file or part of file into an lbuf
returns lbuf or false,error
]]
function lbu.loadfile(name,offset,len)
	if not offset then
		offset=0
	end
	local f,err=io.open(name,'rb')
	if not f then
		return false, err
	end
	local flen = f:seek('end')
	if offset >= flen then
		f:close()
		return false,'offset >= file size'
	end
	if len then
		if offset + len > flen then
			f:close()
			return false,'offset + len > file size'
		end
	else
		len = flen - offset
	end
	local lb
	f:seek('set',offset)
	lb,err=lbuf.new(len)
	if not lb then
		f:close()
		return false, err
	end
	lb:fread(f,0,len)
	f:close()
	return lb
end

--[[
combine string keys of desc and containing field
]]
local function desc_get_attrs(desc,container_info)
	local attrs = {}
	if container_info then
		util.extend_table(attrs,container_info.field,{iter=util.pairs_string_keys})
	end
	return util.extend_table(attrs,desc,{iter=util.pairs_string_keys})
end

local function desc_get_container_attrs(container_info)
	if container_info and container_info.rd then
		return util.extend_table({},container_info.rd.attrs)
	end
end

local function desc_process_primitive(lb,desc,state,container_info)
	local vtype=desc[1]
	local tname,nbits = vtype:match('^([iu])([%d]+)$')
	if not tname or not nbits then
		errlib.throw{etype='bad_arg',msg=('unexpected type %s'):format(tostring(vtype))}
	end
	nbits = tonumber(nbits)
	if not (nbits == 8 or nbits == 16 or nbits == 32) then
		errlib.throw{etype='bad_arg',msg=('unexpected size %s'):format(tostring(nbits))}
	end
	local v=lb['get_'..vtype](lb,state.offset)
	local size = nbits/8
	coroutine.yield({
		ftype=vtype,
		name=state.name,
 		-- copy, so user can modify without mucking up
		path=util.extend_table({},state.path),
		offset=state.offset,
		size=size,
		value=v,
		desc=desc,
		attrs=desc_get_attrs(desc,container_info),
		container_attrs=desc_get_container_attrs(container_info),
	})
	state.offset = state.offset + size
	return v
end

local function desc_composite_start(state,rdesc)
	rdesc.offset = state.offset
	rdesc.name = state.name
	-- copy, so user can modify without mucking up
	rdesc.path = util.extend_table({},state.path)
	rdesc.composite = 'start'
	coroutine.yield(rdesc)
	if state.name then
		table.insert(state.path,state.name)
	end
	return rdesc
end

local function desc_composite_end(state,rdesc)
	rdesc.size = state.offset - rdesc.offset
	rdesc.composite = 'end'
	if #state.path > 0 then
		table.remove(state.path)
		state.name = nil
	end
	coroutine.yield(rdesc)
end

local function offset_align(offset,align)
	local t = offset + align - 1
	return t - t%align
end

local function desc_handle_meta(state,desc)
	if desc._align then
		local n = tonumber(desc._align)
		if not n or n < 1 then
			errlib.throw{etype='bad_arg',msg=('_align invalid %s'):format(desc._align)}
		end
		state.offset = offset_align(state.offset,n)
	end
end

local function desc_process_r(lb,desc,state,container_info)
	-- simple type as plain string, normalize to single element table
	if type(desc) == 'string' then
		desc={desc}
	elseif type(desc) ~= 'table' then
		errlib.throw{etype='bad_arg',msg=('expected string or table, not %s'):format(type(desc))}
	elseif #desc < 1 then
		errlib.throw{etype='bad_arg',msg='expected at least 1 field in field_desc'}
	end
	desc_handle_meta(state,desc)
	if #desc == 1 and type(desc[1]) == 'string' then
		desc_process_primitive(lb,desc,state,container_info)
	-- array: type, count
	elseif type(desc[2]) == 'number' then
		if #desc ~= 2 then
			errlib.throw{etype='bad_arg',msg='expected exactly 2 fields in array field_desc'}
		end
		local ftype = desc[1]
		local count = desc[2]
		local rd=desc_composite_start(state,{
			ftype='array',
			count=count,
			desc=desc,
			attrs=desc_get_attrs(desc,container_info),
			container_attrs=desc_get_attrs(container_info),
		})
		-- TODO for primitive types, could directly use get_* with count
		for i=1,count do
			state.name = i
			desc_process_r(lb,ftype,state,{composite=rd})
		end
		desc_composite_end(state,rd)
	-- struct: array of {'name',type}
	elseif type(desc[1]) == 'table' then
		local rd=desc_composite_start(state,{
			ftype='struct',
			desc=desc,
			attrs=desc_get_attrs(desc,container_info),
			container_attrs=desc_get_attrs(container_info),
		})
		for i,field in ipairs(desc) do
			if #field ~= 2 then
				errlib.throw{etype='bad_arg',msg='expected exactly 2 fields in struct_member'}
			end
			desc_handle_meta(state,field)
			state.name = field[1]
			desc_process_r(lb,field[2],state,{field=field,composite=rd})
		end
		desc_composite_end(state,rd)
	else
		errlib.throw{etype='bad_arg',msg='malformed field_desc'}
	end
end


--[[
iterate over lbuf yielding values defined by descriptor consisting of:
field_def:
	primitive | struct | array
primitive: primitive_string | {primitive_string}
	primitive_string: <'u' | 'i'><8 | 16 | 32>
struct: {
	struct_member,
	...
}
struct_member: {'name', field_def}

array: {
	field_def,count
}

_align=N on field_def or struct_member causes the field to start on the next multiple of N

other named fields can be added for iterator callers

yield value: {
	ftype: string -- primitive name, 'array' or 'struct'
	name: string|number|nil -- struct field name or 1 based array index. nil for top level
	path: table -- array of preceding field names, NOT including current. Empty at top and first level
	offset: number -- starting offset of current field
	value: number -- value if primitive, nil for composite
	composite: string|nil -- 'start' or 'end' for array / struct start or end, nil for primitive
	size: number|nil -- byte size, for primitive or composite end. nil on composite start
	count: number|nil -- array count if array, otherwise nil
	desc: descriptor for this field
	attrs: string key elements of desc and any containing struct_member
	container_attrs: attrs of any containing struct or array
}
]]
function lbu.idesc(lb,desc,opts)
	local state = util.extend_table({
		offset = 0,
	},opts)
	state.path = {}
	state.name = nil
	return coroutine.wrap(function()
		desc_process_r(lb,desc,state)
	end)
end

--[[
print contents of lb described by desc
]]
function lbu.desc_text(lb,desc,opts)
	opts = util.extend_table({
		printf=util.printf,
		fmt='0x%x',
		offsets=false,
		offset_fmt='%04x',
		array_base0=true,
		array_name_subscript=true,
	},opts)
	local start_offset
	for fd in lbu.idesc(lb,desc,util.extend_table({},opts)) do
		if not start_offset then
			start_offset = fd.offset
		end
		local name = fd.name or '(top)'
		local indent = (' '):rep(#fd.path)
		local tstr = fd.ftype
		local vstr = ''
		local fmt = fd.attrs.fmt or opts.fmt
		if type(name) == 'number' and opts.array_base0 then
			name = name - 1
		end
		if fd.composite == 'start' then
			if fd.ftype == 'array' then
				if type(fd.desc[1]) == 'string' then
					tstr = fd.desc[1] -- array of type
				elseif type(fd.desc[1]) == 'table' then
					if #fd.desc[1] == 2 and type(fd.desc[1][2]) == 'number' then
						tstr = 'array' -- array of array
					else
						tstr = 'struct' -- array of struct
					end
				end
				vstr = ('[%d]'):format(fd.count)
			end
		elseif fd.composite == 'end' then
			vstr = (' END size %d (0x%x)'):format(fd.size,fd.size)
		else
			vstr = ' = '..fmt:format(fd.value)
		end
		if opts.offsets then
			local o = fd.offset
			if opts.offsets == 'rel' then
				o = o - start_offset
			end
			-- 'offset' at struct array/end is same as start
			if fd.composite == 'end' then
				-- replace with spaces of same length as struct offset
				opts.printf('%s',(' '):rep(string.format(opts.offset_fmt,o):len()))
			else
				opts.printf(opts.offset_fmt,o)
			end
		end
		if type(name) == 'number' and opts.array_name_subscript then
			local s = ('[%d]'):format(name)
			for i=#fd.path,1,-1 do
				local n = fd.path[i]
				if type(n) == 'number' then
					if opts.array_base0 then
						n = n - 1
					end
					s = ('[%d]%s'):format(n,s)
				else
					s = n .. s
					break
				end
			end
			if fd.composite == 'start' and tstr ~= 'struct' then
				s = ('%-6s %s'):format(tstr,s)
			end
			opts.printf('%s %s%s\n',indent,s,vstr)
		else
			opts.printf('%s %-6s %s%s\n',indent,tstr,name,vstr)
		end
	end
end

--[[
extract contents of lb described by desc to lua values
]]
function lbu.desc_extract(lb,desc,opts)
	local r
	for fd in lbu.idesc(lb,desc,opts) do
		local t
		-- printf("%s.%s\n",table.concat(fd.path,'.'),tostring(fd.name))
		if not fd.composite then
			if not r then
				return fd.value
			end
			if #fd.path > 0 then
				t = util.table_pathtable_get(r,fd.path)
			else
				t = r
			end
			t[fd.name] = fd.value
		elseif fd.composite == 'start' then
			if not r then
				r={}
			else
				if #fd.path > 0 then
					t = util.table_pathtable_get(r,fd.path)
				else
					t = r
				end
				t[fd.name] = {}
			end
		end
	end
	return r
end


-- methods that don't need upvalues
local lbu_methods = {}

function lbu_methods:_check_bind_name(name)
	-- don't allow replacing methods / field
	if rawget(self,name) ~= nil then
		errlib.throw{etype='bad_arg', msg=('attempt to bind field or method name "%s"'):format(tostring(name)),level=3}
	end
end

function lbu_methods:hexdump(off,len)
	if not off then
		off = 0
	end
	if not len then
		len = self._lb:len()
	end
	local s=self._lb:string(off+1,off+len) -- string uses 1 based offset
	return util.hexdump(s)
end
function lbu_methods:bind(name,get,set,len,off)
	if type(off) == 'nil' then
		off=self._bindpos
	end
	if off < 0 or off + len > self._lb:len() then
		errlib.throw{etype='bad_arg', msg=('illegal offset %d'):format(off)}
	end
	self:_check_bind_name(name)
	self._fields[name]={
		get=get,
		set=set,
		offset=off,
		len=len,
	}
	self._bindpos = off+len
end

-- fixed length string field, with anything past the first \0 ignored
function lbu_methods:bind_sz(name,len,off)
	self:bind(name,
		function(fld)
			local str=self._lb:string(fld.offset+1,fld.offset+fld.len)
			local s,e,v = string.find(str,'^([^%z]*)')
			return v
		end,
		nil,
		len,
		off)
end

--[[
bind an array field of lbuf supported data type, specified by signed and el_bytes
returns table with appopriate metamethod
the bound field itself may not be set
bound values can be set if rw is true
array behaves as normal lua arra, 1 based, provides # metamethod
TODO may want a zero based variant
]]
function lbu_methods:bind_array(name,signed,rw,el_bytes,count,off)
	if type(off) == 'nil' then
		off=self._bindpos
	end
	if not util.array_find({1,2,4},el_bytes) then
		errlib.throw{etype='bad_arg',msg=('invalid element size %d'):format(el_bytes)}
	end
	if count < 0 then
		errlib.throw{etype='bad_arg',msg=('invalid count %d'):format(count)}
	end
	local total_size = el_bytes*count
	if off + total_size > self._lb:len() then
		errlib.throw{etype='bad_arg',msg=('bind overflow %d + %d > %d'):format(off,total_size,self._lb:len())}
	end
	local bits = el_bytes*8
	if signed then
		spfx = 'i'
	else
		spfx = 'u'
	end
	local el_get = self._lb[('get_%s%d'):format(spfx,bits)]
	local el_set = self._lb[('set_%s%d'):format(spfx,bits)]

	local av ={ }
	local mt = {
		__index = function(t, i)
			if i > 0 and i <= count then
				return el_get(self._lb,off + (i-1)*el_bytes)
			end
		end,
		__newindex = function(t, i, v)
			if not rw then
				errlib.throw{etype='readonly', msg=('attempt to set element of read-only array "%s"'):format(name),level=2}
			end
			if i > 0 and i <= count then
				el_set(self._lb,off + (i-1)*el_bytes,v)
			else
				errlib.throw{etype='bad_arg', msg=('array set out of range "%s" %d'):format(name,i),level=2}
			end
		end,
		__len = function()
			return count
		end,
	}
	setmetatable(av,mt)
	self:bind(name,function() return av end,nil,total_size,off)
end

-- return a getter for an integer value
local bind_int_get = function(t,vtype)
	local mname = 'get_'..vtype
	if type(lbuf[mname]) ~= 'function' then
		errlib.throw{etype='bad_arg', msg=('invalid lbuf method "%s"'):format(tostring(mname))}
	end
	return function(fld) return t._lb[mname](t._lb,fld.offset) end
end
local bind_int_set = function(t,vtype)
	local mname = 'set_'..vtype
	if type(lbuf[mname]) ~= 'function' then
		errlib.throw{etype='bad_arg', msg=('invalid lbuf method "%s"'):format(tostring(mname))}
	end
	return function(fld,val) return t._lb[mname](t._lb,fld.offset,val) end
end

local function init_int_methods()
	for j,size in ipairs({1,2,4}) do
		local bits=tostring(size*8)
		-- set up integer bind methods
		for i,vt in ipairs({'i'..bits,'u'..bits}) do
			local vtype = vt
			-- default read only
			lbu_methods['bind_'..vtype] = function(self,name,off)
					self:bind(name,
						bind_int_get(self,vtype),
						nil,
						size,
						off)
			end
			-- read/write
			lbu_methods['bind_rw_'..vtype] = function(self,name,off)
					self:bind(name,
						bind_int_get(self,vtype),
						bind_int_set(self,vtype),
						size,
						off)
			end
			lbu_methods['bind_array_'..vtype] = function(self,name,count,off)
				self:bind_array(name, vt:sub(1,1) == 'i', false, size, count, off)
			end
			lbu_methods['bind_array_rw_'..vtype] = function(self,name,count,off)
				self:bind_array(name, vt:sub(1,1) == 'i', true, size, count, off)
			end
		end
	end
end
init_int_methods()

--[[
set next bind pos, mimic lua seek
pos=lbu:bind_seek([whence][,offset])
default whence 'cur', offset is 0
]]
lbu_methods.bind_seek = function(self,whence,offset)
	-- if 2 args, 2nd is offset, whence is implicitly cur
	if type(offset) == 'nil' then
		-- only 'whence' given
		if type(whence) == 'string' then
			offset=0
		-- neither given
		elseif type(whence) == 'nil' then
			whence = 'cur'
			offset = 0
		elseif type(whence) == 'number' then -- only offset given
			offset = whence
			whence = 'cur'
		else
			errlib.throw{etype='bad_arg', msg='invalid argument'}
		end
	end
	local newpos
	if whence == 'set' then
		newpos = offset
	elseif whence == 'cur' then
		newpos = self._bindpos + offset
	elseif whence == 'end' then
		newpos = self._lb:len() + offset
	else
		errlib.throw{etype='bad_arg', msg=('invalid whence "%s"'):format(tostring(whence))}
	end
	-- seeking to the end is allowed, although binding will fail
	if newpos < 0 or newpos > self._lb:len() then
		errlib.throw{etype='bad_arg', msg=('invalid pos %d'):format(newpos)}
	end
	self._bindpos = newpos
	return self._bindpos
end
--]]

--[[
wrap an lbuf in an lbu object
]]
function lbu.wrap(lb)
	local mt = {
		__index=function(t,k)
			local fields = rawget(t,'_fields')
			if fields[k] then
				return fields[k]:get()
			end
		end,
		__newindex=function(t,k,v)
			local fields = rawget(t,'_fields')
			-- TODO not a field, just set it on the table (to allow adding custom methods etc)
			if not fields[k] then
				rawset(t,k,v)
				return
			end
			if not fields[k].set then
				errlib.throw{etype='readonly', msg=('attempt to set read-only field "%s"'):format(tostring(k)),level=2}
			end
			fields[k]:set(v)
		end,
	}
	local t={
		_lb = lb,
		_fields = {}, -- bound fields
		_bindpos = 0, -- default next bind offset
	}
	util.extend_table(t,lbu_methods)

	setmetatable(t,mt)
	return t
end
return lbu
