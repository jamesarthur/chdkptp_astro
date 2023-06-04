--[[
 Copyright (C) 2017-2021 <reyalp (at) gmail dot com>

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
histogram utilities
]]

local m={ }

--[[
return an iterator over histogram, optionally binning, returns count, bin_start, bin_end (inclusive)
assumes histo is a 0 based array of values
if bin does not evenly divide range, final bin will count remainder
opts {
	bin=number: entries per bin, default 1, meaning iterate over the full histogram
	min=number -- minimum value, default 0
	max=number -- maximum value, inclusive default #histo (in 0 based, 0th entry not counted)
}
]]
function m.ibins(histo,opts)
	-- locals instead of opts table to minimize lookups in inner loop
	local range_min = 0
	local bin_size = 1
	local range_max
	if opts then
		if opts.bin then
			bin_size = opts.bin
		end
		if opts.min then
			range_min = opts.min
		end
		if opts.max then
			range_max = opts.max
		end
	end
	-- only use #histo if max not specified, in case histo is userdata without length operator
	if not range_max then
		range_max = #histo
	end
	bin_size = util.round(bin_size) -- integer bin sizes only
	if bin_size <= 0 then
		errlib.throw{ etype='bad_arg', msg=('invalid bin_size %s'):format(tostring(bin_size)) }
	end
	local v = range_min
	-- if bin_size is 1, simple iterator
	-- could use v as iterator state, but want count as first return for simple case of just iterating over counts
	if bin_size == 1 then
		return function()
			if v > range_max then
				return
			end
			local count = histo[v]
			local v_start = v
			v = v + 1
			return count,v_start,v_start
		end
	end

	return function()
		if v > range_max then
			return
		end
		local v_start = v
		local v_end = v + bin_size - 1
		if v_end > range_max then
			v_end = range_max
		end
		local count = 0
		while v <= v_end do
			count = count + histo[v]
			v = v+1
		end
		return count, v_start, v_end
	end
end

--[=[
assumes histo is a 0 based array of values, with a field total optionally giving the total number of values
opts {
	fmt=string|function -- 'count' = raw count (default)
						   '%[r][plotchar[width][!]]' = percentage
							 r = if 'r', percent is of range specified by min/max, instead of total
							 plotchar = one of . or #, used to plot percent as repeated characters
							 width = maximum number of characters, default 100
							 ! = scale so largest bin is [width] characters
								 otherwise, 100% scaled to [width]
						    function f(count)
	outfn=function -- function(count, bin_start, bin_end)
	bin=number -- bin size, default 1
	min=number -- minimum value, default 0
	max=number -- maximum value, default #histo (in 0 based, 0th entry not counted)
	rfmt=string -- format for range values
	total=number -- default histo.total
}

]=]
function m.print(histo,opts)
	opts=util.extend_table({
		fmt='count',
		bin=1,
		min=0,
		total=histo.total,
	},opts)
	-- only use #histo if max not specified, in case histo is userdata without length operator
	if not opts.max then
		opts.max = #histo
	end

	local total=opts.total

	local fmt_pct
	local pct_rel
	local pct_fill
	local pct_max_chars = 100
	local pct_scale_abs
	local pct_scale
	if opts.fmt ~= 'count' then
		local pct_r, fill_char, max_chars, scale_mode = opts.fmt:match('^%%([rR]?)([.#]?)(%d*)(!?)$')
		if not pct_r then
			errlib.throw{etype='bad_arg',msg=('histoutil.print: bad format %s'):format(tostring(opts.fmt))}
		end
		fmt_pct = true
		-- printf('[%s][%s][%s][%s]\n',pct_r,fill_char,max_chars,scale_mode)
		if pct_r ~= '' then
			pct_rel = true
		end
		if fill_char == '' then
			if max_chars ~= '' or scale_mode ~= '' then
				errlib.throw{etype='bad_arg',msg=('histoutil.print: bad format %s'):format(tostring(opts.fmt))}
			end
		else
			pct_fill = fill_char
		end
		if max_chars ~= '' then
			pct_max_chars = tonumber(max_chars)
			if pct_max_chars < 2 then
				errlib.throw{etype='bad_arg',msg=('histoutil.print: bad format %s'):format(tostring(opts.fmt))}
			end
		end
		if scale_mode == '!' then
			pct_scale_abs = false
		else
			pct_scale_abs = true
			pct_scale = pct_max_chars
		end

	end
	if pct_rel then
		total = m.range_count(histo,opts.min,opts.max)
		-- if total is 0, then no bins will have anything in them, so % will be 0
		if total == 0 then
			total = 1
		end
	end
	-- total only required for % formats
	if fmt_pct and not total then
		errlib.throw{etype='bad_arg',msg='histoutil.print: missing total'}
	end

	if not opts.rfmt then
		local l=string.len(string.format('%d',opts.max))
		opts.rfmt='%'..l..'d'
	end

	local fmt_range
	local fmt_count
	if type(opts.fmt) == 'function' then
		fmt_count = opts.fmt
	elseif fmt_pct then
		if pct_fill then
			fmt_count = function(count)
				return string.format('%s',string.rep(pct_fill,util.round((count / total) * pct_scale)))
			end
		else
			fmt_count = function(count)
				return string.format('%6.2f',(count / total) * 100)
			end
		end
	elseif opts.fmt=='count' then
		fmt_count = function(count)
			return tostring(count)
		end
	else
		errlib.throw{etype='bad_arg',msg='histoutil.print: bad format '..tostring(opts.fmt)}
	end

	if opts.bin == 1 then
		fmt_range = function(v1)
			return string.format(opts.rfmt,v1)
		end
	else
		local fstr=opts.rfmt..'-'..opts.rfmt
		fmt_range = function(v1,v2)
			return string.format(fstr,v1,v2)
		end
	end

	local outfn
	if opts.outfn then
		outfn=opts.outfn
	else
		outfn=function(count,v1,v2)
			printf("%s %s\n",fmt_range(v1,v2),fmt_count(count))
		end
	end

	if not pct_scale_abs then
		local max_bin = m.max_bin_count(histo,opts)
		if max_bin == 0 then
			-- no values in specified range
			pct_scale = 0
		else
			pct_scale = (total / max_bin) * pct_max_chars
		end
	end
	for count,b_start,b_end in m.ibins(histo,opts) do
		outfn(count,b_start,b_end)
	end

	return true
end
function m.range_count(histo,vmin,vmax)
	local total=0
	for i=vmin,vmax do
		total = total + histo[i]
	end
	return total
end

--[[
return the count of the bin with the largest count, as specified by ibins opts
]]
function m.max_bin_count(histo,opts)
	local max_bin = 0
	for count in m.ibins(histo,opts) do
		if count > max_bin then
			max_bin = count
		end
	end
	return max_bin
end

-- allow functions above to be bound to a histogram object / meta-table with extend_table
m.histo_methods = {
	ibins=m.ibins,
	print=m.print,
	range=m.range_count,
	max_bin_count=m.max_bin_count,
}
function m.new_histo(size)
	local h=util.extend_table({},m.histo_methods)
	for i=0,size-1 do
		h[i] = 0
	end
	h.total = 0
	return h
end
return m
