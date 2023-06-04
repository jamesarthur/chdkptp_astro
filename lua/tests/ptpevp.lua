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
tests for Canon PTP/eveptroc API
not included in standard tests, because not all cams support,
eventprocs are camera specific and some tests require custom build
--]]
local testlib=require'testlib'
local orig_info_fn = chdku.ptp_txn_info_fn
local tests=testlib.new_test({
'ptpevp',{
{
	'drystd',
	function()
		local msg = {}
		chdku.ptp_txn_info_fn = function(fmt,...) table.insert(msg,fmt:format(...)) end
		con:ptpevp_initiate({verbose=true})
		testlib.assert_eq(#msg,6)
		for i=1,6,2 do
			testlib.assert_eq(msg[i],'txn_nodata 0x9050 CANON.InitiateEventProc0 \n')
			testlib.assert_eq(msg[i+1],'ret=\n')
		end
		msg = {}
		-- no params
		local r={con:ptpevp_call('System.Create',{verbose=true})}
		testlib.assert_eq(msg[1],'txn_senddata 0x9052 CANON.ExecuteEventProc data len=22 0x0 (0), 0x0 (0)\n')
		testlib.assert_eq(msg[2],'ret=0x0 (0)\n')
		testlib.assert_eq(#r,1)
		testlib.assert_eq(r[1],0)
		-- single int, for later use
		local p=con:ptpevp_call('AllocateMemory',64)
		assert(p > 0)
		-- multiple long and regular args
		local cnt=con:ptpevp_call('sprintf',p,'Hello %d %s %d\n\0',2,'world\0',123)
		testlib.assert_eq(cnt,18)

		local fh=con:ptpevp_call('Fopen_Fut','A/test.txt\0','w\0')
		assert(fh > 0)
		local r=con:ptpevp_call('Fwrite_Fut',p,1,cnt,fh,{async=true,wait=true,rtype='detail'})
		testlib.assert_eq(r.f_ret, cnt)
		testlib.assert_eq(r.is_run_ret[1], 2)
		testlib.assert_eq(#r.exec_ret, 0)
		con:ptpevp_call('Fclose_Fut',fh)

		testlib.assert_eq(con:readfile('test.txt'),'Hello 2 world 123\n')

		con:ptpevp_terminate()
	end,
	setup=function(self,opts)
		self:ensure_connected(opts)
		if not util.in_table(con:get_ptp_devinfo().OperationsSupported,0x9050) then
			printf('cam does not support InitiateEventproc, skipping\n')
			return false
		end
	end,
	cleanup = function()
		chdku.ptp_txn_info_fn = orig_info_fn
		cli:execute('rm test.txt')
	end,
},
-- test return data functionality. Requires custom build with eventprocs from
-- https://chdk.setepontos.com/index.php?topic=4338.msg147759#msg147759
{
	'testbuild',
	function()
		con:ptpevp_initiate()
		-- basic call
		testlib.assert_eq(con:ptpevp_call('test_simple'),0xdead)
		-- basic call, async + wait
		testlib.assert_eq(con:ptpevp_call('test_slow',200,{async=true,wait=true}),0xbeef)

		-- sync with data
		local r={con:ptpevp_call('test_retdata',411,{rdata=true})}
		testlib.assert_eq(#r,2)
		assert(r[2]:match("ret 0x[0-9a-f]+ 0x[0-9a-f]+ 0x0000019b"))
		testlib.assert_eq(r[1],0)

		-- async with data
		local r=con:ptpevp_call('test_retdata_slow',0xFF000000,200,{rdata=true,async=true,wait=true,rtype='detail'})
		testlib.assert_eq(r.f_ret,0)
		assert(r.rdata:match("retslow 0x[0-9a-f]+ 0x[0-9a-f]+ 0xff000000 200"))
		testlib.assert_eq(#r.is_run_ret,3)
		testlib.assert_eq(r.is_run_ret[1],2)
		testlib.assert_eq(r.is_run_ret[2],0)
		testlib.assert_eq(r.is_run_ret[3],45)

		-- start async without waiting
		local r=con:ptpevp_call('test_retdata_slow',0xFF000000,200,{rdata=true,async=true})
		testlib.assert_eq(r,nil)

		-- wait and get data
		local r=con:ptpevp_wait()
		assert(r.rdata:match("retslow 0x[0-9a-f]+ 0x[0-9a-f]+ 0xff000000 200"))
		testlib.assert_eq(#r.is_run_ret,3)
		testlib.assert_eq(r.is_run_ret[1],2)
		testlib.assert_eq(r.is_run_ret[2],0)
		testlib.assert_eq(r.is_run_ret[3],45)
	end,
	setup=function(self,opts)
		self:ensure_connected(opts)
		if not util.in_table(con:get_ptp_devinfo().OperationsSupported,0x9050) then
			printf('cam does not support InitiateEventproc, skipping\n')
			return false
		end
	end,
	cleanup = function()
		chdku.ptp_txn_info_fn = orig_info_fn
	end,
},
}})
return tests
