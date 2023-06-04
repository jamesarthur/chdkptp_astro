--[[
  Copyright (C) 2017-2020 <reyalp (at) gmail dot com>
  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
Functions for setting camera clock
]]
local m={}

--[[
convert date in YYYY/MM/DD format to table of {year=YYYY, month=MM, day=DD}
--]]
function m.parse_simple_date(dstr)
	local d={dstr:match('(%d%d%d%d)[-/](%d%d?)[-/](%d%d?)')}
	for i,v in ipairs(d) do
		d[i] = tonumber(v)
	end
	if #d ~= 3 then
		errlib.throw{etype='bad_arg',msg=('invalid date %s'):format(tostring(dstr))}
	end
	if d[1] < 1970 or d[1] > 2038 then
		errlib.throw{etype='bad_arg',msg=('unsupported year %s'):format(tostring(dstr))}
	end
	if d[2] < 1 or d[2] > 12 then
		errlib.throw{etype='bad_arg',msg=('invalid month %s'):format(tostring(dstr))}
	end
	if d[3] < 1 or d[3] > 31 then
		errlib.throw{etype='bad_arg',msg=('invalid day %s'):format(tostring(dstr))}
	end
	return {year=d[1],month=d[2],day=d[3]}
end

--[[
convert time in HH:MM:SS[AM|PM] format to table of {hour=HH, min=MM, sec=ss}
--]]
function m.parse_simple_time(tstr)
	local t={tstr:match('(%d%d?):(%d%d):(%d%d)(.*)')}
	local ampm=t[4]
	if ampm and ampm ~= '' then
		ampm=ampm:upper()
		if not ampm:match('^[AP]M$') then
			errlib.throw{etype='bad_arg',msg=('invalid AM/PM spec %s'):format(tostring(tstr))}
		end
	end
	t[4] = nil

	for i,v in ipairs(t) do
		t[i] = tonumber(v)
	end
	if #t ~= 3 then
		errlib.throw{etype='bad_arg',msg=('invalid time %s'):format(tostring(tstr))}
	end
	if ampm == 'PM' then
		if t[1] ~= 12 then
			t[1] = t[1] + 12
		end
	elseif ampm == 'AM' and t[1] == 12 then
		t[1] = 0
	end
	if t[1] < 0 or t[1] > 23 then
		errlib.throw{etype='bad_arg',msg=('invalid hour %s'):format(tostring(tstr))}
	end
	if t[2] < 0 or t[1] > 59 then
		errlib.throw{etype='bad_arg',msg=('invalid minute %s'):format(tostring(tstr))}
	end
	if t[3] < 0 or t[3] > 59 then
		errlib.throw{etype='bad_arg',msg=('invalid second %s'):format(tostring(tstr))}
	end
	return {hour=t[1],min=t[2],sec=t[3]}
end

function m.parse_simple_datetime(dstr,tstr)
	return util.extend_table(m.parse_simple_date(dstr),m.parse_simple_time(tstr))
end

--[[
register eventprocs needed to set time for CHDK < 1.5 build 5552, if needed
returns false if set_clock is available
returns true if eventprocs are registered or throws an error if not available
--]]
function m.register_evp()
	return con:execwait[[
if type(set_clock) == 'function' then
	return false
end
if get_config_value(1999) == 0 then
	error('This build requires native calls enabled to set time')
end
if call_event_proc('FA.Create') == -1 then
	error('FA.Create failed')
end
if call_event_proc('InitializeAdjustmentFunction') == -1 then
	error('InitializeAdjustmentFunction failed')
end
return true
]]
end

--[[
set camera clock to time specified table
t:{
	year
	month
	day
	hour
	minute
	second
}
returns
time before and after set, in os.date('*t') table

--]]
function m.set_clock(t,opts)
	opts=util.extend_table({use_evp=false},opts)

	if opts.use_evp then
		return con:execwait(string.format([[
local ot=os.date('*t')
if call_event_proc('SetYear',%d) == -1
	or call_event_proc('SetMonth',%d) == -1
	or call_event_proc('SetDay',%d) == -1
	or call_event_proc('SetHour',%d) == -1
	or call_event_proc('SetMinute',%d) == -1
	or call_event_proc('SetSecond',%d) == -1 then
	error('set failed')
end
return ot,os.date('*t')
]],t.year,t.month,t.day,t.hour,t.min,t.sec),{libs='serialize_msgs'})
	else
		return con:execwait(string.format([[
local ot=os.date('*t')
set_clock(%d,%d,%d,%d,%d,%d)
return ot,os.date('*t')
]],t.year,t.month,t.day,t.hour,t.min,t.sec),{libs='serialize_msgs'})
	end
end

function m.sync(opts)
	opts=util.extend_table({utc=false,subsec=true,subsec_margin=10},opts)
	local use_evp = m.register_evp()

	if use_evp then
		util.warnf("CHDK build does not support set_clock, using eventprocs. Camera restart recommended\n")
	end

	local lfmt='*t'
	if opts.utc then
		lfmt='!*t'
	end
	-- send set command on next second change, less subsec_margin for USB overhead
	local sec,usec=sys.gettimeofday()
	if opts.subsec then
		local waitms = (1000 - usec/1000) - opts.subsec_margin
		if waitms < 0 then
			waitms = waitms + 1000
			sec = sec + 1
		end
		sec = sec+1 -- setting time on transition to next second
		sys.sleep(waitms)
	end
	local lt=os.date(lfmt,sec)
	local ot,nt = m.set_clock(lt,{use_evp = use_evp})
	return lt,ot,nt
end
return m
