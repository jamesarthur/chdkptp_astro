--[[
main gui file - GTK
Converted to GKT from the IUP version
]]

lgi = require 'lgi'
Gtk = lgi.require('Gtk','3.0')
Gdk = lgi.require('Gdk','3.0')
GObject = lgi.GObject

local gui = require('gui_base')

local live = require'gtk_gui_live'
local tree = require'gtk_gui_tree'
local user = require'gtk_gui_user'

-- make global for easier testing
gui.live = live
gui.tree = tree
gui.user = user
gui.sched = require'gtk_gui_sched'

-- Open file select dialog
function gui.file_select(title, filter)
	local dialog = Gtk.FileChooserDialog {
		title = title,
		transient_for = gui.window(),
		action = Gtk.FileChooserAction.OPEN,
		buttons = {
			{ Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL },
			{ Gtk.STOCK_OPEN, Gtk.ResponseType.ACCEPT },
		},
	}
	if filter ~= nil then
		local f = Gtk.FileFilter.new()
		f:add_pattern(filter)
		dialog:set_filter(f)
	end

	-- Shows file dialog in the center of the screen
	local res = dialog:run()
	local file = dialog:get_filename()
	dialog:destroy()

	-- return flag if file selected and file name
	return res == Gtk.ResponseType.ACCEPT, file
end

-- Open file select multiple dialog
function gui.file_select_multiple(title)
	local dialog = Gtk.FileChooserDialog {
		title = title,
		transient_for = gui.window(),
		action = Gtk.FileChooserAction.OPEN,
		buttons = {
			{ Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL },
			{ Gtk.STOCK_OPEN, Gtk.ResponseType.ACCEPT },
		},
	}
	dialog:set_select_multiple(true)

	-- Shows file dialog in the center of the screen
	local res = dialog:run()
	local files = dialog:get_filenames()
	dialog:destroy()

	-- return flag if file selected and file names
	return res == Gtk.ResponseType.ACCEPT, files
end

-- Open file select dialog for file save
function gui.file_select_for_save(title, filename)
	local dialog = Gtk.FileChooserDialog {
		title = title,
		transient_for = gui.window(),
		action = Gtk.FileChooserAction.SAVE,
		do_overwrite_confirmation = true,
		buttons = {
			{ Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL },
			{ Gtk.STOCK_SAVE, Gtk.ResponseType.ACCEPT },
		},
	}
	if filename ~= nil then
		dialog:set_current_name(filename)
	end

	-- Shows file dialog in the center of the screen
	local res = dialog:run()
	local file = dialog:get_filename()
	dialog:destroy()

	-- return flag if file selected and file name
	return res == Gtk.ResponseType.ACCEPT, file
end

-- Open folder select dialog
function gui.folder_select(title, current_folder)
	local dialog = Gtk.FileChooserDialog {
		title = title,
		transient_for = gui.window(),
		action = Gtk.FileChooserAction.SELECT_FOLDER,
		buttons = {
			{ Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL },
			{ Gtk.STOCK_SAVE, Gtk.ResponseType.ACCEPT },
		},
	}
	dialog:set_create_folders(true)
	if current_folder ~= nil then
		dialog:set_filename(current_folder)
	end
	local res = dialog:run()
	local folder = dialog:get_filename()
	dialog:destroy()

	-- return flag if folder selected and folder name
	return res == Gtk.ResponseType.ACCEPT, folder
end

-- Open 'confirm action' dialog. Return true is user clicked 'OK'
function gui.confirm_action(title, body)
	local dialog = Gtk.MessageDialog {
		text = title,
		secondary_text = body,
		transient_for = gui.window(),
		modal = true,
		buttons = Gtk.ButtonsType.OK_CANCEL,
	}
	local rv = dialog:run() == Gtk.ResponseType.OK
	dialog:destroy()
	return rv
end

-- Show info popup
function gui.info_popup(title, body)
	local dialog = Gtk.MessageDialog {
		transient_for = gui.window(),
		destroy_with_parent = true,
		text = title,
		secondary_text = body,
		message_type = 'INFO',
		buttons = Gtk.ButtonsType.OK,
	}
	dialog:run()
	dialog:destroy()
end

