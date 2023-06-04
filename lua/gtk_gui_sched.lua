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
module for gui timer/scheduler
]]

local GLib = lgi.GLib

local m={}

--[[
call scheduled function after time ms
]]
function m.run_after(time,fn,data)
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, time,
		function()
			fn()
			return false
		end)
end

function m.run_repeat(time,fn,data)
	local t = {
		time = time,
		cur_time = time,
		fn = fn,
		data = data,
	}

	t.cancel = function(self)
		GLib.source_remove(self.id)
	end

	t.run_timer = function()
		t.last = ticktime.get()
		t:fn()
		-- if interval has changed, create new timer and cancel old by returning false
		if t.time ~= t.cur_time then
			t.cur_time = t.time
			t.id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, t.time, t.run_timer)
			return false
		end
		return true
	end

	t.id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, time, t.run_timer)

	return t
end

-- unlike IUP version, there is no global, minimum time
function m.init_timer(unused)
	m.is_init = true
	m.min_time = 10 -- arbitrary min time for gui.chdk_sleep
end

function m.is_initialized()
	return m.is_init
end

function m.min_interval()
	return m.min_time
end

return m
