--[[
 Copyright (C) 2022 <reyalp (at) gmail dot com>

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
Utility module for linking prefs with gui controls - lgi
]]
local m=require'gui_prefctl_base'

-- create and return a checkbox control bound to a boolean pref
--[[
opts = {
	title=string -- label
	pref=string -- pref name
	-- optional
	pref_to_ctl=f(value) -- function which converts pref value to control value
	ctl_to_pref=f(value) -- function which converts control value to pref value
}
returns GUI control, to allow using as a drop-in replacement for control constructors
--]]

function m.toggle(opts)
	opts=util.extend_table({
		-- in lgi, checkbox values are already boolean
		pref_to_ctl=function(value) return value end,
		ctl_to_pref=function(value) return value end,
	},opts)
	if type(opts.title) ~= 'string' then
		errlib.throw{etype='bad_arg',msg='bad/missing title'}
	end
	if type(opts.pref) ~= 'string' then
		errlib.throw{etype='bad_arg',msg='bad/missing pref'}
	end

	local ctl = Gtk.CheckButton {
		active = prefs[opts.pref],
		label = opts.title,
		on_toggled = function(self)
			prefs[opts.pref] = opts.ctl_to_pref(self.active)
		end,
	}
	m.bind(opts.pref,ctl,
		function(self,value)
			value = opts.pref_to_ctl(value)
			if value ~= self.ctl.active then
				self.ctl.active = value
			end
		end,
		function(self)
			return opts.ctl_to_pref(self.ctl.active)
		end
	)
	return ctl
end
return m
