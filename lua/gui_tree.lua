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
local m=require'gui_tree_base'

-- Get directory name from user input
function m.get_dir_name(remotepath)
	return iup.Scanf("Create directory\n"..remotepath.."%64.11%s\n",'');
end

function m.init()
	m.tree = iup.tree{}
	m.tree.title="Camera"
	m.tree.state="collapsed"
	m.tree.addexpanded="NO"
	-- default
	-- m.tree.addroot="YES"

	function m.tree:get_data(id)
		return iup.TreeGetUserId(self,id)
	end

	-- TODO we could keep a map somewhere
	function m.tree:get_id_from_path(fullpath)
		local id = 0
		while true do
			local data = self:get_data(id)
			if data then
				if not data.dummy then
					if data:fullpath() == fullpath then
						return id
					end
				end
			else
				return
			end
			id = id + 1
		end
	end

	-- TODO
	local filetreedata_getfullpath = function(self)
		-- root is special special, we don't want to add slashes
		if self.name == 'A/' then
			return 'A/'
		end
		if self.path == 'A/' then
			return self.path .. self.name
		end
		return self.path .. '/' .. self.name
	end

	function m.tree:set_data(id,data)
		data.fullpath = filetreedata_getfullpath
		iup.TreeSetUserId(self,id,data)
	end

	function m.tree:refresh_tree_by_id(id)
		if not id then
			printf('refresh_tree_by_id: nil id\n')
			return
		end
		local oldstate=self['state'..id]
		local data=self:get_data(id)
		gui.dbgmsg('old state %s\n', tostring(oldstate))
		self:populate_branch(id,data:fullpath())
		if oldstate and oldstate ~= self['state'..id] then
			self['state'..id]=oldstate
		end
	end

	function m.tree:refresh_tree_by_path(path)
		gui.dbgmsg('refresh_tree_by_path: %s\n',tostring(path))
		local id = self:get_id_from_path(path)
		if id then
			gui.dbgmsg('refresh_tree_by_path: found %s\n',tostring(id))
			self:refresh_tree_by_id(id)
		else
			gui.dbgmsg('refresh_tree_by_path: failed to find %s\n',tostring(path))
		end
	end

	m.tree.dropfiles_cb=errutil.wrap(function(self,filename,num,x,y)
		-- note id -1 > not on any specific item
		local id = iup.ConvertXYToPos(self,x,y)
		gui.dbgmsg('dropfiles_cb: %s %d %d %d %d\n',filename,num,x,y,id)
		-- on unrecognized spot defaults to root
		if id == -1 then
			gui.infomsg("must drop on a directory\n")
			return iup.IGNORE
			-- TODO could default to root, or selected
			-- but without confirm it's would be easy to miss
			-- id = 0
		end
		local data = self:get_data(id)
		local remotepath = data:fullpath()
		if not data.stat.is_dir then
			-- TODO for single files we might want to just overwrite
			-- or drop back to parent?
			gui.infomsg("can't upload to non-directory %s\n",remotepath)
			return iup.IGNORE
		end

		local up_path = remotepath

		if lfs.attributes(filename,'mode') == 'directory' then
			-- if dropped item is dir, append the last directory component to the remote name
			-- otherwise we would just upload the contents
			up_path = fsutil.joinpath_cam(up_path,fsutil.basename(filename))
		end
		gui.infomsg("upload %s to %s\n",filename,remotepath)
		-- TODO no cancel, no overwrite options!
		-- unfortunately called for each dropped item
		con:mupload({filename},up_path)
		self:refresh_tree_by_path(remotepath)
	end)

	function m.tree:rightclick_cb(id)
		local data=self:get_data(id)
		if not data then
			return
		end
		if not con:is_connected() then
			gui.dbgmsg('tree right click: not connected\n')
			return
		end
		if data.fullpath then
			gui.dbgmsg('tree right click: fullpath %s\n',data:fullpath())
		end
		local delete_option = iup.item{
			title='Delete...',
			action=errutil.wrap(function()
				if m.do_delete_dialog(data:fullpath(),data.stat.is_dir) then
					m.tree:refresh_tree_by_path(fsutil.dirname_cam(data:fullpath()))
				end
			end),
		}
		local properties_option = iup.item{
			title='Properties...',
			action=errutil.wrap(function()
				m.do_properties_dialog(data:fullpath(), data.stat.is_dir, data.stat.is_file, data.stat.mtime, data.stat.size)
			end),
		}
		if data.stat.is_dir then
			iup.menu{
				iup.item{
					title='Refresh',
					action=errutil.wrap(function()
						self:refresh_tree_by_id(id)
					end),
				},
				-- the default file selector doesn't let you multi-select with directories
				iup.item{
					title='Upload files...',
					action=errutil.wrap(function()
						if m.do_upload_dialog(data:fullpath()) then
							m.tree:refresh_tree_by_path(data:fullpath())
						end
					end),
				},
				iup.item{
					title='Upload directory contents...',
					action=errutil.wrap(function()
						if m.do_dir_upload_dialog(data:fullpath()) then
							m.tree:refresh_tree_by_path(data:fullpath())
						end
					end),
				},
				iup.item{
					title='Download contents...',
					action=errutil.wrap(function()
						m.do_dir_download_dialog(data:fullpath())
					end),
				},
				iup.item{
					title='Create directory...',
					action=errutil.wrap(function()
						if m.do_mkdir_dialog(data:fullpath()) then
							m.tree:refresh_tree_by_path(data:fullpath())
						end
					end),
				},
				delete_option,
				properties_option,
			}:popup(iup.MOUSEPOS,iup.MOUSEPOS)
		else
			iup.menu{
				iup.item{
					title='Download...',
					action=errutil.wrap(function()
						m.do_download_dialog(data:fullpath(), data.stat.mtime)
					end),
				},
				delete_option,
				properties_option,
			}:popup(iup.MOUSEPOS,iup.MOUSEPOS)
		end
	end

	function m.tree:populate_branch(id,path)
		self['delnode'..id] = "CHILDREN"
		gui.dbgmsg('populate branch %s %s\n',id,path)
		if id == 0 then
			m.tree.state="collapsed"
		end
		local list,msg = con:listdir(path,{stat='*'})
		if type(list) == 'table' then
			chdku.sortdir_stat(list)
			for i=#list, 1, -1 do
				st = list[i]
				if st.is_dir then
					self['addbranch'..id]=st.name
					self:set_data(self.lastaddnode,{name=st.name,stat=st,path=path})
					-- dummy, otherwise tree nodes not expandable
					-- TODO would be better to only add if dir is not empty
					self['addleaf'..self.lastaddnode] = 'dummy'
					self:set_data(self.lastaddnode,{dummy=true})
				else
					self['addleaf'..id]=st.name
					self:set_data(self.lastaddnode,{name=st.name,stat=st,path=path})
				end
			end
		end
	end

	m.tree.branchopen_cb=errutil.wrap(function(self,id)
		gui.dbgmsg('branchopen_cb %s\n',id)
		if not con:is_connected() then
			gui.dbgmsg('branchopen_cb not connected\n')
			return iup.IGNORE
		end
		local path
		if id == 0 then
			path = 'A/'
			local st,err=con:stat(path)
			if not st then
				gui.add_status(st,err)
				st = {is_dir=true,size=0,mtime=0}
			end
			m.tree:set_data(0,{name='A/',stat=st,path=''})
		end
		local data = self:get_data(id)
		self:populate_branch(id,data:fullpath())
	end)
end

-- empty the tree, and add dummy we always re-populate on expand anyway
-- this crashes in gtk
--[[
function m.tree:branchclose_cb(id)
	self['delnode'..id] = "CHILDREN"
	self['addleaf'..id] = 'dummy'
end
]]

function m.get_container()
	return m.tree
end

function m.on_dlg_run()
	m.tree.addbranch0="dummy"
	m.tree:set_data(0,{name='A/',stat={is_dir=true},path=''})
end
return m
