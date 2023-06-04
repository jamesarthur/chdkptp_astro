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
module for live view gui - base class
]]

local m={
	vp_par = 2, -- pixel aspect ratio for viewport 1:n, n=1,2
	bm_par = 1, -- pixel aspect ratio for bitmap 1:n, n=1,2
	vp_aspect_factor = 1, -- correction factor for height values when scaling for aspect
	skip_frames = 0, -- number of frames to drop based on how much longer than desired rate the last one took
	skip_count = 0, -- total number skipped
	lv_frame_num = 0, -- last live frame recieved
	lv_frame_drawn = 0, -- last live frame Flush'd
	lv_stats_str = '', -- value for label
	redraw_count = 0, -- canvas :action calls, for debugging
	resize_canvas_count = 0, -- how many times canvas needed resizing
	frame_timer_count = 0, -- timer_action calls

	live_con_valid = false,
	dump_active = false,
	replay_active = false,
	replay = nil,

	stats = require'gui_live_stats',
	fps_min = 1,
	fps_max = 30,
	fps_default = 10,
}

function m.get_container_title()
	return 'Live'
end

function m.live_support()
	return guisys.caps().LIVEVIEW
end

function m.print_dbg_stats()
	print(string.format([[
redraw %d
resize %d
frame timer %d:%d
]],
	m.redraw_count,
	m.resize_canvas_count,
	m.frame_timer_count,
	m.lv_frame_num))
end

function m.update_stats_text()
	-- updating label appears to trigger a refresh on some gtk versions, only do if changed
	-- TODO should (optionally?) update at a lower rate
	-- NOTE this assumes draw is completed (with :action or iup.Redraw)
	local s = m.stats:get() .. string.format('\nDropped: %d',m.skip_count)
	if s ~= m.lv_stats_str then
		m.lv_stats_str = s
		m.set_stats_text(s)
	end
end

local screen_aspects = {
	[0]=4/3,
	16/9,
	3/2,
}

function m.get_current_frame_data()
	if m.replay_active then
		return m.replay
	end
	return con.live
end

function m.get_fb_selection()
	local what=0
	if prefs.gui_live_vp then
		what = 1
	end
	if prefs.gui_live_bm then
		what = what + 4
		what = what + 8 -- palette TODO shouldn't request if we don't understand type, but palette type is in dynamic data
		if prefs.gui_live_bmo then
			what = what + 16
		end
	end
	return what
end

function m.frame_size()
	local lv = m.get_current_frame_data()
	if not lv then
		return false, 0, 0
	end
	local vp_w = lv.vp:get_screen_width()/m.vp_par
	local vp_h
	if prefs.gui_live_ar_scale then
		local lcd_ar=screen_aspects[lv.lcd_aspect_ratio]
		if not lcd_ar then
			gui.dbgmsg('frame_size: unknown aspect ratio %d\n',lv.lcd_aspect_ratio)
			lcd_ar=4/3
		end
		vp_h = vp_w/lcd_ar
		m.vp_aspect_factor = vp_h/lv.vp:get_screen_height()
	else
		m.vp_aspect_factor = 1
		vp_h = lv.vp:get_screen_height()
	end

	return true, vp_w, vp_h
end

function m.update_should_run()
	-- is the tab current?
	if not gui.is_live_view() then
		return false
	end

	-- is any view active
	if not (prefs.gui_live_vp or prefs.gui_live_bm) then
		return false
	end

	-- in dump replay
	if m.replay_active then
		return true
	end

	if not m.live_con_valid then
		return false
	end

	-- return soft status, connection errors will reset quickly
	return gui.last_connection_status
end

local last_frame_fields = {}
local last_fb_fields = {}

local palette_size_for_type={
	16*4,
	16*4,
	256*4,
	16*4,
}

-- reset last frame fields so reload or new connection will be a "change"
function m.reset_last_frame_vals()
	last_frame_fields={}
	for j,fb in ipairs(lvutil.live_fb_names) do
		last_fb_fields[fb]={}
	end
end

