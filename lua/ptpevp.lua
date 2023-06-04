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

Interface for Canon PTP eventproc API, based on
https://chdk.setepontos.com/index.php?topic=4338.msg147738#msg147738
--]]

local m = {
	-- connection methods to extend chdku.connection
	con_methods = {},
	-- verbose = nil -- module level verbose control. if set, overrides chdku.ptp_txn_verbose
}

local con_methods = m.con_methods

--[[
enable ptp/eventproc API (dryos 30 ish through digic 7 ish)
]]
function con_methods:ptpevp_initiate(opts)
	opts=util.extend_table({
		op=ptp.CANON.OC.InitiateEventProc0,
		count = 3,
		verbose=m.verbose,
	},opts)
	for i=1,opts.count do
		self:ptp_txn(opts.op,{verbose=opts.verbose})
	end
	-- update supported opcodes
	self:update_devinfo{refresh_ptp=true}
end

--[[
disable ptp/eventproc API
]]
function con_methods:ptpevp_terminate(opts)
	opts=util.extend_table({
		op = ptp.CANON.OC.TerminateEventProc_051,
		verbose=m.verbose,
	},opts)
	self:ptp_txn(opts.op,{verbose=opts.verbose})
	-- update supported opcodes
	self:update_devinfo{refresh_ptp=true}
end

