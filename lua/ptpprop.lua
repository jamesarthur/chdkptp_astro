--[[
 Copyright (C) 2022 <reyalp (at) gmail dot com>
  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  with chdkptp. If not, see <http://www.gnu.org/licenses/>.
]]
--[[
module providing wrapper for PTP device properties
]]
local lbu=require'lbufutil'
local m = {
	-- map prop "simple values" to types
	vtypes = {
		[0] = {
			name='(Undefined)',
			size=0,
			undef=true,
		},
		{
			name='i8',
			size=1,
			signed=true,
		},
		{
			name='u8',
			size=1,
		},
		{
			name='i16',
			size=2,
			signed=true,
		},
		{
			name='u16',
			size=2,
		},
		{
			name='i32',
			size=4,
			signed=true,
		},
		{
			name='u32',
			size=4,
		},
		{
			name='i64',
			size=8,
			signed=true,
		},
		{
			name='u64',
			size=8,
		},
		{
			name='i128',
			size=16,
			signed=true,
		},
		{
			name='u128',
			size=16,
		},
	},
	forms = {
		[0]={
			name='simple',
		},
		{
			name='range',
		},
		{
			name='enum',
		},
	},
}

local prop_methods = {}

function prop_methods:bind_string(name)
	-- strings are 16 bit unicode, NULL terminated
	local chars = {}
	local vals = {}
	self:bind_u8(name..'_len')
	local lval=self[name..'_len']
	local l=0
	local start = self:bind_seek()
	local off = start
	while off < self._lb:len() do
		local v = self._lb:get_u16(off)
		if v == 0 then
			if l + 1 ~= lval then
				util.warnf("length field %d != null pos %d\n",lval,l)
			end
			off = off + 2 -- include null
			local s=table.concat(chars)
			self:bind(name,function() return s end,nil,off - start,start)
			self:bind_seek('set',start)
			self:bind(name..'_vals',function() return vals end,nil,off - start,start)
			return
		else
			-- HACK for string value, just pretend it's ASCII in the lower byte
			table.insert(chars,string.char(self._lb:get_u8(off)))
			table.insert(vals, v)
		end
		l = l + 1
		off = off+2
	end
	util.warnf('string %s not null terminated\n',name)
end
function prop_methods:bind_prop_value(name)
	local start = self:bind_seek()
	if self._dt.string then
		self:bind_string(name)
	else
		if self._dt.size <= 4 then
			if self._dt.array then
				local n=self._lb:get_u32(start)
				start = self:bind_seek(4)
				self['bind_array_'..self._dt.name](self,name,n)
			else
				self['bind_'..self._dt.name](self,name)
			end
		else
			util.warnf('%s > 32 bits, binding array\n',name)
			if self._dt.array then
				local n=self._lb:get_u32(start)
				start = self:bind_seek(4)
				self:bind_array_u8(name,n*self._dt.size)
			else
				self:bind_array_u8(name,self._dt.size)
			end
		end
	end
	self:bind(name..'_hex',function() return self:hexdump(start, self:bind_seek()-start) end,nil,self:bind_seek() - start,start)
end

function prop_methods:fmt_val(val)
	if self._dt.array or type(val) == 'table' then
		local r={}
		for i, v in ipairs(val) do
			table.insert(r,('%3d: 0x%x %d'):format(i,v,v))
		end
		return table.concat(r,'\n')
	elseif self._dt.string then
		return ('%s'):format(val)
	else
		return ('0x%x %d'):format(val,val)
	end
end

function prop_methods:print_val(name)
	printf("%s: ",name)
	if self._dt.array or type(self[name]) == 'table' then
		printf('\n')
	end
	printf('%s\n',self:fmt_val(self[name]))
end

function prop_methods:describe(ptp_code_ids)
	ptp_code_ids = ptp_code_ids or {'STD'}
	printf("DPC: %s\n",ptp.get_code_desc('DPC',self.DPC,ptp_code_ids))
	printf("datatype: 0x%04x",self.datatype)
	if self._dt.array then
		printf(" array")
	end
	printf(" %s\n",self._dt.name)
	printf("RW: %d\n",self.RW)
	if self._dt.undef then
		printf('binding incomplete, hexdump:\n')
		printf('%s\n',self:hexdump())
		return
	end
	self:print_val('factory')
	self:print_val('current')
	local formdesc
	if m.forms[self.form] then
		formdesc = m.forms[self.form].name
	else
		formdesc = '(unknown)'
	end
	printf('form: %d %s\n',self.form, formdesc)
	if self.form == 1 then
		self:print_val('range_min')
		self:print_val('range_max')
		self:print_val('range_step')
	elseif self.form == 2 then
		if self._dt.array then
			for i=1,self.enum_items do
				self:print_val(('enum%d'):format(i))
			end
		else
			printf('enum_vals:\n')
			for i,v in ipairs(self.enum_vals) do
				printf('0x%x %d\n',v,v)
			end
		end
	end
end

function m.bind(lb)
	local data=lbu.wrap(lb)
	util.extend_table(data,prop_methods)
	data:bind_u16('DPC')
	data:bind_u16('datatype')
	local dt = m.vtypes[data.datatype]
	-- simple value
	if dt then
		data._dt = util.extend_table({},dt)
	else
		dt = m.vtypes[data.datatype-0x4000]
		if dt then
			data._dt = util.extend_table({array=true},dt)
		elseif data.datatype == 0xffff then
			data._dt = { name='string', string=true }
		else
			data._dt = util.extend_table({},m.vtypes[0])
		end
	end
	data:bind_u8('RW')
	-- cant bind remaining items without size
	if data._dt.undef then
		util.warnf('datatype undefined 0x%04x\n',data.datatype)
		return data
	end
	data:bind_prop_value('factory')
	data:bind_prop_value('current')
	data:bind_u8('form')
	if data.form == 1 then -- range
		data:bind_prop_value('range_min')
		data:bind_prop_value('range_max')
		data:bind_prop_value('range_step')
	elseif data.form == 2 then -- enum
		data:bind_u16('enum_items')
		-- MTP spec not clear if arrays are allowed for range/enum
		if data._dt.array then
			-- don't support nested arrays
			for i=1,data.enum_items do
				data:bind_prop_value('enum'..i)
			end
		else
			data['bind_array_'..data._dt.name](data,'enum_vals',data.enum_items)
		end
	elseif data.form ~= 0  then
		util.warnf('unknown form %d\n',data.form)
	end
	return data
end
return m
