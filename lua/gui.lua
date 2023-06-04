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
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


Originally based on the button example from the IUP distribution, but
no longer contains any significant code from it
]]
local gui = require'gui_base'

local live = require'gui_live'
local tree = require'gui_tree'
local user = require'gui_user'
local icon = require'gui_icon'

-- make global for easier testing
gui.live = live
gui.tree = tree
gui.user = user
gui.sched = require'gui_sched'

local function get_all_files_filter()
	if sys.ostype() == 'Windows' then
		return "*.*"
	end
	return "*"
end

-- Open file select dialog
function gui.file_select(title, filter)
	local dlg = iup.filedlg{
		dialogtype = "OPEN",
		title = title,
		filter = filter,
	}
	dlg:popup (iup_centerparent, iup_centerparent)

	-- return flag if file selected and file name
	return dlg.status == "0", dlg.value
end

-- Open file select multiple dialog
function gui.file_select_multiple(title)
	local dlg = iup.filedlg{
		dialogtype = "OPEN",
		title = title,
		filter = get_all_files_filter(),
		filterinfo = "all files",
		multiplefiles = "yes",
	}
	dlg:popup (iup_centerparent, iup_centerparent)

	local files = dlg.value
	local paths = {}
	local e=1
	local dir
	while true do
		local s,sub
		s,e,sub=string.find(files,'([^|]+)|',e)
		if s then
			if not dir then
				dir = sub
			else
				table.insert(paths,fsutil.joinpath(dir,sub))
			end
		else
			break
		end
	end
	-- single select
	if #paths == 0 then
		table.insert(paths,files)
	end

	-- return flag if file selected and file name
	return dlg.status == "0", paths
end

-- Open file select dialog for file save
function gui.file_select_for_save(title, filename)
	local dlg = iup.filedlg{
		dialogtype = "SAVE",
		title = title,
		filter = get_all_files_filter(),
		filterinfo = "all files",
		file = filename
	}

	-- Shows file dialog in the center of the screen
	dlg:popup (iup_centerparent, iup_centerparent)

	-- return flag if file selected and file name
	return dlg.status == "0" or dlg.status == "1", dlg.value
end

-- Open folder select dialog
function gui.folder_select(title, current_folder)
	local dlg=iup.filedlg{
		dialogtype = "DIR",
		title = title,
		directory = current_folder,
	}
	dlg:popup(iup_centerparent, iup_centerparent)

	-- return flag if file selected and file name
	return dlg.status == "0", dlg.value
end

-- Open 'confirm action' dialog. Return true is user clicked 'OK'
function gui.confirm_action(title, body)
	return iup.Alarm(title,body,'OK','Cancel') == 1
end

-- Show info popup
function gui.info_popup(title, body)
	iup.Alarm(title,body,'OK')
end

-- parse a NxM attribute and return as numbers
function gui.parsesize(size)
	local w,h=string.match(size,'(%d+)x(%d+)')
	return tonumber(w),tonumber(h)
end

function gui.update_mode_dropdown(cur)
	gui.dbgmsg('update mode dropdown %s\n',tostring(cur))
	gui.mode_dropdown["1"] = nil -- empty the list
	if not gui.mode_list or not cur or cur == 0 then
		return
	end
	gui.mode_map = {}
	local curid
	for i=1,#gui.mode_list do
		gui.mode_dropdown[tostring(i)] = gui.mode_list[i].name
		-- list index to chdk value
		gui.mode_map[i] = gui.mode_list[i].id
		if cur == gui.mode_list[i].id then
			curid = i
		end
	end
	gui.mode_dropdown.value = curid
	gui.dbgmsg('new value %s\n',tostring(gui.mode_map[curid]))
end

function gui.set_connection_status(status)
	if status then
		gui.last_connection_status = true
		gui.connect_icon.active = "YES"
		gui.btn_connect.title = "Disconnect"
		-- if connection was initialized in a different chdku con wrapper
		-- connection info might not be up to date
		if not con.apiver then
			con:update_connection_info()
		end
		con:do_on_connect_actions()
		gui.connect_label.title = string.format("host:%d.%d cam:%d.%d",
											chdku.apiver.MAJOR,chdku.apiver.MINOR,
											con.apiver.MAJOR,con.apiver.MINOR)
		gui.update_mode_list()
	else
		gui.last_connection_status = false
		gui.connect_icon.active = "NO"
		gui.btn_connect.title = "Connect"
		gui.connect_label.title = string.format("host:%d.%d cam:-.-",chdku.apiver.MAJOR,chdku.apiver.MINOR)
		gui.clear_mode_list()
	end
	live.on_connect_change(con)