function gui.update_mode_dropdown(cur)
	gui.dbgmsg('update mode dropdown %s\n',tostring(cur))
	gui.main_dialog.child.mode_dropdown:remove_all() -- empty the list
	if not gui.mode_list or not cur or cur == 0 then
		return
	end
	gui.mode_map = {}
	local curid
	for i=1,#gui.mode_list do
		gui.main_dialog.child.mode_dropdown:append(i, gui.mode_list[i].name)
		-- list index to chdk value
		gui.mode_map[i] = gui.mode_list[i].id
		if cur == gui.mode_list[i].id then
			curid = i
		end
	end
	gui.main_dialog.child.mode_dropdown:set_active(curid-1)
	gui.dbgmsg('new value %s\n',tostring(gui.mode_map[curid]))
end

function gui.set_connection_status(status)
	if status then
		gui.last_connection_status = true
		gui.main_dialog.child.btn_connect.label = "Disconnect"
		gui.main_dialog.child.connect_icon.stock = Gtk.STOCK_YES
		-- if connection was initialized in a different chdku con wrapper
		-- connection info might not be up to date
		if not con.apiver then
			con:update_connection_info()
		end
		con:do_on_connect_actions()

		gui.main_dialog.child.connect_label.label = string.format("host:%d.%d cam:%d.%d", chdku.apiver.MAJOR,chdku.apiver.MINOR, con.apiver.MAJOR,con.apiver.MINOR)
		gui.update_mode_list()
	else
		gui.last_connection_status = false
		gui.main_dialog.child.btn_connect.label = "Connect"
		gui.main_dialog.child.connect_icon.stock = Gtk.STOCK_NO
		gui.main_dialog.child.connect_label.label = string.format("host:%d.%d cam:-.-",chdku.apiver.MAJOR,chdku.apiver.MINOR)
		gui.clear_mode_list()
		tree.clear();
	end
	live.on_connect_change()
end

function gui.update_cam_list(devs)
	gui.main_dialog.child.cam_dropdown:remove_all() -- empty the list
	local curid
	for i,dev in ipairs(devs) do
		-- TODO name would be nice, but will might hose other connections
		local s=string.format("%s:%s",dev.bus,dev.dev)
		gui.main_dialog.child.cam_dropdown:append(i, s)
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
			gui.main_dialog.child.cam_dropdown:set_active(curid-1)
		else
			gui.dbgmsg('cam_dropdown: current not found, default to 1\n')
			gui.main_dialog.child.cam_dropdown:set_active(0)
--			gui.cam_dropdown:on_changed(gui_camdropdown, nil)
		end
	else
		gui.main_dialog.child.cam_dropdown:set_active(-1) -- none
	end
end

local function exec_input()
	gui.exec_command(gui.main_dialog.child.inputtext.text)
	gui.main_dialog.child.inputtext.text=''
end

local console_page = 0
local console_view;

function gui.statusprint(...)
	local args={...}
	local s = tostring(args[1])
	for i=2,#args do
		s=s .. ' ' .. tostring(args[i])
	end
	console_view.buffer.text = console_view.buffer.text .. s
	gui.statusupdatepos()
end

function gui.statusupdatepos()
	if console_view ~= nil then
		local buffer = console_view.buffer
		local iter = buffer:get_end_iter()
		local mark = buffer:create_mark(nil, iter, true)
		iter:set_line_offset(0)
		buffer:move_mark(mark, iter)
		console_view:scroll_mark_onscreen(mark)
	end
end

local function switch_console(page_num)
	console_page = string.format("%.0f", page_num)
	local view = gui.main_dialog.child['statustext' .. console_page]
	if console_view ~= nil then
		view.buffer.text = console_view.buffer.text
	end
	console_view = view
	gui.statusupdatepos()
	live.on_tab_change()
end

local function cam_script_btn(script,title)
	return Gtk.Button { label = title, on_clicked = function(self) gui.execquick(script) end }
end

local function cam_btn(name,title)
	return cam_script_btn('click("' .. name .. '")', title or name)
end

