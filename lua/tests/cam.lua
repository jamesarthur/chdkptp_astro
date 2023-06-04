--[[
 Copyright (C) 2013-2022 <reyalp (at) gmail dot com>
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
some tests to run against the camera
--]]
local m={}

local testlib=require'testlib'

function m.make_stats(stats)
	local r={
		total=0
	}

	if #stats == 0 then
		return r
	end

	for i,v in ipairs(stats) do
		if not r.max or v > r.max then
			r.max = v
		end
		if not r.min or v < r.min then
			r.min = v
		end
		r.total = r.total + v
	end
	r.mean = r.total/#stats
	return r
end


--[[
repeatedly start scripts, measuring time
opts:{
	count=number -- number of iterations
	code=string  -- code to run
}
]]
function m.exectime(opts)
	opts = util.extend_table({count=100, code="dummy=1"},opts)
	if not con:is_connected() then
		error('not connected')
	end
	local times={}
	local tstart = ticktime.get()
	for i=1,opts.count do
		local t0 = ticktime.get()
		con:exec(opts.code,{nodefaultlib=true})
		table.insert(times,ticktime.elapsed(t0))
		-- wait for the script to be done
		con:wait_status{run=false}
	end
	local wall_time = ticktime.elapsed(tstart)
	local stats = m.make_stats(times)
	printf("exec %d mean %.4f min %.4f max %.4f total %.4f (%.4f/sec) wall %.4f (%.4f/sec)\n",
		opts.count,
		stats.mean,
		stats.min,
		stats.max,
		stats.total, opts.count / stats.total,
		wall_time, opts.count / wall_time)
end

--[[
repeatedly exec code and wait for return, checking that returned value = retval
opts:{
	count=number -- number of iterations
	code=string  -- code to run, should return something
	retval=value -- value code is expected to return
}
--]]
function m.execwaittime(opts)
	opts = util.extend_table({count=100, code="return 1",retval=1},opts)
	if not con:is_connected() then
		error('not connected')
	end
	local times={}
	local tstart = ticktime.get()
	for i=1,opts.count do
		local t0 = ticktime.get()
		local r = con:execwait(opts.code,{nodefaultlib=true,poll=50})
		if r ~= opts.retval then
			error('bad retval '..tostring(r) .. ' ~= '..tostring(opts.retval))
		end
		table.insert(times,ticktime.elapsed(t0))
	end
	local wall_time = ticktime.elapsed(tstart)
	local stats = m.make_stats(times)
	printf("execw %d mean %.4f min %.4f max %.4f total %.4f (%.4f/sec) wall %.4f (%.4f/sec)\n",
		opts.count,
		stats.mean,
		stats.min,
		stats.max,
		stats.total, opts.count / stats.total,
		wall_time, opts.count / wall_time)
end

function m.fake_rsint_input(seq)
	return function()
		while true do
			-- ensure sequence ends
			if #seq == 0 then
				return 'l'
			end
			local op=table.remove(seq,1)
			if type(op) == 'number' then
				sys.sleep(op)
			elseif type(op) == 'string' then
				return op
			end
		end
	end
end

--[[
repeatedly time memory transfers from cam
opts:{
	count=number -- number of iterations
	size=number  -- size to transfer
	addr=number  -- address to transfer from (default 0x1900)
	buffer=bool  -- use camera side buffered getmem
}
]]
function m.xfermem(opts)
	opts = util.extend_table({count=100, size=1024*1024,addr=0x1900,buffer=false},opts)
	if not con:is_connected() then
		error('not connected')
	end
	local times={}
	local tstart = ticktime.get()
	local flags = 0
	if opts.buffer then
		flags = 1
	end
	for i=1,opts.count do
		local t0 = ticktime.get()
		local v=con:getmem(opts.addr,opts.size,'string',flags)
		table.insert(times,ticktime.elapsed(t0))
	end
	local wall_time = ticktime.elapsed(tstart)
	local stats = m.make_stats(times)
	printf("%d x %d bytes mean %.4f min %.4f max %.4f total %.4f (%.0f byte/sec) wall %.4f (%.0f byte/sec)\n",
		opts.count,
		opts.size,
		stats.mean,
		stats.min,
		stats.max,
		stats.total, opts.count*opts.size / stats.total,
		wall_time, opts.count*opts.size / wall_time)
end

function m.cliexec(cmd)
	local out=testlib.assert_cli_ok(cmd,{echo=true,level=3})
	cli:print_status(true,out)
end

-- return output on success instead of printing
function m.cliexec_ret_ok(cmd)
	local out=testlib.assert_cli_ok(cmd,{echo=true,level=3})
	return out
end

function m.fmt_meminfo_num(v)
	if v then
		return string.format('%d',v)
	end
	return '-'
end

function m.fmt_meminfo(mi)
	local start
	if mi.start_address then
		start=string.format('%#08x',mi.start_address)
	else
		start='-'
	end
	return string.format('%s heap start:%s size:%s free:%s free_block_max:%s',
						mi.name,start,
						m.fmt_meminfo_num(mi.total_size),
						m.fmt_meminfo_num(mi.free_size),
						m.fmt_meminfo_num(mi.free_block_max_size))
end

function m.is_cont_enabled()
	return con:execwait([[ return rlib_get_drive_mode_info().is_cont ]],{libs={'serialize_msgs','drive_mode_info'}})
end

function m.set_capmode(mode)
	con:execwait(string.format([[
capmode=require'capmode'
if not capmode.set('%s') then
	error('capmode.set failed')
end
sleep(200)
if capmode.get_name() ~= '%s' then
	error('failed to set mode')
end
]],mode,mode))
end

