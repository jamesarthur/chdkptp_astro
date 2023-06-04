--[[
 Copyright (C) 2020 <reyalp (at) gmail dot com>

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

local m={}
--[[
get a range of param values
returns a table indexed by param id
Use _min, _max to iterate, not ipairs!
devutil provides cli
]]
function m.get(start,count,init_code)
	if not start then
		start=0
	end
	if not count then
		count=false
	end
	if not init_code then
		init_code=''
	end
	local t={}
	con:execwait(string.format([[
%s
local start=%d
local count=%s
]],init_code,start,count)..[[
local b=msg_batcher()
if count then
	max = start + count
else
	max = get_flash_params_count()-start-1
end

for i=start,max do
	local v={s=false,n=false}
	s,n = get_parameter_data(i)
	if s then
		v.s = s
		if n then
			v.n = n
		end
	end

	b:write(v)
end
b:flush()
]],{libs='msg_batcher',msgs=chdku.msg_unbatcher(t)})
	local params={_min=start, _max=start+#t-1}
	-- remap to param IDs
	local id=start
	for i,v in ipairs(t) do
		params[id]=v
		id = id + 1
	end
	return params
end

function m.fmt(params,i)
	local v=params[i];
	local s=string.format("%4d",i)
	if v.n then
		-- bit32.extract to handle negatives, otherwise error with %x
		s = s..string.format(' 0x%08x',bit32.extract(v.n,0,32))
	else
		s = s..'          '
	end
	if v.s then
		s = s..string.format(' %q',v.s)
	else
		s = s..' (none)'
	end
	return s
end

-- print an array returned by get
function m.print(params)
	for i=params._min,params._max do
		printf("%s\n",m.fmt(params,i))
	end
end
function m.write(params,filename)
	local fh=fsutil.open_e(filename,'wb')
	for i=params._min,params._max do
		fh:write(string.format("%s\n",m.fmt(params,i)))
	end
	fh:close()
end
-- compare arrays returned by get
function m.comp(old,new)
	for i=new._min,new._max do
		local old_s
		if old[i] then
			old_s = old[i].s
		end
		if new[i].s ~= old_s then
			if old_s then
				printf("< %s\n",m.fmt(old,i))
			else
				printf("< (missing)\n")
			end
			printf("> %s\n",m.fmt(new,i))
		end
	end
end
--]]
return m

