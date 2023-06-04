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
local prefctl=require'gui_prefctl'

--[[
note - these are 'private' but exposed in the module for easier debugging
container -- outermost widget
icnv -- iup canvas
timer -- timer for fetching updates
statslabel -- text for stats
]]


--[[
update canvas size from frame
]]
function m.update_canvas_size()
	local active, vp_w, vp_h = m.frame_size()
	if active then
		local w,h = gui.parsesize(m.icnv.rastersize)
		if w ~= vp_w or h ~= vp_h then
			m.resize_canvas_count = m.resize_canvas_count + 1
			m.icnv.rastersize = vp_w.."x"..vp_h
			iup.Refresh(m.container)
			gui.resize_for_content()
		end
	end
end

function m.set_stats_text(str)
	m.statslabel.title = str
end


function m.set_frame_time(time)
	m.frame_time = time
	if m.timer then
		iup.Destroy(m.timer)
	end
	m.timer = iup.timer{
		time = tostring(m.frame_time),
		action_cb = function()
			-- use xpcall so we don't get a popup every frame
			local cstatus,msg = xpcall(m.frame_timer_action,errutil.format)
			if not cstatus then
				printf('live timer update error\n%s\n',tostring(msg))
				-- TODO could stop live updates here, for now just spam the console
			end
		end,
	}
	m.update_run_state()
end

m.redraw_canvas = errutil.wrap(function()
	if not gui.is_live_view() then
		return
	end
	m.redraw_count = m.redraw_count+1
	local ccnv = m.icnv.dccnv
	-- only run stats for new live frames, not refreshes for other reasons
	local lv_new_frame = (m.lv_frame_num ~= m.lv_frame_drawn)
	if lv_new_frame then
		m.stats:start_frame()
		m.lv_frame_drawn = m.lv_frame_num
	end
	ccnv:Activate()
	ccnv:Clear()
	local lv = m.get_current_frame_data()
	if lv and lv._frame then
		if prefs.gui_live_vp then
			m.vp_img = liveimg.get_viewport_pimg(m.vp_img,lv._frame,m.vp_par == 2)
			if m.vp_img then
				if prefs.gui_live_ar_scale then
					m.vp_img:put_to_cd_canvas(ccnv,
						lv.vp.margin_left/m.vp_par,
						lv.vp.margin_bot*m.vp_aspect_factor,
						m.vp_img:width(),
						m.vp_img:height()*m.vp_aspect_factor)
				else
					m.vp_img:put_to_cd_canvas(ccnv,
						lv.vp.margin_left/m.vp_par,
						lv.vp.margin_bot)
				end
			end
		end
		if prefs.gui_live_bm then
			m.bm_img = liveimg.get_bitmap_pimg(m.bm_img,lv._frame,m.bm_par == 2)
			if m.bm_img then
				-- NOTE bitmap assumed fullscreen, margins ignored
				if prefs.gui_live_bm_fit then
					m.bm_img:blend_to_cd_canvas(ccnv, 0, 0, lv.vp:get_screen_width()/m.vp_par, lv.vp:get_screen_height()*m.vp_aspect_factor)
				else
					m.bm_img:blend_to_cd_canvas(ccnv, 0, lv.vp:get_screen_height() - lv.bm.visible_height)
				end
			end
		end
	end
	ccnv:Flush()
	if lv_new_frame then
		m.stats:end_frame()
	end
end)

