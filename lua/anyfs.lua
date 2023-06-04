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
--]]
--[[
file utilities that operate on local or camera files based on path
anything starting with A/ is assumed to be camera path. To avoid false
positives on local, relative paths starting with A/, use ./A/...
]]
local anyfs={}

function anyfs.is_remote(path)
	return (path:sub(1,2) == 'A/')
end
--[[
read the entire contents of file, throw on error
opts: {
	bin=boolean - open file in binary mode. Default text
                - Camera does not distinguish text v binary
	con=conection - connection for remote files, default global con
	nolua=boolean - do not attempt to stat. Call will fail on empty files
	missing_ok=boolean - return nil if file can't be stat'd
}
]]
function anyfs.readfile(path,opts)
	opts = util.extend_table({
		con=con, -- default to global con object
	},opts)
	if anyfs.is_remote(path) then
		return opts.con:readfile(path,opts)
	end
	return fsutil.readfile(path,opts)
end
--[[
write string or number to file, throw on error
opts: {
	bin=boolan  - write in binary mode
                - Camera does not distinguish text v binary
	con=conection - connection for remote files, default global con
	nolua=boolean - do not use remote Lua to create / check destination
	mkdir=boolean - create parent directories as needed, default true
}
Note append is not supported, because camera files are written with upload
]]
function anyfs.writefile(path,val,opts)
	opts = util.extend_table({
		con=con, -- default to global con object
		mkdir=true,
	},opts)
	-- check for append, since otherwise compatible with fsutil.writefile
	if opts.append then
		errlib.throw{etype='bad_arg',msg='append not implemented'}
	end
	if anyfs.is_remote(path) then
		opts.con:writefile(path,val,opts)
		return
	end
	fsutil.writefile(path,val,opts)
end
return anyfs