function m.update_frame_data(frame)
	local dirty
	for i,f in ipairs(frame._field_names) do
		local v = frame[f]
		if v ~= last_frame_fields[f] then
			dirty = true
		end
	end
	for j,fb in ipairs(lvutil.live_fb_names) do
		if frame[fb] then
			for i,f in ipairs(frame._fb_field_names) do
				local v = frame[fb][f]
				if v ~= last_fb_fields[fb][f] then
					dirty = true
				end
			end
		else
			-- if last had some value, new doesn't exist, changed
			if last_fb_fields[fb].fb_type then
				dirty = true
			end
		end
	end

	if dirty then
		gui.dbgmsg('update_frame_data: changed\n')
		for i,f in ipairs(frame._field_names) do
			local v = frame[f]
			gui.dbgmsg("%s:%s->%s\n",f,tostring(last_frame_fields[f]),v)
			last_frame_fields[f]=v
		end
		for j,fb in ipairs(lvutil.live_fb_names) do
			if frame[fb] then
				for i,f in ipairs(frame._fb_field_names) do
					local v = frame[fb][f]
					gui.dbgmsg("%s.%s:%s->%s\n",fb,f,tostring(last_fb_fields[fb][f]),v)
					last_fb_fields[fb][f]=v
				end
			else
				gui.dbgmsg("%s->nil\n",fb)
				last_fb_fields[fb].fb_type = nil
			end
		end

		-- for big palettes this lags, optional
		if prefs.gui_dump_palette and last_frame_fields.palette_data_start > 0 then
			printf('palette:\n')
			local c=0

			local bytes = {frame._frame:byte(last_frame_fields.palette_data_start+1,
										last_frame_fields.palette_data_start+palette_size_for_type[last_frame_fields.palette_type])}
			for i,v in ipairs(bytes) do
				printf("0x%02x,",v)
				c = c + 1
				if c == 16 then
					printf('\n')
					c=0
				else
					printf(' ')
				end
			end
		end
	end
end

function m.frame_timer_action()
	m.frame_timer_count = m.frame_timer_count + 1
	if m.update_should_run() then
		if m.skip_frames > 0 then
			m.skip_count = m.skip_count + 1
			m.skip_frames = m.skip_frames - 1
			return
		end
		-- skip frames to avoid bogging UI if frame rate can't keep up
		if prefs.gui_live_dropframes and m.stats:get_last_total_ms() > m.frame_time then
			-- skipping ones seems to be enough, just letting the normal
			-- gui run for a short time would probably do it too
			m.skip_frames = 1
		end
		m.lv_frame_num = m.lv_frame_num + 1
		if m.replay_active then
			m.read_dump_frame()
			-- TODO
			m.update_canvas_size()
		else
			m.stats:start()
			local what=m.get_fb_selection()
			if what == 0 then
				return
			end
			m.stats:start_xfer()
			local status,err = con:live_get_frame_pcall(what)
			if not status then
				m.end_dump()
				printf('error getting frame: %s\n',tostring(err))
				gui.update_connection_status() -- update connection status on error, to prevent spamming
				m.stats:stop()
			else
				m.stats:end_xfer(con.live._frame:len())
				m.update_frame_data(con.live)
				m.record_dump()
				m.update_canvas_size()
			end
		end
		-- IUP docs say action shouldn't be called directly, use iup.Update(m.icnv)
		-- or iup.Redraw(m.icnv,0) instead but those appear to trigger
		-- multiple redraws, action seems to work
		m.redraw_canvas()
	else
		m.stats:stop()
	end
	m.update_stats_text()
end

function m.init_dump_replay(file)
	m.replay_active = false
	local replay = lvutil.live_wrapper()
	local status,err = pcall(function()
		replay:replay_load(file)
	end)
	if not status then
		gui.infomsg("replay load failed %s\n",tostring(err))
		return
	end
	m.replay = replay
	m.reset_last_frame_vals()
	m.replay_active = true
	gui.infomsg("loaded dump ver %d.%d\n",m.replay.replay_ver_major,m.replay.replay_ver_minor)
end

