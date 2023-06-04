--[[
 Copyright (C) 2012-2021 <reyalp (at) gmail dot com>
  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  with chdkptp. If not, see <http://www.gnu.org/licenses/>.

--]]

-- wrapper that makes old documented commands work
local m = require'tests/nocam'

function m:run(name)
	if not name or name == m.tests.name then
		m.tests:do_test()
	else
		m.tests:do_subtest(name)
	end
end
function m:runall()
	m.tests:do_test()
end
return m