end

function gui.update_cam_list(devs)
	gui.cam_dropdown["1"] = nil -- empty the list
	local curid
	for i,dev in ipairs(devs) do
		-- TODO name would be nice, but will might hose other connections
		local s=string.format("%s:%s",dev.bus,dev.dev)
		gui.cam_dropdown[tostring(i)] = s
		gui.dbgmsg('cam_dropdown %d=%s\n',i,s)
		if con.condev and con.condev.dev == dev.dev and con.condev.bus == dev.bus then
			gui.dbgmsg('cur %d\n',i)
			curid = i
		end
	end
	gui.cached_devs = devs
	if #devs > 0 then
		if curid then
			gui.dbgmsg('cam_dropdown: current %s\n',tostring(curid))
			gui.cam_dropdown.value = curid
		else
			gui.dbgmsg('cam_dropdown: current not found, default to 1\n')
			gui.cam_dropdown.value = 1
			gui.cam_dropdown:valuechanged_cb()
		end
	else
		gui.cam_dropdown.value = 0 -- none
	end
end

local function exec_input()
	gui.exec_command(gui.inputtext.value)
	gui.inputtext.value=''
end

function gui.statusprint(...)
	local args={...}
	local s = tostring(args[1])
	for i=2,#args do
		s=s .. ' ' .. tostring(args[i])
	end
	gui.statustext.append = s
	gui.statusupdatepos()
end

-- TODO it would be better to only auto update if not manually scrolled up
-- doesn't work all the time
function gui.statusupdatepos()
	local pos = gui.statustext.count -- iup 3.5 only
	if not pos then
		pos = string.len(gui.statustext.value)
	end
	local l = iup.TextConvertPosToLinCol(gui.statustext,pos)
	local h = math.floor(tonumber(string.match(gui.statustext.size,'%d+x(%d+)'))/8)
	--print(l,h)
	if l > h then
		l=l-h + 1
		--print('scrollto',l)
		gui.statustext.scrollto = string.format('%d:1',l)
	end
end

