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

local m = require('gui_user_base')

function m.get_container()
	return iup.hbox{
		margin="4x4",
		gap="10",
		m.remote_capture_ui(),
		m.dcim_download_ui(),
	}
end

--[[
remote capture function as gui function
* Destination - dialog for file destination, default is chdkptp dir
* JPG Remote Shoot - shoot and save a JPG file in the destination (only available for cameras that support filewrite_task)
* DNG Remote Shoot - shoot and save a DNG file in the destination
]]
function m.remote_capture_ui()
	return iup.frame{
		title="Remote Capture",
		iup.vbox{
			gap="10",
			iup.button{
				title="Destination",
				size="75x15",
				fgcolor="0 0 255",
				--current path as tooltip
				tip=m.rs_dest,
				action=function(self)
					m.set_remote_capture_destination()
					--update path as tooltip
					self.tip = m.rs_dest
				end,
			},
			iup.button{
				title="JPG Remote Shoot",
				size="75x15",
				fgcolor="255 0 0",
				tip="Does not work for all cameras!",
				action=function(self) m.do_jpg_remote_shoot() end,
			},
			iup.button{
				title="DNG Remote Shoot",
				size="75x15",
				fgcolor="255 0 0",
				action=function(self) m.do_dng_remote_shoot() end,
			},
		},
	}
end

--[[
-simple GUI mode for image download
-default destination is chdkptp/images
-subdirs are organized by capture date
-optional download from A/RAW & GPS data
]]
function m.dcim_download_ui()
	return iup.frame{
		title="Pic&Vid Download",
		iup.vbox{
			gap="10",
			iup.button{
				title="Destination",
				size="75x15",
				fgcolor="0 0 255",
				--current path as tooltip
				tip=m.imdl_dest,
				action=function(self)
					m.set_download_destination()
					--update path as tooltip
					self.tip = m.imdl_dest
				end,
			},
			iup.button{
				title="Download",
				size="75x15",
				fgcolor="0 0 0",
				tip="Does not overwrite existing files",
				action=function(self) m.do_download() end,
			},
			iup.toggle{
				title = "incl. A/RAW",
				value = m.imdl_raw,
				action=function(self, state) m.toggle_raw(state==1) end,
			},
			iup.toggle{
				title = "incl. GPS data",
				value = m.imdl_gps,
				action=function(self, state) m.toggle_gps(state==1) end,
			},
			iup.toggle{
				title = "pretend",
				value = m.imdl_pre,
				action=function(self, state) m.toggle_pretend(state==1) end,
			},
		},
	}
end

return m