--[[
prep_args = chdku.ptpevp_prepare(name,args...)
prepare lbuf to use as data in ExecuteEventProc call
name must be string or lbuf, will be automatically null terminated
arguments may be:
number
string
lbuf

WARNING string / lbuf args MUST be explicitly null terminated if called function expects C strings

returns lbuf
]]
function m.ptpevp_prepare(name,...)
	local args = {...}
	if #args > 10 then
		errlib.throw{etype='bad_arg',msg=('max args 10, got %d'):format(#args)}
	end
	if type(name) ~= 'string' and not lbuf.is_lbuf(name) then
		errlib.throw{etype='bad_arg',msg=('expected name string or lbuf, not %s'):format(type(name))}
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
			ad.lnum = 0
		elseif type(v) == 'string' or lbuf.is_lbuf(v) then
			if v:len() == 0 then
				errlib.throw{etype='bad_arg',msg=('argument %d: zero length not supported'):format(i)}
			end
			ad.val = v
			ad.long = true
			ad.lnum = lcount
			size = size + v:len() + 4
			lcount = lcount + 1
			ad.num = i - 1
		else
			errlib.throw{etype='bad_arg',msg=('argument %d: unsupported type %s'):format(i,type(v))}
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
			lb:set_i32(off,2) -- 32 bit (ignored on p&s/eos)
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
		lb:set_i32(off,0) -- word 3, high order word of 64 bit (not supported on p&s)
		off = off+4
		lb:set_i32(off,ad.lnum) -- word 4, long arg index
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
			lb:set_i32(off,ad.lnum) -- long arg index
			off = off+4
			off = off + lb:fill(ad.val,off,1) -- write value
		end
	end
	return lb
end

--[[
convenience method to make prepare available on con
]]
function con_methods:ptpevp_prepare(...)
	return m.ptpevp_prepare(...)
end

function con_methods:ptpevp_is_running(opts)
	opts = util.extend_table({
		verbose=m.verbose,
	},opts)
	local rets={self:ptp_txn(ptp.CANON.OC.IsEventProcRunning,{verbose=opts.verbose})}
	return (rets[1] == 1), table.unpack(rets)
end

function con_methods:ptpevp_get_rdata(opts)
	opts = util.extend_table({
		verbose=m.verbose,
		rdtype='string',
	},opts)
	local rvals
	rvals={self:ptp_txn(ptp.CANON.OC.GetEventProcReturnData,{getdata=opts.rdtype,verbose=opts.verbose})}
	return table.unpack(rvals)
end

--[[
opts:{
	getrdata=string -- 'string' or 'lbuf', default string. If rdata, wait and async
	                -- settings permit, Use GetEventProcReturnData to return in specified format
	timeout=number -- milliseconds to wait
	timeout_error -- throw error on timeout, otherwise returns result with timeout=true,
	poll=number -- milliseconds between poll intervals while waiting
	verbose=bool -- passed to transaction function
}
returns {
	rdata=string|lbuf -- return data, if enabled
	rdata_ret=array -- return values from GetEventProcReturnData, if used
	is_run_ret=array -- return values from final IsEventProcRunning call, if wait enabled
	timeout=bool -- true if timed out waiting and timeout_error not set
	f_ret=number -- function return value, if available (async ended)
}
]]
function con_methods:ptpevp_wait(opts)
	opts = util.extend_table({
		timeout=20000,
		timeout_error=false,
		getrdata='string',
		poll=20,
		verbose=m.verbose,
	},opts)
	local t0=ticktime.get()
	while true do
		local rvals={self:ptpevp_is_running()}
		local is_run = table.remove(rvals,1)
		-- printf('is_running %s\n',table.concat(rvals,', '))
		if not is_run then
			local r={
				is_run_ret = rvals,
			}
			if rvals[1] == 2 then -- async finished
				r.f_ret = rvals[2] -- function return value
				if opts.getrdata and rvals[3] then
					local rvals={self:ptpevp_get_rdata{rdtype=opts.getrdata, verbose=opts.verbose}}
					r.rdata = table.remove(rvals,1)
					r.rdata_ret = rvals
				end
			end
			return r
		end
		if ticktime.elapsed(t0) > opts.timeout/1000 then
			if opts.timeout_error then
				errlib.throw{etype='timeout','ptpevp_wait timeout'}
			end
			return {
				timeout=true,
				is_run_ret=rvals,
			}
		end
		sys.sleep(opts.poll)
	end
end

--[[
rets=con:ptpevp_call(name,arg1,...argN,opts)
name: string specifying eventproc name
args1...n,: number, string or lbuf
WARNING: Strings/lbufs must be explicitly null terminated if called function expects string
opts: table
NOTE: the first table argument is assumed to be opts

opts:{
	args_prep=lbuf -- lbuf of arguments prepared by ptpevp_prepare
	async=bool -- async call
	rdata=bool -- call function with return data option
	wait=bool -- wait for IsEventProcRunning
	getrdata=string -- 'string' or 'lbuf', default string. If rdata, wait and async
	                -- settings permit, Use GetEventProcReturnData to return in specified format
	verbose=bool -- passed to transaction functions
	rtype=string -- 'values'|'detail' control return type, as described below
	-- passed to ptpevp_wait when wait is set
	timeout=number -- milliseconds to wait
	timeout_error -- throw error on timeout, otherwise returns result with timeout=true,
	poll=number -- milliseconds between poll intervals while waiting
}
if rtype='values' returns
	function return value, return data on success
	false, 'timeout' on timeout if timeout_error not set

if rtype='detail', returns table
{
	exec_ret=array -- return values from ExecuteEventProc call
	rdata=string|lbuf -- return data, if enabled
	rdata_ret=array -- return values from GetEventProcReturnData, if used
	is_run_ret=array -- return values from final IsEventProcRunning call, if wait enabled
	timeout=bool -- true if timed out waiting and timeout_error not set
	f_ret=number -- function return value, from exec or is_running if async
}
]]
function con_methods:ptpevp_call(...)
	local args={...}
	local opts
	local name
	local ev_args = {}
	for i,arg in ipairs(args) do
		if type(arg) == 'table' then
			if opts then
				errlib.throw{etype='bad_arg',msg=('argument %d: unexpected table'):format(i)}
			end
			opts = arg
		elseif not name then
			if type(arg) ~= 'string' then
				errlib.throw{etype='bad_arg',msg=('argument %d: expected name string not %s'):format(i,type(arg))}
			end
			name = arg
		else
			if type(arg) ~= 'number' and type(arg) ~= 'string' and not lbuf.is_lbuf(arg) then
				errlib.throw{etype='bad_arg',msg=('argument %d: unexpected type %s'):format(i,type(arg))}
			end
			table.insert(ev_args,arg)
		end
	end
	opts = util.extend_table({
		timeout=20000,
		getrdata='string',
		poll=20,
		verbose=m.verbose,
		rtype='values',
	},opts)
	if not name and not opts.args_prep then
		errlib.throw{etype='bad_arg',msg='expected name or args_prep'}
	end
	if opts.args_prep and not lbuf.is_lbuf(opts.args_prep) then
		errlib.throw{etype='bad_arg',msg='expected args_prep to be lbuf'}
	end
	if not opts.rdata then
		opts.getrdata=nil
	end
	if not (util.flag_table({'values','detail'}))[opts.rtype] then
		errlib.throw{etype='bad_arg',msg=('invalid rtype %s'):format(opts.rtype)}
	end

	local prep_args = opts.prep_args
	if not prep_args then
		prep_args = m.ptpevp_prepare(name,table.unpack(ev_args))
	end

	-- convert bools to integer ptp params
	local f_async = 0
	if opts.async then
		f_async = 1
	end
	local f_rdata = 0
	if opts.rdata then
		f_rdata = 1
	end

	local r = {}

	r.exec_ret={self:ptp_txn(ptp.CANON.OC.ExecuteEventProc,f_async,f_rdata,{data=prep_args,verbose=opts.verbose})}

	if opts.async then
		if opts.wait then
			util.extend_table(r,self:ptpevp_wait(opts))
		end
	else
		r.f_ret = r.exec_ret[1]
		if opts.getrdata then
			local rvals={self:ptpevp_get_rdata{rdtype=opts.getrdata, verbose=opts.verbose}}
			r.rdata = table.remove(rvals,1)
			r.rdata_ret = rvals
		end
	end
	if opts.rtype == 'values' then
		if r.timeout then
			return false, 'timeout'
		end
		return r.f_ret,r.rdata
	else
		return r
	end
end

return m
