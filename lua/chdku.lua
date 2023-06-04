--[[
 Copyright (C) 2010-2022 <reyalp (at) gmail dot com>
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
lua helper functions for working with the chdk.* c api
]]

local ptpevp = require'ptpevp'
local chdku={}
chdku.rlibs = require('rlibs')
chdku.sleep = sys.sleep -- to allow override
chdku.nop = function() end -- dummy callback

-- format a script message in a human readable way
function chdku.format_script_msg(msg)
	if msg.type == 'none' then
		return ''
	end
	local r=string.format("%d:%s:",msg.script_id,msg.type)
	-- for user messages, type is clear from value, strings quoted, others not
	if msg.type == 'user' or msg.type == 'return' then
		if msg.subtype == 'boolean' or msg.subtype == 'integer' or msg.subtype == 'nil' then
			r = r .. tostring(msg.value)
		elseif msg.subtype == 'string' then
			r = r .. string.format("'%s'",msg.value)
		else
			r = r .. msg.subtype .. ':' .. tostring(msg.value)
		end
	elseif msg.type == 'error' then
		r = r .. msg.subtype .. ':' .. tostring(msg.value)
	end
	return r
end

--[[
Camera timestamps are in seconds since Jan 1, 1970 in current camera time
PC timestamps (linux, windows) are since Jan 1, 1970 UTC
return offset of current PC time from UTC time, in seconds
]]
function chdku.ts_get_offset()
	-- local timestamp, assumed to be seconds since unix epoch
	local tslocal=os.time()
	-- !*t returns a table of hours, minutes etc in UTC (without a timezone spec)
	-- the dst flag is overridden using the local value
	-- os.time turns this into a timestamp, treating as local time
	local ttmp = os.date('!*t',tslocal)
	ttmp.isdst  = os.date('*t',tslocal).isdst
	return tslocal - os.time(ttmp)
end

--[[
covert a timestamp from the camera to the equivalent local time on the pc
]]
function chdku.ts_cam2pc(tscam)
	local tspc = tscam - chdku.ts_get_offset()
	-- TODO
	-- on windows, a time < 0 causes os.date to return nil
	-- these can appear from the cam if you set 0 with utime and have a negative utc offset
	-- since this is a bogus date anyway, just force it to zero to avoid runtime errors
	if tspc > 0 then
		return tspc
	end
	return 0
end

--[[
covert a timestamp from the pc to the equivalent on the camera
default to current time if none given
]]
function chdku.ts_pc2cam(tspc)
	if not tspc then
		tspc = os.time()
	end
	local tscam = tspc + chdku.ts_get_offset()
	-- TODO
	-- cameras handle < 0 times inconsistently (vxworks > 2100, dryos < 1970)
	if tscam > 0 then
		return tscam
	end
	return 0
end

--[[
format PTP parameters for a debug string
]]
function chdku.dbg_fmt_ptp_params(params)
	local r={}
	for i,v in ipairs(params) do
		if type(v) == 'number' then
			table.insert(r,('0x%x (%d)'):format(v,v))
		else
			table.insert(r,('(%s:%s)'):format(type(v),tostring(v)))
		end
	end
	return table.concat(r,', ')
end

--[[
connection methods, added to the connection object
]]
local con_methods = {}

-- allow other modules to extend / override
chdku.con_methods = con_methods

-- add ptp eventproc methods
util.extend_table(con_methods,ptpevp.con_methods)
-- non-con method
chdku.ptpevp_prepare = ptpevp.ptpevp_prepare

-- log all ptp_txn call parameters and returns
chdku.ptp_txn_verbose = false
-- default logging function
chdku.ptp_txn_info_fn = util.printf
--[[
execute an arbitrary PTP transaction, with various options

[data][,param1,...param5] = con:ptp_txn(opcode[,param1...param5][,opts])
perform a ptp transaction
op and param1 through param5 must be convertible to number
opts: {
  getdata='lbuf':'string' -- perform getdata transaction, return as specified type
  data=lbuf|string -- perform senddata transaction with specified lbuf or string
  verbose=bool -- log parameters and returns with info_fn, default chdku.ptp_txn_verbose
  info_fn=function, default util.printf
}
returns
data if getdata is set, followed by PTP return params
]]
function con_methods:ptp_txn(op,...)
	local args={...}
	local opts
	local ptp_params={}
	op = tonumber(op)
	if not op then
		errlib.throw{etype='bad_arg',msg=('argument 1: expected opcode number, not %s'):format(type(op))}
	end
	for i,arg in ipairs(args) do
		if type(arg) == 'table' then
			if opts then
				errlib.throw{etype='bad_arg',msg=('argument %d: unexpected table'):format(i)}
			end
			opts = arg
		else
			local narg = tonumber(arg)
			if not narg then
				errlib.throw{etype='bad_arg',msg=('argument %d: expected number not %s:%s'):format(i,type(arg),tostring(arg))}
			end
			table.insert(ptp_params,narg)
		end
	end

	opts=util.extend_table({
		info_fn=chdku.ptp_txn_info_fn,
		verbose=chdku.ptp_txn_verbose,
	},opts)

	local opstr
	if opts.verbose then
		opstr=con:get_ptp_code_desc('OC',op)
	else
		opts.info_fn = chdku.nop
	end
	if opts.getdata and opts.data then
		errlib.throw{etype='bad_arg',msg='getdata and data are mutually exclusive'}
	end
	local rvals
	if opts.getdata then
		if opts.getdata == 'lbuf' then
			opts.info_fn('txn_getdata_lbuf %s %s\n',opstr,chdku.dbg_fmt_ptp_params(ptp_params))
			rvals={self:ptp_txn_getdata_lbuf(op,table.unpack(ptp_params))}
		elseif opts.getdata == 'string' or opts.getdata == true then
			opts.info_fn('txn_getdata_str %s %s\n',opstr,chdku.dbg_fmt_ptp_params(ptp_params))
			rvals={self:ptp_txn_getdata_str(op,table.unpack(ptp_params))}
		else
			errlib.throw{etype='bad_arg',msg=('unexpected getdata %s'):format(tostring(opts.getdata))}
		end
		opts.info_fn('data len=%d ret=%s\n',rvals[1]:len(),chdku.dbg_fmt_ptp_params({table.unpack(rvals,2)}))
	elseif opts.data then
		opts.info_fn('txn_senddata %s data len=%d %s\n',opstr,opts.data:len(), chdku.dbg_fmt_ptp_params(ptp_params))
		rvals={self:ptp_txn_senddata(op,opts.data,table.unpack(ptp_params))}
		opts.info_fn('ret=%s\n',chdku.dbg_fmt_ptp_params(rvals))
	else
		opts.info_fn('txn_nodata %s %s\n',opstr,chdku.dbg_fmt_ptp_params(ptp_params))
		rvals={self:ptp_txn_nodata(op,table.unpack(ptp_params))}
		opts.info_fn('ret=%s\n',chdku.dbg_fmt_ptp_params(rvals))
	end
	return table.unpack(rvals)
end


--[[
check whether this cameras model and serial number match those given
assumes self.ptpdev is up to date
bool = con:match_ptp_info(match)
{
	model='model pattern'
	serial='serial number pattern'
	plain=bool -- plain text match
}
empty / false model or serial matches any
]]
function con_methods:match_ptp_info(match)
	if match.model and not string.find(self.ptpdev.model,match.model,1,match.plain) then
		return false
	end
	-- older cams don't have serial
	local serial = ''
	if self.ptpdev.serial_number then
		serial = self.ptpdev.serial_number
	end
	if match.serial_number and not string.find(serial,match.serial_number,1,match.plain) then
		return false
	end
	return true
end

--[[
check if connection API is major and >= minor
todo might want to allow major >= in some cases
]]
function con_methods:is_ver_compatible(major,minor)
	-- API ver not initialized
	-- TODO maybe it should just be an error to call without connecting?
	if not self.apiver then
		return false
	end
	if self.apiver.MAJOR ~= major or self.apiver.MINOR < minor then
		return false
	end
	return true
end
--[[
return a list of remote directory contents
dirlist=con:listdir(path,opts)
path should be directory, without a trailing slash (except in the case of A/...)
opts may be a table, or a string containing lua code for a table
returns directory listing as table, throws on local or remote error
note may return an empty table if target is not a directory
]]
function con_methods:listdir(path,opts)
	if type(opts) == 'table' then
		opts = serialize(opts)
	elseif type(opts) ~= 'string' and type(opts) ~= 'nil' then
		return false, "invalid options"
	end
	if opts then
		opts = ','..opts
	else
		opts = ''
	end
	local results={}
	local i=1
	local rstatus,err=self:execwait("return ls('"..path.."'"..opts..")",{
		libs='ls',
		msgs=chdku.msg_unbatcher(results),
	})
	if not rstatus then
		errlib.throw{etype='remote',msg=err}
	end

	return results
end

