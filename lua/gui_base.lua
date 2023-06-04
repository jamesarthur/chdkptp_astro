--[[
main gui file - base code, independant of GUI system
]]
local gui = {}

gui.shoot_half_script =
[[
local timeout=%d
local rec,vid = get_mode()
if rec and not vid then
 press("shoot_half")
 local n = 0
 repeat
  sleep(10)
  n = n + 10
 until get_shooting() == true or n > timeout
 release("shoot_half")
else
 press("shoot_half")
 sleep(1000)
 release("shoot_half")
end
]]

-- video seems to need a small delay after half press to reliably start recording
gui.shoot_script =
[[
local rec,vid = get_mode()
if rec and not vid then
 shoot()
else
 if vid then
  press('shoot_half')
  sleep(200)
 end
 click('shoot_full')
end
]]

gui.get_modes_script =
[[
capmode=require'capmode'
local l={}
local i=1
for id,name in ipairs(capmode.mode_to_name) do
 if capmode.valid(id) then
  l[i] = {name=name,id=id}
  i = i + 1
 end
end
return l,capmode.get()
]]

--[[
info printf - message to be printed at normal verbosity
]]
gui.infomsg = util.make_msgf( function() return prefs.gui_verbose end, 1)
gui.dbgmsg = util.make_msgf( function() return prefs.gui_verbose end, 2)

--[[
wrapper that catches and prints errors
]]
gui.exec=errutil.wrap(function(code,opts) con:exec(code,opts) end)

function gui.execquick(code,opts)
	opts = util.extend_table({nodefaultlibs=true},opts)
	gui.exec(code,opts)
end

function gui.exec_command(txt)
	printf('> %s\n',txt)
	gui.cmd_history:add(txt)
	-- if gui_exec_direct enabled, execute ! / exec directly from the main thread, in the button callback
	-- this causes the exec code to block the gui until complete, and breaks readline from inside the exec'd code
	-- but maybe be useful for poking gui internals
	if prefs.gui_exec_direct and (string.find(txt,'[%c%s]*^!') or string.find(txt,'^[%c%s]*exec[%c%s]+')) then
		gui.add_status(cli:execute(txt))
	else
		if gui.cli_thread_status == 'readline' then
			local s
			s,gui.cli_thread_status=coroutine.resume(gui.cli_thread,txt)
		else
			printf('busy %s\n',tostring(gui.cli_thread_status))
		end
	end
	if cli.finished then
		gui.close()
	end
end

function gui.connect_action()
	if con:is_connected() then
		con:disconnect()
	else
		con:connect()
		if con:is_connected() then
			cli.infomsg('connected: %s, max packet size %d\n',con.ptpdev.model,con.ptpdev.max_packet_size)
		end
	end
	gui.update_connection_status()
end

function gui.clear_mode_list()
	gui.mode_list = nil
	gui.mode_map = nil
	gui.update_mode_dropdown()
end

function gui.update_mode_list()
	gui.mode_list = nil
	gui.mode_map = nil
	local status,modes,cur = con:execwait_pcall(gui.get_modes_script)
	if not status then
		gui.infomsg('update_mode_list failed %s\n',tostring(modes))
		gui.clear_mode_list()
		return
	end
	-- TODO need to do something about play,
	-- would be good to select the current mode in rec mode
	gui.mode_list = modes
	gui.update_mode_dropdown(cur)
end

function gui.update_connection_status()
	gui.set_connection_status(con:is_connected())
end

function gui.timer_update_connection_status()
	local new_status = con:is_connected()
	if new_status ~= gui.last_connection_status then
		gui.set_connection_status(new_status)
	end
	local devs = {}
	for _,d in ipairs(chdk.list_usb_devices()) do
		-- only include Canon devices in GUI list
		-- if you REALLY want to connect to something else, use the cli command
		if d.vendor_id == 1193 then
			table.insert(devs,d)
		end
	end
	if not util.compare_values(devs,gui.cached_devs) then
		gui.update_cam_list(devs)
	end
end

function gui.select_device(v)
	-- 0 means none selected. Callback can be called with this (multiple times) when list is emptied
	if v == 0 then
		return
	end

	gui.dbgmsg('cam_dropdown set %s\n',tostring(v))

	con=chdku.connection(gui.cached_devs[v])
	if con:is_connected() then
		con:update_connection_info()
	else
		con.condev=con:get_con_devinfo()
	end
	gui.dbgmsg('cam_dropdown new con %s:%s\n',con.condev.dev,con.condev.bus)
end

