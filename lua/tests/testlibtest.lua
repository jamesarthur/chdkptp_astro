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

--[[
scratchpad to test testlib framwork
intended to be used with dofile like
chdkptp -e"exec t=dofile('lua/tests/testlibtest.lua') t:do_test()"
]]
local testlib=util.forcerequire'testlib'
return testlib.new_test{
'Group',
{
	{
		'Sub1',
		function()
			print'hi from sub1'
		end,
	},
	{
		'Sub2',
		function()
			error('sub2 failed!')
		end,
	},
	{
		'Subgroup1',
		{
			{
				's1t1',
				function()
					print('hola from s1t1')
				end,
			},
			{
				's1t2',
				function()
					print('hola from s1t2')
				end,
				setup=function()
					return false
				end,
				cleanup=function()
					error('s1t2 cleanup should not be reached!')
				end,
			},
			{
				's1t3',
				function()
					error('s1t3 fails')
				end,
				cleanup=function()
					error('s1t3 cleanup fails too!')
				end,
			},
			{
				's1t4',
				function()
					error('s1t4 should not be reached!')
				end,
				setup=function()
					error('s1t4 setup fails!')
				end,
				cleanup=function()
					print('s1t4 cleanup!')
				end,
			},
		},
		setup=function()
			print('subgroup1 setup')
		end,
		cleanup=function()
			print('subgroup1 cleanup')
		end,
	},

},
}
