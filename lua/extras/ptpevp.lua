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

!!!! OBSOLETE, use chdku con: methods !!!!

TEMP scratchpad for Canon PTP eventproc API, based on
https://chdk.setepontos.com/index.php?topic=4338.msg147738#msg147738
--]]

local m = {
	ops = {
		InitiateEventProc0=0x9050,
		TerminateEventProc_051=0x9051,
		ExecuteEventProc=0x9052,
		GetEventProcReturnData=0x9053,
		IsEventProcRunning=0x9057,
		QuerySizeOfTransparentMemory=0x9058,
		LoadTransparentMemory=0x9059,
		SaveTransparentMemory=0x905a,
		QuickLoadTransparentMemory=0x905b,
		InitiateEventProc1=0x905c,
		TerminateEventProc_05D=0x905d,
	},
}

function m.init(lcon,count,use_alt)
	count = count or 3
	local op = m.ops.InitiateEventProc0
	if use_alt then
		op = m.ops.InitiateEventProc1
	end
	for i=1,count do
		printf("op %x %d:%d",op,i,count)
		local rets = {lcon:ptp_txn_nodata(op)}
		if #rets > 0 then
			printf(" ret %s",table.concat(rets,','))
		end
		printf("\n")

	end
end
function m.term(lcon,use_alt)
	local op = m.ops.TerminateEventProc_051
	if use_alt then
		op = m.ops.TerminateEventProc_05D
	end
	printf("op %x",op)
	local rets = {lcon:ptp_txn_nodata(op)}
	if #rets > 0 then
		printf(" ret %s",table.concat(rets,','))
	end
	printf("\n")
end

--[[
prepare lbuf to eventproc with integer args
]]
function m.prep_simple(name,...)
	local args = {...}
	local size = name:len() + 1 -- name + null
				 + 4 -- arg count
				 + #args*(20) -- arg block
				 + 4 -- long args count
	local lb = lbuf.new(size)
	local off = lb:fill(name .. '\0',0,1)
	lb:set_i32(off,#args)
	off = off + 4
	for i,v in ipairs(args) do
		lb:set_i32(off,0) -- arg type
		off = off+4
		if v < 0 then
			lb:set_i32(off,v) -- value
		else
			lb:set_u32(off,v) -- value
		end
		off = off+4
		lb:set_i32(off,0) -- word 3, unk
		off = off+4
		lb:set_i32(off,0) -- word 4 unk
		off = off+4
		lb:set_i32(off,0) -- word 5 long arg data size
		off = off+4
	end
	lb:set_i32(off,0) -- long args
	return lb
end

--[[
perpare lbuf to use as data in ExecuteEventProc call
arguments may be:
number
string
lbuf
]]
function m.prep(name,...)
	local args = {...}
	if #args > 10 then
		errlib.throw{etype='bad_arg',msg=('max args 10, got %d'):format(#args)}
	end
	local size = name:len() + 1 -- name + null
				 + 4 -- arg count
				 + 4 -- long args count
	local argdefs = { }
	local lcount = 0
	for i,v in ipairs(args) do
		size = size + 20 -- minimum size for arg spec
		local ad = {}
		if type(v) == 'number' then
			ad.val = v
		elseif type(v) == 'string' or lbuf.is_lbuf(v) then
			if v:len() == 0 then
				errlib.throw{etype='bad_arg',msg=('arg %d zero length not supported'):format(i)}
			end
			ad.val = v
			ad.long = true
			size = size + v:len() + 4
			lcount = lcount + 1
			ad.num = i - 1
		else
			errlib.throw{etype='bad_arg',msg=('arg %d unsupported type %s'):format(i,type(v))}
		end
		table.insert(argdefs,ad)
	end
	local lb = lbuf.new(size)
	local off = lb:fill(name .. '\0',0,1)
	lb:set_i32(off,#args)
	off = off + 4
	for i,ad in ipairs(argdefs) do
		-- arg type
		if ad.long then
			lb:set_i32(off,4)
		else
			lb:set_i32(off,0)
		end
		off = off+4
 		-- value, if not long
		if ad.long then
			lb:set_i32(off,0)
		else
			if ad.val < 0 then
				lb:set_i32(off,ad.val)
			else
				lb:set_u32(off,ad.val)
			end
		end
		off = off+4
		lb:set_i32(off,0) -- word 3, unk
		off = off+4
		lb:set_i32(off,0) -- word 4 unk
		off = off+4
		-- word 5 long arg data size
		if ad.long then
			lb:set_i32(off,ad.val:len())
		else
			lb:set_i32(off,0)
		end
		off = off+4
	end
	lb:set_i32(off,lcount) -- num long args
	off = off+4
	for i,ad in ipairs(argdefs) do
		if ad.long then
			lb:set_i32(off,0) -- unk
			off = off+4
			off = off + lb:fill(ad.val,off,1) -- write value
		end
	end
	return lb
end

--[[
call event proc with integer args, sync, single int return
]]
function m.call_simple(lcon,name,...)
	local lb = m.prep_simple(name,...)
	printf("op %x",m.ops.ExecuteEventProc)
	local rets={lcon:ptp_txn_senddata(m.ops.ExecuteEventProc,lb,0,0)}
	if #rets > 0 then
		printf(" ret %s",table.concat(rets,','))
	end
	printf("\n")
	return table.unpack(rets)
end

function m.call_long(lcon,name,...)
	local lb = m.prep(name,...)
	printf("op %x",m.ops.ExecuteEventProc)
	local rets={lcon:ptp_txn_senddata(m.ops.ExecuteEventProc,lb,0,0)}
	if #rets > 0 then
		printf(" ret %s",table.concat(rets,','))
	end
	printf("\n")
	return table.unpack(rets)
end

return m