function gui.create_controls()
	-- controls that need to be available outside dialog declaration
	gui.connect_icon = iup.label{
		image = icon.on,
		iminactive = icon.off,
		active = "NO",
	}

	gui.connect_label = iup.label{
		title = string.format("host:%d.%d cam:-.- ",chdku.apiver.MAJOR,chdku.apiver.MINOR),
	}

	gui.btn_connect = iup.button{
		title = "Connect",
		size = "48x",
		action=errutil.wrap(function(self) gui.connect_action() end)
	}

	gui.cam_dropdown = iup.list{
		VISIBLECOLUMNS="10",
		DROPDOWN="YES",
	}

	gui.cam_dropdown.valuechanged_cb=errutil.wrap(function(self)
		gui.select_device(tonumber(self.value))
		-- TODO cams should be in the tree
		gui.tree.get_container().state = 'COLLAPSED' -- force refresh when switching cams
	end)


	-- console input
	gui.inputtext = iup.text{
		expand = "HORIZONTAL",
	}

	-- console output
	gui.statustext = iup.text{
		multiline = "YES",
		readonly = "YES",
		expand = "YES",
		formatting = "YES",
		scrollbar = "VERTICAL",
		autohide = "YES",
		visiblelines="2",
		appendnewline="NO",
	}

	gui.btn_exec = iup.button{
		title = "Execute",
		-- no erruitl.wrap here, calls are protected by cli
		action=exec_input,
	}


	local cam_btns={}
	local function cam_btn(name,title)
		if not title then
			title = name
		end
		cam_btns[name] = iup.button{
			title=title,
			size='31x15', -- couldn't get normalizer to work for some reason
			action=function(self) gui.execquick('click("' .. name .. '")') end,
		}
	end
	cam_btn("erase")
	cam_btn("up")
	cam_btn("print")
	cam_btn("left")
	cam_btn("set")
	cam_btn("right")
	cam_btn("display","disp")
	cam_btn("down")
	cam_btn("menu")

	gui.mode_dropdown = iup.list{
		VISIBLECOLUMNS="10",
		DROPDOWN="YES",
	}

	function gui.mode_dropdown:valuechanged_cb()
		gui.dbgmsg('mode_dropdown %s\n',tostring(self.value))
		local v = tonumber(self.value)
		-- 0 means none selected. Callback can be called with this (multiple times) when list is emptied
		if v == 0 then
			return
		end
		if not gui.mode_map or not gui.mode_map[v] then
			gui.infomsg('tried to set invalid mode %s\n',tostring(v))
			return
		end
		gui.execquick(string.format('set_capture_mode(%d)',gui.mode_map[v]))
	end

	local cam_btn_frame = iup.vbox{
		iup.hbox{
			cam_btns.erase,
			cam_btns.up,
			cam_btns.print,
		},
		iup.hbox{
			cam_btns.left,
			cam_btns.set,
			cam_btns.right,
		},
		iup.hbox{
			cam_btns.display,
			cam_btns.down,
			cam_btns.menu,
		},

		iup.label{separator="HORIZONTAL"},
		iup.hbox{
			iup.button{
				title='zoom+',
				size='45x15',
				action=function(self)
					gui.execquick('click("zoom_in")')
				end,
			},
			iup.fill{
			},
			iup.button{
				title='zoom-',
				size='45x15',
				action=function(self)
					gui.execquick('click("zoom_out")')
				end,
			},
			expand="HORIZONTAL",
		},

		iup.hbox{
			iup.button{
				title='wheel l',
				size='45x15',
				action=function(self)
					gui.execquick('wheel_left()')
				end,
			},
			iup.fill{
			},
			iup.button{
				title='wheel r',
				size='45x15',
				action=function(self)
					gui.execquick('wheel_right()')
				end,
			},
			expand="HORIZONTAL",
		},

		iup.label{separator="HORIZONTAL"},

		iup.hbox{
			-- TODO we should have a way to press shoot half and have it stay down,
			-- so we can do normal shooting proccess
			iup.button{
				title='shoot half',
				size='45x15',
				action=function(self)
					gui.execquick(string.format(gui.shoot_half_script, prefs.gui_shoot_half_timeout))
				end,
			},
			iup.fill{
			},
			iup.button{
				title='video',
				size='45x15',
				action=function(self)
					gui.execquick('click("video")')
				end,
			},
			expand="HORIZONTAL",
		},

		iup.button{
			title='shoot',
			size='94x15',
			action=function(self)
				-- video seems to need a small delay after half press to reliably start recording
				gui.execquick(gui.shoot_script)
			end,
		},
		iup.label{separator="HORIZONTAL"},
		iup.hbox{
			iup.button{
				title='rec',
				size='45x15',
				action=function(self)
					gui.switch_mode(1)
				end,
			},
			iup.fill{},
			iup.button{
				title='play',
				size='45x15',
				action=function(self)
					gui.switch_mode(0)
				end,
			},
			expand="HORIZONTAL",
		},
		iup.label{separator="HORIZONTAL"},
		iup.hbox{
			gui.mode_dropdown,
		},
		iup.fill{},
		iup.hbox{
			iup.button{
				title='shutdown',
				size='45x15',
				action=function(self)
					gui.execquick('shut_down()')
				end,
			},
			iup.fill{},
			iup.button{
				title='reboot',
				size='45x15',
				action=function(self)
					gui.execquick('reboot()')
				end,
			},
			expand="HORIZONTAL",
		},
		expand="VERTICAL",
		nmargin="4x4",
		ngap="2"
	}
	tree.init()
	live.init()
	user.init()

	local contab = iup.vbox{
		gui.statustext,
	}

	gui.maintabs = iup.tabs{
		contab,
		tree.get_container(),
		live.get_container(),
		user.get_container(),
		tabtitle0='Console',
		tabtitle1=tree.get_container_title(),
		tabtitle2=live.get_container_title(),
		tabtitle3=user.get_container_title(),
	}

	local inputbox = iup.hbox{
		gui.inputtext,
		gui.btn_exec,
	}

	local leftbox = iup.vbox{
		gui.maintabs,
	--				gui.statustext,
		inputbox,
		nmargin="4x4",
		ngap="2"
	}

	--[[
	TODO this is lame, move console output for min-console or full tab
	]]
	function gui.maintabs:tabchange_cb(new,old)
		--printf('tab change %s->%s %s\n',old,new,maintabs.valuepos)
		-- from callback, set value directly, but only if initial value applied
		if gui.prefs_ready then
			prefs._obj.gui_tab.value = gui.tab_index_to_name(gui.get_tab_index(new))
		end
		if new == contab then
			iup.SaveClassAttributes(gui.statustext)
			iup.Detach(gui.statustext)
			iup.Insert(contab,nil,gui.statustext)
			iup.Map(gui.statustext)
			iup.Refresh(gui.main_dialog)
			gui.statusupdatepos()
		elseif old == contab then
			iup.SaveClassAttributes(gui.statustext)
			iup.Detach(gui.statustext)
			iup.Insert(leftbox,inputbox,gui.statustext)
			iup.Map(gui.statustext)
			iup.Refresh(gui.main_dialog)
			gui.statusupdatepos()
		end
		gui.resize_for_content() -- this may trigger a second refresh, but needed
		live.on_tab_change(new,old)
	end

	-- main dialog
	gui.main_dialog = iup.dialog{
		iup.vbox{
			iup.hbox{
				gui.connect_icon,
				gui.connect_label,
				iup.fill{},
				gui.cam_dropdown,
				gui.btn_connect;
				nmargin="4x2",
			},
			iup.label{separator="HORIZONTAL"},
			iup.hbox{
				leftbox,
				iup.vbox{
				},
				cam_btn_frame,
			},
		};
		title = "CHDK PTP",
		resize = "YES",
		menubox = "YES",
		maxbox = "YES",
		minbox = "YES",
		icon = icon.logo,
		menu = menu,
		rastersize = "700x560",
		padding = '2x2'
	}
	function gui.main_dialog:resize_cb(w,h)
		--[[
		local cw,ch=gui.content_size()
		print("gui.main_dialog Resize: Width="..w.."   Height="..h)
		print("gui.main_dialog content: Width="..cw.."   Height="..ch)
		--]]
		self.clientsize=w.."x"..h
	end

	function gui.main_dialog:close_cb()
		gui.on_exit()
	end

	function gui.inputtext:k_any(k)
		if k == iup.K_CR then
			exec_input()
		elseif k == iup.K_UP then
			local hval = gui.cmd_history:prev()
			if hval then
				gui.inputtext.value = hval
			end
		elseif k == iup.K_DOWN then
			gui.inputtext.value = gui.cmd_history:next()
		end
	end