--[[
switch play / rec mode, update capture mode dropdown
]]
gui.switch_mode=errutil.wrap(function(m)
	local capmode
	if m == 0 then
		gui.execquick('if get_mode() then switch_mode_usb(0) end')
	else
		-- switch mode, wait for complete, return current mode
		local status,msg
		capmode,status,msg=con:execwait(([[
local status,msg=rlib_switch_mode(1,%s)
return rlib_get_capture_mode(),status,msg
]]):format(prefs.cam_switch_mode_timeout),{libs={'switch_mode','get_capture_mode'}})
		if not status then
			util.warnf('%s\n',msg)
		elseif msg then
			util.printf('%s\n',msg)
		end
	end
	gui.update_mode_dropdown(capmode)
end)

gui.cmd_history = {
	pos = 1,
	prev = function(self)
		if self[self.pos - 1]  then
			self.pos = self.pos - 1
			return self[self.pos]
--[[
		elseif #self > 1 then
			self.pos = #self
			return self[self.pos]
--]]
		end
	end,
	next = function(self)
		if self[self.pos + 1]  then
			self.pos = self.pos + 1
			return self[self.pos]
		end
	end,
	add = function(self,value)
		table.insert(self,value)
		self.pos = #self+1
	end
}

--[[
mock file object that sends to gui console
]]
gui.status_out = {
	write=function(self,...)
		gui.statusprint(...)
	end
}

function gui.add_status(status,msg)
	if status then
		if msg then
			printf('%s',msg)
		end
	else
		printf("ERROR: %s\n",tostring(msg))
	end
end

-- resume with input line, yield returns as result
-- currently the only place it should yield
function gui.cli_readline(prompt)
	return coroutine.yield('readline')
end

function gui.chdku_sleep(time)
	-- in lua 5.1 just use sys.sleep
	if util.lua_ver_minor < 2 then
		sys.sleep(time)
		return
	end
	-- if not in the cli thread, can't yield
	if coroutine.status(gui.cli_thread) ~= 'running' then
		sys.sleep(time)
		return
	end
	-- if time is less than scheduler interval, just sleep
	-- TODO might want to fudge a bit
	if time < gui.sched.min_interval() then
		sys.sleep(time)
		return
	end
	gui.sched.run_after(time,function()
		local s
		s,gui.cli_thread_status=coroutine.resume(gui.cli_thread)
	end)
	coroutine.yield('sleep')
end

function gui.schedule_dev_check()
	if gui.connection_check then
		gui.connection_check:cancel()
	end
	if prefs.gui_dev_check_interval > 0 then
		gui.connection_check = gui.sched.run_repeat(prefs.gui_dev_check_interval,gui.timer_update_connection_status)
	end
end

function gui.on_exit()
	gui.live.on_dlg_close()
	do_autosave_rc_file()
end

function gui.test_timer(ms,count)
	if not count then
		count = 10
	end
	if not ms then
		ms = 100
	end
	local t0 = ticktime.get()
	gui.sched.run_repeat(ms,function(self)
		if self.prev then
			local el = ticktime.elapsedms(self.prev)
			print(string.format("tick:  %7.3f diff %7.3f",el,(el - ms)))
		else
			local el = ticktime.elapsedms(t0)
			print(string.format("start: %7.3f diff %7.3f",el,(el - ms)))
		end
		count = count - 1
		if count <= 0 then
			self:cancel()
		end
		self.prev = self.last
	end)
end

gui.tab_names = {
	'console',
	'files',
	'live',
	'user',
}
-- tab indexes is 0 based
gui.tab_names_map=(function()
	local t={}
	for i,v in ipairs(gui.tab_names) do
		t[v] = i-1
	end
	return t
end)()

function gui.tab_name_to_index(name)
	return gui.tab_names_map[name]
end
function gui.tab_index_to_name(i)
	return gui.tab_names[i+1]
end

-- apply GUI prefs
function gui.apply_startup_prefs()
	-- flag for pref setters to know they can manipulate GUI
	gui.prefs_ready = true
	gui.set_tab(gui.tab_name_to_index(prefs.gui_tab))
	-- ensure FPS value set after controls created
	prefs.gui_live_fps = prefs.gui_live_fps
end

prefs._add('gui_verbose','number','control verbosity of GUI',1)
prefs._add('gui_shoot_half_timeout','number','max time to wait for shoot_half, in ms',3000)
prefs._add('gui_exec_direct','boolean','run ! in GUI context, not CLI coroutine. Blocks, breaks readline',false)
prefs._add('gui_dev_check_interval','number','connection/device list check time in ms, 0=never',500, {
	set=function(self,val)
		self.value = val
		-- if timer already running, reset
		if gui.sched and gui.sched.is_initialized() then
			gui.schedule_dev_check()
		end
	end,
	values={0},
	min=100,
})
prefs._add('gui_tab','string','active GUI tab',gui.tab_names[1], {
	set=function(self,val)
		if gui.prefs_ready then
			gui.set_tab(gui.tab_name_to_index(val))
		end
		self.value = val
	end,
	values=gui.tab_names,
})

return gui