--[[
download using a table returned by find_files
]]
function con_methods:download_file_ff(finfo,dst,opts)
	local src=finfo.full

	-- TODO info_fn should be a msgf function that accepts verbosity
	if opts.verbose then
		opts.info_fn('%s->%s\n',src,dst)
	end

	local st=lfs.attributes(dst)

	if st then
		local skip
		if not opts.overwrite then
			skip=true
		elseif type(opts.overwrite) == 'function' then
			skip = not opts.overwrite(self,opts,finfo,st,src,dst)
		elseif opts.overwrite == true then
			skip = false
		else
			error("invalid overwrite option")
		end
		if skip then
			opts.info_fn("skip existing: %s\n",dst)
			return
		else
			opts.info_fn("overwrite: %s\n",dst)
		end
	end

	if opts.pretend then
		return
	end

	-- ensure parent exists
	fsutil.mkdir_parent(dst)

	-- ptp download fails on zero byte files (zero size data phase, possibly other problems)
	if finfo.st.size > 0 then
		self:download(src,dst)
	else
		local f=fsutil.open_e(dst,"wb")
		f:close()
	end
	if opts.mtime then
		local status,err = lfs.touch(dst,chdku.ts_cam2pc(finfo.st.mtime));
		if not status then
			error(err)
		end
	end
end

