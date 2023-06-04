--[[
 Copyright (C) 2010-2019 <reyalp (at) gmail dot com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
]]
--[[
module for gui tree view - common code
]]

local m = {}

function m.do_download_dialog(remotepath, mtime)
	local selected, file = gui.file_select_for_save("Download " .. remotepath, fsutil.basename(remotepath))
	if selected then
		gui.dbgmsg("d %s->%s\n",remotepath,file)
		-- can't use mdownload here because local name might be different than remote basename
		gui.add_status(con:download_pcall(remotepath,file))
		gui.add_status(lfs.touch(file,chdku.ts_cam2pc(mtime)))
	end
end

function m.do_dir_download_dialog(remotepath)
	gui.dbgmsg('dir download dialog %s\n',remotepath)
	local selected, folder = gui.folder_select("Download contents of " .. remotepath, nil)
	if selected then
		gui.dbgmsg("d %s->%s",remotepath,folder)
		con:mdownload({remotepath}, folder, {nosubst=true})
		return true
	end

	return false
end

function m.do_dir_upload_dialog(remotepath)
	gui.dbgmsg('dir upload dialog %s\n',remotepath)
	local selected, folder = gui.folder_select("Upload contents to " .. remotepath, nil)
	if selected then
		gui.dbgmsg("u %s->%s\n",folder,remotepath)
		con:mupload({folder},remotepath)
		return true
	end

	return false
end

function m.do_upload_dialog(remotepath)
	gui.dbgmsg('upload dialog %s\n',remotepath)
	local selected, files = gui.file_select_multiple("Upload to " .. remotepath)
	if selected then
		gui.dbgmsg('upload value %s\n',tostring(files))
		-- note native windows dialog does not allow multi-select to include directories.
		-- If it did, each to-level directory contents would get dumped into the target dir
		-- should add an option to mupload to include create top level dirs
		-- gtk/linux doesn't allow either
		con:mupload(files,remotepath)
		return true
	end

	return false
end

function m.do_delete_dialog(path, isdir)
	local msg
	if isdir then
		msg = 'delete directory ' .. path .. ' and all contents ?'
	else
		msg = 'delete ' .. path .. ' ?'
	end
	local rv = false
	if gui.confirm_action("Confirm delete", msg) then
		con:mdelete({path})
		rv = true
	end
	return rv
end

function m.do_mkdir_dialog(remotepath)
	local dirname = m.get_dir_name(remotepath)
	if dirname and dirname ~= '' then
		gui.dbgmsg('mkdir: %s\n',dirname)
		gui.add_status(con:mkdir_m(fsutil.joinpath_cam(remotepath,dirname)))
		return true
	end
	gui.dbgmsg('mkdir canceled\n')
	return false
end

function m.do_properties_dialog(path, isdir, isfile, mtime, size)
	local ftype = isdir and 'directory' or isfile and 'file' or 'other'
	size = isdir and 'n/a' or string.format('%.0f', size)
	mtime = os.date('%c',chdku.ts_cam2pc(mtime))
	gui.info_popup('Properties', string.format("%s\ntype: %s\nsize: %s\nmodifed: %s\n",path,ftype,size,mtime))
end

function m.get_container_title()
	return "Files"
end

return m