function m.end_dump_replay()
	m.replay_active = false
	if m.replay.replay_fh ~= nil then
		m.replay:replay_end()
	end
	m.replay = nil
	m.stats:stop()
end

function m.read_dump_frame()
	m.stats:start()
	m.stats:start_xfer()

	-- eof, loop
	if m.replay:replay_eof() then
		gui.infomsg("restart %s\n",m.replay.replay_fn)
		m.replay:replay_restart()
	end
	m.replay:replay_frame()

	if prefs.gui_force_replay_palette ~= -1 then
		m.replay._frame:set_u32(lvutil.live_frame_map.palette_type,prefs.gui_force_replay_palette)
	end

	m.update_frame_data(m.replay)

	m.stats:end_xfer(m.replay._frame:len())
end

function m.end_dump()
	if con.live and con.live.dump_fh then
		gui.infomsg('%d bytes recorded to %s\n',tonumber(con.live.dump_size),tostring(con.live.dump_fn))
		con:live_dump_end()
	end
end

function m.record_dump()
	if not m.dump_active then
		return
	end
	if not con.live.dump_fh then
		local status,err = con:live_dump_start_pcall()
		if not status then
			printf('error starting dump:%s\n',tostring(err))
			m.dump_active = false
			-- TODO update checkbox
			return
		end
		printf('recording to %s\n',con.live.dump_fn)
	end
	local status,err = con:live_dump_frame_pcall()
	if not status then
		printf('error dumping frame:%s\n',tostring(err))
		m.end_dump()
		m.dump_active = false
	end
end

function m.toggle_dump(active)
	m.dump_active = active
	-- TODO this should be called on disconnect etc
	if not m.dump_active then
		m.end_dump()
	end
end

function m.toggle_play_dump(active)
	if active then
		local selected, file = gui.file_select("File to play", '*.lvdump')
		if selected then
			gui.infomsg('playing %s\n',file)
			m.init_dump_replay(file)
		else
			gui.dbgmsg('play dump canceled\n')
			return false
		end
	else
		m.end_dump_replay()
	end
	return true
end

function m.on_connect_change()
	m.live_con_valid = false
	if con:is_connected() then
		m.reset_last_frame_vals()
		if con:live_is_api_compatible() then
			m.live_con_valid = true
		else
			util.warnf('camera live view protocol not supported by this client, live view disabled')
		end
	end
end

function m.update_fps(val)
	val = tonumber(val)
	if val == 0 then
		return
	end
	-- avoid control changes triggering repeated updates
	if val ~= prefs.gui_live_fps then
		prefs.gui_live_fps = val
	end
	val = math.floor(1000/val)
	if val ~= m.frame_time then
		m.stats:stop()
		m.set_frame_time(val)
	end
end

-- windows degrades gracefully if req rate is too high
prefs._add('gui_live_dropframes','boolean','drop frames if target fps too high',(sys.ostype() ~= 'Windows'))
prefs._add('gui_dump_palette','boolean','dump live palette data on state change')
prefs._add('gui_force_replay_palette','number','override palette type dump replay, -1 disable',-1)
prefs._add('gui_live_fps','number','Live view target FPS',m.fps_default,{
	min=m.fps_min,
	max=m.fps_max,
})
prefs._add('gui_live_vp','boolean','Enable live viewport',false)
prefs._add('gui_live_bm','boolean','Enable UI overlay',false)
prefs._add('gui_live_bmo','boolean','Enable D6 UI Opacity',true)
prefs._add('gui_live_ar_scale','boolean','Scale live view to aspect ratio',true)
prefs._add('gui_live_bm_fit','boolean','Scale UI overlay to fit',true)
prefs._add('gui_live_vp_fullx','boolean','Viewport 100% or 50% downsample',false,{
	set=function(self,value)
		if value then
			m.vp_par = 1
		else
			m.vp_par = 2
		end
		self.value = value
	end,
})
prefs._add('gui_live_bm_fullx','boolean','UI overlay 100% or 50% downsample',true,{
	set=function(self,value)
		if value then
			m.bm_par = 1
		else
			m.bm_par = 2
		end
		self.value = value
	end,
})

return m
