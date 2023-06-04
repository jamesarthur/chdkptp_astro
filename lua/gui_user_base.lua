--[[
(C)2014 msl

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
module for user tab in gui
a place for user defined stuff
]]

ini = require("iniLib")

local m={}

function m.get_container_title()
	return "User"
end

function m.init()
	--ini file for modul gui_user
	ini_user, new = ini.read("gui_user_cfg")
	if new then
		ini_user.dcim_download = {
			dest = lfs.currentdir().."/images",
			raw = "OFF",
			gps = "OFF",
			pre = "OFF"
		}
		ini_user.remote_capture = {
		dest = lfs.currentdir()
		}
		ini.write(ini_user)
	end
	m.rs_dest   = ini_user.remote_capture.dest
	m.imdl_dest = ini_user.dcim_download.dest
	m.imdl_raw  = ini_user.dcim_download.raw
	m.imdl_gps  = ini_user.dcim_download.gps
	m.imdl_pre  = ini_user.dcim_download.pre
	return
end

function m.toggle_raw(active)
	local new = active and 'ON' or 'OFF'
	if new ~= m.imdl_raw then
		m.imdl_raw = new
		ini_user.dcim_download.raw = m.imdl_raw
		ini.write(ini_user)
	end
end

function m.toggle_gps(active)
	local new = active and 'ON' or 'OFF'
	if new ~= m.imdl_gps then
		m.imdl_gps = new
		ini_user.dcim_download.gps = m.imdl_gps
		ini.write(ini_user)
	end
end

function m.toggle_pretend(active)
	local new = active and 'ON' or 'OFF'
	if new ~= m.imdl_pre then
		m.imdl_pre = new
		ini_user.dcim_download.pre = m.imdl_pre
		ini.write(ini_user)
	end
end

function m.set_remote_capture_destination()
	local selected, folder = gui.folder_select("Destination", m.rs_dest)
	if selected then
		m.rs_dest = folder
		--update to new ini selection
		ini_user.remote_capture.dest = m.rs_dest
		ini.write(ini_user)
		gui.infomsg("download destination %s\n", m.rs_dest)
	end
	return selected
end

function m.set_download_destination()
	local selected, folder = gui.folder_select("Destination", m.imdl_dest)
	if selected then
		m.imdl_dest = folder
		--update to new ini selection
		ini_user.dcim_download.dest = m.imdl_dest
		ini.write(ini_user)
		gui.infomsg("download destination %s\n", m.imdl_dest)
	end
	return selected
end

function m.do_download()
	if con:is_connected() then
		gui.infomsg("download started ...\n")
		local pre = m.imdl_pre == "ON" and "-pretend" or ""
		local cmd1 = "imdl "..pre.." -overwrite='n' -d="
		local cmd2 = "mdl "..pre.." -overwrite='n'"
		local path = string.gsub(m.imdl_dest, "\\", "/")
		if string.sub(path, #path) ~= "/" then path = path.."/" end
		local sub = "${mdate,%Y_%m_%d}/${name}"
		gui.add_status(cli:execute(cmd1..path..sub))
		if m.imdl_raw == "ON" then
			local check = con:execwait([[return os.stat("A/RAW")]])
			if check and check.is_dir then
				add_status(cli:execute(cmd1..path.."raw/"..sub.." A/RAW"))
			end
		end
		if m.imdl_gps == "ON" then
			local check = con:execwait([[return os.stat("A/DCIM/CANONMSC/GPS")]])
			if check and check.is_dir then
				gui.add_status(cli:execute(cmd2.." A/DCIM/CANONMSC/GPS "..path.."gps/"))
			end
		end
		gui.infomsg("... download finished\n")
	else
		gui.infomsg("No camera connected!\n")
	end
end

function m.do_jpg_remote_shoot()
	local cmd = string.format("rs '%s'", m.rs_dest)
	gui.add_status(cli:execute(cmd))
end

function m.do_dng_remote_shoot()
	local cmd = string.format("rs '%s' -dng", m.rs_dest)
	gui.add_status(cli:execute(cmd))
end

return m