function gui.create_controls()
	tree:init()
	live:init()
	user:init()

	gui.main_dialog = Gtk.Window {
		default_width = 1000,
		default_height = 640,
		title = "CHDK PTP",
		on_destroy = Gtk.main_quit,
		border_width = 8,
		Gtk.Box {
			orientation = 'VERTICAL',
			spacing = 4,
			Gtk.ButtonBox {
				orientation = 'HORIZONTAL',
				spacing = 4,
				layout_style = 'EDGE',
				Gtk.Box {
					orientation = 'HORIZONTAL',
					spacing = 4,
					Gtk.Image { stock = Gtk.STOCK_NO, id = 'connect_icon' },
					Gtk.Label { label = string.format("host:%d.%d cam:-.- ",chdku.apiver.MAJOR,chdku.apiver.MINOR), id = 'connect_label' },
				},
				Gtk.Box {
					orientation = 'HORIZONTAL',
					spacing = 4,
					Gtk.ComboBoxText {
						id = 'cam_dropdown',
						on_changed = errutil.wrap(function(self, data)
							gui.select_device(self:get_active() + 1)
						end),
					},
					Gtk.Button {
						label = "Connect",
						id = 'btn_connect',
						on_clicked = errutil.wrap(function(self) gui.connect_action() end),
					},
				},
			},
			Gtk.Separator { orientation = 'HORIZONTAL' },
			Gtk.Box {
				orientation = 'HORIZONTAL',
				spacing = 4,
				Gtk.Box {
					orientation = 'VERTICAL',
					spacing = 4,
					Gtk.Notebook {
						id = 'tabs',
						on_switch_page = function(self, page, page_num, data)
							--printf("switch_page %s->%s\n",self.page,page_num)
							-- this is called as pages are added so skip processing until window is finished being created
							if gui.main_dialog ~= nil then
								-- update pref value on tab change, but only after initial pref applied
								if gui.prefs_ready then
									prefs._obj.gui_tab.value = gui.tab_index_to_name(page_num)
								end
								switch_console(page_num)
							end
						end,
						{
							tab_label = 'Console',
							Gtk.Box {
								orientation = 'VERTICAL',
								spacing = 4,
								Gtk.ScrolledWindow {
									Gtk.TextView {
										id = 'statustext0',
										expand = true,
										editable = false,
										cursor_visible = false,
									}
								}
							},
						},
						{
							tab_label = tree:get_container_title(),
							Gtk.Box {
								orientation = 'VERTICAL',
								spacing = 4,
								Gtk.ScrolledWindow {
									height_request = 400,
									tree:get_container(),
								},
								Gtk.Box {
									valign = Gtk.ALIGN_END,
									Gtk.ScrolledWindow {
										Gtk.TextView {
											id = 'statustext1',
											expand = true,
											editable = false,
											cursor_visible = false,
										}
									}
								},
							},
						},
						{
							tab_label = live:get_container_title(),
							Gtk.Box {
								orientation = 'VERTICAL',
								spacing = 4,
								Gtk.Box {
									height_request = 400,
									live:get_container(),
								},
								Gtk.Box {
									valign = Gtk.ALIGN_END,
									Gtk.ScrolledWindow {
										Gtk.TextView {
											id = 'statustext2',
											expand = true,
											editable = false,
											cursor_visible = false,
										}
									}
								},
							},
						},
						{
							tab_label = user:get_container_title(),
							Gtk.Box {
								orientation = 'VERTICAL',
								spacing = 4,
								Gtk.Box {
									height_request = 400,
									user:get_container(),
								},
								Gtk.Box {
									valign = Gtk.ALIGN_END,
									Gtk.ScrolledWindow {
										Gtk.TextView {
											id = 'statustext3',
											expand = true,
											editable = false,
											cursor_visible = false,
										}
									}
								},
							},
						},
					},
					Gtk.Box {
						orientation = 'HORIZONTAL',
						spacing = 4,
						Gtk.Entry {
							id = 'inputtext',
							hexpand = true,
							on_activate = exec_input,
							on_key_press_event = function(self, ev, d)
								if ev.keyval == Gdk.KEY_Up then
									local hval = gui.cmd_history:prev()
									if hval then
										self.text = hval
									end
									return true
								end
								if ev.keyval == Gdk.KEY_down then
									self.text = gui.cmd_history:next()
									return true
								end
								return false
							end
						},
						Gtk.Button {
							label = "Execute",
							on_clicked = exec_input,
						},
					}
				},
				Gtk.ButtonBox {
					orientation = 'VERTICAL',
					spacing = 4,
					layout_style = 'EDGE',
					Gtk.Box {
						orientation = 'VERTICAL',
						spacing = 4,
						Gtk.ButtonBox{
							orientation = 'HORIZONTAL',
							spacing = 4,
							layout_style = 'SPREAD',
							cam_btn('erase'),
							cam_btn('up'),
							cam_btn('print'),
						},
						Gtk.ButtonBox{
							orientation = 'HORIZONTAL',
							spacing = 4,
							layout_style = 'SPREAD',
							cam_btn('left'),
							cam_btn('set'),
							cam_btn('right'),
						},
						Gtk.ButtonBox{
							orientation = 'HORIZONTAL',
							spacing = 4,
							layout_style = 'SPREAD',
							cam_btn('display','disp'),
							cam_btn('down'),
							cam_btn('menu'),
						},
						Gtk.Separator { orientation = 'HORIZONTAL' },
						Gtk.ButtonBox {
							orientation = 'HORIZONTAL',
							spacing = 4,
							layout_style = 'SPREAD',
							cam_btn('zoom_in', 'zoom+'),
							cam_btn('zoom_out', 'zoom-'),
						},
						Gtk.ButtonBox {
							orientation = 'HORIZONTAL',
							spacing = 4,
							layout_style = 'SPREAD',
							cam_script_btn('wheel_left()', 'wheel l'),
							cam_script_btn('wheel_right()', 'wheel r'),
						},
						Gtk.Separator { orientation = 'HORIZONTAL' },
						Gtk.ButtonBox {
							orientation = 'HORIZONTAL',
							spacing = 4,
							layout_style = 'SPREAD',
							-- TODO we should have a way to press shoot half and have it stay down,
							-- so we can do normal shooting proccess
							Gtk.Button {
								label = 'shoot half',
								on_clicked = function(self)
									gui.execquick(string.format(gui.shoot_half_script, prefs.gui_shoot_half_timeout))
								end,
							},
							cam_btn('video'),
						},
						Gtk.ButtonBox {
							orientation = 'HORIZONTAL',
							spacing = 4,
							layout_style = 'SPREAD',
							cam_script_btn(gui.shoot_script, 'shoot'),
						},
						Gtk.Separator { orientation = 'HORIZONTAL' },
						Gtk.ButtonBox {
							orientation = 'HORIZONTAL',
							spacing = 4,
							layout_style = 'SPREAD',
							Gtk.Button {
								label = 'rec',
								on_clicked = function(self) gui.switch_mode(1) end,
							},
							Gtk.Button {
								label = 'play',
								on_clicked = function(self) gui.switch_mode(0) end,
							},
						},
						Gtk.Separator { orientation = 'HORIZONTAL' },
						Gtk.ComboBoxText {
							id = 'mode_dropdown',
							on_changed = errutil.wrap(function(self, data)
								local v = self:get_active() + 1
								-- 0 means none selected. Callback can be called with this (multiple times) when list is emptied
								if v < 1 then
									return
								end
								gui.dbgmsg('mode_dropdown %s\n',tostring(v))
								if not gui.mode_map or not gui.mode_map[v] then
									gui.infomsg('tried to set invalid mode %s\n',tostring(v))
									return
								end
								gui.execquick(string.format('set_capture_mode(%d)',gui.mode_map[v]))
							end),
						},
					},
					Gtk.ButtonBox {
						orientation = 'HORIZONTAL',
						spacing = 4,
						layout_style = 'SPREAD',
						cam_script_btn('shut_down()', 'shutdown'),
						cam_script_btn('reboot()', 'reboot'),
					},
				},
			},
		}
	}
end

--[[
size the dialog large enough for the content
]]
function gui.resize_for_content(refresh)
end

function gui.run()
	gui.create_controls()
	gui.main_dialog:set_position(Gtk.WindowPosition.CENTER)
	gui.main_dialog:override_background_color(0, Gdk.RGBA { red = 0.9, green = 0.9, blue = 0.9, alpha = 1 })
	gui.main_dialog.child.tabs:override_background_color(0, Gdk.RGBA { red = 0.9, green = 0.9, blue = 0.9, alpha = 1 })
	gui.main_dialog:show_all()
	gui.sched.init_timer(20)

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
	Gtk.main()

	gui.on_exit()
end

function gui.set_tab(i)
	gui.main_dialog.child.tabs:set_current_page(i)
	-- unlike IUP, callback is automatically called
end

function gui.get_tab_index()
	return gui.main_dialog.child.tabs.page
end

function gui.close()
	Gtk.main_quit()
end

function gui.window()
	return gui.main_dialog
end

function gui.is_live_view()
	return console_page == '2'
end

return gui