function chdku.dl_set_subst_finfo_state(state,finfo)
	state.mdate = chdku.ts_cam2pc(finfo.st.mtime)
	state.mts = chdku.ts_cam2pc(finfo.st.mtime)
	-- could use image fsutil.parse_image_path_cam here, leaving image specific
	-- parts empty for non-images, but some names would be confusing (subdir etc)
	-- and possible false positives like FOO_1234.LUA
	state.name = finfo.name
	state.basename,state.ext = fsutil.split_ext(state.name)
	state.dir = string.sub(fsutil.dirname_cam(finfo.full),3) -- everything after A/, or empty string if A/

	-- either directly specified, or directly in specified dir, no reldir
	if #finfo.path <= 2 then
		state.reldir = ''
	elseif #finfo.path == 3 then
		state.reldir = finfo.path[#finfo.path-1] -- joinpath doesn't accept just one part
	else
		state.reldir = fsutil.joinpath(unpack(finfo.path,2,#finfo.path-1))
	end
	-- trailing slash if not empty, to simplify building paths
	if state.dir ~= '' and state.dir ~= 'A/' then
		state.dir = state.dir .. '/'
	end
	if state.reldir ~= '' then
		state.reldir = state.reldir .. '/'
	end
end

--[[
download files and directories
con:mdownload(srcpaths,dst,opts)
srcpaths: array of files / directories
dst: destination directory or subst string. Subst if contains $, unless nosubst
opts:
	mtime=bool -- keep (default) or discard remote mtime NOTE files only for now
	overwrite=bool|function -- overwrite if existing found
	info_fn=function -- printf like function to receive status messages
	pretend=bool
	verbose=bool
	nosubst=bool -- treat dst strictly as a directory, even if it contains $
other opts are passed to find_files
throws on error
]]
function con_methods:mdownload(srcpaths,dst,opts)
	if not dst then
		dst = '.'
	end
	local lopts=util.extend_table({
		mtime=true,
		overwrite=true,
		info_fn=util.printf,
		verbose=true,
	},opts)
	if lopts.pretend then
		lopts.verbose=true
	end
	local subst
	if not lopts.nosubst and string.match(dst,'%$') then
		subst=varsubst.new(chdku.dl_subst_funcs)
		subst:validate(dst)
		chdku.set_subst_time_state(subst.state)
		self:set_subst_con_state(subst.state)
	end
	local ropts=util.extend_table({},opts)
	ropts.dirsfirst=true
	-- unset options that don't apply to remote
	ropts.mtime=nil
	ropts.overwrite=nil
	if not subst then
		local dstmode = lfs.attributes(dst,'mode')
		if dstmode and dstmode ~= 'directory' then
			errlib.throw{etype='bad_arg',msg='mdownload: dest must be a directory'}
		end
	end
	local files={}
	if lopts.dbgmem then
		files._dbg_fn=chdku.msg_unbatcher_dbgstr
	end
	local rstatus,rerr = self:execwait('return ff_mdownload('..serialize(srcpaths)..','..serialize(ropts)..')',
										{libs={'ff_mdownload'},msgs=chdku.msg_unbatcher(files)})

	if not rstatus then
		errlib.throw{etype='remote',msg=rerr}
	end

	if #files == 0 then
		util.warnf("no matching files\n");
		return true
	end

	local mkdir=function(path)
		if lopts.verbose then
			lopts.info_fn('mkdir %s\n',tostring(path))
		end
		if not lopts.pretend then
			fsutil.mkdir_m(path)
		end
	end

	for i,finfo in ipairs(files) do
		local relpath
		local src,dstfull
		src = finfo.full
		if #finfo.path == 1 then
			relpath = finfo.name
		else
			if #finfo.path == 2 then
				relpath = finfo.path[2]
			else
				relpath = fsutil.joinpath(unpack(finfo.path,2))
			end
		end
		if subst then
			chdku.dl_set_subst_finfo_state(subst.state,finfo)
			dstfull = subst:run(dst)
		else
			dstfull = fsutil.joinpath(dst,relpath)
		end
		if finfo.st.is_dir then
			mkdir(dstfull)
		else
			self:download_file_ff(finfo,dstfull,lopts)
		end
	end
end

--[[
standard imglist varsubst
${serial,strfmt}  camera serial number, or '' if not available, default format %s
${pid,strfmt}     camera platform ID, default format %x
${ldate,datefmt}  PC clock date, os.date format, default %Y%m%d_%H%M%S
${lts,strfmt}     PC clock date as unix timestamp + microseconds, default format %f
${lms,strfmt}     PC clock milliseconds part, default format %03d
${mdate,datefmt}  Camera file modified date, converted to PC time, os.date format, default %Y%m%d_%H%M%S
${mts,strfmt}     Camera file modified date, as unix timestamp converted to PC time, default format %d
${name}           Image full name, like IMG_1234.JPG
${basename}       Image name without extension, like IMG_1234
${ext}            Image extension, like .JPG
${subdir}         Image DCIM subdirectory, like 100CANON or 100___01 or 100_0101
${imgnum}         Image number like 1234
${imgpfx}         Image prefix like IMG
${dirnum}         Image directory number like 101
${dirmonth}       Image DCIM subdirectory month, like 01, date folder naming cameras only
${dirday}         Image DCIM subdirectory day, like 01, date folder naming cameras only
${dlseq}          Sequential number incremented per file downloaded
${shotseq}        Sequential number incremented when imgnum changes.

 NOTE
  ${shotseq} depends on sort grouping related shots together, like 'date' or 'shot'

]]

--[[
default subst funcs, split into tables for easier re-use
]]
-- connection related
chdku.con_subst_funcs={
	serial=varsubst.format_state_val('serial','%s'),
	pid=varsubst.format_state_val('pid','%x'),
}

-- local time
chdku.ltime_subst_funcs={
	ldate=varsubst.format_state_date('ldate','%Y%m%d_%H%M%S'),
	lts=varsubst.format_state_val('lts','%f'),
	lms=varsubst.format_state_val('lms','%03d'),
}

-- sequential numbering
chdku.seq_subst_funcs={
	dlseq=varsubst.format_state_val('dlseq','%04d'),
	shotseq=varsubst.format_state_val('shotseq','%04d'),
}

-- stat
chdku.stat_subst_funcs={
	mdate=varsubst.format_state_date('mdate','%Y%m%d_%H%M%S'),
	mts=varsubst.format_state_val('mts','%d'),
}
-- image names
chdku.name_subst_funcs={
	name=varsubst.format_state_val('name','%s'),
	basename=varsubst.format_state_val('basename','%s'),
	ext=varsubst.format_state_val('ext','%s'),
	imgnum=varsubst.format_state_val('imgnum','%s'), -- defaults to string format, since it could be empty
	imgpfx=varsubst.format_state_val('imgpfx','%s'),
}
-- image directories
chdku.dir_subst_funcs={
	subdir=varsubst.format_state_val('subdir','%s'),
	dirnum=varsubst.format_state_val('dirnum','%s'),
	dirmonth=varsubst.format_state_val('dirmonth','%s'),
	dirday=varsubst.format_state_val('dirday','%s'),
}
-- image directories + name
chdku.path_subst_funcs=util.extend_table_multi({},{
	chdku.name_subst_funcs,
	chdku.dir_subst_funcs,
})

-- combine into one table for imdl etc
chdku.imglist_subst_funcs=util.extend_table_multi({},{
	varsubst.string_subst_funcs,
	chdku.con_subst_funcs,
	chdku.ltime_subst_funcs,
	chdku.seq_subst_funcs,
	chdku.stat_subst_funcs,
	chdku.path_subst_funcs,
})
-- remote capture
chdku.rc_subst_funcs=util.extend_table_multi({},{
	varsubst.string_subst_funcs,
	chdku.con_subst_funcs,
	chdku.ltime_subst_funcs,
	chdku.name_subst_funcs,
	{
		shotseq=varsubst.format_state_val('shotseq','%04d'),
		imgfmt=varsubst.format_state_val('imgfmt','%s'),
	}
})

-- general file downloads, for mdl
chdku.dl_subst_funcs=util.extend_table_multi({},{
	varsubst.string_subst_funcs,
	chdku.con_subst_funcs,
	chdku.ltime_subst_funcs,
	chdku.stat_subst_funcs,
	{
		name=varsubst.format_state_val('name','%s'),
		basename=varsubst.format_state_val('basename','%s'),
		ext=varsubst.format_state_val('ext','%s'),
		-- directory relative to initial path
		reldir=varsubst.format_state_val('reldir','%s'),
		-- full camera directory, excluding A/
		dir=varsubst.format_state_val('dir','%s'),
	}
})

--[[
per connection state
]]
function con_methods:set_subst_con_state(state)
	if self.ptpdev.serial_number then
		state.serial = self.ptpdev.serial_number
	else
		state.serial = ''
	end
	state.pid=self.condev.product_id
end

--[[
local PC time related state
callers may want this to apply to an entire batch, or each file
]]
function chdku.set_subst_time_state(state)
	state.ldate = os.time() -- local time as a timestamp
	local t=ustime.new()
	state.lts = t:float() -- local unix timestamp + microseconds
	state.lms = t.usec/1000 -- ms only
end

--[[
per file state
]]
function chdku.imglist_set_subst_finfo_state(state,finfo)
	state.mdate = chdku.ts_cam2pc(finfo.st.mtime)
	state.mts = chdku.ts_cam2pc(finfo.st.mtime)
	util.extend_table(state,fsutil.parse_image_path_cam(finfo.full,{string=true}))
end
-- assumes _finfo_state already run
function chdku.imglist_set_subst_seq_state(state)
	local imgnum = tonumber(state.imgnum)
	-- state setting happens before expansion, so only increment after first call
	if state._seq_first_done then
		if state._seq_imgnum_prev ~= imgnum then
			state.shotseq = state.shotseq+1
		end
		state.dlseq = state.dlseq+1
	else
		state._seq_first_done=true
	end
	state._seq_imgnum_prev = imgnum
end
--[[
names of option to pass to remote code
]]
chdku.imglist_remote_opts={
	'lastimg',
	'imgnum_min',
	'imgnum_max',
	'dirnum_min',
	'dirnum_max',
	'sizemin',
	'sizemax',
	'start_paths',
	'fmatch',
	'dmatch',
	'rmatch',
	'maxdepth',
	'batchsize',
	'dbgmem',
}

--[[
sort finfo using strings generated by varsubst
]]
function chdku.finfo_subst_sort(files,sortstr,sort_order)
	local subst=varsubst.new(util.extend_table_multi({},{
		chdku.stat_subst_funcs,
		chdku.path_subst_funcs,
	}))

	local get_cmp_str=function(finfo)
		chdku.imglist_set_subst_finfo_state(subst.state,finfo)
		return subst:run(sortstr)
	end
	-- default, low to high like lua default
	local cmp
	if sort_order == 'asc' then
		cmp = function(a,b)
			return a < b
		end
	elseif sort_order == 'des' then
		cmp = function(a,b)
			return a > b
		end
	else
		errlib.throw{etype='bad_arg',msg='finfo_subst_sort: invalid sort order'..tostring(sort_order)}
	end
	table.sort(files,function(a,b)
		return cmp(get_cmp_str(a),get_cmp_str(b))
	end)
end
--[[
files: finfo array as returned by imglist
opts:
{
	sort=string -- sort type
	sort_order=string -- 'asc' or 'dsc'
}
]]
function chdku.imglist_sort(files,opts)
	local sortopts={
		path={'full'},
		name={'name'},
		date={'st','mtime'},
		size={'st','size'},
		shot='${dirnum}${imgnum}${imgpfx}${ext}', -- directory number, shot number, followed by non-number bits of name
	}
	local sortpath = sortopts[opts.sort]
	if not sortpath then
		-- if sort option is a string, assume it is subst pattern
		if type(opts.sort) == 'string' and opts.sort:sub(1,1) == '$' then
			sortpath=opts.sort
		else
			errlib.throw{etype='bad_arg',msg='imglist_sort: invalid sort '..tostring(opts.sort)}
		end
	end
	if type(sortpath) == 'table' then
		util.table_path_sort(files,sortpath,opts.sort_order)
	else
		chdku.finfo_subst_sort(files,sortpath,opts.sort_order)
	end
end
--[[
get a list of image files with ff_imglist
]]
function con_methods:imglist(opts)
	opts=util.extend_table({},opts)
	local ropts=util.extend_table({
		use_idir=true,
		dirs=false,
		fmatch='%a%a%a_%d%d%d%d%.%w%w%w',
	},opts,{
		keys=chdku.imglist_remote_opts,
	})

	-- coerce numeric options to numbers
	for i,name in ipairs{'lastimg','imgnum_min','imgnum_max','dirnum_min','dirnum_max','sizemin','sizemax'} do
		if type(ropts[name]) == 'string' then
			ropts[name] = tonumber(ropts[name])
		end
	end

	local files={}

	if opts.dbgmem then
		files._dbg_fn=chdku.msg_unbatcher_dbgstr
	end

	local rstatus,rerr = self:execwait('return ff_imglist('..serialize(ropts)..')',
										{libs={'ff_imglist'},msgs=chdku.msg_unbatcher(files)})

	if not rstatus then
		errlib.throw{etype='remote',msg=rerr}
	end

	if opts.sort then
		chdku.imglist_sort(files,opts)
	end
	return files
end

--[[
download files returned by imglist, using varsubst to generate output names
]]
function con_methods:imglist_download(files,opts)
	opts=util.extend_table({
		dst='${subdir}/${name}',
		dstdir=false,
		mtime=true,
		info_fn=util.printf,
		dlseq_start=1,
		shotseq_start=1,
	},opts)
	if opts.pretend then
		opts.verbose = true
	end
	local subst=varsubst.new(chdku.imglist_subst_funcs)
	subst:validate(opts.dst)
	chdku.set_subst_time_state(subst.state)
	self:set_subst_con_state(subst.state)
	subst.state.dlseq = opts.dlseq_start
	subst.state.shotseq = opts.shotseq_start
	for i,finfo in ipairs(files) do
		chdku.imglist_set_subst_finfo_state(subst.state,finfo)
		chdku.imglist_set_subst_seq_state(subst.state)
		local dst = subst:run(opts.dst)
		if opts.dstdir then
			dst=fsutil.joinpath(opts.dstdir,dst)
		end
		self:download_file_ff(finfo,dst,opts)
	end
end

--[[
delete files from imglist
]]
function con_methods:imglist_delete(files,opts)
	opts=util.extend_table({
		info_fn=util.printf,
	},opts)
	if opts.pretend then
		opts.verbose = true
	end
	for i,f in ipairs(files) do
		if opts.verbose then
			opts.info_fn('delete %s\n',f.full)
		end
		if not opts.pretend then
			-- TODO would be much faster to send a bunch of names over at once
			local status, err = self:remove(f.full)
			-- TODO maybe this should abort with error?
			if not status then
				util.warnf("failed %s\n",tostring(err))
			end
		end
	end
end

--[[
upload files and directories
status[,err]=con:mupload(srcpaths,dstpath,opts)
opts are as for find_files, plus
	pretend: just print what would be done
	mtime: preserve mtime of local files
]]
local function mupload_fn(self,opts)
	local con=opts.con
	if #self.rpath == 0 and self.cur.st.mode == 'directory' then
		return
	end
	if self.cur.name == '.' or self.cur.name == '..' then
		return
	end
	local relpath
	local src=self.cur.full
	if #self.cur.path == 1 then
		relpath = self.cur.name
	else
		if #self.cur.path == 2 then
			relpath = self.cur.path[2]
		else
			relpath = fsutil.joinpath(unpack(self.cur.path,2))
		end
	end
	local dst=fsutil.joinpath_cam(opts.mu_dst,relpath)
	if self.cur.st.mode == 'directory' then
		if opts.pretend then
			printf('remote mkdir_m(%s)\n',dst)
		else
			local status,err=con:mkdir_m(dst)
			if not status then
				errlib.throw{etype='remote',msg=tostring(err)}
			end
		end
		opts.lastdir = dst
	else
		local dst_dir=fsutil.dirname_cam(dst)
		-- cache target directory so we don't have an extra stat call for every file in that dir
		if opts.lastdir ~= dst_dir then
			local st,err=con:stat(dst_dir)
			if st then
				if not st.is_dir then
					errlib.throw{etype='remote',msg='not a directory: '..tostring(dst_dir)}
				end
			else
				if opts.pretend then
					printf('remote mkdir_m(%s)\n',dst_dir)
				else
					local status,err=con:mkdir_m(dst_dir)
					if not status then
						errlib.throw{etype='remote',msg=tostring(err)}
					end
				end
			end
			opts.lastdir = dst_dir
		end
		-- TODO stat'ing in batches would be faster
		local st,err=con:stat(dst)
		if st and not st.is_file then
			errlib.throw{etype='remote',msg='not a file: '..tostring(dst)}
		end
		-- TODO timestamp comparison
		printf('%s->%s\n',src,dst)
		if not opts.pretend then
			con:upload(src,dst)
			if opts.mtime then
				-- TODO updating times in batches would be faster
				local status,err = con:utime(dst,chdku.ts_pc2cam(self.cur.st.modification))
				if not status then
					errlib.throw{etype='remote',msg=tostring(err)}
				end
			end
		end
	end
end

function con_methods:mupload(srcpaths,dstpath,opts)
	opts = util.extend_table({mtime=true},opts)
	opts.dirsfirst=true
	opts.mu_dst=dstpath
	opts.con=self
	fsutil.find_files(srcpaths,opts,mupload_fn)
end

--[[
delete files and directories
opts are as for find_files, plus
	pretend:only return file name and action, don't delete
	skip_topdirs: top level directories passed in paths will not be removed
		e.g. mdelete({'A/FOO'},{skip_topdirs=true}) will delete everything in FOO, but not foo itself
	ignore_errors: ignore failed deletes
]]
function con_methods:mdelete(paths,opts)
	opts=util.extend_table({},opts)
	opts.dirsfirst=false -- delete directories only after recursing into
	local results
	local msg_handler
	if opts.msg_handler then
		msg_handler = opts.msg_handler
		opts.msg_handler = nil -- don't pass to remote
	else
		results={}
		msg_handler = chdku.msg_unbatcher(results)
	end
	local status,err = self:call_remote('ff_mdelete',{libs={'ff_mdelete'},msgs=msg_handler},paths,opts)

	if not status then
		errlib.throw{etype='remote',msg=tostring(err)}
	end
	if results then
		return results
	end
end

--[[
download contents of file to Lua string, throw on error
opts: {
	nolua=boolean - do not attempt to stat. Call will fail on empty files
	missing_ok=boolean - return nil if file can't be stat'd
}
]]
function con_methods:readfile(path,opts)
	path = fsutil.make_camera_path(path)
	opts = opts or {}
	if opts.missing_ok and opts.nolua then
		errlib.throw{etype='bad_arg',msg='missing_ok requires lua'}
	end
	-- portocol can't download empty file, have to stat
	-- TODO could read and return from camera lua if small
	if not opts.nolua then
		local st,err = self:stat(path)
		if not st then
			if opts.missing_ok then
				return nil
			end
			errlib.throw{etype='remote',msg=err}
		end
		if not st.is_file then
			errlib.throw{etype='remote',msg='not a file'..tostring(path)}
		end
		if st.size == 0 then
			return ''
		end
	end
	return self:download_str(path)
end

--[[
con:writefile(path,value,opts)
upload Lua string or number to file, throw on error
opts: {
	nolua=boolean - do not sanity check dest
	mkdir=boolean - create parent directories as needed, default true, disabled if nolua used
}
]]
function con_methods:writefile(path,val,opts)
	path = fsutil.make_camera_path(path)
	opts = util.extend_table({
		mkdir=true,
	},opts)
	if type(val) == 'number' then
		val = tostring(val)
	elseif type(val) ~= 'string' then
		errlib.throw{etype='bad_arg',msg='expected string or number'}
	end
	if not opts.nolua then
		local status, err = self:execwait(([[
function checkpath(path,mkdir)
	local st,err = os.stat(path)
	if st and not st.is_file then
		return false, 'destination not a file'
	end
	if mkdir then
		local status, err=mkdir_parent(path)
		if not status then
			return false, err
		end
	else
		st, err = os.stat(dirname(path))
		if not st then
			return false, 'missing dest dir'
		end
		if not st.is_dir then
			return false, 'dest not a dir'
		end
	end
	return true
end
return checkpath("%s",%s)
]]):format(path,opts.mkdir),{libs='mkdir_parent'})
		if not status then
			errlib.throw{etype='remote',msg=err}
		end
	end
	self:upload_str(path,val)
end

--[[
wrapper for remote functions, serialize args, combine remote and local error status
func must be a string that evaluates to a function on the camera
returns remote function return values on success, throws on error
]]
function con_methods:call_remote(func,opts,...)
	local args = {...}
	local argstrs = {}
	-- preserve nils between values (not trailing ones but shouldn't matter in most cases)
	for i = 1,table.maxn(args) do
		argstrs[i] = serialize(args[i])
	end

	local code = "return "..func.."("..table.concat(argstrs,',')..")"
--	printf("%s\n",code)
	local results = {self:execwait(code,opts)}
	return unpack(results,1,table.maxn(results)) -- maxn expression preserves nils
end

function con_methods:stat(path)
	return self:call_remote('os.stat',nil,path)
end

function con_methods:utime(path,mtime,atime)
	return self:call_remote('os.utime',nil,path,mtime,atime)
end

function con_methods:mdkir(path)
	return self:call_remote('os.mkdir',nil,path)
end

function con_methods:remove(path)
	return self:call_remote('os.remove',nil,path)
end

function con_methods:mkdir_m(path)
	return self:call_remote('mkdir_m',{libs='mkdir_m'},path)
end

--[[
sort an array of stat+name by directory status, name
]]
function chdku.sortdir_stat(list)
	table.sort(list,function(a,b)
			if a.is_dir and not b.is_dir then
				return true
			end
			if not a.is_dir and b.is_dir then
				return false
			end
			return a.name < b.name
		end)
end

--[[
read pending messages and return error from current script, if available
]]
function con_methods:get_error_msg()
	while true do
		local msg = self:read_msg()
		if msg.type == 'none' then
			return false
		end
		if msg.type == 'error' and msg.script_id == self:get_script_id() then
			return msg
		end
		util.warnf("chdku.get_error_msg: ignoring message %s\n",chdku.format_script_msg(msg))
	end
end

--[[
format a remote lua error from chdku.exec using line number information
NOTE errors inside loadstring() etc are not correctly identified
]]
function chdku.format_exec_error(execinfo,msg)
	local errmsg = msg.value
	local lnum=tonumber(string.match(errmsg,'^%s*:(%d+):'))
	if not lnum then
		return string.format('format_exec_error: line num not found\n%s',errmsg)
	end
	if not (execinfo and execinfo.libs and execinfo.code) then
		return string.format("format_exec_error: no execinfo\n%s\n",errmsg)
	end
	local l = 0
	local lprev, errlib, errlnum
	for i,lib in ipairs(execinfo.libs.list) do
		lprev = l
		l = l + lib.lines + 1 -- TODO we add \n after each lib when building code
		if l >= lnum then
			errlib = lib
			errlnum = lnum - lprev
			break
		end
	end
	if errlib then
		return string.format("%s\nrlib %s:%d\n",errmsg,errlib.name,errlnum)
	else
		return string.format("%s\nuser code: %d\n",errmsg,lnum - l)
	end
end

--[[
read and discard all pending messages.
throws on error
]]
function con_methods:flushmsgs()
	repeat
		local msg=self:read_msg()
	until msg.type == 'none'
end

--[[
read all pending messages, processing as specified by opts
opts {
	default=handler -- for all not matched by a specific handler
	user=handler
	return=handler
	error=handler
	values=bool -- store value, unserialized if table for return and user messages
}
handler = table or function(msg,opts)
throws on error
returns true unless aborted by handler
handler function may abort by returning false or throwing
]]
function con_methods:read_all_msgs(opts)
	opts = util.extend_table({},opts)
	-- if an 'all' handler is given, use it for any that don't have a specific handler
	if opts.default then
		for i,mtype in ipairs({'user','return','error'}) do
			if opts[mtype] == nil then
				opts[mtype] = opts.default
			end
		end
	end
	local handlers = {}
	for i,mtype in ipairs({'user','return','error'}) do
		local h = opts[mtype]
		local htype = type(h)
		if htype == 'function' then
			handlers[mtype] = h
		elseif htype == 'table' then
			handlers[mtype] = function(v)
				table.insert(h,v)
			end
		elseif opts[mtype] then -- nil or false = ignore
			errlib.throw{etype='bad_arg',msg='read_all_msgs: invalid handler: '..tostring(h)}
		end
	end

	while true do
		local msg=self:read_msg()
		if msg.type == 'none' then
			break
		end
		local v
		if msg.type == 'return' or msg.type == 'user' and opts.values then
			if msg.subtype == 'table' then
				local err
				v,err = util.unserialize(msg.value)
				if err then
					errlib.throw{etype='unserialize',msg=tostring(err)}
				end
			else
				v = msg.value
			end
		else
			v = msg
		end
		local status,err = handlers[msg.type](v,opts)
		-- only explicit false aborts
		if status == false then
			return false, err
		end
	end
	return true
end

function chdku.msg_unbatcher_dbgstr(self,chunk)
	if chunk._dbg then
		printf("dbg: %s\n",tostring(chunk._dbg))
	end
end
--[[
return a closure to be used with as a chdku.exec msgs function, which unbatches messages msg_batcher into t
]]
function chdku.msg_unbatcher(t)
	local i=1
	return function(msg)
		if msg.subtype ~= 'table' then
			errlib.throw{etype='wrongmsg_sub',msg='wrong message subtype: ' ..tostring(msg.subtype)}
		end
		local chunk,err=util.unserialize(msg.value)
		if err then
			errlib.throw{etype='unserialize',msg=tostring(err)}
		end
		for j,v in ipairs(chunk) do
			t[i]=v
			i=i+1
		end
		if type(t._dbg_fn) == 'function' then
			t:_dbg_fn(chunk)
		end
		return true
	end
end
--[[
wrapper for chdk.execlua, using optional code from rlibs
[remote results]=con:exec("code",opts)
opts {
	libs={"rlib name1","rlib name2"...} -- rlib code to be prepended to "code"
	wait=bool -- wait for script to complete, return values will be returned after status if true
	nodefaultlib=bool -- don't automatically include default rlibs
	clobber=bool -- if false, will check script-status and refuse to execute if script is already running
				-- clobbering is likely to result in crashes / memory leaks in chdk prior to 1.3
	flush_cam_msgs=bool -- if true (default) read and silently discard any pending messages from previous script before running script
					-- Prior to 1.3, ignored if clobber is true, since the running script could just spew messages indefinitely
	flush_host_msgs=bool -- Only supported in 1.3 and later, flush any message from the host unread by previous script
	execinfo=table -- table to receive context information for format_exec_error
	-- below only apply if wait is set
	msgs={table|callback} -- table or function to receive user script messages
	rets={table|callback} -- table or function to receive script return values, instead of returning them
	fdata={any lua value} -- data to be passed as second argument to callbacks
	initwait={ms|false} -- passed to first wait_status call, wait before first poll
						-- Use to avoid polling before script has a chance to execute
	poll={ms} -- passed to wait_status, poll interval after ramp up
	pollstart={ms|false} -- passed to wait_status, initial poll interval, ramps up to poll
						-- note poll rate is reset to pollstart each time a message is received
}
callbacks
	f(message,fdata)
	callbacks should throw an error to abort processing
	return value is ignored

execinfo {
	code=string -- complete script code
	libs=array -- rlib names
	start_time=number -- script start time
}

returns
	if wait is set and rets is not, returns values returned by remote code
	otherwise returns nothing

throws on error
]]
-- use serialize by default
chdku.default_libs={
	'serialize_msgs',
}

-- script execute flags, for proto 2.6 and later
chdku.execflags={
	nokill=0x100,
	flush_cam_msgs=0x200,
	flush_host_msgs=0x400,
}

--[[
convenience, defaults wait=true
]]
function con_methods:execwait(code,opts_in)
	return self:exec(code,util.extend_table({wait=true,initwait=5},opts_in))
end

function con_methods:exec(code,opts_in)
	-- setup the options
	local opts = util.extend_table({flush_cam_msgs=true,flush_host_msgs=true},opts_in)
	local liblist={}
	-- add default libs, unless disabled
	-- TODO default libs should be per connection
	if not opts.nodefaultlib then
		util.extend_table(liblist,chdku.default_libs)
	end
	-- allow a single lib to be given as by name
	if type(opts.libs) == 'string' then
		liblist={opts.libs}
	else
		util.extend_table(liblist,opts.libs)
	end

	local execinfo = opts.execinfo or {}

	local execflags = 0
	-- in protocol 2.6 and later, handle kill and message flush in script exec call
	if self:is_ver_compatible(2,6) then
		if not opts.clobber then
			execflags = chdku.execflags.nokill
		end
		-- TODO this doesn't behave the same as flushmsgs in pre 2.6
		-- works whether or not clobber is set, flushes both inbound and outbound
		if opts.flush_cam_msgs then
			execflags = execflags + chdku.execflags.flush_cam_msgs
		end
		if opts.flush_host_msgs then
			execflags = execflags + chdku.execflags.flush_host_msgs
		end
	else
		-- check for already running script and flush messages
		if not opts.clobber then
			-- this requires an extra PTP round trip per exec call
			local status = self:script_status()
			if status.run then
				errlib.throw({etype='execlua_scriptrun',msg='a script is already running'})
			end
			if opts.flush_cam_msgs and status.msg then
				self:flushmsgs()
			end
		end
	end

	-- build the complete script from user code and rlibs
	local libs = chdku.rlibs:build(liblist)
	code = libs:code() .. code

	execinfo.libs = libs
	execinfo.code = code
	execinfo.start_time = ticktime.get()

	-- try to start the script
	-- catch errors so we can handle compile errors
	local status,err=self:execlua_pcall(code,execflags)
	if not status then
		-- syntax error, try to fetch the error message
		if err.etype == 'execlua_compile' then
			local msg = self:get_error_msg()
			if msg then
				-- add full details to message
				-- TODO could just add to a new field and let caller deal with it
				-- but would need lib code
				err.msg = chdku.format_exec_error(execinfo,msg)
			end
		end
		--  other unspecified error, or fetching syntax/compile error message failed
		error(err)
	end

	-- if not waiting, we're done
	if not opts.wait then
		return
	end

	-- to collect return values
	local results={}
	local i=1

	-- process messages and wait for script to end
	local initwait = opts.initwait
	while true do
		status=self:wait_status{
			msg=true,
			run=false,
			initwait=initwait,
			poll=opts.poll,
			pollstart=opts.pollstart
		}
		-- initwait only controls the wait for the first wait after execution start
		initwait = nil
		if status.msg then
			local msg=self:read_msg()
			if msg.script_id ~= self:get_script_id() then
				util.warnf("chdku.exec: message from unexpected script %d %s\n",msg.script_id,chdku.format_script_msg(msg))
			elseif msg.type == 'user' then
				if type(opts.msgs) == 'function' then
					opts.msgs(msg,opts.fdata)
				elseif type(opts.msgs) == 'table' then
					table.insert(opts.msgs,msg)
				else
					util.warnf("chdku.exec: unexpected user message %s\n",chdku.format_script_msg(msg))
				end
			elseif msg.type == 'return' then
				if type(opts.rets) == 'function' then
					opts.rets(msg,opts.fdata)
				elseif type(opts.rets) == 'table' then
					table.insert(opts.rets,msg)
				else
					-- if serialize_msgs is not selected, table return values will be strings
					if msg.subtype == 'table' and libs.map['serialize_msgs'] then
						results[i] = util.unserialize(msg.value)
					else
						results[i] = msg.value
					end
					i=i+1
				end
			elseif msg.type == 'error' then
				errlib.throw{etype='exec_runtime',msg=chdku.format_exec_error(execinfo,msg)}
			else
				errlib.throw({etype='wrongmsg',msg='unexpected msg type: '..tostring(msg.type)})
			end
		end
		-- script is completed
		if status.run == false then
			-- all messages have been processed, done
			if status.msg == false then
				-- returns were handled by callback or table
				if opts.rets then
					return
				else
					return unpack(results,1,table.maxn(results)) -- maxn expression preserves nils
				end
			end
		end
	end
end

--[[
convenience method, get a message of a specific type
mtype=<string> - expected message type
msubtype=<string|nil> - expected subtype, or nil for any
munserialize=<bool> - unserialize and return the message value, only valid for user/return

returns
message|msg value
]]
function con_methods:read_msg_strict(opts)
	opts=util.extend_table({},opts)
	local msg=self:read_msg()
	if msg.type == 'none' then
		errlib.throw({etype='nomsg',msg='read_msg_strict no message'})
	end
	if msg.script_id ~= self:get_script_id() then
		errlib.throw({etype='bad_script_id',msg='msg from unexpected script id'})
	end
	if msg.type ~= opts.mtype then
		if msg.type == 'error' then
			errlib.throw({etype='wrongmsg_error',msg='unexpected error: '..msg.value})
		end
		errlib.throw({etype='wrongmsg',msg='unexpected msg type: '..tostring(msg.type)})
	end
	if opts.msubtype and msg.subtype ~= opts.msubtype then
		errlib.throw({etype='wrongmsg_sub',msg='wrong message subtype: ' ..msg.subtype})
	end
	if opts.munserialize then
		local v = util.unserialize(msg.value)
		if opts.msubtype and type(v) ~= opts.msubtype then
			errlib.throw({etype='unserialize',msg='unserialize error'})
		end
		return v
	end
	return msg
end
--[[
convenience method, wait for a single message and return it
throws if matching message is not available within timeout
opts passed wait_status, and read_msg_strict
]]
function con_methods:wait_msg(opts)
	opts=util.extend_table({},opts)
	opts.msg=true
	opts.run=nil
	local status=self:wait_status(opts)
	if status.timeout then
		errlib.throw({etype='timeout',msg='wait_msg timed out'})
	end
	if not status.msg then
		errlib.throw({etype='nomsg',msg='wait_msg no message'})
	end
	return self:read_msg_strict(opts)
end

-- bit number to ext + id mapping
chdku.remotecap_dtypes={
	[0]={
		ext='jpg',
		id=1,
-- actual limit isn't clear, sanity check so bad hook won't fill up disk
-- MAX_CHUNKS_FOR_JPEG is per session, dryos > r50 can have multiple sessions
		max_chunks=100,
	},
	{
		ext='raw',
		id=2,
		max_chunks=1,
	},
	{
		ext='dng_hdr', -- header only
		id=4,
		max_chunks=1,
	},
	{
		ext='cr2', -- canon raw
		id=8,
		max_chunks=100,
	},
}

--[[
return a handler that stores collected chunks into an array or using a function
]]
function chdku.rc_handler_store(store)
	local store_fn
	if type(store) == 'function' then
		store_fn = store
	elseif type(store) == 'table' then
		store_fn = function(val)
			table.insert(store,val)
		end
	else
		errlib.throw{etype='bad_arg',msg='rc_handler_store: invalid store target'}
	end
	return function(lcon,hdata)
		local chunk
		local n_chunks = 0
		repeat
			local status,err
			cli.dbgmsg('rc chunk get %d %d\n',hdata.id,n_chunks)
			chunk=lcon:capture_get_chunk(hdata.id)
			cli.dbgmsg('rc chunk size:%d offset:%s last:%s\n',
						chunk.size,
						tostring(chunk.offset),
						tostring(chunk.last))

			chunk.imgnum = hdata.imgnum -- for convenience, store image number in chunk
			store_fn(chunk)
			n_chunks = n_chunks + 1
		until chunk.last or n_chunks > hdata.max_chunks
		if n_chunks > hdata.max_chunks then
			errlib.throw{etype='protocol',msg='rc_handler_store: exceeded max_chunks'}
		end
	end
end

function chdku.rc_set_subst_state(state,hdata,opts)
	if opts.fmt then
		state.imgfmt=opts.fmt
	else
		-- uppercase for consistency with shoot
		state.imgfmt=string.upper(hdata.ext)
	end

	if opts.ext then
		state.ext=opts.ext
	else
		state.ext=hdata.ext
	end
	-- ext includes the . to match other subst functions
	state.ext='.'..state.ext
	state.imgpfx='IMG' -- TODO could vary based on type, or from cam settings
	state.imgnum=string.format('%04d',hdata.imgnum)
	state.basename=string.format('%s_%s',state.imgpfx,state.imgnum)
	state.name=state.basename..state.ext
end

function chdku.rc_build_path(hdata,opts)
	local filename = opts.dst
	if filename then
		if hdata.subst then
			chdku.rc_set_subst_state(hdata.subst.state,hdata,opts)
			return hdata.subst:run(filename)
		end
	else
		filename = string.format('IMG_%04d',hdata.imgnum)
	end

	if opts.ext then
		filename = filename..'.'..opts.ext
	else
		filename = filename..'.'..hdata.ext
	end

	if opts.dst_dir then
		filename = fsutil.joinpath(opts.dst_dir,filename)
	end
	return filename
end

function chdku.rc_process_dng(dng_info,raw)
	local hdr,err=dng.bind_header(dng_info.hdr)
	if not hdr then
		error(err)
	end
	-- TODO makes assumptions about header layout
	local ifd=hdr:get_ifd{0,0} -- assume main image is first subifd of first ifd
	if not ifd then
		error('ifd 0.0 not found')
	end
	local ifd0=hdr:get_ifd{0} -- assume thumb is first ifd
	if not ifd0 then
		error('ifd 0 not found')
	end

	raw.data:reverse_bytes()

	local bpp = ifd.byname.BitsPerSample:getel()
	local width = ifd.byname.ImageWidth:getel()
	local height = ifd.byname.ImageLength:getel()

	cli.dbgmsg('dng %dx%dx%d\n',width,height,bpp)

	-- values are assumed to be valid
	-- sub-image, pad
	if dng_info.lstart ~= 0 or dng_info.lcount ~= 0 then
		-- TODO assume a single strip with full data
		local fullraw = lbuf.new(ifd.byname.StripByteCounts:getel())
		local offset = (width * dng_info.lstart * bpp)/8;
		--local blacklevel = ifd.byname.BlackLevel:getel()
		-- filling with blacklevel would be nicer but max doesn't care about byte order
		fullraw:fill(string.char(0xff),0,offset) -- fill up to data
		-- copy
		fullraw:fill(raw.data,offset,1)
		fullraw:fill(string.char(0xff),offset+raw.data:len()) -- fill remainder
		-- replace original data
		raw.data=fullraw
	end


	local twidth = ifd0.byname.ImageWidth:getel()
	local theight = ifd0.byname.ImageLength:getel()

	local status, err = pcall(hdr.set_data,hdr,raw.data)
	if not status then
		cli.dbgmsg('not creating thumb: %s\n',tostring(err))
		dng_info.thumb = lbuf.new(twidth*theight*3)
		return -- thumb failure isn't fatal
	end
	if dng_info.badpix then
		cli.dbgmsg('patching badpixels: ')
		local bcount=hdr.img:patch_pixels(dng_info.badpix) -- TODO should use values from opcodes
		cli.dbgmsg('%d\n',bcount)
	end

	cli.dbgmsg('creating thumb: %dx%d\n',twidth,theight)
	-- TODO assumes header is set up for RGB uncompressed
	-- TODO could make a better / larger thumb than default and adjust entries
	dng_info.thumb = hdr.img:make_rgb_thumb(twidth,theight)
end
--[[
return a raw handler that will take a previously received dng header and build a DNG file
dng_info:
	lstart=<number> sub image start
	lcount=<number> sub image lines
	hdr=<lbuf> dng header lbuf

]]
function chdku.rc_handler_raw_dng_file(hopts,dng_info)
	if not dng_info then
		errlib.throw{etype='bad_arg',msg='rc_handler_raw_dng_file: missing dng_info'}
	end
	return function(lcon,hdata)
		local filename = chdku.rc_build_path(hdata,hopts)
		if not dng_info.hdr then
			errlib.throw{etype='bad_arg',msg='rc_handler_raw_dng_file: missing dng_info.hdr'}
		end

		cli.dbgmsg('rc file %s %d\n',filename,hdata.id)
		cli.dbgmsg('rc chunk get %s %d\n',filename,hdata.id)
		local raw=lcon:capture_get_chunk(hdata.id)
		cli.dbgmsg('rc chunk size:%d offset:%s last:%s\n',
						raw.size,
						tostring(raw.offset),
						tostring(raw.last))
		chdku.rc_process_dng(dng_info,raw)
		fsutil.mkdir_parent(filename)
		local fh=fsutil.open_e(filename,'wb')
		dng_info.hdr:fwrite(fh)
		--fh:write(string.rep('\0',128*96*3)) -- fake thumb
		dng_info.thumb:fwrite(fh)
		raw.data:fwrite(fh)
		fh:close()
	end
end
--[[
return a handler function that just downloads the data to a file
TODO should stream to disk in C code like download
]]
function chdku.rc_handler_file(hopts)
	return function(lcon,hdata)
		local filename = chdku.rc_build_path(hdata,hopts)
		cli.dbgmsg('rc file %s %d\n',filename,hdata.id)

		fsutil.mkdir_parent(filename)
		local fh = fsutil.open_e(filename,'wb')

		local chunk
		local n_chunks = 0
		-- note only jpeg has multiple chunks
		-- pcall to allow closing file on error
		local status,err=pcall(function()
			repeat
				cli.dbgmsg('rc chunk get %s %d %d\n',filename,hdata.id,n_chunks)
				chunk=lcon:capture_get_chunk(hdata.id)
				cli.dbgmsg('rc chunk size:%d offset:%s last:%s\n',
							chunk.size,
							tostring(chunk.offset),
							tostring(chunk.last))

				if chunk.offset then
					fh:seek('set',chunk.offset)
				end
				if chunk.size ~= 0 then
					chunk.data:fwrite(fh)
				else
					-- TODO zero size chunk could be valid but doesn't appear to show up in normal operation
					util.warnf('ignoring zero size chunk\n')
				end
				n_chunks = n_chunks + 1
			until chunk.last or n_chunks > hdata.max_chunks
		end)
		fh:close()
		if not status then
			error(err)
		end
		if n_chunks > hdata.max_chunks then
			errlib.throw{etype='protocol',msg='rc_handler_file: exceeded max_chunks'}
		end
	end
end
--[[
create handlers suitable for saving jpg, dng and raw files
opts {
	jpg=bool -- jpeg
	dng=bool -- dng file, combining raw with dng header (exclusive with raw and dng_hdr)
	raw=bool -- CHDK frambuffer raw
	dnghdr=bool -- DNG header alone
	craw=bool -- canon raw (only for cameras with filewrite and native raw support)
	dst=string -- destination file base name
	dst_dir=string -- destination directory
	badpix=bool -- threshold to patch bad pixels in in dng
	lstart=number -- starting line for sub-image dng (default = 0)
	lcount=number -- number of lines for sub-image dng (default = 0 = all)
]]
function chdku.rc_init_std_handlers(opts)
	opts=util.extend_table({
		lstart=0,
		lcount=0,
	},opts)
	local hopts=util.extend_table({},opts,{keys={'dst','dst_dir'}})
	local rcopts={}
	if opts.jpg then
		rcopts.jpg=chdku.rc_handler_file(hopts)
	end
	if opts.craw then
		rcopts.craw=chdku.rc_handler_file(hopts)
	end
	if opts.dng then
		if opts.raw or opts.dng_hdr then
			errlib.throw{etype='bad_arg',msg='rc_init_std_handlers: dng cannot be combined with raw or dng_hdr'}
		end
		if opts.badpix == true then
			opts.badpix = 0
		end
		-- local structure used for dng options, and to pass header from header handler to DNG handler
		local dng_info = {
			lstart=opts.lstart,
			lcount=opts.lcount,
			badpix=opts.badpix,
		}
		rcopts.dng_hdr = chdku.rc_handler_store(function(chunk) dng_info.hdr=chunk.data end)
		rcopts.raw = chdku.rc_handler_raw_dng_file(util.extend_table({ext='dng',fmt='DNG'},hopts),dng_info)
	else
		if opts.raw then
			rcopts.raw=chdku.rc_handler_file(hopts)
		end
		if opts.dnghdr then
			rcopts.dng_hdr=chdku.rc_handler_file(hopts)
		end
	end
	return rcopts
end

function con_methods:capture_is_api_compatible()
	return self:is_ver_compatible(2,5)
end
--
--[[
fetch remote capture data
results=con:capture_get_data(opts)
opts:
	timeout, initwait, poll, pollstart -- passed to wait_status
									-- note wait_status is called for each
									-- chunk and script message
	jpg=handler,
	raw=handler,
	dng_hdr=handler,
	craw=handler,
	msg_handlers=table -- table of handlers for con:read_all_msgs
					-- default: user and return messages are unserialized and stored in results
					-- errors are re-thrown, aborting capture_get_data
	wait_script=bool -- wait for script to end, consuming messages
					-- note if wait_script is false, which messages are collected depends
					-- on the timing of the data transfer relative to the script
					-- default: False
	wait_script_timeout,wait_script_poll -- passed to wait_status for script end wait
	execinfo=table -- execinfo from con:exec, to allow formatting script error messages

handler: - capture data chunk handlers
	f(lcon,handler_data)
	handlers should throw with error() on error, return values are ignored
handler_data:
	ext -- extension from remotecap dtypes
	id  -- data type number
	opts -- options passed to capture_get_data
	imgnum -- image number
results:
	msgs_return=table|nil - script messages, if function handler not specified
	msgs_user=table|nil - script return messages,  if function handler not specified

	throws on error
]]
function con_methods:capture_get_data(opts)
	opts=util.extend_table({
		timeout=20000,
		shotseq=1,
		wait_script=false,
		wait_script_timeout=10000,
		wait_script_poll=100,
	},opts)
	local wait_opts=util.extend_table({
		rsdata=true,
		timeout_error=true,
		msg=true,
	},opts,{keys={'timeout','initwait','poll','pollstart'}})

	local toget = {}
	local handlers = {}

	if not self:capture_is_api_compatible() then
		error("camera does not support remote capture")
	end


	-- TODO can probably combine these
	if opts.jpg then
		toget[0] = true
		handlers[0] = opts.jpg
	end
	if opts.raw then
		toget[1] = true
		handlers[1] = opts.raw
	end
	if opts.dng_hdr then
		toget[2] = true
		handlers[2] = opts.dng_hdr
	end
	if opts.craw then
		toget[3] = true
		handlers[3] = opts.craw
	end

	local subst

	local results = { }

	if not opts.msg_handlers then
		opts.msg_handlers = { }
	end
	-- don't use extend_table to ensure original opts table is used and passed handlers
	for i,mtype in ipairs{'user','return'} do
		if opts.msg_handlers[mtype] == nil then
			opts.msg_handlers[mtype] = {}
		end
		if type(opts.msg_handlers[mtype]) == 'table' then
			results['msgs_'..mtype] = opts.msg_handlers[mtype]
		end
	end
	if opts.msg_handlers.error == nil then
		opts.msg_handlers.error = function(msg)
			errlib.throw{etype='exec_'..msg.subtype,msg=chdku.format_exec_error(opts.execinfo,msg)}
		end
	end

	local done
	local status
	while not done do
		-- note a script spamming messages could avoid timeout
		status = self:wait_status(wait_opts)
		if status.rsdata == 0x10000000 then
			error('remote shoot error')
		end
		if status.rsdata then
			-- initialize subst state when first data available, ~shot time
			if opts.do_subst and not subst then
				subst=varsubst.new(chdku.rc_subst_funcs)
				self:set_subst_con_state(subst.state)
				chdku.set_subst_time_state(subst.state)
				-- each capture_get_data only handles one shot, so caller is responsible for incrementing
				subst.state.shotseq = opts.shotseq
			end

			local avail = util.bit_unpack(status.rsdata)
			local n_toget = 0
			for i=0,3 do
				if avail[i] == 1 then
					if not toget[i] then
						error(string.format('unexpected type %d',i))
					end
					local hdata = util.extend_table({
						subst=subst,
						opts=opts,
						imgnum=status.rsimgnum,
					},chdku.remotecap_dtypes[i])

					handlers[i](self,hdata)
					toget[i] = nil
				end
				if toget[i] then
					n_toget = n_toget + 1
				end
			end
			if n_toget == 0 then
				done = true
			end
		end
		if status.msg then
			self:read_all_msgs(opts.msg_handlers)
		end
	end
	if opts.wait_script and status.run then
		while status.run do
			-- note a script spamming messages could avoid timeout
			status = self:wait_status{
				run = false,
				msg = true,
				timeout = opts.wait_script_timeout,
				timeout_error = true,
				poll = opts.wait_script_poll,
			}
			if status.msg then
				self:read_all_msgs(opts.msg_handlers)
			end
		end
	else
		-- process any remaining messages, since read in main loop happens
		-- after potentially long transfer without re-checking status
		self:read_all_msgs(opts.msg_handlers)
	end
	return results
end

--[[
sleep until specified status is matched
status=con:wait_status(opts)
opts:
{
	-- msg/run bool values cause the function to return when the status matches the given value
	-- if not set, status of that item is ignored
	msg=bool
	run=bool
	rsdata=bool -- if true, return when remote capture data available, data in status.rsdata
	timeout=<number> -- timeout in ms
	timeout_error=bool -- if true, an error is thrown on timeout instead of returning it in status
	poll=<number> -- polling interval in ms
	pollstart=<number> -- if not false, start polling at pollstart, double interval each iteration until poll is reached
	initwait=<number> -- wait N ms before first poll. If this is long enough for call to finish, saves round trip
}
-- TODO should allow passing in a custom sleep in opts
status:
{
	msg:bool -- message status
	run:bool -- script status
	rsdata:number -- available remote capture data format
	rsimgnum:number -- remote capture image number
	timeout:bool -- true if timed out
}
rs values are only set if rsdata is requested in opts
throws on error
]]
function con_methods:wait_status(opts)
	opts = util.extend_table({
		poll=250,
		pollstart=4,
		timeout=86400000 -- 1 day
	},opts)
	local timeleft = opts.timeout
	local sleeptime
	if opts.poll < 50 then
		opts.poll = 50
	end
	if opts.pollstart then
		sleeptime = opts.pollstart
	else
		sleeptime = opts.poll
	end
	if opts.initwait then
		chdku.sleep(opts.initwait)
		timeleft = timeleft - opts.initwait
	end
	-- if waiting on remotecap state, make sure it's supported
	if opts.rsdata then
		if not self:capture_is_api_compatible() then
			error('camera does not support remote capture')
		end
		if type(self.capture_ready) ~= 'function' then
			error('client does not support remote capture')
		end
	end

	-- TODO timeout should be based on time, not adding up sleep times
	-- local t0=ustime.new()
	while true do
		-- TODO shouldn't poll script status if only waiting on rsdata
		local status = self:script_status()
		if opts.rsdata then
			local imgnum
			status.rsdata,imgnum = self:capture_ready()
			-- TODO may want to handle PTP_CHDK_CAPTURE_NOTSET differently
			if status.rsdata ~= 0 then
				status.rsimgnum = imgnum
				return status
			end
		end
		if status.run == opts.run or status.msg == opts.msg then
			return status
		end
		if timeleft > 0 then
			if opts.pollstart and sleeptime < opts.poll then
				sleeptime = sleeptime * 2
				if sleeptime > opts.poll then
					sleeptime = opts.poll
				end
			end
			if timeleft < sleeptime then
				sleeptime = timeleft
			end
			chdku.sleep(sleeptime)
			timeleft = timeleft - sleeptime
		else
			if opts.timeout_error then
				errlib.throw{etype='timeout',msg='timed out'}
			end
			status.timeout=true
			return status
		end
	end
end

--[[
return array of chdkptp PTP code extension IDs applicable to current connection
]]
function con_methods:get_ptp_ext_code_ids()
	local r={}
	-- check for matching manufacturer first
	for k,v in pairs(ptp.groups) do
		-- USB vendor ID. Not present for PTP/IP
		if self.condev and self.condev.vendor_id and self.condev.vendor_id == v.usb_vendor_id then
			table.insert(r,k)
			break
		end
		if self.ptpdev and self.ptpdev.manufacturer and self.ptpdev.manufacturer == v.vendor_str then
			table.insert(r,k)
			break
		end
	end
	-- MTP device may use 6 or 0xFFFFFFFF as extension ID. don't add MTP_EXT
	-- because clashes with other IDs.
	-- According to MTP spec, extensions to MTP should theoretically be
	-- identified in VendorExtensionDesc, but in practice Canon does not
	if self.ptpdev and (self.ptpdev.VendorExtensionID == 6 or self.ptpdev.VendorExtensionID == 0xffffffff) then
		table.insert(r, 'MTP')
	end
	return r
end

--[[
return string name and extension ID for code in extensions supported by current connection
codetype is one of 'OC', 'EC', 'OFC', 'DPC' or 'RC'
code is numeric code ID
returns name, group id if found, otherwise false
]]
function con_methods:get_ptp_code_info(codetype,code)
	return ptp.get_code_info(codetype,code,self.ptp_code_ids)
end

--[[
return formatted string describing code
]]
function con_methods:get_ptp_code_desc(codetype,code)
	return ptp.fmt_code_desc(code,self:get_ptp_code_info(codetype,code))
end

--[[
build a map of supported operations etc
]]
function con_methods:get_ptp_supported_codes()
	local r={}
	for _,cdesc in ipairs(ptp.devinfo_code_map) do
		local k = cdesc.cid
		-- There are two lists of object format codes, for image and capture
		if k == 'OFC' and cdesc.devid == 'CaptureFormats' then
			k = 'OFC_cap'
		end
		r[k] = util.flag_table(self.ptpdev[cdesc.devid])
	end
	return r
end

--[[
update USB and PTP devinfo, along with stuff derived from PTP devinfo
]]
function con_methods:update_devinfo(opts)
	opts = opts or {}
	-- this currently can't fail, devinfo is always stored in connection object
	self.condev=self:get_con_devinfo()
	self.ptpdev=self:get_ptp_devinfo(opts.refresh_ptp)
	-- list PTP constant groups from ptpcodes modules which apply to this connection
	self.ptp_code_ids = {'STD',table.unpack(self:get_ptp_ext_code_ids())}
	self.ptp_support = self:get_ptp_supported_codes()
end

--[[
set condev, ptpdev, and apiver for current connection
throws on error
if CHDK extension not present or not checked, apiver is set to -1,-1 but no error is thrown
opts{
	chdk_check=bool|'force' -- get CHDK API version, default true
							-- false=don't check, true=check if opcode supported, 'force' check always
							-- not checking saves up to ~10ms depending on cam
	refresh_ptp=bool -- refresh ptp devinfo from device
}
]]
function con_methods:update_connection_info(opts)
	opts = util.extend_table({chdk_check=true},opts)
	self:update_devinfo(opts)
	if not opts.chdk_check or (opts.chdk_check ~= 'force' and not self.ptp_support.OC[ptp.CANON.OC.CHDK]) then
		-- NOTE this makes not checked equivalent to not supported
		self.apiver={MAJOR=-1,MINOR=-1}
		return
	end
	local status,major,minor=self:camera_api_version_pcall()
	if not status then
		local err = major
		-- device connected doesn't support PTP_OC_CHDK
		if err.ptp_rc == ptp.RC.OperationNotSupported then
			self.apiver={MAJOR=-1,MINOR=-1}
			return
		end
		error(err) -- re-throw
	end
	self.apiver={MAJOR=major,MINOR=minor}
end

--[[
handle prefs that affect behavior on connect
NOTE: NOT currently called in con:connect(), intended only for primary
CLI/GUI connections, not temp connections associated with list or
device matching
]]
function con_methods:do_on_connect_actions()
	-- should Canon firmware PTP mode be enabled?
	local ptp_mode_set
	if prefs.cam_connect_set_ptp_mode == 'always'
			or (prefs.cam_connect_set_ptp_mode == self.condev.transport) then
		-- Both getting object handles and querying MTP property support
		-- put the camera in PTP mode. Prefer MTP when available (most DryOS cams)
		-- as there can potentially be thousands of handles
		if self.ptp_support.OC[ptp.MTP.OC.GetObjectPropsSupported] and #con.ptpdev.ImageFormats then
			self:ptp_txn(ptp.MTP.OC.GetObjectPropsSupported,con.ptpdev.ImageFormats[1],{getdata='string'})
		else
			self:ptp_get_object_handles()
		end
		ptp_mode_set = true
	end
	if prefs.cam_connect_unlock_ui == 'always'
			or (prefs.cam_connect_unlock_ui == 'ptpset' and ptp_mode_set) then
		-- need to wait for transition to complete if locked
		-- TODO should expose cameracon_state in camera side lua, wait
		if ptp_mode_set then
			sys.sleep(250)
		end
		self:execwait('ptp_ui_unlock()',{libs='ptp_ui_unlock'})
	end
end

--[[
override low level connect to gather some useful information that shouldn't change over life of connection
opts - passed to con_methods:update_connection_info
]]
function con_methods:connect(opts)
	chdk_connection.connect(self._con)
	self:update_connection_info(opts)
end

--[[
attempt to reconnect to the device
opts{
	wait=<ms> -- amount of time to wait, default 2.5 sec to avoid probs with dev numbers changing
	strict=bool -- fail if model, pid or serial number changes
}
if strict is not set, reconnect to different device returns true, <message>
]]
function con_methods:reconnect(opts)
	opts=util.extend_table({
		wait=2500,
		strict=true,
	},opts)
	if self:is_connected() then
		self:disconnect()
	end
	local ptpdev = self.ptpdev
	local condev = self.condev
	-- appears to be needed to avoid device numbers changing (reset too soon ?)
	chdku.sleep(opts.wait)
	self:connect()
	if ptpdev.model ~= self.ptpdev.model
			or ptpdev.serial_number ~= self.ptpdev.serial_number
			or condev.product_id ~= self.condev.product_id then
		if opts.strict then
			self:disconnect()
			error('reconnected to a different device')
		else
			util.warnf('reconnected to a different device')
		end
	end
end

--[[
NOTE this only tells if the CHDK protocol supports live view
the live sub-protocol might not be fully compatible
]]
function con_methods:live_is_api_compatible()
	return self:is_ver_compatible(2,3)
end

--[[
get a new frame specified by 'what' to con.live._frame
throws on error
--]]
function con_methods:live_get_frame(what)
	self.live:set_frame(self:get_live_data(self.live._frame,what))
end

--[[
start dump to filename, default pid+date used if not set
throws on error
]]
function con_methods:live_dump_start(filename)
	if not self:is_connected() then
		errlib.throw{etype='not_connected',msg='not connected'}
	end
	if not self:live_is_api_compatible() then
		errlib.throw{etype='protocol',msg='api not compatible'}
	end
	self.live:dump_start(filename)
end

function con_methods:live_dump_frame()
	self.live:dump_frame()
end

-- TODO should ensure this is automatically called when connection is closed, or re-connected
function con_methods:live_dump_end()
	self.live:dump_end()
end

--[[
meta table for wrapped connection object
]]
local con_meta = {
	__index = function(t,key)
		return con_methods[key]
	end
}

--[[
proxy connection methods from low level object to chdku
]]
local function init_connection_methods()
	for name,func in pairs(chdk_connection) do
		if con_methods[name] == nil and type(func) == 'function' then
			con_methods[name] = function(self,...)
				return chdk_connection[name](self._con,...)
			end
			-- pcall variants for things that want to catch errors
			con_methods[name..'_pcall'] = function(self,...)
				return pcall(chdk_connection[name],self._con,...)
			end
		end
	end
end

init_connection_methods()

-- methods with pcall wrappers
-- generally stuff you would expect to want to examine the error rather than just throwing
-- or for direct use with cli:print_status
local con_pcall_methods={
	'connect',
	'exec',
	'execwait',
	'wait_status',
	'capture_get_data',
	'live_get_frame',
	'live_dump_start',
	'live_dump_frame',
	'ptp_txn',
	'ptpevp_initiate',
	'ptpevp_call',
	'ptpevp_terminate',
}
local function init_pcall_wrappers()
	for i,name in ipairs(con_pcall_methods) do
		if type(con_methods[name]) ~= 'function' then
			error('tried to wrap non-function '..tostring(name))
		end
		-- pcall variants for things that want to catch errors
		con_methods[name..'_pcall'] = function(self,...)
			return pcall(con_methods[name],self,...)
		end
	end
end
init_pcall_wrappers()

-- host api version
chdku.apiver = chdk.host_api_version()
-- host progam version
chdku.ver = chdk.program_version()
chdku.ver.FULL_STR =('%d.%d.%d'):format(chdku.ver.MAJOR,chdku.ver.MINOR,chdku.ver.BUILD)

--[[
bool = chdku.match_device(devinfo,match)
attempt to find a device specified by the match table
{
	bus='bus pattern'
	dev='device pattern'
	product_id = number
	vendor_id = number
	plain = bool -- plain text match
}
empty / false dev or bus matches any
]]
function chdku.match_device(devinfo,match)
--[[
	printf('try bus:%s (%s) dev:%s (%s) pid:%s (%s) vid:%s (%s)\n',
		devinfo.bus, tostring(match.bus),
		devinfo.dev, tostring(match.dev),
		devinfo.product_id, tostring(match.product_id),
		devinfo.vendor_id, tostring(match.vendor_id))
--]]
	if match.bus and not string.find(devinfo.bus,match.bus,1,match.plain) then
		return false
	end
	if match.dev and not string.find(devinfo.dev,match.dev,1,match.plain) then
		return false
	end
	if match.vendor_id and tonumber(match.vendor_id) ~= devinfo.vendor_id then
		return false
	end
	return (match.product_id == nil or tonumber(match.product_id)==devinfo.product_id)
end
--[[
return a connection object wrapped with chdku methods
devspec is a table specifying the bus and device name to connect to
no checking is done on the existence of the device
if devspec is null, a dummy connection is returned

TODO this returns a *new* wrapper object, even
if one already exist for the underlying object
not clear if this is desirable, could cache a table of them
]]
function chdku.connection(devspec)
	local con = {}
	setmetatable(con,con_meta)
	con._con = chdk.connection(devspec)
	con.live = lvutil.live_wrapper()
	return con
end

return chdku
