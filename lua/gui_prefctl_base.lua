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
Utility module for linking prefs with gui controls
]]
local m={
	-- table of objects describing linking to controls, by pref name
	ctls = {}
}

-- function to be used as a pref set function
function m.pref_set_fn(pref, value)
	local pctl = m.ctls[pref.name]
	-- if no control defined, assumed to be initialization, just save the value
	if pctl then
		pctl:set(value)
	end
	pref.value = value
end

function m.bind(pref_name, ctl, set_fn, get_fn)
	local pref=prefs._obj[pref_name]
	if not pref then
		errlib.throw{etype='bad_arg',msg='unknown pref '..tostring(pref_name)}
	end
	m.ctls[pref_name] = {
		ctl = ctl,
		set = set_fn,
		get = get_fn,
	}
	-- hook into the prefs set_value function
	local orig_set_value = pref.set_value
	pref.set_value = function(self, value)
		m.ctls[pref_name]:set(value)
		orig_set_value(self,value)
	end
	-- return GUI control to allow using in nested GUI components
	return ctl
end
return m
