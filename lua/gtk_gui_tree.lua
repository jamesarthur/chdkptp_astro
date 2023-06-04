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
module for gui tree view
]]

local Pango = lgi.Pango

local m = require'gui_tree_base'

local lc = {
	ICON = 1,
	TITLE = 2,
	STYLE = 3,
	PATH = 4,
	ISDIR = 5,
	ISFILE = 6,
	MTIME = 7,
	SIZE = 8,
}

local model = Gtk.TreeStore.new {
	[lc.ICON] = GObject.Type.STRING,
	[lc.TITLE] = GObject.Type.STRING,
	[lc.STYLE] = Pango.Style,
	[lc.PATH] = GObject.Type.STRING,
	[lc.ISDIR] = GObject.Type.BOOLEAN,
	[lc.ISFILE] = GObject.Type.BOOLEAN,
	[lc.MTIME] = GObject.Type.UINT64,
	[lc.SIZE] = GObject.Type.UINT64,
}

local function add(parent, name, path, isdir, isfile, mtime, size)
	if path == '' then
		path = 'A/'
	elseif path == 'A/' then
		path = path .. name
	else
		path = path .. '/' .. name
	end
	return model:append(parent, {
			[lc.ICON] = isdir and Gtk.STOCK_DIRECTORY or Gtk.STOCK_FILE,
			[lc.TITLE] = name,
			[lc.STYLE] = 'NORMAL',
			[lc.PATH] = path,
			[lc.ISDIR] = isdir,
			[lc.ISFILE] = isfile,
			[lc.MTIME] = mtime,
			[lc.SIZE] = size,
		})
end

local function clear_branch(parent)
	local child = model:iter_children(parent)
	while model:iter_is_valid(child) do
		model:remove(child)
	end
end

local function find_parent(path)
	local parent = model:get_first_iter()
	model:foreach(
		function(m, p, i, d)
			local r = m:get_value(i,lc.PATH-1)
			if r.value == path then
				parent = m:get_iter(p)
				return true
			end
			return false
		end, nil)
	return parent
end

local function populate(parent, path)
	local has_children = false
	if con:is_connected() then
		gui.dbgmsg('populate branch %s\n',path)
		local list,msg = con:listdir(path,{stat='*'})
		if type(list) == 'table' then
			chdku.sortdir_stat(list)
			for i=1, #list do
				st = list[i]
				if st.is_dir then
					local b = add(parent, st.name, path, true, false, st.mtime, st.size)
					add(b, '?', '', false, false, 0, 0)
				else
					add(parent, st.name, path, false, st.is_file, st.mtime, st.size)
				end
				has_children = true
			end
		end
	else
		gui.dbgmsg('files list - not connected\n')
	end
	if not has_children then
		add(parent, '?', '', false, false, 0, 0)
	end
	return has_children
end

local function populate_model(parent)
	local path = model:get_value(parent,lc.PATH-1)
	clear_branch(parent)
	return populate(parent, path.value)
end

local expanding = false

-- path is TreeModel path, not files system path
local function refresh_branch(iter, path)
	if not expanding then
		expanding = true
		if populate_model(iter) then
			m.tree:expand_row(path, false)
		end
		expanding = false
	end
end

local function refresh_parent(item)
	local parent = model:get_path(item)
	parent:up()
	refresh_branch(model:get_iter(parent), parent)
end

-- Get directory nane from user input
function m.get_dir_name(remotepath)
	local dialog = Gtk.MessageDialog {
		transient_for = gui.window(),
		destroy_with_parent = true,
		text = 'Create directory in:',
		secondary_text = remotepath,
		message_type = 'QUESTION',
		buttons = Gtk.ButtonsType.OK_CANCEL,
	}
	local entry = Gtk.Entry { activates_default = true, hexpand = true }
	dialog:get_content_area():add(entry)
	entry.has_focus = true
	local ok = dialog:get_widget_for_response(Gtk.ResponseType.OK)
	ok:set_can_default(true)
	ok:grab_default()

	dialog:show_all()
	local res = dialog:run()
	local dirname = entry:get_text()
	dialog:destroy()

	return res == Gtk.ResponseType.OK and dirname or nil
end

