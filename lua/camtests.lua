--[[
 Copyright (C) 2013-2021 <reyalp (at) gmail dot com>
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

-- wrapper that makes old documented commands work
local m = require'tests/cam'

function m.run(name)
	if not name then
		error('no test specified')
	elseif name == m.tests.name then
		m.tests:do_test()
	else
		m.tests:do_subtest(name)
	end
end

function m.runbatch(opts)
	if not opts then
		opts={}
	end
	local test_opts = {
		connect_dev=opts.devspec,
		skip_paths={}
	}
	if not opts.bench then
		table.insert(test_opts.skip_paths,'cam.bench')
	end
	if not opts.xfersizebugs then
		table.insert(test_opts.skip_paths,'cam.xfersizebugs')
	end
	if not opts.filexfer then
		table.insert(test_opts.skip_paths,'cam.filexfer')
	end
	if not opts.shoot then
		table.insert(test_opts.skip_paths,'cam.shoot')
	end
	m.tests:do_test(test_opts)
end

return m
