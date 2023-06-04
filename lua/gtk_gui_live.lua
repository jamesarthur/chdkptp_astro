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
module for live view gui
]]
local m = require'gui_live_base'
local GdkPixbuf = lgi.GdkPixbuf
local prefctl=require'gtk_gui_prefctl'

--[[
update canvas size from frame
]]
function m.update_canvas_size()
	local active, vp_w, vp_h = m.frame_size()
	if active then
		if m.pixbuf.width ~= vp_w or m.pixbuf.height ~= vp_h then
			m.resize_canvas_count = m.resize_canvas_count + 1
			m.pixbuf = GdkPixbuf.Pixbuf.new('RGB', true, 8, vp_w, vp_h)
			m.pixbuf:fill(0x000000FF)
			m.area:set_size_request(vp_w, vp_h)
			gui.resize_for_content()
		end
	end
end

function m.set_stats_text(str)
	m.statslabel.label = str
end

function m.set_frame_time(time)
	if not time then time = 100 end
	m.frame_time = time
	if gui.is_live_view() then
		if not m.sched then
			m.sched = gui.sched.run_repeat(m.frame_time,function()
				local cstatus,msg = xpcall(m.frame_timer_action,errutil.format)
				if not cstatus then
					printf('live timer update error\n%s\n',tostring(msg))
					-- TODO could stop live updates here, for now just spam the console
				end
			end)
			m.skip_frames = 0
			m.skip_count = 0
		else
			m.sched.time = m.frame_time
		end
	else
		if m.sched then
			m.sched:cancel()
			m.sched = nil
		end
		m.stats:stop()
	end
end

m.redraw_canvas = errutil.wrap(function()
	if not gui.is_live_view() then
		return;
	end
	m.redraw_count = m.redraw_count+1
	local lv_new_frame = (m.lv_frame_num ~= m.lv_frame_drawn)
	if lv_new_frame then
		m.stats:start_frame()
		m.lv_frame_drawn = m.lv_frame_num
	end
	m.pixbuf:fill(0x000000FF)
	local lv = m.get_current_frame_data()
	if lv and lv._frame then
		if prefs.gui_live_vp then
			local vp_img = liveimg.get_viewport_table_rgba(lv._frame,m.vp_par == 2)
			if vp_img then
				local vp_pixbuf = GdkPixbuf.Pixbuf.new_from_data(vp_img.data, 'RGB', true, 8, vp_img.width, vp_img.height, vp_img.width*4, nil, nil)
				local x = lv.vp.margin_left / m.vp_par
				local y = lv.vp.margin_top * m.vp_aspect_factor
				local w = vp_img.width
				local h = vp_img.height * m.vp_aspect_factor
				-- sanity check values - changing aspect ratio with Canon menu may result in size & offset values being out of sync - ignore frame in this case
				if (y + h <= m.pixbuf.height) and (x + w <= m.pixbuf.width) then
					vp_pixbuf:composite(m.pixbuf, x, y, w, h, x, y, 1, m.vp_aspect_factor, 'NEAREST', 255)
				end
			end
		end
		if prefs.gui_live_bm then
			local bm_img = liveimg.get_bitmap_table_rgba(lv._frame,m.bm_par == 2)
			if bm_img then
				local bm_pixbuf = GdkPixbuf.Pixbuf.new_from_data(bm_img.data, 'RGB', true, 8, bm_img.width, bm_img.height, bm_img.width*4, nil, nil)
				local x = lv.bm.margin_left
				local y = lv.bm.margin_top
				local w = bm_img.width
				local h = bm_img.height
				local xs = 1
				local ys = 1
				if prefs.gui_live_bm_fit then
					-- scale overlay to fit viewport
					xs = m.pixbuf.width / (lv.bm:get_screen_width() / m.bm_par)
					ys = m.pixbuf.height / lv.bm:get_screen_height()
					x = x * xs
					y = y * ys
					w = w * xs
					h = h * ys
				else
					-- clip to fit
					if x + w > m.pixbuf.width then w = m.pixbuf.width - x end
					if y + h > m.pixbuf.height then h = m.pixbuf.height - x end
				end
				bm_pixbuf:composite(m.pixbuf, x, y, w, h, x, y, xs, ys, 'NEAREST', 255)
			end
		end
	end
	if lv_new_frame then
		m.stats:end_frame()
	end
end)

m.pixbuf = GdkPixbuf.Pixbuf.new('RGB', true, 8, 360, 240)
m.area = Gtk.DrawingArea { width = 360, height = 240 }