function m.do_filexfer(ldir,size,teststr)
	if not teststr then
		teststr='The quick brown fox jumps over the lazy dog\n\0more after the null!\xff\n1234567890'
	end
	local fn
	if size > 1024*1024 then
		fn=string.format('TST%04.0fM.dat',size/(1024*1024))
	elseif size > 1024 then
		fn=string.format('TST%04.0fK.dat',size/1024)
	else
		fn=string.format('TEST%0.0fd.dat',size)
	end
	local lfn=string.format('%s/%s',ldir,fn)
	local dfn=string.format('%s/d_%s',ldir,fn)
	local s1=util.str_rep_trunc_to(teststr,size)
	testlib.makefile(lfn,s1)
	m.cliexec('u '..lfn)
	m.cliexec('d '..fn .. ' ' .. dfn)
	local s2=testlib.readfile(dfn)
	assert(s1==s2)
	m.cliexec('rm '..fn)
end

function m.do_bulkmsgs(s,count)
	local msgs={}
	local t0 = ticktime.get()
	con:execwait(([[
function f(s,n)
	local wait_count = 0
	for i=1,n do
		if not write_usb_msg(s) then
			wait_count = wait_count + 1
			if not write_usb_msg(s,1000) then
				error('queue time out')
			end
		end
	end
	-- return silently fails if queue full, write message for wait count
	if not write_usb_msg(wait_count,1000) then
		error('send wait_count time out')
	end
end
f("%s",%d)
]]):format(s,count),{msgs=msgs})
	testlib.assert_eq(#msgs,count+1)
	local m = table.remove(msgs,#msgs)
	testlib.assert_eq(m.type,'user')
	testlib.assert_eq(m.subtype,'integer')
	local wait_count = m.value
	printf("%d x %d time %.4f queue filled %d\n",count,s:len(),ticktime.elapsed(t0),wait_count)
	for i, v in ipairs(msgs) do
		testlib.assert_eq(msgs[i].value,s)
	end
end

local tests=testlib.new_test({
'cam',{
{
	'connect',
	function(opts)
		local devspec = opts.connect_dev
		local devs=chdk.list_usb_devices()
		if #devs == 0 and not devspec then
			error('no usb devices available')
		end
		if con:is_connected() then
			error('already connected')
		end
		local cmd = 'connect'
		if devspec then
			cmd = cmd .. ' ' .. devspec
		else
			printf('using default device\n')
		end
		m.cliexec(cmd)
		assert(con:is_connected())
	end,
},
{
	'con_ptpinfo',
	function()
		testlib.assert_eq(con.ptp_support.OC[ptp.OC.GetDeviceInfo],true)
		testlib.assert_eq(con.ptp_support.OC[ptp.CANON.OC.CHDK],true)
		testlib.assert_eq(con.ptp_support.EC[ptp.EC.CancelTransaction],true)
		testlib.assert_eq(con.ptp_support.OFC[ptp.OFC.EXIF_JPEG],true)
		testlib.assert_eq(con.ptp_support.OFC_cap[ptp.OFC.EXIF_JPEG],true)
		testlib.assert_eq(util.in_table(con.ptp_code_ids,'STD'),true)
		testlib.assert_eq(util.in_table(con.ptp_code_ids,'CANON'),true)
		testlib.assert_teq({con:get_ptp_code_info('OC',ptp.CANON.OC.CHDK)},{'CHDK','CANON'})
		testlib.assert_teq({con:get_ptp_code_info('OC',ptp.OC.GetDeviceInfo)},{'GetDeviceInfo','STD'})
	end,
	setup=testlib.setup_ensure_connected,
},
{
	'cam_info',
	function()
		local bi,meminfo,sdinfo=con:execwait[[
return get_buildinfo(),{
	combined=get_meminfo(),
	system=get_meminfo('system'),
	aram=get_meminfo('aram'),
	exmem=get_meminfo('exmem')
},{
	size=get_disk_size(),
	free=get_free_disk_space(),
}
]]
		printf('platform:%s-%s version:%s-%s built:%s %s\n',
				bi.platform,bi.platsub,bi.build_number,bi.build_revision,
				bi.build_date,bi.build_time)
		printf('CHDK core start:%#08x size:%d total free:%s\n',
				meminfo.combined.chdk_start,
				meminfo.combined.chdk_size,
				m.fmt_meminfo_num(meminfo.combined.free_size))
		for _,heapname in ipairs({'system','aram','exmem'}) do
			local mi=meminfo[heapname]
			if mi then
				printf('%s\n',m.fmt_meminfo(mi))
			end
		end
		printf('SD size:%d KB free:%d KB\n',sdinfo.size,sdinfo.free)
	end,
	setup=testlib.setup_ensure_connected,
},
{
	'list_connected',
	function()
		local list=m.cliexec_ret_ok('list')
		local lines=util.string_split(list,'\n',{plain=true,empty=false})
		for i,l in ipairs(lines) do
			-- match the current (marked *) device, grab bus and dev name
			local bus,dev=string.match(lines[1],'^%*%d+:.*b=([%S]+) d=([%S]+)')
			if bus then
				assert(bus==con.condev.bus and dev==con.condev.dev)
				return true
			end
		end
		-- PTP/IP cons aren't in list
		if con.condev.transport == 'ip' then
			return true
		end
		error('current dev not found')
	end,
	setup=testlib.setup_ensure_connected,
},
{
	'wait_status',
	function()
		local status=con:wait_status{msg=true,timeout=100}
		assert(status.timeout)
		local pstatus,status=con:wait_status_pcall{msg=true,timeout=100,timeout_error=true}
		assert(status.etype=='timeout')
	end,
	setup=testlib.setup_ensure_connected,
},
{
	'exec_errors',
	function()
		con:exec('sleep(500)')
		local status,err=con:exec_pcall('print"test"')
		assert((not status) and err.etype == 'execlua_scriptrun')
		-- test killscript if compatible
		if con:is_ver_compatible(2,6) then
			con:execwait('print"kill"',{clobber=true})
		else
			-- otherwise just wait
			sys.sleep(600)
		end
		status,err=con:exec_pcall('bogus]')
		assert((not status) and err.etype == 'execlua_compile')
	end,
},
{
	'msgfuncs',
	function()
		-- test script not running
		local status,err=con:write_msg_pcall("test")
		assert((not status) and err.etype == 'msg_notrun')
		-- test flushmsgs
		con:exec('write_usb_msg("msg1") return 2,3')
		con:wait_status{run=false}
		status = con:script_status()
		assert(status.msg == true)
		con:flushmsgs()
		status = con:script_status()
		assert(status.msg == false)
		con:exec('write_usb_msg("msg2") return 1')
		local m=con:wait_msg({mtype='user'})
		assert(m.type=='user' and m.value == 'msg2')
		m=con:wait_msg({mtype='return'})
		assert(m.type=='return' and m.value == 1)
		status,err=pcall(con.wait_msg,con,{mtype='return',timeout=100})
		assert(err.etype=='timeout',tostring(err))
		con:exec('return 1')
		status,err=pcall(con.wait_msg,con,{mtype='user'})
		assert(err.etype=='wrongmsg',tostring(err))
	end,
	setup=testlib.setup_ensure_connected,
},
{
	'serialize',
	function()
		local r1,r2,r3=con:execwait('return 1,nil,2')
		assert(r1 == 1 and r2 == nil and r3 == 2)
		r1,r2,r3=con:call_remote('select',nil,1,3,nil,1)
		assert(r1 == 3 and r2 == nil and r3 == 1)
		local r=con:execwait(string.format('return %s',util.serialize({1,1.4,1.5,1.6,0xFFFFFFFF})))
		-- current serialize rounds, cam returns -1 for 0xFFFFFFFF
		assert(util.compare_values(r,{1,1,2,2,-1}))
	end,
	setup=testlib.setup_ensure_connected,
},
{
	'ptp_txn',
	function()
		local msg={}
		local info_fn=function(fmt,...) table.insert(msg,fmt:format(...)) end
		local r={con:ptp_txn(ptp.CANON.OC.CHDK,ptp.CHDK.CMD.Version)}
		testlib.assert_eq(#r,2)
		testlib.assert_eq(r[1], con.apiver.MAJOR)
		testlib.assert_eq(r[2], con.apiver.MINOR)
		con:ptp_txn(ptp.CANON.OC.CHDK,ptp.CHDK.CMD.Version,{verbose=true,info_fn=info_fn})
		testlib.assert_eq(#msg,2)
		testlib.assert_eq(msg[1], "txn_nodata 0x9999 CANON.CHDK 0x0 (0)\n")
		testlib.assert_eq(msg[2], ("ret=0x%x (%d), 0x%x (%d)\n"):format(
										con.apiver.MAJOR,con.apiver.MAJOR,
										con.apiver.MINOR,con.apiver.MINOR))
		msg={}
		local r={con:ptp_txn(ptp.CANON.OC.CHDK,ptp.CHDK.CMD.GetMemory,0x1900,100,0,{getdata='string',verbose=true,info_fn=info_fn})} -- CHDK_GetMemory
		testlib.assert_eq(#r,1)
		testlib.assert_eq(r[1]:len(),100)
		testlib.assert_eq(#msg,2)
		testlib.assert_eq(msg[1], "txn_getdata_str 0x9999 CANON.CHDK 0x1 (1), 0x1900 (6400), 0x64 (100), 0x0 (0)\n")
		testlib.assert_eq(msg[2], "data len=100 ret=\n")
		msg={}
		local r={con:ptp_txn(ptp.CANON.OC.CHDK,ptp.CHDK.CMD.ExecuteScript,0x600,{data='return 42\0',verbose=true,info_fn=info_fn})} -- CHDK_ExecuteScript
		local script_id = r[1]
		testlib.assert_eq(#r,2)
		testlib.assert_eq(r[2],0)
		testlib.assert_eq(#msg,2)
		testlib.assert_eq(msg[1], "txn_senddata 0x9999 CANON.CHDK data len=10 0x7 (7), 0x600 (1536)\n")
		testlib.assert_eq(msg[2], ("ret=0x%x (%d), 0x0 (0)\n"):format(script_id,script_id))
		-- have to wait for script to end to read message, too lazy to re-implement wait_status in raw txn
		con:wait_status{run=false}
		msg={}
		local r={con:ptp_txn(ptp.CANON.OC.CHDK,ptp.CHDK.CMD.ReadScriptMsg,{getdata='lbuf',verbose=true,info_fn=info_fn})}
		testlib.assert_eq(#r,5)
		assert(lbuf.is_lbuf(r[1]))
		testlib.assert_eq(r[1]:get_i32(0),42) -- message data, number 42
		testlib.assert_eq(r[2],2) -- message type, return
		testlib.assert_eq(r[3],3) -- message subtype, int
		testlib.assert_eq(r[4],script_id) -- message script id
		testlib.assert_eq(r[5],4) -- message len
		testlib.assert_eq(#msg,2)
		testlib.assert_eq(msg[1], "txn_getdata_lbuf 0x9999 CANON.CHDK 0xa (10)\n")
		testlib.assert_eq(msg[2], ("data len=4 ret=0x2 (2), 0x3 (3), 0x%x (%d), 0x4 (4)\n"):format(script_id,script_id))
	end,
	setup=testlib.setup_ensure_connected,
},
{
	'bench',{
	{
		'exectimes',
		function()
			m.execwaittime({count=50})
			m.exectime({count=50})
		end,
		setup=testlib.setup_ensure_connected,
	},
	{
		'xfer',
		function()
			m.xfermem({count=50})
		end,
		setup=testlib.setup_ensure_connected,
	},
	{
		'xferbuf',
		function()
			m.xfermem({count=50,buffer=true})
		end,
		setup=testlib.setup_ensure_connected,
	},
	{
		'msgs',
		function()
			local mt=require'extras/msgtest'
			assert(mt.test({size=1,sizeinc=1,count=100,verbose=0}))
			assert(con:wait_status{run=false})
			assert(mt.test({size=10,sizeinc=10,count=100,verbose=0}))
		end,
		setup=testlib.setup_ensure_connected,
	},
	{
		'bulkmsgs',
		function()
			m.do_bulkmsgs('a',100)
			m.do_bulkmsgs(('X'):rep(500),100)
		end,
		setup=testlib.setup_ensure_connected,
	}},
},
{
	'xfersizebugs',{
	{
		'xferbug_0x23f4',
		function()
			local mt=require'extras/msgtest'
			-- early dryos (e.g. D10) fail transfers to cached memory where size=0x23f4 + n*512
			-- https://chdk.setepontos.com/index.php?topic=4338.1150
			assert(mt.test({size=0x23f4,sizeinc=128,count=8,verbose=0,teststr='Hello world'}))
			assert(con:wait_status{run=false})
		end,
		setup=testlib.setup_ensure_connected,
	},
	{
		'xferbug_0x1f5',
		function(self)
			local mt=require'extras/msgtest'
			-- cameras which fail on multiple recv_data calls where total size
			-- (512*n) - 11 to (512*n)
			-- https://chdk.setepontos.com/index.php?topic=4338.msg140577#msg140577

			-- default code transfers in chunks up to free_block_max_size/2
			local mi=con:execwait([[return get_meminfo()]])
			local msize=math.floor((mi.free_block_max_size/2)/512)*512 - 11
			-- running 600 takes care of variation due to lua being loaded for get_meminfo,
			-- without script running, sent messages are discarded in chunks so no risk of OOM
			assert(mt.test({noscript=true,size=msize,sizeinc=512,count=600,verbose=0}))
			-- test near 256K, 512K in case using native buffer
			assert(mt.test({noscript=true,size=1024*255 - 11,sizeinc=512,count=5,verbose=0}))
			assert(mt.test({noscript=true,size=1024*511 - 11,sizeinc=512,count=5,verbose=0}))
			-- file - tests data, but less exhaustive size range

		--	problem size (256*1024 + 501 - 4 - 13)
			for i,size in ipairs({(256*1024 + 501 - 17),msize - 17,msize+512-17}) do
				m.do_filexfer(self._data.ldir,size)
			end
		end,
		setup=testlib.setup_ensure_connected,
		cleanup=function(self)
			fsutil.rm_r(self._data.ldir)
		end,
		_data = {
			ldir='camtest',
		},
	}},
},
{
	'filexfer',{
	{
		'filexfer',
		function(self)
			for i,size in ipairs({511,512,4096,(256*1024),(500*1024)}) do
				m.do_filexfer(self._data.ldir,size)
			end
		end,
		setup=testlib.setup_ensure_connected,
		cleanup=function(self)
			fsutil.rm_r(self._data.ldir)
		end,
		_data = {
			ldir='camtest',
		},
	},
	{
		'filexfer_string',
		function(self)
			for i,size in ipairs({1,511,512,513,12345}) do
				local s=util.str_rep_trunc_to("abc\0def",size)
				con:upload_str('A/TESTMEM.DAT',s)
				testlib.assert_eq(s,con:download_str('A/TESTMEM.DAT'))
			end
		end,
		setup=testlib.setup_ensure_connected,
		cleanup=function(self)
			m.cliexec('rm A/TESTMEM.DAT')
		end,
	},
	{
		'anyfs',
		function(self)
			local anyfs=require'anyfs'
			local ldir=self._data.ldir
			testlib.assert_thrown(function()
					anyfs.writefile(fsutil.joinpath(ldir,'bogus.txt'),'bogus',{mkdir=false})
				end, {etype='io', errno=errno_vals.ENOENT})
			testlib.assert_thrown(function()
					anyfs.writefile('A/TESTAFS/bogus.txt','bogus',{mkdir=false})
				end, {etype='remote', msg_eq='missing dest dir'})
			testlib.assert_thrown(function()
					anyfs.readfile('A/TESTAFS/bogus.txt')
				end, {etype='remote'}) -- exact camera message unpredictable
			testlib.assert_eq(anyfs.readfile('A/TESTAFS/bogus.txt',{missing_ok=true}),nil)
			local s='test\ntext\n'
			anyfs.writefile('A/TESTAFS/test.txt',s)
			testlib.assert_eq(anyfs.readfile('A/TESTAFS/test.txt'),s)
			anyfs.writefile(fsutil.joinpath(ldir,'test.txt'),s)
			testlib.assert_eq(anyfs.readfile(fsutil.joinpath(ldir,'test.txt')),s)
		end,
		setup=testlib.setup_ensure_connected,
		cleanup={
			function(self)
				fsutil.rm_r(self._data.ldir)
			end,
			function(self)
				m.cliexec('rm A/TESTAFS')
			end,
		},
		_data = {
			ldir='camtest',
		},
	},
	{
		'mfilexfer',
		function(self)
			local ldir=self._data.ldir
			m.cliexec('mup '..ldir..'/up muptest')
			m.cliexec('mdl muptest '..ldir..'/dn')
			testlib.assert_file_eq(ldir..'/up/EMPTY.TXT',ldir..'/dn/EMPTY.TXT')
			testlib.assert_file_eq(ldir..'/up/ONE.TXT',ldir..'/dn/ONE.TXT')
			testlib.assert_file_eq(ldir..'/up/1.TXT',ldir..'/dn/1.TXT')
			testlib.assert_file_eq(ldir..'/up/SUB1/SUB.TXT',ldir..'/dn/SUB1/SUB.TXT')
			testlib.assert_file_eq(ldir..'/up/EMPTYSUB',ldir..'/dn/EMPTYSUB')
			-- test with subst strings
			m.cliexec('mdl muptest '..ldir..'/dn2/${s_lower,${basename}${ext}}')
			testlib.assert_file_eq(ldir..'/up/EMPTY.TXT',ldir..'/dn2/empty.txt')
			testlib.assert_file_eq(ldir..'/up/1.TXT',ldir..'/dn2/1.txt')
			testlib.assert_file_eq(ldir..'/up/ONE.TXT',ldir..'/dn2/one.txt')
			testlib.assert_file_eq(ldir..'/up/SUB1/SUB.TXT',ldir..'/dn2/sub.txt')
			testlib.assert_file_eq(ldir..'/up/EMPTYSUB',ldir..'/dn2/emptysub')
			-- test size limits
			m.cliexec('mdl -sizemax=0 -nodirs muptest '..ldir..'/dn3')
			testlib.assert_file_eq(ldir..'/up/EMPTY.TXT',ldir..'/dn3/EMPTY.TXT')
			testlib.assert_eq(lfs.attributes(ldir..'/dn3/1.TXT','mode'),nil)
			testlib.assert_eq(lfs.attributes(ldir..'/dn3/ONE.TXT','mode'),nil)
			testlib.assert_eq(lfs.attributes(ldir..'/dn3/SUB1','mode'),nil)
			testlib.assert_eq(lfs.attributes(ldir..'/dn3/EMPTYSUB','mode'),nil)

			m.cliexec('mdl -sizemin=1000 -nodirs muptest '..ldir..'/dn4')
			testlib.assert_eq(lfs.attributes(ldir..'/dn4/EMPTY.TXT','mode'),nil)
			testlib.assert_eq(lfs.attributes(ldir..'/dn4/1.TXT','mode'),nil)
			testlib.assert_eq(lfs.attributes(ldir..'/dn4/ONE.TXT','mode'),nil)
			testlib.assert_file_eq(ldir..'/up/SUB1/SUB.TXT',ldir..'/dn4/SUB1/SUB.TXT')
			testlib.assert_eq(lfs.attributes(ldir..'/dn4/EMPTYSUB','mode'),nil)

			m.cliexec('mdl -sizemin=3 -sizemax=3 -nodirs muptest '..ldir..'/dn5')
			testlib.assert_eq(lfs.attributes(ldir..'/dn5/EMPTY.TXT','mode'),nil)
			testlib.assert_file_eq(ldir..'/up/ONE.TXT',ldir..'/dn5/ONE.TXT')
			testlib.assert_eq(lfs.attributes(ldir..'/dn5/1.TXT','mode'),nil)
			testlib.assert_eq(lfs.attributes(ldir..'/dn3/SUB1','mode'),nil)
			testlib.assert_eq(lfs.attributes(ldir..'/dn5/EMPTYSUB','mode'),nil)

			m.cliexec('rm muptest')
			-- test on non-existing dir
			testlib.assert_cli_error('mdl muptest '..ldir,{match='^A/muptest:',echo=true})

			m.cliexec('mup -nodirs -sizemin=1 -sizemax=3 '..ldir..'/up muptest')
			m.cliexec('mdl muptest '..ldir..'/dn6')
			testlib.assert_eq(lfs.attributes(ldir..'/dn5/EMPTY.TXT','mode'),nil)
			testlib.assert_file_eq(ldir..'/up/ONE.TXT',ldir..'/dn/ONE.TXT')
			testlib.assert_file_eq(ldir..'/up/1.TXT',ldir..'/dn/1.TXT')
			testlib.assert_eq(lfs.attributes(ldir..'/dn3/SUB1','mode'),nil)
			testlib.assert_eq(lfs.attributes(ldir..'/dn5/EMPTYSUB','mode'),nil)

			m.cliexec('rm muptest')
		end,
		setup=function(self,opts)
			self:ensure_connected(opts)
			local ldir=self._data.ldir
			-- names are in caps since cam may change, client may be case sensitive
			testlib.makefile(ldir..'/up/EMPTY.TXT','')
			testlib.makefile(ldir..'/up/1.TXT','1')
			testlib.makefile(ldir..'/up/ONE.TXT','one')
			testlib.makefile(ldir..'/up/SUB1/SUB.TXT',string.rep('subtext',1000))
			fsutil.mkdir_m(ldir..'/up/EMPTYSUB')
		end,
		cleanup=function(self)
			fsutil.rm_r(self._data.ldir)
		end,
		_data = {
			ldir='camtest',
		},
	},
	{
		'rmemfile',
		function(self)
			local ldir=self._data.ldir
			local fn=ldir..'/rmem.dat'
			testlib.assert_cli_ok('rmem 0x1900 0x400 -f='..fn,{match='^0x00001900 1024 '..fn..'\n',echo=true})
			assert(lfs.attributes(fn).size == 1024)
		end,
		setup=testlib.setup_ensure_connected,
		cleanup=function(self)
			fsutil.rm_r(self._data.ldir)
		end,
		_data = {
			ldir='camtest',
		},
	},
	{
		'lvdump',
		function(self)
			local ldir=self._data.ldir
			m.cliexec('lvdumpimg -count=2 -vp='..ldir..'/${frame}.ppm -bm='..ldir..'/${frame}.pam -quiet')
			testlib.assert_eq(lfs.attributes(ldir..'/000001.pam','mode'), 'file')
			testlib.assert_eq(lfs.attributes(ldir..'/000001.ppm','mode'), 'file')
			m.cliexec('lvdump -count=2 -quiet '..ldir..'/test.lvdump')
			testlib.assert_eq(lfs.attributes(ldir..'/test.lvdump','mode'), 'file')
			m.cliexec('lvdumpimg -infile='..ldir..'/test.lvdump -count=all -quiet'..
						' -vp='..ldir..'/${frame}_f.ppm'..
						' -bm='..ldir..'/${frame}_f.pam')
			testlib.assert_eq(lfs.attributes(ldir..'/000001.ppm','size'), lfs.attributes(ldir..'/000001_f.ppm','size'))
			testlib.assert_eq(lfs.attributes(ldir..'/000001.pam','size'), lfs.attributes(ldir..'/000001_f.pam','size'))
			testlib.assert_cli_error('lvdumpimg -count=1 -quiet -seek=2 -vp='..ldir..'/seekfail.ppm',
									{match='^seek only valid',echo=true})

			m.cliexec('lvdumpimg -infile='..ldir..'/test.lvdump -count=all -quiet'..
						' -vp='..ldir..'/${frame}_${channel}.pgm -vpfmt=yuv-s-pgm')
			testlib.assert_eq(lfs.attributes(ldir..'/000001_y.pgm','mode'),'file')
			testlib.assert_eq(lfs.attributes(ldir..'/000001_u.pgm','mode'),'file')
			testlib.assert_eq(lfs.attributes(ldir..'/000001_v.pgm','mode'),'file')

			m.cliexec('lvdumpimg -infile='..ldir..'/test.lvdump -count=all -quiet'..
						' -vp='..ldir..'/${frame}_${channel}.bin -vpfmt=yuv-s-raw')

			local y_size = lfs.attributes(ldir..'/000001_y.bin','size')
			local u_size = lfs.attributes(ldir..'/000001_u.bin','size')
			local v_size = lfs.attributes(ldir..'/000001_v.bin','size')
			testlib.assert_eq(u_size,v_size)
			-- may be 411 or 422
			assert((y_size == 2*u_size) or (y_size == 4*u_size))
			testlib.assert_cli_error('lvdumpimg -infile='..ldir..'/test.lvdump -seek=3 -quiet -vp='..ldir..'/sf_${frame}.ppm',
									{match='^at eof',echo=true})
			m.cliexec('lvdumpimg -infile='..ldir..'/test.lvdump -count=all -quiet -seek=1'..
						' -vp='..ldir..'/seek_${frame}.ppm')

			testlib.assert_eq(lfs.attributes(ldir..'/seek_000001.ppm','mode'),'file')
			testlib.assert_eq(lfs.attributes(ldir..'/seek_000002.ppm','mode'),nil)

			-- TODO testing pipe options requires something to pipe to
		end,
		setup=testlib.setup_ensure_connected,
		cleanup=function(self)
			fsutil.rm_r(self._data.ldir)
		end,
		_data = {
			ldir='camtest',
		},
	}},
},
{
	'shoot',{
	{
		'rec',
		function()
			m.cliexec('rec')
			sys.sleep(250)
		end,
		setup=testlib.setup_ensure_connected,
	},
	{
		'rec_in_rec',
		function()
			testlib.assert_cli_ok('rec',{match='already in rec'})
		end,
		setup=testlib.setup_ensure_connected_rec,
	},
	{
		'rec_info',
		function()
			local ri=con:execwait[[
props=require'propcase'
capmode=require'capmode'
function get_halfpress_vals(ri)
	ri.tv=get_prop(props.TV)
	ri.av=get_prop(props.AV)
	ri.min_av=get_prop(props.MIN_AV)
	ri.sv=get_prop(props.SV)
	ri.sv_market=get_prop(props.SV_MARKET)
	ri.bv=get_prop(props.BV)
	ri.sd=get_focus()
	ri.sd_ok=get_focus_ok()
	if type(get_nd_current_ev96) == 'function' then
		ri.nd=get_nd_current_ev96()
	else
		ri.nd=0
	end
end

is_rec,is_vid,mode=get_mode()
ri={
	mode=capmode.get(),
	is_vid=is_vid,
	mode_name=capmode.get_name(),
	iso_mode=get_prop(props.ISO_MODE),
	flash_mode=get_prop(props.FLASH_MODE),
	focus_mode=get_focus_mode(),
	nd_present=get_nd_present(),
	resolution=get_prop(props.RESOLUTION),
	quality=get_prop(props.QUALITY),
	zoom=get_zoom(),
	zoom_steps=get_zoom_steps(),
	rc=get_usb_capture_support(),
	propset=get_propset(),
}
if is_vid or not is_rec then
	get_halfpress_vals(ri)
else
	press'shoot_half'
	timeout=get_tick_count()+2000
	repeat
		sleep(10)
		if get_tick_count() > timeout then
			ri.timeout=true
		end
	until get_shooting() or ri.timeout
	get_halfpress_vals(ri)
	release'shoot_half'
end
return ri
]]
			printf('Rec info:\n')
			local mode_type
			if ri.is_vid then
				mode_type = ',video'
			elseif ri.mode == 0 then
				mode_type = ''
			else
				mode_type = ',still'
			end
			printf('Propset:%d mode:%s (%d%s) flash_m:%d iso_m:%d ',
				ri.propset,ri.mode_name,ri.mode,mode_type,ri.flash_mode,ri.iso_mode)
			printf('focus_m:%d ND:%d zoom:%d/%d rc:%d res:%d qual:%d\n',
					ri.focus_mode,ri.nd_present,ri.zoom,ri.zoom_steps,ri.rc,ri.resolution,ri.quality)
			printf('Exposure info:\n')
			if ri.timeout then
				printf('WARNING: half press timed out\n')
			end
			local sd_ok
			if ri.sd_ok then
				sd_ok = 'OK'
			else
				sd_ok = '!OK'
			end
			printf('Tv:%s (%.0f) Av:%0.1f (%.0f) minAv:%0.1f (%.0f) Sv:%.0f (%.0f) SvM:%.0f (%.0f) Bv:%.0f (%.0f) NDEv:%.0f (%.0f) SD:%.0f,%s\n',
					exp.tv96_to_shutter_str(ri.tv),ri.tv,
					exp.av96_to_f(ri.av),ri.av,
					exp.av96_to_f(ri.min_av),ri.min_av,
					exp.sv96_to_iso(ri.sv),ri.sv,
					exp.sv96_to_iso(ri.sv_market),ri.sv_market,
					ri.bv/96,ri.bv,
					ri.nd/96,ri.nd,
					ri.sd,
					sd_ok)
		end,
		setup=testlib.setup_ensure_connected_rec,
	},
	{
		'remoteshoot',
		function(self)
			local ldir = self._data.ldir
			local cfg = self._data.cfg
			-- TODO would be good to sanity check files
			m.cliexec(string.format('remoteshoot -jpg -filedummy %s/',ldir))
			-- if canon raw support, test, otherwise just check that it fails with the expected message
			if cfg.craw_fwt then
				-- verify image format was not changed in jpeg shot above
				assert(con:execwait([[ return get_canon_image_format() ]]) == cfg.fmt)

				m.cliexec(string.format('remoteshoot -seq=120 -craw -filedummy %s/${imgpfx}_${imgfmt}_${shotseq}${ext}',ldir))
				assert(prefs.cli_shotseq == 121)
				assert(con:execwait([[ return get_canon_image_format() ]]) == cfg.fmt)
				assert(lfs.attributes(ldir..'/IMG_CR2_0120.cr2','mode') == 'file')

				m.cliexec(string.format('remoteshoot -craw -jpg -filedummy %s/${imgpfx}_${imgfmt}_${shotseq}${ext}',ldir))
				assert(prefs.cli_shotseq == 122)
				assert(con:execwait([[ return get_canon_image_format() ]]) == cfg.fmt)
				assert(lfs.attributes(ldir..'/IMG_CR2_0121.cr2','mode') == 'file')
				assert(lfs.attributes(ldir..'/IMG_JPG_0121.jpg','mode') == 'file')
			else
				testlib.assert_cli_error(string.format('remoteshoot -craw -filedummy %s/',ldir),
										{match='unsupported format',echo=true})
			end

			m.cliexec(string.format('remoteshoot -seq=100 -dng -jpg -filedummy %s/${imgpfx}_${imgfmt}_${shotseq}${ext}',ldir))
			assert(prefs.cli_shotseq == 101)
			assert(lfs.attributes(ldir..'/IMG_JPG_0100.jpg','mode') == 'file')
			assert(lfs.attributes(ldir..'/IMG_DNG_0100.dng','mode') == 'file')

			m.cliexec(string.format('remoteshoot -raw -dnghdr -filedummy %s/${imgfmt}_${shotseq}${ext}',ldir))
			assert(prefs.cli_shotseq == 102)
			assert(lfs.attributes(ldir..'/RAW_0101.raw','mode') == 'file')
			assert(lfs.attributes(ldir..'/DNG_HDR_0101.dng_hdr','mode') == 'file')

			m.cliexec(string.format('remoteshoot -quick=3 -jpg -filedummy %s/${imgfmt}_${shotseq}${ext}',ldir))
			assert(prefs.cli_shotseq == 105)
			m.cliexec(string.format('remoteshoot -quick=3 -int=5 -jpg -filedummy %s/${imgfmt}_${shotseq}${ext}',ldir))
			if cfg.craw_fwt then
				-- ensure previous shots have fully completed on camera
				sys.sleep(250)
				m.cliexec(string.format('remoteshoot -quick=3 -craw -filedummy %s/${imgfmt}_${shotseq}${ext}',ldir))
				m.cliexec(string.format('remoteshoot -quick=3 -craw -jpg -filedummy %s/${imgfmt}_${shotseq}${ext}',ldir))
			end

			-- TODO should be standalone test
			-- only test cont if enabled in UI, because can't be set by prop
			if m.is_cont_enabled() then
				m.cliexec(string.format('remoteshoot -cont=3 -jpg -filedummy %s/${name}',ldir))
				if cfg.craw_fwt then
					m.cliexec(string.format('remoteshoot -cont=3 -craw -filedummy %s/${imgfmt}_${shotseq}${ext}',ldir))
					m.cliexec(string.format('remoteshoot -cont=3 -craw -jpg -filedummy %s/${imgfmt}_${shotseq}${ext}',ldir))
				end
			else
				printf('cont mode not set, skipping remoteshoot cont test\n')
			end
		end,
		setup=function(self,opts)
			self:ensure_connected_rec(opts)
			-- get camera capabilities
			local cfg = con:execwait([[
cfg = {
fwt=(bitand(get_usb_capture_support(),7) == 7),
craw_fwt=(bitand(get_usb_capture_support(),8) == 8),
craw_fn=(type(get_canon_raw_support) == 'function')
}
if cfg.craw_fn then
	cfg.craw = get_canon_raw_support()
	cfg.fmt = get_canon_image_format()
end
return cfg
]])
			-- check filewrite capability (could do RAW/DNG only)
			if not cfg.fwt then
				printf('cam does not support remote capture, skipping\n')
				return false
			end
			self._data.cfg = cfg
			-- try to set the camera to a normal shooting mode
			m.set_capmode('P')
			fsutil.mkdir_m(self._data.ldir)
		end,
		cleanup=function(self)
			-- TODO cleanup jpeg dummies on cam, need to be in playback to avoid crash
			fsutil.rm_r(self._data.ldir)
		end,
		_data = {
			ldir = 'camtest',
		},
	},
	{
		'rsint',
		function(self)
			local ldir=self._data.ldir
			fsutil.mkdir_m(ldir)
			local rsint=require'rsint'
			-- build arguments for rsint.run instead of using cli so we can override input
			-- have to set some options that default to non-false in cli code (e.g. u)
			assert(rsint.run{
				[1]=ldir..'/${imgfmt}_${shotseq}${ext}',
				u='s',
				seq=200,
				cmdwait=60,
				jpg=true,
				filedummy=true,
				input_func=m.fake_rsint_input{
					's',
					5000,
					's',
					5000,
					'q',
				}
			})
			-- TODO should be standalone test
			-- only test cont if enabled in UI, because can't be set by prop
			if m.is_cont_enabled() then
				assert(rsint.run{
					[1]=ldir..'/',
					u='s',
					cmdwait=60,
					cont=true,
					jpg=true,
					filedummy=true,
					input_func=m.fake_rsint_input{
						's',
						5000,
						's',
						5000,
						'l',
					}
				})
			else
				printf('cont mode not set, skipping rsint cont test\n')
			end
		end,
		setup=function(self,opts)
			self:ensure_connected_rec(opts)
			-- skip if fwt not supported
			if not con:execwait([[ return (bitand(get_usb_capture_support(),7) == 7) ]]) then
				return false
			end

			-- try to set the camera to a normal shooting mode
			m.set_capmode('P')
			fsutil.mkdir_m(self._data.ldir)
		end,
		cleanup=function(self)
			-- TODO cleanup jpeg dummies on cam, need to be in playback to avoid crash
			fsutil.rm_r(self._data.ldir)
		end,
		_data = {
			ldir = 'camtest',
		},
	},
	{
		'shoot',
		function(self)
			local ldir=self._data.ldir
			local cfg = self._data.cfg
			-- imgfmt avoids depending on camera ext settings
			if cfg.craw_support then
				m.cliexec(string.format('shoot -dng=1 -cfmt=jpg -seq=300 -dl=%s/IMG_${shotseq}.${imgfmt}',ldir))
			else
				m.cliexec(string.format('shoot -dng=1 -seq=300 -dl=%s/IMG_${shotseq}.${imgfmt}',ldir))
			end
			assert(prefs.cli_shotseq == 301)
			assert(lfs.attributes(ldir..'/IMG_0300.JPG','mode') == 'file')
			assert(lfs.attributes(ldir..'/IMG_0300.DNG','mode') == 'file')
			if cfg.craw_support then
				m.cliexec(string.format('shoot -raw=0 -cfmt=both -dl=%s/IMG_${shotseq}.${imgfmt}',ldir))
				assert(lfs.attributes(ldir..'/IMG_0301.JPG','mode') == 'file')
				assert(lfs.attributes(ldir..'/IMG_0301.CR2','mode') == 'file')
				assert(con:execwait([[ return get_canon_image_format() ]]) == cfg.fmt)
			end
		end,
		setup=function(self,opts)
			self:ensure_connected_rec(opts)
			local cfg = con:execwait([[
r = { }
if type(get_canon_image_format) == 'function' then
	r.fmt=get_canon_image_format()
	r.craw_support=get_canon_raw_support()
end
return r
]],{libs='serialize_msgs'})
			self._data.cfg = cfg
			fsutil.mkdir_m(self._data.ldir)
		end,
		cleanup=function(self)
			-- TODO should clean up camera file, but deleting before play switch crashes some cams
			fsutil.rm_r(self._data.ldir)
		end,
		_data = {
			ldir = 'camtest',
		},
	},
	{
		'play',
		function()
			sys.sleep(250)
			m.cliexec('play')
			sys.sleep(250)
		end,
		setup=testlib.setup_ensure_connected_rec,
	},
	{
		'play_in_play',
		function()
			testlib.assert_cli_ok('play',{match='already in play'})
		end,
		setup=testlib.setup_ensure_connected_play,
	}},
	-- save and restore shotseq for shoot test group
	setup=function(self)
		self._data = {cli_shotseq = prefs.cli_shotseq}
	end,
	cleanup={
		function(self)
			prefs.cli_shotseq = self._data.cli_shotseq
		end,
		function(self,opts)
			-- normally play test will put cam in play, but could still be in rec from failures
			self:ensure_connected_play(opts)
			-- clean up dummy files generated by rs tests (also any other 0 byte image files lying around)
			m.cliexec('imrm -sizemax=0')
		end,
	},
},
{
	'reconnect',
	function()
		assert(con:is_connected())
		m.cliexec('reconnect')
		assert(con:is_connected())
	end,
	setup=testlib.setup_ensure_connected,
},
{
	'disconnect',
	function()
		m.cliexec('dis')
		assert(not con:is_connected())
	end,
	setup=testlib.setup_ensure_connected,
},
{
	'not_connected',
	function()
		local status,err=con:script_status_pcall()
		assert((not status) and err.ptp_rc == ptp.RC.ERROR_NOT_CONNECTED)
	end,
	setup=function()
		if con:is_connected() then
			con:disconnect()
		end
	end,
}
}})

m.tests = tests

return m