end


function gui.content_size()
	return gui.parsesize(gui.main_dialog[1].rastersize)
end

--[[
size the dialog large enough for the content
]]
function gui.resize_for_content(refresh)
	local cw,ch= gui.content_size()
	local w,h=gui.parsesize(gui.main_dialog.clientsize)
	--[[
	print("resize_for_content gui.main_dialog:"..w.."x"..h)
	print("resize_for_content content:"..cw.."x"..ch)
	--]]
	if not (w and cw and h and ch) then
		return
	end
	local update
	if w < cw then
		w = cw
		update = true
	end
	if h < ch then
		h = ch
		update = true
	end
	if update then
		gui.main_dialog.clientsize = w..'x'..h
		iup.Refresh(gui.main_dialog)
	end
end


function gui.run()
	gui.create_controls()
	gui.main_dialog:showxy( iup.CENTER, iup.CENTER)
	gui.sched.init_timer(10)

	tree.on_dlg_run()
	util.util_stdout = gui.status_out
	util.util_stderr = gui.status_out
	do_connect_option()
	do_execute_option()
	live.on_dlg_run()
	gui.resize_for_content()

	cli.readline = gui.cli_readline
	gui.cli_thread = coroutine.create(function() cli:run() end)
	local s
	s,gui.cli_thread_status = coroutine.resume(gui.cli_thread)

	-- TODO in lua 5.1, can't use xpcall because rsint needs to yield in readline
	if util.is_lua_ver(5,1) and cli.names.rsint then
		cli.names.rsint.noxpcall=true
	end
	chdku.sleep = gui.chdku_sleep

	gui.schedule_dev_check()

	gui.apply_startup_prefs()
	if (iup.MainLoopLevel()==0) then
		iup.MainLoop()
	end
end

function gui.close()
	gui.on_exit()
	gui.main_dialog:hide()
end

function gui.set_tab(i)
	local old = gui.maintabs.value
	local new = iup.GetChild(gui.maintabs,i)
	if not new then
		util.warnf('set_tab invalid tab %s\n',i)
		return
	end
	gui.maintabs.valuepos=tostring(i)
	gui.maintabs:tabchange_cb(new, old)
end
function gui.get_current_tab_index()
	return tonumber(gui.maintabs.valuepos)
end
function gui.get_tab_index(tab)
	for i=0,3 do
		if iup.GetChild(gui.maintabs,i) == tab then
			return i
		end
	end
end

function gui.is_live_view()
	return gui.maintabs.valuepos == '2'
end

return gui