function m.area:on_draw(cr)
	cr:set_source_pixbuf(m.pixbuf, 0, 0)
	cr:paint()
	return true
end

function m.init()
	if not m.live_support() then
		return false
	end
	m.statslabel = Gtk.Label { width_request = 90, height_request = 64, xalign = 0 }
	m.container = Gtk.Box {
		orientation = 'HORIZONTAL',
		spacing = 4,
		m.area,
		Gtk.Box {
			orientation = 'VERTICAL',
			spacing = 4,
			Gtk.Frame {
				label = "Stream",
				Gtk.Box {
					orientation = 'VERTICAL',
					spacing = 4,
					prefctl.toggle{
						title='Viewfinder',
						pref='gui_live_vp',
					},
					prefctl.toggle{
						title='UI Overlay',
						pref='gui_live_bm',
					},
					prefctl.toggle{
						title = " D6 UI Opacity",
						pref='gui_live_bmo',
					},
					prefctl.toggle{
						title="Viewfinder 1:1",
						pref='gui_live_vp_fullx',
					},
					prefctl.toggle{
						title="Overlay 1:1",
						pref='gui_live_bm_fullx',
					},
					prefctl.toggle{
						title = "Overlay fit",
						pref='gui_live_bm_fit',
					},
					prefctl.toggle{
						title="Scale for A/R",
						pref='gui_live_ar_scale',
					},
					Gtk.Box {
						orientation = 'HORIZONTAL',
						spacing = 4,
						Gtk.Label { label = "Target FPS" },
						prefctl.bind('gui_live_fps',Gtk.SpinButton {
							adjustment = Gtk.Adjustment {
								lower = m.fps_min,
								upper = m.fps_max,
								step_increment = 1,
							},
							numeric = true,
							value = prefs.gui_live_fps,
							on_value_changed = function(self)
								m.update_fps(tonumber(self.value))
							end
						},
						function(self,value)
							self.ctl.value = tostring(value)
						end,
						function(self)
							return tonumber(self.ctl.value)
						end),
					},
					Gtk.Button {
						label = "Screenshot",
						on_clicked = function(self)
							-- quick n dirty screenshot
							local w = m.pixbuf.width
							local h = m.pixbuf.height
							local r = m.pixbuf.rowstride
							local n = m.pixbuf.n_channels
							local bm = m.pixbuf:get_pixels()
							local lb = lbuf.new(w*h*3)
							local o=0
							for y=0,(h-1)*r,r do
								for x=1,w*n,n do
									lb:set_u8(o,string.byte(bm, y+x))
									o=o+1
									lb:set_u8(o,string.byte(bm, y+x+1))
									o=o+1
									lb:set_u8(o,string.byte(bm, y+x+2))
									o=o+1
								end
							end
							local filename = 'chdkptp_'..os.date('%Y%m%d_%H%M%S')..'.ppm'
							local fh, err = io.open(filename,'wb')
							if not fh then
								warnf("failed to open %s: %s",tostring(filename),tostring(err))
								return
							end
							fh:write(string.format('P6\n%d\n%d\n%d\n', w, h,255))
							lb:fwrite(fh)
							fh:close()
							gui.infomsg('wrote %dx%d ppm %s\n',w,h,tostring(filename))
						end
					},
				},
			},
			Gtk.Notebook {
				{
					tab_label = 'Statistics',
					Gtk.Box {
						orientation = 'VERTICAL',
						spacing = 4,
						m.statslabel,
					},
				},
				{
					tab_label = 'Debug',
					Gtk.Box {
						orientation = 'VERTICAL',
						spacing = 4,
						Gtk.CheckButton {
							label = "Dump to file",
							on_toggled = function(self) m.toggle_dump(self.active) end,
						},
						Gtk.CheckButton {
							label = "Play from file",
							on_toggled = function(self) if not m.toggle_play_dump(self.active) then self.active = false end end,
						},
						Gtk.Button {
							label = "Quick dump",
							on_clicked = function()
								gui.add_status(cli:execute('lvdump'))
							end
						},
					},
				},
			},
		},
	}
end

function m.get_container()
	return m.container
end

function m.on_tab_change()
	if m.live_support() then
		m.set_frame_time(m.frame_time)
	end
end

-- for anything that needs to be intialized when everything is started
function m.on_dlg_run()
	m.set_frame_time(100)
	m.pixbuf:fill(0x000000FF)
end

function m.on_dlg_close()
end

return m