function m.init()
	if not m.live_support() then
		return false
	end

	local icnv = iup.canvas{rastersize="360x240",border="NO",expand="NO"}
	m.icnv = icnv
	-- flatlabel is only available in IUP 3.25+
	-- updating standard label appears to cause canvas to redraw on some GTK versions
	if iup.flatlabel then
		m.statslabel = iup.flatlabel{size="90x64",alignment="ALEFT:ATOP"}
	else
		m.statslabel = iup.label{size="90x64",alignment="ALEFT:ATOP"}
	end
	m.container = iup.hbox{
		iup.frame{
			icnv,
		},
		iup.vbox{
			iup.frame{
				iup.vbox{
					prefctl.toggle{
						title='Viewfinder',
						pref='gui_live_vp',
					},
					prefctl.toggle{
						title='UI Overlay',
						pref='gui_live_bm',
					},
					prefctl.toggle{
						title=" D6 UI Opacity",
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
						title="Overlay fit",
						pref='gui_live_bm_fit',
					},
					prefctl.toggle{
						title="Scale for A/R",
						pref='gui_live_ar_scale',
					},
					iup.hbox{
						iup.label{title="Target FPS"},
						prefctl.bind('gui_live_fps',iup.text{
								spin="YES",
								spinmax=tostring(m.fps_max),
								spinmin=tostring(m.fps_min),
								spininc="1",
								value=tostring(prefs.gui_live_fps),
								action=function(self,c,newval)
									local v = tonumber(newval)
									local min = tonumber(self.spinmin)
									local max = tonumber(self.spinmax)
									if v and v >= min and v <= max then
										self.value = tostring(v)
										self.caretpos = string.len(tostring(v))
										m.update_fps(self.value)
									end
									return iup.IGNORE
								end,
								spin_cb=function(self,newval)
									m.update_fps(newval)
								end
							},
							function(self,value)
								self.ctl.value = tostring(value)
							end,
							function(self)
								return tonumber(self.ctl.value)
							end),
					},
					iup.button{
						title="Screenshot",
						action=function(self)
							-- quick n dirty screenshot
							local cnv = icnv.dccnv
							local w,h = cnv:GetSize()
							local bm = cd.CreateBitmap(w,h,cd.RGB)
							cnv:GetBitmap(bm,0,0)
							local lb=lbuf.new(w*h*3)
							local o=0
							for y=h-1,0,-1 do
								for x=0,w-1 do
									lb:set_u8(o,bm.r[y*w + x])
									o=o+1
									lb:set_u8(o,bm.g[y*w + x])
									o=o+1
									lb:set_u8(o,bm.b[y*w + x])
									o=o+1
								end
							end
							cd.KillBitmap(bm)
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
				title="Stream"
			},
			iup.tabs{
				iup.vbox{
					m.statslabel,
					tabtitle="Statistics",
				},
				iup.vbox{
					tabtitle="Debug",
					iup.toggle{title="Dump to file",action = function(self,state) m.toggle_dump(state==1) end},
					iup.toggle{title="Play from file",action = function(self,state) if not m.toggle_play_dump(state==1) then self.value = "OFF" end end},
					iup.button{
						title="Quick dump",
						action=function()
							gui.add_status(cli:execute('lvdump'))
						end,
					},
				},
			},
		},
		margin="4x4",
		ngap="4"
	}

	function icnv:map_cb()
		if prefs.gui_context_plus then
			-- TODO UseContextPlus seems harmless if not built with plus support
			if guisys.caps().CDPLUS then
				cd.UseContextPlus(true)
				gui.infomsg("ContexIsPlus iup:%s cd:%s\n",tostring(cd.ContextIsPlus(cd.IUP)),tostring(cd.ContextIsPlus(cd.DBUFFER)))
			else
				gui.infomsg("context_plus requested but not available\n")
			end
		end
		self.ccnv = cd.CreateCanvas(cd.IUP,self)
		self.dccnv = cd.CreateCanvas(cd.DBUFFER,self.ccnv)
		if prefs.gui_context_plus and guisys.caps().CDPLUS then
			cd.UseContextPlus(false)
		end
		self.dccnv:SetBackground(cd.EncodeColor(32,32,32))
	end

	icnv.action=m.redraw_canvas

	function icnv:unmap_cb()
		self.dccnv:Kill()
		self.ccnv:Kill()
	end

	function icnv:resize_cb(w,h)
		gui.dbgmsg("Resize: Width="..w.."   Height="..h..'\n')
	end
end

function m.get_container()
	return m.container
end

-- check whether we should be running, update timer
function m.update_run_state(state)
	if state == nil then
		state = gui.is_live_view()
	end
	if state then
		if m.timer then
			m.timer.run = "YES"
		end
		m.skip_frames = 0
		m.skip_count = 0
	else
		if m.timer then
			m.timer.run = "NO"
		end
		m.stats:stop()
	end
end

function m.on_tab_change(new,old)
	if not m.live_support() then
		return
	end
	if new == m.container then
		m.update_run_state(true)
	else
		m.update_run_state(false)
	end
end

-- for anything that needs to be intialized when everything is started
function m.on_dlg_run()
	m.set_frame_time(100)
end

-- stop live on exit, otherwise process can keep running after dialog goes away on windows
-- when target framerate is higher than system can support
function m.on_dlg_close()
	m.update_run_state(false)
end

-- only applicable to IUP GUI, effectively always on for modern GTK
prefs._add('gui_context_plus','boolean','use IUP context plus if available')

return m