--tree.dropfiles_cb=errutil.wrap(function(self,filename,num,x,y)
	-- note id -1 > not on any specific item
--	local id = iup.ConvertXYToPos(self,x,y)
--	gui.dbgmsg('dropfiles_cb: %s %d %d %d %d\n',filename,num,x,y,id)
--	-- on unrecognized spot defaults to root
--	if id == -1 then
--		gui.infomsg("must drop on a directory\n")
--		return iup.IGNORE
--		-- TODO could default to root, or selected
--		-- but without confirm it's would be easy to miss
--		-- id = 0
--	end
--	local data = self:get_data(id)
--	local remotepath = data:fullpath()
--	if not data.stat.is_dir then
--		-- TODO for single files we might want to just overwrite
--		-- or drop back to parent?
--		gui.infomsg("can't upload to non-directory %s\n",remotepath)
--		return iup.IGNORE
--	end
--
--	local up_path = remotepath
--
--	if lfs.attributes(filename,'mode') == 'directory' then
--		-- if dropped item is dir, append the last directory component to the remote name
--		-- otherwise we would just upload the contents
--		up_path = fsutil.joinpath_cam(up_path,fsutil.basename(filename))
--	end
--	gui.infomsg("upload %s to %s\n",filename,remotepath)
--	-- TODO no cancel, no overwrite options!
--	-- unfortunately called for each dropped item
--	con:mupload({filename},up_path)
--	self:refresh_tree_by_path(remotepath)
--end)

local function rightclick(item, event)
	if not con:is_connected() then
		gui.dbgmsg('tree right click: not connected\n')
		return
	end
	local path = model:get_value(item, lc.PATH-1).value
	local isdir = model:get_value(item, lc.ISDIR-1).value
	local isfile = model:get_value(item, lc.ISFILE-1).value
	local mtime = model:get_value(item, lc.MTIME-1).value
	local size = model:get_value(item, lc.SIZE-1).value
	gui.dbgmsg('tree right click: path %s\n',path)
	local menu
	if isdir then
		menu = Gtk.Menu {
			Gtk.MenuItem {
				label = 'Refresh',
				on_activate = errutil.wrap(function()
					refresh_branch(item, model:get_path(item))
				end),
			},
			-- the default file selector doesn't let you multi-select with directories
			Gtk.MenuItem {
				label = 'Upload files...',
				on_activate = errutil.wrap(function()
					if m.do_upload_dialog(path) then
						refresh_branch(item, model:get_path(item))
					end
				end),
			},
			Gtk.MenuItem {
				label = 'Upload directory contents...',
				on_activate = errutil.wrap(function()
					if m.do_dir_upload_dialog(path) then
						refresh_branch(item, model:get_path(item))
					end
				end),
			},
			Gtk.MenuItem {
				label = 'Download contents...',
				on_activate = errutil.wrap(function()
					m.do_dir_download_dialog(path)
				end),
			},
			Gtk.MenuItem {
				label = 'Create directory...',
				on_activate = errutil.wrap(function()
					if m.do_mkdir_dialog(path) then
						refresh_branch(item, model:get_path(item))
					end
				end),
			},
		}
	else
		menu = Gtk.Menu {
			Gtk.MenuItem {
				label = 'Download...',
				on_activate = errutil.wrap(function()
					m.do_download_dialog(path, mtime)
				end),
			},
		}
	end
	menu:append(Gtk.MenuItem {
		label = 'Delete...',
		on_activate = errutil.wrap(function()
			if m.do_delete_dialog(path, isdir) then
				refresh_parent(item)
			end
		end),
	})
	menu:append(Gtk.MenuItem {
		label = 'Properties...',
		on_activate = errutil.wrap(function()
			m.do_properties_dialog(path, isdir, isfile, mtime, size)
		end),
	})
	menu:show_all()
	menu:popup(nil, nil, nil, event.button, event.time)
end

function m.clear()
	model:clear()
	local root = add(nil, 'Camera', '', true, false, 0, 0)
	add(root, '?', '', false, false, 0, 0)
end

function m.init()
	m.tree = Gtk.TreeView {
		headers_visible = false,
		model = model,
		on_row_expanded = function(self, i, p, d)
			refresh_branch(i, p)
		end,
		on_button_release_event = function(self, event)
			if event.button ~= 3 then return false end
			local m, r = self:get_selection():get_selected()
			rightclick(r, event)
		end,
		Gtk.TreeViewColumn {
			{ Gtk.CellRendererText {}, { text = lc.TITLE, style = lc.STYLE } },
			{ Gtk.CellRendererPixbuf {}, { stock_id = lc.ICON } },
		},
	}
end

function m.get_container()
	return m.tree
end

function m.on_dlg_run()
	m.clear()
end

return m
