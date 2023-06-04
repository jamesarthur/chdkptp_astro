--[[
(C)2020 philmoz

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
	return Gtk.Box {
		orientation = 'HORIZONTAL',
		spacing = 10,
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
	return Gtk.Frame {
		label = "Remote Capture",
		width_request = 180,
		Gtk.ButtonBox {
			orientation = 'VERTICAL',
			spacing = 10,
			layout_style = 'START',
			Gtk.Button {
				label = "Destination",
				--current path as tooltip
				tooltip_text = m.rs_dest,
				on_clicked = function(self)
					m.set_remote_capture_destination()
					--update path as tooltip
					self.tooltip_text = m.rs_dest
				end,
			},
			Gtk.Button {
				label = "JPG Remote Shoot",
				tooltip_text = "Does not work for all cameras!",
				on_clicked = function(self) m.do_jpg_remote_shoot() end,
			},
			Gtk.Button {
				label = "DNG Remote Shoot",
				on_clicked = function(self) m.do_dng_remote_shoot() end,
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
	return Gtk.Frame {
		label = "Pic&Vid Download",
		width_request = 180,
		Gtk.ButtonBox {
			orientation = 'VERTICAL',
			spacing = 10,
			layout_style = 'START',
			Gtk.Button {
				label = "Destination",
				--current path as tooltip
				tooltip_text = m.imdl_dest,
				on_clicked = function(self)
					m.set_download_destination()
					--update path as tooltip
					self.tooltip_text = m.imdl_dest
				end,
			},
			Gtk.Button {
				label = "Download",
				tooltip_text = "Does not overwrite existing files",
				on_clicked = function(self) m.do_download() end,
			},
			Gtk.CheckButton {
				label = "incl. A/RAW",
				active = m.imdl_raw == 'ON',
				on_toggled = function(self) m.toggle_raw(self.active) end,
			},
			Gtk.CheckButton {
				label = "incl. GPS data",
				active = m.imdl_gps == 'ON',
				on_toggled = function(self) m.toggle_gps(self.active) end,
			},
			Gtk.CheckButton {
				label = "pretend",
				active = m.imdl_pre == 'ON',
				on_toggled = function(self) m.toggle_pretend(self.active) end,
			},
		},
	}
end

return m
