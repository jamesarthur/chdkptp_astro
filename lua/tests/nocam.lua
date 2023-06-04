--[[
 Copyright (C) 2012-2022 <reyalp (at) gmail dot com>
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
tests that do not depend on the camera
]]
local testlib = require'testlib'
-- module
local m={}

local function spoof_fsutil_ostype(name)
	fsutil.ostype = function()
		return name
	end
end
local function unspoof_fsutil_ostype()
	fsutil.ostype = sys.ostype
end

local function spoof_con(methods)
	local _saved_con = con

	local spoof = util.extend_table({},methods)
	spoof._unspoof = function()
		con = _saved_con
	end
	con = spoof
end

local tests=testlib.new_test({
'nocam',
{{
	'argparser',
	function()
		local argparser = require'argparser'
		local function get_word(val,eword,epos)
			local word,pos = argparser:get_word(val)
			testlib.assert_eq(word, eword,3)
			testlib.assert_eq(pos, epos,3)
		end
		get_word('','',1)
		get_word('whee','whee',5)
		get_word([["whee"]],'whee',7)
		get_word([["'whee'"]],[['whee']],9)
		get_word([['"whee"']],[["whee"]],9)
		get_word([['whee']],'whee',7)
		get_word([[\whee\]],[[\whee\]],7)
		get_word("whee foo",'whee',5)
		get_word([["whee\""]],[[whee"]],9)
		get_word([['whee\']],[[whee\]],8)
		get_word("'whee ",false,[[unclosed ']])
		get_word([["whee \]],false,[[unexpected \]])
		get_word('wh"e"e','whee',7)
		get_word('wh""ee','whee',7)
		get_word([[wh"\""ee]],[[wh"ee]],9)
		testlib.assert_eq(argparser.quote_if_needed('"'),'"\\""')
		testlib.assert_eq(argparser.quote_if_needed("'"),'"\'"')
		testlib.assert_eq(argparser.quote_if_needed('hello\\world'),'"hello\\\\world"')
		testlib.assert_eq(argparser.quote_if_needed('hello world'),'"hello world"')
		testlib.assert_eq(argparser.quote_if_needed("hello 'world'"),'"hello \'world\'"')
		testlib.assert_thrown(function()
			argparser.quote_if_needed('hello\nworld')
		end,{etype='bad_arg',msg_eq='unsupported charcaters'})
		testlib.assert_thrown(function()
			argparser.quote_if_needed('hello\rworld')
		end,{etype='bad_arg',msg_eq='unsupported charcaters'})
	end,
},
{
	'dirname',
	function()
		testlib.assert_eq(fsutil.dirname('/'),'/')
		testlib.assert_eq(fsutil.dirname('//'), '/')
		testlib.assert_eq(fsutil.dirname('/a/b/'), '/a')
		testlib.assert_eq(fsutil.dirname('//a//b//'), '//a')
		testlib.assert_eq(fsutil.dirname(), nil)
		testlib.assert_eq(fsutil.dirname('a'), '.')
		testlib.assert_eq(fsutil.dirname(''), '.')
		testlib.assert_eq(fsutil.dirname('/a'), '/')
		testlib.assert_eq(fsutil.dirname('a/b'), 'a')
	end
},
{
	'dirname_win',
	function()
		testlib.assert_eq(fsutil.dirname('c:\\'), 'c:/')
		testlib.assert_eq(fsutil.dirname('c:'), 'c:')
	end,
	setup=function()
		spoof_fsutil_ostype('Windows')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'basename',
	function()
		testlib.assert_eq(fsutil.basename('foo/bar'), 'bar')
		testlib.assert_eq(fsutil.basename('foo/bar.txt','.txt'), 'bar')
		testlib.assert_eq(fsutil.basename('foo/bar.TXT','.txt'), 'bar')
		assert(fsutil.basename('foo/bar.TXT','.txt',{ignorecase=false})=='bar.TXT')
		testlib.assert_eq(fsutil.basename('bar'), 'bar')
		testlib.assert_eq(fsutil.basename('bar/'), 'bar')
		testlib.assert_eq(fsutil.basename('bar','bar'), 'bar')
	end,
},
{
	'basename_win',
	function()
		testlib.assert_eq(fsutil.basename('c:/'), nil)
		testlib.assert_eq(fsutil.basename('c:/bar'), 'bar')
	end,
	setup=function()
		spoof_fsutil_ostype('Windows')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'basename_cam',
	function()
		testlib.assert_eq(fsutil.basename_cam('A/'), nil)
		testlib.assert_eq(fsutil.basename_cam('A/DISKBOOT.BIN'), 'DISKBOOT.BIN')
		testlib.assert_eq(fsutil.basename_cam('bar/'), 'bar')
	end,
},
{
	'dirname_cam',
	function()
		testlib.assert_eq(fsutil.dirname_cam('A/'), 'A/')
		testlib.assert_eq(fsutil.dirname_cam('A/DISKBOOT.BIN'), 'A/')
		testlib.assert_eq(fsutil.dirname_cam('bar/'), nil)
		testlib.assert_eq(fsutil.dirname_cam('A/CHDK/SCRIPTS'), 'A/CHDK')
	end,
},
{
	'splitjoin_cam',
	function()
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath_cam('A/FOO'))), 'A/FOO')
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath_cam('foo/bar/mod'))), 'foo/bar/mod')
	end,
},
{
	'joinpath',
	function()
		testlib.assert_eq(fsutil.joinpath('/foo','bar'), '/foo/bar')
		testlib.assert_eq(fsutil.joinpath('/foo/','bar'), '/foo/bar')
		testlib.assert_eq(fsutil.joinpath('/foo/','/bar'), '/foo/bar')
		testlib.assert_eq(fsutil.joinpath('/foo/','bar','/mod'), '/foo/bar/mod')
	end,
},
{
	'joinpath_win',
	function()
		testlib.assert_eq(fsutil.joinpath('/foo\\','/bar'), '/foo\\bar')
	end,
	setup=function()
		spoof_fsutil_ostype('Windows')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'fsmisc',
	function()
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath('/foo/bar/mod'))), '/foo/bar/mod')
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath('foo/bar/mod'))), './foo/bar/mod')
	end,
},
{
	'fsmisc_win',
	function()
		testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath('d:/foo/bar/mod'))), 'd:/foo/bar/mod')
		testlib.assert_eq(fsutil.normalize_dir_sep('foo/blah\\blah.txt'), 'foo/blah/blah.txt')
		testlib.assert_eq(fsutil.normalize_dir_sep('foo/blah/blah.txt'), 'foo/blah/blah.txt')
		-- testlib.assert_eq(fsutil.joinpath(unpack(fsutil.splitpath('d:foo/bar/mod'))), 'd:foo/bar/mod')
	end,
	setup=function()
		spoof_fsutil_ostype('Windows')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'fsmisc_lin',
	function()
		testlib.assert_eq(fsutil.normalize_dir_sep('foo/blah\\blah.txt'), 'foo/blah\\blah.txt')
		testlib.assert_eq(fsutil.normalize_dir_sep('foo/blah/blah.txt'), 'foo/blah/blah.txt')
	end,
	setup=function()
		spoof_fsutil_ostype('Linux')
	end,
	cleanup=function()
		unspoof_fsutil_ostype()
	end,
},
{
	'split_ext',
	function()
		local name,ext = fsutil.split_ext('foo')
		assert(name == 'foo' and ext == '')
		name,ext = fsutil.split_ext('.blah')
		assert(name == '.blah' and ext == '')
		name,ext = fsutil.split_ext('.blah.blah')
		assert(name == '.blah' and ext == '.blah')
		name,ext = fsutil.split_ext('bar.txt')
		assert(name == 'bar' and ext == '.txt')
		name,ext = fsutil.split_ext('bar.foo.txt')
		assert(name == 'bar.foo' and ext == '.txt')
		name,ext = fsutil.split_ext('whee.foo/txt')
		assert(name == 'whee.foo/txt' and ext == '')
		name,ext = fsutil.split_ext('whee.foo/bar.txt')
		assert(name == 'whee.foo/bar' and ext == '.txt')
		name,ext = fsutil.split_ext('')
		assert(name == '' and ext == '')
	end,
},
{
	'parse_image_path_cam',
	function()
		testlib.assert_teq(fsutil.parse_image_path_cam('A/DCIM/139___10/IMG_5609.JPG'),{
			dirnum="139",
			dirday="",
			imgnum="5609",
			ext=".JPG",
			pathparts={
				[1]="A/",
				[2]="DCIM",
				[3]="139___10",
				[4]="IMG_5609.JPG",
			},
			dirmonth="10",
			subdir="139___10",
			name="IMG_5609.JPG",
			imgpfx="IMG",
			basename="IMG_5609",
		})
		testlib.assert_teq(fsutil.parse_image_path_cam('A/DCIM/136_1119/CRW_0013.DNG',{string=false}),{
			dirnum="136",
			pathparts={
				[1]="A/",
				[2]="DCIM",
				[3]="136_1119",
				[4]="CRW_0013.DNG",
			},
			dirday="19",
			imgnum="0013",
			basename="CRW_0013",
			imgpfx="CRW",
			subdir="136_1119",
			dirmonth="11",
			name="CRW_0013.DNG",
			ext=".DNG",
			})
		testlib.assert_teq(fsutil.parse_image_path_cam('IMG_5609.JPG',{string=false}),{
			ext=".JPG",
			pathparts={
				[1]="IMG_5609.JPG",
			},
			imgpfx="IMG",
			basename="IMG_5609",
			name="IMG_5609.JPG",
			imgnum="5609",
		})
	end,
},
{
	'find_files',
	function(self)
		local tdir=self._data.tdir
		-- should throw on error
		local r=fsutil.find_files({tdir},{dirs=false,fmatch='%.txt$'},function(t,opts) t:ff_store(t.cur.full) end)
		assert(r)
		local check_files = util.flag_table{
			fsutil.joinpath(tdir,'empty.txt'),
			fsutil.joinpath(tdir,'foo.txt'),
			fsutil.joinpath(tdir,'sub','x.txt'),
		}
		local found = 0
		for i,p in ipairs(r) do
			if check_files[p] then
				found = found+1
			end
			testlib.assert_eq(lfs.attributes(p,'mode'), 'file')
		end
		testlib.assert_eq(found, 3)

		local r=fsutil.find_files({tdir},{dirs=false,fsfx='.DAT'},function(t,opts) t:ff_store(t.cur.full) end)
		testlib.assert_eq(#r,1)
		testlib.assert_eq(r[1],fsutil.joinpath(tdir,'x.dat'))

		local r=fsutil.find_files({tdir},{dirs=false,fsfx='.DAT',fsfx_ic=false},function(t,opts) t:ff_store(t.cur.full) end)
		testlib.assert_eq(r,nil)

		local r=fsutil.find_files({tdir},{dirs=false,sizemax=0},function(t,opts) t:ff_store(t.cur.full) end)
		testlib.assert_eq(#r,1)
		testlib.assert_eq(r[1],fsutil.joinpath(tdir,'empty.txt'))

		local r=fsutil.find_files({tdir},{dirs=false,sizemin=200},function(t,opts) t:ff_store(t.cur.full) end)
		testlib.assert_eq(#r,1)
		testlib.assert_eq(r[1],fsutil.joinpath(tdir,'sub','x.txt'))

		testlib.assert_thrown(function()
			return fsutil.find_files({'a_bogus_name_1234'},{dirs=false,fmatch='%.lua$'},function(t,opts) t:ff_store(t.cur.full) end)
		end,{etype='lfs',errno=errno_vals.ENOENT})
	end,
	setup=function(self)
		local tdir=self._data.tdir
		fsutil.mkdir_m(tdir)
		fsutil.writefile(fsutil.joinpath(tdir,'empty.txt'),'',{bin=true})
		fsutil.writefile(fsutil.joinpath(tdir,'foo.txt'),'foo',{bin=true})
		fsutil.writefile(fsutil.joinpath(tdir,'x.dat'),('X'):rep(100),{bin=true})
		local sdir = fsutil.joinpath(tdir,'sub')
		fsutil.mkdir_m(sdir)
		fsutil.writefile(fsutil.joinpath(sdir,'x.txt'),('X'):rep(200),{bin=true})
	end,
	cleanup=function(self)
		fsutil.rm_r(self._data.tdir)
	end,
	_data = {
		tdir='chdkptp-test-data'
	},
},
{
	'readwritefile',
	function(self)
		local tdir=self._data.tdir
		local fn = fsutil.joinpath(tdir,'test.txt')
		fsutil.writefile(fn,'this\nis\na\ntest\n')
		testlib.assert_eq(fsutil.readfile(fn),'this\nis\na\ntest\n')
		fsutil.writefile(fn,'file\n',{append=true})
		testlib.assert_eq(fsutil.readfile(fn),'this\nis\na\ntest\nfile\n')
		fsutil.writefile(fn,'test\r\nfile\r\n',{bin=true})
		testlib.assert_eq(fsutil.readfile(fn,{bin=true}),'test\r\nfile\r\n')
		fn = fsutil.joinpath(tdir,'sub','test.txt')
		testlib.assert_thrown(function()
			fsutil.readfile(fn)
		end,{etype='io',errno=errno_vals.ENOENT})
		testlib.assert_thrown(function()
			fsutil.writefile(fn,'test',{mkdir=false})
		end,{etype='io',errno=errno_vals.ENOENT})
		testlib.assert_eq(fsutil.readfile(fn,{missing_ok=true}),nil)
		fsutil.writefile(fn,100)
		testlib.assert_eq(fsutil.readfile(fn),'100')
		testlib.assert_thrown(function()
			fsutil.writefile(fn,false)
		end,{etype='bad_arg',msg_match='expected string not boolean'})
	end,
	cleanup=function(self)
		fsutil.rm_r(self._data.tdir)
	end,
	_data = {
		tdir='chdkptp-test-data'
	},
},
{
	'ustime',
	function()
		local t=os.time()
		local t0=ustime.new(t,600000)
		local t1=ustime.new(t+1,500000)
		testlib.assert_eq(ustime.diff(t1,t0), 900000)
		local t0=ustime.new()
		sys.sleep(100)
		local d = t0:diff()
		-- allow 50 msec (!) fudge, timing is bad on some windows systems
		assert(d > 80000 and d < 150000)
	end,
},
{
	'lbuf',
	function()
		local s="hello world"
		local l=lbuf.new(s)
		testlib.assert_eq(lbuf.is_lbuf(l), true)
		testlib.assert_eq(lbuf.is_lbuf(s), false)
		testlib.assert_eq(lbuf.is_lbuf(1), false)
		testlib.assert_eq(lbuf.is_lbuf(true), false)
		testlib.assert_eq(lbuf.is_lbuf({}), false)
		testlib.assert_eq(s:len(), l:len())
		testlib.assert_eq(s, l:string())
		testlib.assert_eq(s:sub(0,100), l:string(0,100))
		testlib.assert_eq(l:string(-5), 'world')
		testlib.assert_eq(l:string(1,5), 'hello')
		testlib.assert_eq(l:string(nil,5), 'hello')
		testlib.assert_eq(l:string(100,200), s:sub(100,200))
		testlib.assert_eq(l:byte(0), s:byte(0))
		testlib.assert_eq(l:byte(5), s:byte(5))
		local t1 = {l:byte(-5,100)}
		local t2 = {s:byte(-5,100)}
		testlib.assert_eq(#t1, #t2)
		for i,v in ipairs(t2) do
			testlib.assert_eq(t1[i], t2[i])
		end
		local l2=l:sub()
		testlib.assert_eq(l2:string(), l:string())
		l2 = l:sub(-5)
		testlib.assert_eq(l2:string(), 'world')
		l2 = l:sub(1,5)
		testlib.assert_eq(l2:string(), 'hello')
		l2 = l:sub(100,101)
		testlib.assert_eq(l2:len(), 0)
		testlib.assert_eq(l2:string(), '')
		l=lbuf.new(100)
		testlib.assert_eq(l:len(), 100)
		testlib.assert_eq(l:byte(), 0)
		s=""
		l=lbuf.new(s)
		testlib.assert_eq(l:len(), 0)
		testlib.assert_eq(l:byte(), nil)
		testlib.assert_eq(l:string(), "")
		testlib.assert_thrown(
			function()
				lbuf.new(false)
			end,
			{str_match='invalid argument'}
		)
	end,
},
{
	'lbufi',
	function()
		-- TODO not endian aware
		local l=lbuf.new('\001\000\000\000\255\255\255\255')
		testlib.assert_eq(l:get_i32(), 1)
		testlib.assert_eq(l:get_i16(), 1)
		testlib.assert_eq(l:get_i8(), 1)
		testlib.assert_eq(l:get_i32(10), nil)
		testlib.assert_eq(l:get_i32(5), nil)
		testlib.assert_eq(l:get_i16(4), -1)
		testlib.assert_eq(l:get_i32(4,10), -1)
		testlib.assert_eq(l:get_u32(), 1)
		testlib.assert_eq(l:get_u16(), 1)
		testlib.assert_eq(l:get_i32(4), -1)
		testlib.assert_eq(l:get_u8(4), 0xFF)
		testlib.assert_eq(l:get_i8(4), -1)
		testlib.assert_eq(l:get_u32(4), 0xFFFFFFFF)
		testlib.assert_eq(l:get_u32(1), 0xFF000000)
		testlib.assert_eq(l:get_u16(3), 0xFF00)
		local t={l:get_i32(0,100)}
		testlib.assert_eq(#t, 2)
		testlib.assert_eq(t[1], 1)
		testlib.assert_eq(t[2], -1)
		local l=lbuf.new('\001\000\000\000\000\255\255\255\255')
		testlib.assert_eq(l:get_i32(1), 0x000000)
		local t={l:get_u32(0,3)}
		testlib.assert_eq(#t, 2)
		testlib.assert_eq(t[1], 1)
		testlib.assert_eq(t[2], 0xFFFFFF00)
		local l=lbuf.new(string.rep('\001',256))
		local t={l:get_u32(4,-1)}
		testlib.assert_eq(#t, 63)
		local l=lbuf.new(8)
		l:set_u32(0,0xFEEDBABE,0xDEADBEEF)
		local t={l:get_u32(0,2)}
		testlib.assert_eq(#t, 2)
		testlib.assert_eq(t[1], 0xFEEDBABE)
		testlib.assert_eq(t[2], 0xDEADBEEF)
		local t={l:get_u16(0,4)}
		testlib.assert_eq(t[1], 0xBABE)
		testlib.assert_eq(t[2], 0xFEED)
		testlib.assert_eq(t[3], 0xBEEF)
		testlib.assert_eq(t[4], 0xDEAD)
		l:set_i16(0,-1)
		l:set_u16(2,0xDEAD)
		local t={l:get_u16(0,2)}
		testlib.assert_eq(t[1], 0xFFFF)
		testlib.assert_eq(t[2], 0xDEAD)
		local l=lbuf.new(5)
		l:set_i32(0,-1,42)
		local t={l:get_i32(0,2)}
		testlib.assert_eq(#t, 1)
		testlib.assert_eq(t[1], -1)
		local l=lbuf.new(16)
		testlib.assert_eq(l:fill("a"), 16)
		testlib.assert_eq(l:get_u8(), string.byte('a'))
		local l2=lbuf.new(4)
		testlib.assert_eq(l2:fill("hello world"), 4)
		testlib.assert_eq(l:fill(l2,100,1), 0)
		testlib.assert_eq(l:fill(l2,1,2), 8)
		testlib.assert_eq(l:string(2,9), "hellhell")
		testlib.assert_eq(l:string(), "ahellhellaaaaaaa")
		testlib.assert_eq(l:fill(l2,14,20), 2)
		testlib.assert_thrown(
			function()
				l:set_i32(-1,1)
			end,
			{str_match='negative offset not allowed'}
		)
		testlib.assert_thrown(
			function()
				l:get_i32(-1,1)
			end,
			{str_match='negative offset not allowed'}
		)
		testlib.assert_thrown(
			function()
				l:fill({})
			end,
			{str_match='invalid argument'}
		)
	end,
},
{
	'lbufutil',
	function()
		local lbu=require'lbufutil'
		local b=lbu.wrap(lbuf.new('\001\000\000\000\255\255\255\255hello world\000\002\000\000\000'))
		b:bind_i32('first')
		b:bind_i32('second')
		b:bind_u32('second_u',4)
		b:bind_sz('str',12)
		b:bind_rw_i32('last')
		testlib.assert_eq(b.first, 1)
		testlib.assert_eq(b.second, -1)
		testlib.assert_eq(b.second_u, 0xFFFFFFFF)
		testlib.assert_eq(b.str, "hello world")
		testlib.assert_eq(b.last, 2)
		b.last = 3
		testlib.assert_eq(b.last, 3)
		b:bind_seek('set',0)
		b:bind_i32('s1')
		testlib.assert_eq(b.s1, 1)
		testlib.assert_eq(b:bind_seek(), 4) -- return current pos
		testlib.assert_eq(b:bind_seek(4), 8) -- cur +4
		testlib.assert_eq(b:bind_seek('end'), b._lb:len()) -- length
		testlib.assert_eq(b:bind_seek('end',-4), b._lb:len()-4)
		b:bind_seek('set',0)
		b:bind_i8('i8_1')
		testlib.assert_eq(b.i8_1, 1)
		b:bind_seek('set',4)
		b:bind_i8('i8_2')
		testlib.assert_eq(b.i8_2, -1)
		b:bind_u8('u8_1')
		testlib.assert_eq(b.u8_1, 0xFF)
		testlib.assert_thrown(
			function()
				b:bind_seek(false)
			end,
			{etype='bad_arg',msg_eq='invalid argument'}
		)
		testlib.assert_thrown(
			function()
				b:bind_seek('where',1)
			end,
			{etype='bad_arg',msg_eq='invalid whence "where"'}
		)
		testlib.assert_thrown(
			function()
				b:bind_seek('set',-1)
			end,
			{etype='bad_arg',msg_eq='invalid pos -1'}
		)
		testlib.assert_thrown(
			function()
				b:bind_seek(b._lb:len()+1)
			end,
			{etype='bad_arg',msg_eq='invalid pos 31'}
		)
		testlib.assert_thrown(
			function()
				b:bind_i32('bind_i32',0)
			end,
			{etype='bad_arg',msg_eq='attempt to bind field or method name "bind_i32"'}
		)
		testlib.assert_thrown(
			function()
				b:bind_i32('bind_i32',-1)
			end,
			{etype='bad_arg',msg_eq='illegal offset -1'}
		)
		testlib.assert_thrown(
			function()
				b:bind_i32('bind_i32',b._lb:len()-3)
			end,
			{etype='bad_arg',msg_eq='illegal offset 21'}
		)
	end,
},
{
	'lbufutil_array',
	function()
		local lbu=require'lbufutil'
		local b=lbu.wrap(lbuf.new('\001\000\000\000\255\255\255\255hello world\000\002\000\003\000\255\255'))
		b:bind_array_u32('a1',2)
		testlib.assert_eq(b:bind_seek(), 8) -- return current pos
		b:bind_array_u8('s',12)
		b:bind_array_rw_i16('a2',3)
		b:bind_array_i32('empty',0)
		testlib.assert_thrown(
			function()
				b:bind_array_i8('overlength',1)
			end,
			{etype='bad_arg',msg_match='bind overflow'}
		)
		testlib.assert_thrown(
			function()
				b:bind_array_i8('neglen',-1)
			end,
			{etype='bad_arg',msg_eq='invalid count -1'}
		)
		testlib.assert_eq(#b.a1,2)
		testlib.assert_teq(b.a1,{1,0xffffffff})
		testlib.assert_teq(b.a1[0],nil)
		testlib.assert_teq(b.a1[3],nil)
		testlib.assert_teq(b.a1[-1],nil)
		testlib.assert_thrown(
			function()
				b.a1 = {}
			end,
			{etype='readonly', msg_eq='attempt to set read-only field "a1"'}
		)
		testlib.assert_thrown(
			function()
				b.a1[1] = 2
			end,
			{etype='readonly', msg_eq='attempt to set element of read-only array "a1"'}
		)

		testlib.assert_eq(#b.s,12)
		testlib.assert_eq(string.char(b.s[1]),'h')
		testlib.assert_eq(b.s[12],0)
		testlib.assert_eq(table.concat({string.char(table.unpack(b.s))}),"hello world\0")

		testlib.assert_eq(#b.a2,3)
		testlib.assert_teq(b.a2,{2,3,-1})
		testlib.assert_thrown(
			function()
				b.a2 = 'bogus'
			end,
			{etype='readonly', msg_eq='attempt to set read-only field "a2"'}
		)
		b.a2[1] = 5
		b.a2[2] = 4
		b.a2[3] = -3
		testlib.assert_teq(b.a2,{5,4,-3})
		testlib.assert_thrown(
			function()
				b.a2[0] = 1
			end,
			{etype='bad_arg', msg_eq='array set out of range "a2" 0'}
		)
		testlib.assert_thrown(
			function()
				b.a2[4] = 10
			end,
			{etype='bad_arg', msg_eq='array set out of range "a2" 4'}
		)
	end,
},
{
	'lbufutil_desc',
	function()
		local lbu=require'lbufutil'
		local l=lbuf.new('\001\000\000\000\255\255\255\255hello world\000\002\000\000\000')
		testlib.assert_eq(lbu.desc_extract(l,'u8'),1)
		testlib.assert_eq(lbu.desc_extract(l,{'u8'}),1)
		testlib.assert_teq(lbu.desc_extract(l,{'u8',4}),{1,0,0,0})
		testlib.assert_teq(lbu.desc_extract(l,{'u8',4},{offset=2}),{0,0,255,255})
		testlib.assert_teq(lbu.desc_extract(l,{
			{'field1','u16'},
			{'field2','u16'},
		},{offset=2}),{field1=0,field2=65535})
		testlib.assert_teq(lbu.desc_extract(l,{
			{'field1','u32'},
			{'field2','i32'},
			-- array of 3 struct
			{'afield',{
				{
					{'c1','u8'},
					{'c2','u8'},
					{'c3','u8'},
				},3}
			},
			-- array of 4 u8
			{'a2',{'u8',4}},
		}),{
			field1=1,
			field2=-1,
			afield={
				{
					c1=string.byte('h'),
					c2=string.byte('e'),
					c3=string.byte('l'),
				},
				{
					c1=string.byte('l'),
					c2=string.byte('o'),
					c3=string.byte(' '),
				},
				{
					c1=string.byte('w'),
					c2=string.byte('o'),
					c3=string.byte('r'),
				},

			},
			a2={
				string.byte('l'),
				string.byte('d'),
				0,
				2,
			}
		})
		testlib.assert_teq(lbu.desc_extract(l,{
			{'field1','u8'},
			{'field2','i32',_align=4},
		}),{field1=1,field2=-1})
		testlib.assert_thrown(function() lbu.desc_extract(l,1) end,{etype='bad_arg',msg_match='expected string or'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{}) end,{etype='bad_arg',msg_match='expected at least 1'})
		testlib.assert_thrown(function() lbu.desc_extract(l,'bogus') end,{etype='bad_arg',msg_match='unexpected type'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{'u63'}) end,{etype='bad_arg',msg_match='unexpected size'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{'u8',3,10}) end,{etype='bad_arg',msg_match='expected exactly 2 fields in array field_desc'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{{'field','u8',10}}) end,{etype='bad_arg',msg_match='expected exactly 2 fields in struct_member'})
		testlib.assert_thrown(function() lbu.desc_extract(l,{false,'u8',10}) end,{etype='bad_arg',msg_match='malformed field_desc'})
		-- TODO desc_text, more complicated nesting
	end,
},
{
	'lbufutil_file',
	function(self)
		local lbu=require'lbufutil'
		local testfile=self._data.testfile
		local b=lbu.loadfile(testfile)
		testlib.assert_eq(b:string(), 'hello world')
		b=lbu.loadfile(testfile,6)
		testlib.assert_eq(b:string(), 'world')
		b=lbu.loadfile(testfile,0,5)
		testlib.assert_eq(b:string(), 'hello')
		b=lbu.loadfile(testfile,6,2)
		testlib.assert_eq(b:string(), 'wo')
		b=lbu.loadfile(testfile,10,1)
		testlib.assert_eq(b:string(), 'd')
		local err
		b,err=lbu.loadfile(testfile,11)
		assert((b==false) and (err=='offset >= file size'))
		b,err=lbu.loadfile(testfile,10,3)
		assert((b==false) and (err=='offset + len > file size'))
	end,
	setup=function(self)
		local testfile=self._data.testfile
		fsutil.mkdir_parent(testfile)
		fsutil.writefile(testfile,'hello world',{bin=true})
	end,
	cleanup=function(self)
		fsutil.rm_r(self._data.testdir)
	end,
	_data={
		testdir='chdkptp-test-data',
		testfile='chdkptp-test-data/lbuftest.dat',
	},
},
{
	'lbuff',
	function(self)
		local testfile=self._data.testfile
		local l=lbuf.new('hello world')
		local f=io.open(testfile,'wb')
		l:fwrite(f)
		f:close()
		local l2=lbuf.new(l:len())
		f=io.open(testfile,'rb')
		l2:fread(f)
		f:close()
		testlib.assert_eq(l:string(), l2:string())
		f=io.open(testfile,'wb')
		l:fwrite(f,6)
		f:close()
		f=io.open(testfile,'rb')
		l2:fread(f,0,5)
		f:close()
		testlib.assert_eq(l2:string(), 'world world')
		f=io.open(testfile,'wb')
		l:fwrite(f,6,2)
		f:close()
		f=io.open(testfile,'rb')
		l2:fread(f,9,2)
		f:close()
		testlib.assert_eq(l2:string(), 'world worwo')
	end,
	setup=function(self)
		local testfile=self._data.testfile
		fsutil.mkdir_parent(testfile)
	end,
	cleanup=function(self)
		fsutil.rm_r(self._data.testdir)
	end,
	_data={
		testdir='chdkptp-test-data',
		testfile='chdkptp-test-data/lbuftest.dat',
	},
},
{
	'compare',
	function()
		assert(util.compare_values_subset({1,2,3},{1}))
		assert(util.compare_values_subset({1},{1,2,3})==false)
		local t1={1,2,3,t={a='a',b='b',c='c'}}
		local t2=util.extend_table({},t1)
		assert(util.compare_values(t1,t2))
		assert(util.compare_values(true,true))
		assert(util.compare_values(true,1)==false)
		-- TODO test error conditions
	end,
},
{
	'serialize',
	function()
	local s="this \n is '\" a test"
	local t1={1,2,3,{aa='bb'},[6]=6,t={a='a',['1b']='b',c='c'},s=s}
		testlib.assert_teq(t1, util.unserialize(util.serialize(t1)))
		testlib.assert_eq(s, util.unserialize(util.serialize(s)))
		testlib.assert_eq(true, util.unserialize(util.serialize(true)))
		testlib.assert_eq(nil, util.unserialize(util.serialize(nil)))
		testlib.assert_eq(util.serialize({foo='vfoo'},{pretty=false,bracket_keys=false}), '{foo="vfoo"}')
		testlib.assert_eq(util.serialize({foo='vfoo'},{pretty=false,bracket_keys=true}), '{["foo"]="vfoo"}')
		testlib.assert_eq(util.serialize({1,'two',3,key='value'},{pretty=false,bracket_keys=false}), '{1,"two",3,key="value"}')
		testlib.assert_teq(util.unserialize(util.serialize({-1.4,-1.5,-1.6,1.4,1.5,1.6,0xFFFFFFFF})),{-1,-2,-2,1,2,2,0xFFFFFFFF})
		-- TODO test error conditions
	end,
},
{
	'round',
	function()
		testlib.assert_eq(util.round(0), 0)
		testlib.assert_eq(util.round(0.4), 0)
		testlib.assert_eq(util.round(-0.4), 0)
		testlib.assert_eq(util.round(0.5), 1)
		testlib.assert_eq(util.round(-0.5), -1)
		testlib.assert_eq(util.round(1.6), 2)
		testlib.assert_eq(util.round(-1.6), -2)
	end,
},
{
	'extend_table',
	function()
		local tsub={ka='a',kb='b','one','two'}
		local t={1,2,3,tsub=tsub}
		testlib.assert_teq(util.extend_table({},t),t)
		assert(util.compare_values_subset(util.extend_table({'a','b','c','d'},t),t))
		testlib.assert_teq(util.extend_table({},t,{deep=true}),t)
		testlib.assert_teq(util.extend_table({},t,{deep=true,keys={3,'tsub'}}),{[3]=3,tsub=tsub})
		testlib.assert_teq(util.extend_table({},t,{keys={1,2}}),{1,2})
		testlib.assert_teq(util.extend_table({},t,{keys={1,2,'tsub'}}),{1,2,tsub=tsub})
		assert(not util.compare_values(util.extend_table({},t,{keys={1,2,'tsub'}}),t))
		testlib.assert_teq(util.extend_table({a='a'},t,{keys={1,2,'a'}}),{1,2,a='a'})
		testlib.assert_teq(util.extend_table_multi(
			{a='a',b='A'},{{b='b',c='B',t={ka='b',kc='c'}},{c='c',t=tsub}}),
			{a='a',b='b',c='c',t=tsub})
		testlib.assert_teq(util.extend_table_multi(
			{a='a',b='A'},{{b='b',c='B',t={ka='b',kc='c'}},{c='c',t=tsub}},{deep=true}),
			{a='a',b='b',c='c',t={ka='a',kb='b',kc='c','one','two'}})
		testlib.assert_teq(util.extend_table({},tsub,{iter=util.pairs_string_keys}),
			{ka='a',kb='b'})
	end,
},
{
	'flip_table',
	function()
		testlib.assert_teq(util.flip_table({}),{})
		testlib.assert_teq(util.flip_table({'a','b','c'}),{a=1,b=2,c=3})
		local t=util.flip_table{'a','b','c',foo='bar',dup='c',d=1}
		-- undefined which key is kept for dupes
		assert(t.c == 'dup' or t.c == 3)
		t.c=nil
		testlib.assert_teq(t,{'d',a=1,b=2,bar='foo'})
	end,
},
{
	'table_path',
	function()
		local t={'foo','bar',sub={'one','two',subsub={x='y'},a='b'},one=1}
		testlib.assert_eq(util.table_path_get(t,'bogus'), nil)
		testlib.assert_eq(util.table_path_get(t,'bogus','subbogus'), nil)
		testlib.assert_eq(util.table_path_get(t,1), 'foo')
		testlib.assert_eq(util.table_path_get(t,'sub',2), 'two')
		testlib.assert_eq(util.table_path_get(t,'sub','subsub','x'), 'y')
		testlib.assert_eq(util.table_pathstr_get(t,'sub.subsub.x'), 'y')
		testlib.assert_teq(util.table_path_get(t,'sub'),{'one','two',subsub={x='y'},a='b'})
		local t={{k='b'},{k='a'},{k='c'}}
		util.table_path_sort(t,{'k'})
		testlib.assert_teq(t,{{k='a'},{k='b'},{k='c'}})
		util.table_path_sort(t,{'k'},'des')
		testlib.assert_teq(t,{{k='c'},{k='b'},{k='a'}})
	end,
},
{
	'table_misc',
	function()
		testlib.assert_eq(util.table_amean{1,2,3,4,5,6,7,8,9}, 5)
		testlib.assert_teq(util.table_stats{1,2},{
			min=1,
			sum=3,
			sd=0.5,
			max=2,
			mean=1.5
		})
		assert(util.in_table({'foo','bar'},'foo'))
		assert(not util.in_table({'foo','bar'},'boo'))
		assert(util.in_table({'foo',bar='mod'},'mod'))
		assert(not util.in_table({bar='mod'},'bar'))
	end,
},
{
	'string_split',
	function()
		testlib.assert_teq(util.string_split('hi'),{'hi'})
		testlib.assert_teq(util.string_split('hi',''),{'h','i'})
		testlib.assert_teq(util.string_split('hello world',' '),{'hello','world'})
		testlib.assert_teq(util.string_split('hello world ',' '),{'hello','world',''})
		testlib.assert_teq(util.string_split('hello world ',' ',{empty=false}),{'hello','world'})
	end,
},
{
	'string_trim',
	function()
		testlib.assert_eq(util.string_trim('hi'), 'hi')
		testlib.assert_eq(util.string_trim(' hi '), 'hi')
		testlib.assert_eq(util.string_trim('  hello world  '), 'hello world')
		testlib.assert_eq(util.string_trim('  \nhello world\r\n'), 'hello world')
		testlib.assert_eq(util.string_trim('  \n\t'), '')
		testlib.assert_eq(util.string_trim('  \n\t',' *'), '\n\t')
		testlib.assert_eq(util.string_trim('hehello world','he'), 'hello world')
	end,
},
{
	'bit_util',
	function()
		local b=util.bit_unpack(0)
		testlib.assert_eq(#b, 31)
		testlib.assert_eq(b[0], 0)
		testlib.assert_eq(b[1], 0)
		testlib.assert_eq(b[31], 0)
		testlib.assert_eq(util.bit_packu(b), 0)
		local b=util.bit_unpack(0x80000000)
		testlib.assert_eq(b[0], 0)
		testlib.assert_eq(b[31], 1)
		testlib.assert_eq(util.bit_packu(b), 0x80000000)
		testlib.assert_eq(util.bit_packu(util.bit_unpack(15,2)), 7)
		testlib.assert_eq(util.bit_packstr(util.bit_unpackstr('hello world')), 'hello world')
		local v=util.bit_packu({[0]=1,0,1})
		testlib.assert_eq(v, 5)
		local v=util.bit_packstr({[0]=1,0,0,0,1,1})
		testlib.assert_eq(v, '1')
		local b=util.bit_unpackstr('hello world')
		local b2 = {[0]=1,0,0,0,1,1}
		for i=0,#b2 do
			table.insert(b,b2[i])
		end
		testlib.assert_eq(util.bit_packstr(b), 'hello world1')
	end,
},
{
	'errutil',
	function()
		local last_err_str
		local last_err
		local f=errutil.wrap(function(a,...)
			if a=='error' then
				error('errortext')
			end
			if a=='throw' then
				errlib.throw({etype='test',msg='test msg'})
			end
			if a=='critical' then
				errlib.throw({etype='testcrit',msg='test msg',critical=true})
			end
			return ...
		end,
		{
			output=function(err_str)
				last_err_str=err_str
			end,
			handler=function(err)
				last_err=err
				return errutil.format(err)
			end,
		})
		local t={f('ok',1,'two')}
		assert(util.compare_values(t,{1,'two'}))
		t={f()}
		testlib.assert_eq(#t, 0)
		local t={f('ok',1,nil,3)}
		assert(util.compare_values(t,{[1]=1,[3]=3}))
		local t={f('error',1,2,3)}
		testlib.assert_eq(#t, 0)
		testlib.assert_eq(string.sub(last_err,-9), 'errortext')
		assert(string.find(last_err_str,'stack traceback:'))
		local t={f('throw',1,2,3)}
		testlib.assert_eq(#t, 0)
		testlib.assert_eq(last_err.etype, 'test')
		assert(not string.find(last_err_str,'stack traceback:'))
		local t={f('critical')}
		testlib.assert_eq(#t, 0)
		testlib.assert_eq(last_err.etype, 'testcrit')
		assert(string.find(last_err_str,'stack traceback:'))
	end,
	setup=function(self)
		self._data.err_trace = prefs.err_trace
		prefs.err_trace='critical'
	end,
	cleanup=function(self)
		prefs.err_trace = self._data.err_trace
	end,
	_data={},
},
{
	'varsubst',
	function()
		local vs=require'varsubst'
		local s={
			fmt=123.4,
			date=os.time{year=2001,month=11,day=10},
		}
		local funcs=util.extend_table({
			fmt=vs.format_state_val('fmt','%.0f'),
			date=vs.format_state_date('date','%Y%m%d_%H%M%S'),
		},vs.string_subst_funcs)
		local subst=vs.new(funcs,s)
		testlib.assert_eq(subst:run('${fmt}'), '123')
		testlib.assert_eq(subst:run('whee${fmt}ee'), 'whee123ee')
		testlib.assert_eq(subst:run('${fmt, %3.2f}'), '123.40')
		testlib.assert_eq(subst:run('${s_format, hello world}'), 'hello world')
		testlib.assert_eq(subst:run('${s_format,hello world %d,${fmt}}'), 'hello world 123')
		testlib.assert_eq(subst:run('${date}'), '20011110_120000')
		testlib.assert_eq(subst:run('${date,%Y}'), '2001')
		testlib.assert_eq(subst:run('${date,whee %H:%M:%S}'), 'whee 12:00:00')
		assert(pcall(function() subst:validate('${s_format,hello world %d,${fmt}}') end))
		testlib.assert_thrown(function() subst:validate('${bogus}') end,{etype='varsubst',msg_match='unknown'})
		testlib.assert_thrown(function() subst:validate('whee${fmt') end,{etype='varsubst',msg_match='unclosed'})
		testlib.assert_thrown(function() subst:validate('whee${fmt ___}') end,{etype='varsubst',msg_match='parse failed'})
		testlib.assert_eq(subst:run('${s_format,0x%x %s,101,good doggos}'), '0x65 good doggos')
		testlib.assert_eq(subst:run('${s_format,}'), '') -- empty string->empty string
		testlib.assert_thrown(function() subst:run('${s_format}') end,{etype='varsubst',msg_match='s_format missing arguments'})
		testlib.assert_eq(subst:run('${s_sub,hello world,-5}'), 'world')
		testlib.assert_thrown(function() subst:run('${s_sub,hello world}') end,{etype='varsubst',msg_match='s_sub expected 2'})
		testlib.assert_thrown(function() subst:run('${s_sub,hello world,bob}') end,{etype='varsubst',msg_match='s_sub expected number'})
		testlib.assert_thrown(function() subst:run('${s_sub,hello world,5,bob}') end,{etype='varsubst',msg_match='s_sub expected number'})
		testlib.assert_eq(subst:run('${s_upper,hi}'), 'HI')
		testlib.assert_eq(subst:run('${s_lower,Bye}'), 'bye')
		testlib.assert_eq(subst:run('${s_reverse,he}'), 'eh')
		testlib.assert_eq(subst:run('${s_rep, he, 2}'), 'hehe')
		testlib.assert_thrown(function() subst:run('${s_rep,hello world}') end,{etype='varsubst',msg_match='s_rep expected 2'})
		testlib.assert_thrown(function() subst:run('${s_rep,hello world,}') end,{etype='varsubst',msg_match='s_rep expected number'})
		testlib.assert_eq(subst:run('${s_match,hello world,.o%s.*}'), 'lo world')
		testlib.assert_eq(subst:run('${s_match,hello world,o.,6}'), 'or')
		testlib.assert_eq(subst:run('${s_match,hello world,(%a+)%s+(%a+)}'), 'helloworld')
		testlib.assert_thrown(function() subst:run('${s_match,hello world,.,bob}') end,{etype='varsubst',msg_match='s_match expected number'})
		testlib.assert_eq(subst:run('${s_gsub,hello world,(%a+)%s+(%a+),%2 %1}'), 'world hello')
		testlib.assert_eq(subst:run('${s_gsub,hello world,l,_,2}'), 'he__o world')
		testlib.assert_thrown(function() subst:run('${s_gsub,hello world,one,two,three,four}') end,{etype='varsubst',msg_match='s_gsub expected 3'})
		assert(pcall(function() subst:validate('${s_gsub,${s_sub,${s_upper,${s_format,hello world %d,${fmt}}},${s_sub,${fmt},1,1},${s_sub,${fmt},-1}},$,L}') end))
		testlib.assert_eq(subst:run('${s_gsub,${s_sub,${s_upper,${s_format,hello world %d,${fmt}}},${s_sub,${fmt},1,1},${s_sub,${fmt},-1}},$,L}'), 'HELL')
	end,
},
{
	'dng',
	function(self)
		local infile=self._data.infile
		local outfile=self._data.outfile
		local status,err=cli:execute('dngload '..infile)
		assert(status and err == 'loaded '..infile)
		status,err=cli:execute('dngsave '..outfile)
		assert(status) -- TODO 'wrote' message goes to stdout
		status,err=cli:execute('dngdump -thm='..outfile..'.ppm  -tfmt=ppm -raw='..outfile..'.pgm  -rfmt=8pgm')
		assert(status)
		testlib.assert_eq(lfs.attributes(outfile,'mode'), 'file')
		testlib.assert_eq(lfs.attributes(outfile..'.ppm','mode'), 'file')
		testlib.assert_eq(lfs.attributes(outfile..'.pgm','mode'), 'file')
		status,err=cli:execute('dnglistpixels -max=0 -out='..outfile..'.bad.txt -fmt=chdk')
		assert(status)
		testlib.assert_eq(lfs.attributes(outfile..'.bad.txt','mode'), 'file')
	end,
	setup=function(self)
		-- test files not checked in, skip if not present
		if not lfs.attributes(self._data.infile) then
			return false
		end
	end,
	cleanup={
		function(self)
			fsutil.remove_e(self._data.outfile)
		end,
		function(self)
			fsutil.remove_e(self._data.outfile..'.ppm')
		end,
		function(self)
			fsutil.remove_e(self._data.outfile..'.pgm')
		end,
		function(self)
			fsutil.remove_e(self._data.outfile..'.bad.txt')
		end,

	},
	_data = {
		infile='test10.dng',
		outfile='dngtest.tmp',
	},
},
{
	'climisc',
	function(self)
		local status,msg=cli:execute('!return 1')
		local tmpfile=self._data.tmpfile
		assert(status and msg=='=1')
		status,msg=cli:execute('!<'..tmpfile)
		assert(status and msg=='=2')
	end,
	setup=function(self)
		self._data.tmpfile=os.tmpname()
		fsutil.writefile(self._data.tmpfile,'return 1+1\n',{bin=true})
	end,
	cleanup=function(self)
		fsutil.remove_e(self._data.tmpfile)
	end,
	_data={}
},
{
	'prefs',
	function(self)
		-- test setting values before reg
		prefs._allow_unreg(true)
		testlib.assert_cli_ok('set test_pref=test')
		prefs._allow_unreg(false)
		prefs._add('test_pref','string','test pref','hi')
		testlib.assert_eq(prefs.test_pref, 'test')
		testlib.assert_cli_ok('set -v test_pref',{match='^test_pref=test%s+- string %(default:hi%): test pref'})
		prefs._remove('test_pref')
		testlib.assert_cli_error('set test_pref=bye',{eq='unknown pref: test_pref'})
		testlib.assert_thrown(function() prefs.test_pref="byebye" end,{etype='bad_arg',msg_match='unknown pref'})

		testlib.assert_thrown(function() prefs._add() end,{etype='bad_arg',msg_match='pref name must be string'})
		testlib.assert_thrown(function() prefs._add('bogus') end,{etype='bad_arg',msg_match='unknown vtype: nil'})
		testlib.assert_thrown(function() prefs._add('_describe') end,{etype='bad_arg',msg_match='pref name conflicts with method'})
		testlib.assert_thrown(function() prefs.bogus=1 end,{etype='bad_arg',msg_match='unknown pref'})
		testlib.assert_thrown(function() local v=prefs.bogus end,{etype='bad_arg',msg_match='unknown pref'})
		testlib.assert_thrown(function() prefs.cli_shotseq='bogus' end,{etype='bad_arg',msg_match='invalid value'})

		-- string enum
		prefs._add('test_pref2','string','test pref two','bye',{values={'hi','bye','whatever'}})
		testlib.assert_eq(prefs.test_pref2, 'bye')
		testlib.assert_cli_ok('set test_pref2=whatever')
		testlib.assert_cli_ok('set test_pref2=hi')
		testlib.assert_cli_error('set test_pref2=bogus',{eq='invalid value bogus'})
		testlib.assert_eq(prefs.test_pref2, 'hi')
		testlib.assert_cli_ok('set -d test_pref2')
		testlib.assert_eq(prefs.test_pref2, 'bye')
		testlib.assert_cli_error('set -d',{eq='-d requires name'})
		testlib.assert_cli_error('set -d test_pref2=bogus',{eq='unexpected value with -d'})

		-- numeric enum
		prefs._remove('test_pref2')
		prefs._add('test_pref2','number','test pref two b',1,{values={0,1,2,5}})
		testlib.assert_eq(prefs.test_pref2, 1)
		testlib.assert_cli_ok('set test_pref2=0')
		testlib.assert_eq(prefs.test_pref2, 0)
		prefs.test_pref2 = 5
		testlib.assert_eq(prefs.test_pref2, 5)
		testlib.assert_thrown(function() prefs.test_pref2=3 end,{etype='bad_arg',msg_match='invalid value'})
		testlib.assert_cli_ok('set -v test_pref2',{match='^test_pref2=5%s+- number %(default:1 allowed:0, 1, 2, 5%): test pref two b'})

		-- numeric range
		prefs._remove('test_pref2')
		prefs._add('test_pref2','number','test pref two c',0,{min=-1,max=3})
		testlib.assert_eq(prefs.test_pref2, 0)
		prefs.test_pref2 = -1
		testlib.assert_eq(prefs.test_pref2, -1)
		prefs.test_pref2 = 3
		testlib.assert_eq(prefs.test_pref2, 3)
		testlib.assert_thrown(function() prefs.test_pref2=-2 end,{etype='bad_arg',msg_eq='value -2 < min -1'})
		testlib.assert_thrown(function() prefs.test_pref2=4 end,{etype='bad_arg',msg_eq='value 4 > max 3'})
		testlib.assert_cli_ok('set -v test_pref2',{match='^test_pref2=3%s+- number %(default:0 allowed:%[%-1 3%]%): test pref two c'})

		-- numeric enum + range
		prefs._remove('test_pref2')
		prefs._add('test_pref2','number','test pref two d',10,{min=10,max=20,values={-2,0,3}})
		testlib.assert_eq(prefs.test_pref2, 10)
		prefs.test_pref2 = -2
		testlib.assert_eq(prefs.test_pref2, -2)
		prefs.test_pref2 = 3
		testlib.assert_eq(prefs.test_pref2, 3)
		prefs.test_pref2 = 10
		testlib.assert_eq(prefs.test_pref2, 10)
		prefs.test_pref2 = 20
		testlib.assert_eq(prefs.test_pref2, 20)
		testlib.assert_thrown(function() prefs.test_pref2=-1 end,{etype='bad_arg',msg_eq='value -1 < min 10'})
		testlib.assert_thrown(function() prefs.test_pref2=2 end,{etype='bad_arg',msg_eq='value 2 < min 10'})
		testlib.assert_thrown(function() prefs.test_pref2=9 end,{etype='bad_arg',msg_eq='value 9 < min 10'})
		testlib.assert_thrown(function() prefs.test_pref2=21 end,{etype='bad_arg',msg_eq='value 21 > max 20'})
		testlib.assert_cli_ok('set -v test_pref2',{match='^test_pref2=20%s+- number %(default:10 allowed:%-2, 0, 3 or %[10 20%]%): test pref two d'})

		-- numeric min only
		prefs._remove('test_pref2')
		prefs._add('test_pref2','number','test pref two e',11,{min=10})
		testlib.assert_eq(prefs.test_pref2, 11)
		prefs.test_pref2 = 10
		testlib.assert_eq(prefs.test_pref2, 10)
		testlib.assert_thrown(function() prefs.test_pref2=9 end,{etype='bad_arg',msg_eq='value 9 < min 10'})
		testlib.assert_cli_ok('set -v test_pref2',{match='^test_pref2=10%s+- number %(default:11 allowed:>= 10%): test pref two e'})

		-- numeric max only
		prefs._remove('test_pref2')
		prefs._add('test_pref2','number','test pref two f',-10,{max=-1})
		testlib.assert_eq(prefs.test_pref2, -10)
		prefs.test_pref2 = -1
		testlib.assert_eq(prefs.test_pref2, -1)
		testlib.assert_thrown(function() prefs.test_pref2=0 end,{etype='bad_arg',msg_eq='value 0 > max -1'})
		testlib.assert_cli_ok('set -v test_pref2',{match='^test_pref2=%-1%s+- number %(default:%-10 allowed:<= %-1%): test pref two f'})

		-- remove really removes
		prefs._remove('test_pref2')
		testlib.assert_thrown(function() return prefs.test_pref2==nil end,{etype='bad_arg',msg_eq='unknown pref: test_pref2'})

		-- non existent
		testlib.assert_cli_error('set bogus',{match='unknown pref'})
		testlib.assert_cli_error('set bogus=1',{match='unknown pref'})
		-- invalid number
		testlib.assert_cli_error('set cli_time=bogus',{match='invalid value'})
		-- invalid custom
		testlib.assert_cli_error('set err_trace=bogus',{match='invalid value'})
		-- non 0/1 for boolean
		testlib.assert_cli_error('set cli_error_exit=2',{match='invalid value'})
		testlib.assert_cli_ok('set cli_shotseq=100')
		testlib.assert_eq(prefs.cli_shotseq,100)
		prefs.cli_shotseq=200
		testlib.assert_cli_ok('set cli_shotseq',{match='^cli_shotseq=200\n$'})
		testlib.assert_cli_ok('set -c cli_shotseq',{match='^set cli_shotseq=200\n$'})
		testlib.assert_cli_ok('set -v cli_shotseq',{match='^cli_shotseq=200%s+- number %(default:1%):'})
	end,
	setup=function(self)
		self._data.cli_shotseq = prefs.cli_shotseq
	end,
	cleanup=function(self)
		prefs.cli_shotseq = self._data.cli_shotseq
		prefs._remove('test_pref')
		prefs._remove('test_pref2')
		prefs._allow_unreg(false)
	end,
	_data={}
},
{
	'cli_nocon',
	function(self)
		local nocon = {match='not connected'}
		local fn = self._data.testfile
		-- check that commands which require connection return expected error
		testlib.assert_cli_error('lua return 1',nocon)
		testlib.assert_cli_error('getm',nocon)
		testlib.assert_cli_error('putm',nocon)
		testlib.assert_cli_error('luar return 1',nocon)
		-- TODO killscript alone gives protocol ver error, this generates warning about crashes
		-- testlib.assert_cli_error('killscript -force',nocon)
		testlib.assert_cli_error('rmem 0x1900 4',nocon)
		testlib.assert_cli_error('upload '..fn,nocon)
		testlib.assert_cli_error('download bogus bogus',nocon)
		testlib.assert_cli_error('imdl',nocon)
		testlib.assert_cli_error('imls',nocon)
		testlib.assert_cli_error('mdl bogus bogus',nocon)
		testlib.assert_cli_error('mup '..fn..' A/',nocon)
		testlib.assert_cli_error('rm bogus',nocon)
		testlib.assert_cli_error('ls',nocon)
		testlib.assert_cli_error('reboot',nocon)
		-- TODO lvmdump returns bad proto
		testlib.assert_cli_error('lvdumpimg -vp',nocon)
		testlib.assert_cli_error('shoot',nocon)
		testlib.assert_cli_error('rs',nocon)
		testlib.assert_cli_error('rsint',nocon)
		testlib.assert_cli_error('rec',nocon)
		testlib.assert_cli_error('play',nocon)
		testlib.assert_cli_error('clock',nocon)
		testlib.assert_cli_error('unlock',nocon)
	end,
	setup=function(self)
		-- tests expect not connected error
		if con:is_connected() then
			return false
		end
		self._data.testfile=os.tmpname()
		fsutil.writefile(self._data.testfile,'test',{bin=true})
	end,
	cleanup=function(self)
		fsutil.remove_e(self._data.testfile)
	end,
	_data={}
},
{
	'lvdumpimg_nocon',
	function(self)
		testlib.assert_cli_error('lvdumpimg',{match='^nothing selected'})
		testlib.assert_cli_error('lvdumpimg -fps=1 -wait=10 -vp',{match='^specify wait or fps'})
		testlib.assert_cli_error('lvdumpimg -vp -count=all',{match='^count=all'})
		testlib.assert_cli_error('lvdumpimg -bm -count=quack',{match='^invalid count'})
		testlib.assert_cli_error('lvdumpimg -vp -bm -count=-10',{match='^invalid count'})
		testlib.assert_cli_error('lvdumpimg -vp -seek=5',{match='^seek only valid'})
		-- message varies by os
		local fn = self._data.noexist_file
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp')
		local fn = self._data.bogusfile
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp',{match='^unrecognized file'})
		local fn = self._data.testfile
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=${bogus}',{match='^unknown substitution'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp -vpfmt=bogus',{match='^invalid format bogus'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp -pipevp',{match='^must specify command'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=cat -pipevp=split',{match='^pipe split only valid'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=cat -pipevp=combine',{match='^pipe combine only valid'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=cat -pipevp=bogus',{match='^invalid pipe'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -bm -pipebm=combine ',{match='^pipe combine requires'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -vp=cat -vpfmt=yuv-s-pgm -pipevp=split -bm -pipebm=combine',{match='^pipe combine requires'})
		testlib.assert_cli_error('lvdumpimg -infile='..fn..' -bm=cat -pipebm=split ',{match='^pipe split only valid'})
	end,
	setup=function(self)
		-- tests expect not connected error
		if con:is_connected() then
			return false
		end
		-- file to allow checking format check
		self._data.bogusfile=os.tmpname()
		fsutil.writefile(self._data.bogusfile,('bogus\n'):rep(100),{bin=true})

		self._data.testfile=os.tmpname()
		-- minimally valid header for v1.0 lvdump
		fsutil.writefile(self._data.testfile,
							'chlv'..
							'\x08\x00\x00\x00\x01\x00\x00\x00'..
							'\x00\x00\x00\x00\x68\x90\x0a\x00\x02\x00\x00\x00'..
							'\x02\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00'..
							'\x68\x00\x00\x00\x20\x00\x00\x00\x44\x00\x00\x00'..
							'\x00\x00\x00\x00\x00\x00\x00\x00\x68\x04\x00\x00'..
							'\xd0\x02\x00\x00\xd0\x02\x00\x00\xe0\x01\x00\x00'..
							'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'..
							'\x00\x00\x00\x00\x01\x00\x00\x00',
							{bin=true})

		-- non-existing file
		self._data.noexist_file=os.tmpname()
		-- os.tmpname may create
		if lfs.attributes(self._data.noexist_file) then
			fsutil.remove_e(self._data.noexist_file)
		end
	end,
	cleanup={
		-- failure test cases may leave file handles open, depending where error thrown
		-- handles would normally be collected and closed at exit, but
		-- collect to ensure they can be removed under windows
		function(self)
			collectgarbage('collect')
		end,
		function(self)
			fsutil.remove_e(self._data.bogusfile)
		end,
		function(self)
			fsutil.remove_e(self._data.testfile)
		end,
	},
	_data={}
},
{
	'shoot_common_opts',
	function()
		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='0.1',
		})
		testlib.assert_eq(opts.sd, 100)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1mm',
		})
		testlib.assert_eq(opts.sd, 1)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1.5m',
		})
		testlib.assert_eq(opts.sd, 1500)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1ft',
		})
		testlib.assert_eq(opts.sd, 305)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1in',
		})
		testlib.assert_eq(opts.sd, 25)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='-1ft',
		})
		testlib.assert_eq(opts.sd, -1)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='-1in',
		})
		testlib.assert_eq(opts.sd, -1)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='iNf',
		})
		testlib.assert_eq(opts.sd, -1)

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1bogus',
		})
		testlib.assert_eq(opts, false)
		testlib.assert_eq(status, 'invalid sd units bogus')

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='1/23',
		})
		testlib.assert_eq(opts, false)
		testlib.assert_eq(status, 'invalid sd 1/23')

		local opts,status=cli:get_shoot_common_opts({
			u='s',
			sd='one hundred fathoms',
		})
		testlib.assert_eq(opts, false)
		testlib.assert_eq(status, 'invalid sd one hundred fathoms')
	end,
	setup=function()
		spoof_con({
			is_connected=function()
				return true
			end,
			is_ver_compatible = function(maj,minor)
				return true
			end
		})
	end,
	cleanup=function()
		if con._unspoof() then
			con._unspoof()
		end
	end,
},
{
	'chdkmenuscript',
	function()
		local chdkmenuscript=require'chdkmenuscript'
		local w={}
		chdkmenuscript.warnf = function(fmt,...)
			local s=fmt:format(...)
			--printf('%s',s)
			table.insert(w,s)
		end
		-- various well formed items, should not produce warnings
		local s=[[
@chdk_version 1.4.1
@title Menu param test
-- space between keyword and name not required
@defaulta 1
@parama Item a

-- item with range, hex, octal and dec all allowed
@param bee at with range -10-0x20
@default bee 010
@range bee -10 0x20

-- boolean, leading space
 @param boo Boolean @ param
   @default boo  true
-- default can include any number of = and space
@param   c Option c
@default c = = 10000

@subtitle First subtitle
-- shorthand syntax, basic
#sh1=-1 "'Shorthand' one"
#sh2=1000000 '"Shorthand" two' long
-- space isn't require after description
#sh3=2 "Shorthand 3 range"[0 10]
-- boolean by value
#sh4=false "Shortand 4 boolean"
-- empty subtitle is allowed
@subtitle
-- boolean by keyword
#sh5=1 "Shorthand 5 boolean"bool
-- table
#sh6=3 "Shorthand 6 table" { One Two 3 Four } table
-- enum
#sh7=0 "Shorthand 7 enum" { 1 2 Three 4 Five 6 }

-- something to simulate the body of the script
print('hello world')

]]
		local h=chdkmenuscript.new_header{text=s}
		testlib.assert_eq(h.title,'Menu param test')
		testlib.assert_eq(h.chdk_version,'1.4.1')
		testlib.assert_eq(h.by_name.a.desc,'Item a')
		testlib.assert_eq(h.by_name.a.val,1)
		testlib.assert_eq(h.by_name.a.paramtype,'short')
		testlib.assert_eq(h.by_name.bee.val,8)
		testlib.assert_teq(h.by_name.bee.range,{-10,32})
		testlib.assert_eq(h.by_name.boo.val,true)
		testlib.assert_eq(h.by_name.boo.paramtype,'bool')
		testlib.assert_eq(h.by_name.c.val,10000)
		testlib.assert_eq(h.by_name.subtitle1.val,"First subtitle")
		testlib.assert_eq(h.by_name.subtitle1.paramtype,'subtitle')
		testlib.assert_eq(h.by_name.sh1.desc,"'Shorthand' one")
		testlib.assert_eq(h.by_name.sh1.val,-1)
		testlib.assert_eq(h.by_name.sh1.paramtype,'short')
		testlib.assert_eq(h.by_name.sh2.desc,'"Shorthand" two')
		testlib.assert_eq(h.by_name.sh2.val,1000000)
		testlib.assert_eq(h.by_name.sh2.paramtype,'long')
		testlib.assert_eq(h.by_name.sh3.val,2)
		testlib.assert_eq(h.by_name.sh3.paramtype,'short')
		testlib.assert_teq(h.by_name.sh3.range,{0,10})
		testlib.assert_eq(h.by_name.sh4.val,false)
		testlib.assert_eq(h.by_name.sh4.paramtype,'bool')
		testlib.assert_eq(h.by_name.subtitle2.val,"")
		testlib.assert_eq(h.by_name.sh5.desc,"Shorthand 5 boolean")
		testlib.assert_eq(h.by_name.sh5.val,true)
		testlib.assert_eq(h.by_name.sh5.paramtype,'bool')
		testlib.assert_eq(h.by_name.sh6.val,3)
		testlib.assert_eq(h.by_name.sh6.items[h.by_name.sh6.val],"3")
		testlib.assert_eq(h.by_name.sh6.paramtype,'table')
		testlib.assert_eq(h.by_name.sh7.val,0)
		testlib.assert_eq(h.by_name.sh7.items[h.by_name.sh7.val+1],"1")
		testlib.assert_eq(h.by_name.sh7.paramtype,'enum')
		testlib.assert_eq(#h.items,13)
		testlib.assert_eq(#w,0)
		local cfg1 = h:make_saved_cfg()
		testlib.assert_eq(cfg1,[[
#a=1
#bee=8
#boo=1
#c=10000
#sh1=-1
#sh2=1000000
#sh3=2
#sh4=0
#sh5=1
#sh6=2
#sh7=0
]])
		-- merging generated cfg should give identical results
		h:merge_saved_cfg(cfg1)
		testlib.assert_eq(cfg1,h:make_saved_cfg())

		testlib.assert_eq(h:make_header(),[[
@title Menu param test
@chdk_version 1.4.1
@param a Item a
@default a 1
@param bee at with range -10-0x20
@default bee 8
@range bee -10 32
@param boo Boolean @ param
@default boo true
@param c Option c
@default c 10000
@subtitle First subtitle
#sh1=-1 "'Shorthand' one"
#sh2=1000000 '"Shorthand" two' long
#sh3=2 "Shorthand 3 range" [0 10]
#sh4=false "Shortand 4 boolean"
@subtitle
#sh5=true "Shorthand 5 boolean"
#sh6=3 "Shorthand 6 table" {One Two 3 Four} table
#sh7=0 "Shorthand 7 enum" {1 2 Three 4 Five 6}
]])
		testlib.assert_eq(h:make_header({format='#'}),[[
@title Menu param test
@chdk_version 1.4.1
#a=1 "Item a"
#bee=8 "at with range -10-0x20" [-10 32]
#boo=true "Boolean @ param"
#c=10000 "Option c"
@subtitle First subtitle
#sh1=-1 "'Shorthand' one"
#sh2=1000000 '"Shorthand" two' long
#sh3=2 "Shorthand 3 range" [0 10]
#sh4=false "Shortand 4 boolean"
@subtitle
#sh5=true "Shorthand 5 boolean"
#sh6=3 "Shorthand 6 table" {One Two 3 Four} table
#sh7=0 "Shorthand 7 enum" {1 2 Three 4 Five 6}
]])
		testlib.assert_eq(h:make_header({format='@'}),[[
@title Menu param test
@chdk_version 1.4.1
@param a Item a
@default a 1
@param bee at with range -10-0x20
@default bee 8
@range bee -10 32
@param boo Boolean @ param
@default boo true
@param c Option c
@default c 10000
@subtitle First subtitle
@param sh1 'Shorthand' one
@default sh1 -1
#sh2=1000000 '"Shorthand" two' long
@param sh3 Shorthand 3 range
@default sh3 2
@range sh3 0 10
@param sh4 Shortand 4 boolean
@default sh4 false
@subtitle
@param sh5 Shorthand 5 boolean
@default sh5 true
#sh6=3 "Shorthand 6 table" {One Two 3 Four} table
@param sh7 Shorthand 7 enum
@default sh7 0
@values sh7 1 2 Three 4 Five 6
]])
		-- test setting
		h.by_name.a:set_value(2)
		h.by_name.bee:set_value(-10)
		h.by_name.c:set_value_str("10001")
		h.by_name.boo:set_value(false)
		h.by_name.sh3:set_value_str("10")
		h.by_name.sh5:set_value_str("0")
		h.by_name.sh6:set_value_by_item("One")
		h.by_name.sh7:set_value_by_item("6")
		testlib.assert_eq(h:make_header({format='#'}),[[
@title Menu param test
@chdk_version 1.4.1
#a=2 "Item a"
#bee=-10 "at with range -10-0x20" [-10 32]
#boo=false "Boolean @ param"
#c=10001 "Option c"
@subtitle First subtitle
#sh1=-1 "'Shorthand' one"
#sh2=1000000 '"Shorthand" two' long
#sh3=10 "Shorthand 3 range" [0 10]
#sh4=false "Shortand 4 boolean"
@subtitle
#sh5=false "Shorthand 5 boolean"
#sh6=1 "Shorthand 6 table" {One Two 3 Four} table
#sh7=5 "Shorthand 7 enum" {1 2 Three 4 Five 6}
]])
		-- set errors / range checking
		testlib.assert_thrown(function()
			h.by_name.a:set_value(-10000)
		end,{etype='bad_value',msg_eq ='item a invalid value -10000'})
		testlib.assert_thrown(function()
			h.by_name.a:set_value(100000)
		end,{etype='bad_value',msg_eq ='item a invalid value 100000'})
		testlib.assert_thrown(function()
			h.by_name.bee:set_value(33)
		end,{etype='bad_value',msg_eq ='item bee value 33 out of range -10 32'})
		testlib.assert_thrown(function()
			h.by_name.bee:set_value(-11)
		end,{etype='bad_value',msg_eq ='item bee value -11 out of range -10 32'})
		testlib.assert_thrown(function()
			h.by_name.sh2:set_value(-1)
		end,{etype='bad_value',msg_eq ='item sh2 invalid value -1'})
		testlib.assert_thrown(function()
			h.by_name.sh2:set_value(10000000)
		end,{etype='bad_value',msg_eq ='item sh2 invalid value 10000000'})
		testlib.assert_thrown(function()
			h.by_name.sh4:set_value(0)
		end,{etype='bad_value',msg_eq ='item sh4 expected boolean, not number'})
		testlib.assert_thrown(function()
			h.by_name.sh4:set_value("false")
		end,{etype='bad_value',msg_eq ='item sh4 expected boolean, not string'})
		testlib.assert_thrown(function()
			h.by_name.sh4:set_value(nil)
		end,{etype='bad_value',msg_eq ='item sh4 expected boolean, not nil'})
		testlib.assert_thrown(function()
			h.by_name.sh6:set_value(0)
		end,{etype='bad_value',msg_eq ='item sh6 table value 0 out of range 1 4'})
		testlib.assert_thrown(function()
			h.by_name.sh6:set_value(5)
		end,{etype='bad_value',msg_eq ='item sh6 table value 5 out of range 1 4'})
		testlib.assert_thrown(function()
			h.by_name.sh7:set_value(-1)
		end,{etype='bad_value',msg_eq ='item sh7 enum value -1 out of range 0 5'})
		testlib.assert_thrown(function()
			h.by_name.sh7:set_value(6)
		end,{etype='bad_value',msg_eq ='item sh7 enum value 6 out of range 0 5'})

		testlib.assert_thrown(function()
			h.by_name.a:set_value_str("one")
		end,{etype='bad_value',msg_eq ='item a expected number, not one'})
		testlib.assert_thrown(function()
			h.by_name.sh4:set_value_str("2")
		end,{etype='bad_value',msg_eq ='item sh4 expected boolean, not 2'})

		testlib.assert_thrown(function()
			h.by_name.a:set_value_by_item("1")
		end,{etype='bad_value',msg_eq ='item a not a table or enum'})
		testlib.assert_thrown(function()
			h.by_name.sh6:set_value_by_item("2")
		end,{etype='bad_value',msg_eq ='item sh6 value 2 not found'})
		testlib.assert_thrown(function()
			h.by_name.sh7:set_value_by_item("two")
		end,{etype='bad_value',msg_eq ='item sh7 value two not found'})

		testlib.assert_thrown(function()
			h:set_values{{'bogus',1}}
		end,{etype='bad_arg',msg_eq ='unknown item bogus'})

		-- glue
		h=chdkmenuscript.new_header{text=s}
		testlib.assert_eq(h:make_glue_tpl(),
[[
-- BEGIN menu glue
-- @title Menu param test
-- @chdk_version 1.4.1
-- @defaulta 1
-- @parama Item a
a=1
-- @param bee at with range -10-0x20
-- @default bee 010
-- @range bee -10 0x20
bee=8
-- @param boo Boolean @ param
-- @default boo  true
boo=true
-- @param   c Option c
-- @default c = = 10000
c=10000
-- @subtitle First subtitle
-- #sh1=-1 "'Shorthand' one"
sh1=-1
-- #sh2=1000000 '"Shorthand" two' long
sh2=1000000
-- #sh3=2 "Shorthand 3 range"[0 10]
sh3=2
-- #sh4=false "Shortand 4 boolean"
sh4=false
-- @subtitle
-- #sh5=1 "Shorthand 5 boolean"bool
sh5=true
-- #sh6=3 "Shorthand 6 table" { One Two 3 Four } table
sh6={
 index=3,
 value="3"
}
-- #sh7=0 "Shorthand 7 enum" { 1 2 Three 4 Five 6 }
sh7=0
-- END menu glue
-- BEGIN glued script
@chdk_version 1.4.1
@title Menu param test
-- space between keyword and name not required
@defaulta 1
@parama Item a

-- item with range, hex, octal and dec all allowed
@param bee at with range -10-0x20
@default bee 010
@range bee -10 0x20

-- boolean, leading space
 @param boo Boolean @ param
   @default boo  true
-- default can include any number of = and space
@param   c Option c
@default c = = 10000

@subtitle First subtitle
-- shorthand syntax, basic
#sh1=-1 "'Shorthand' one"
#sh2=1000000 '"Shorthand" two' long
-- space isn't require after description
#sh3=2 "Shorthand 3 range"[0 10]
-- boolean by value
#sh4=false "Shortand 4 boolean"
-- empty subtitle is allowed
@subtitle
-- boolean by keyword
#sh5=1 "Shorthand 5 boolean"bool
-- table
#sh6=3 "Shorthand 6 table" { One Two 3 Four } table
-- enum
#sh7=0 "Shorthand 7 enum" { 1 2 Three 4 Five 6 }

-- something to simulate the body of the script
print('hello world')

-- END glued script
]])
		testlib.assert_eq(h:make_glue_tpl([[
-- this is trimmed from the output

 --[!glue:start]
-- glue goes here
--[!glue:vars]
-- body here
--[!glue:body]
]],{comment=false}),
[[
-- glue goes here
-- BEGIN menu glue
a=1
bee=8
boo=true
c=10000
sh1=-1
sh2=1000000
sh3=2
sh4=false
sh5=true
sh6={
 index=3,
 value="3"
}
sh7=0
-- END menu glue
-- body here
-- BEGIN glued script
@chdk_version 1.4.1
@title Menu param test
-- space between keyword and name not required
@defaulta 1
@parama Item a

-- item with range, hex, octal and dec all allowed
@param bee at with range -10-0x20
@default bee 010
@range bee -10 0x20

-- boolean, leading space
 @param boo Boolean @ param
   @default boo  true
-- default can include any number of = and space
@param   c Option c
@default c = = 10000

@subtitle First subtitle
-- shorthand syntax, basic
#sh1=-1 "'Shorthand' one"
#sh2=1000000 '"Shorthand" two' long
-- space isn't require after description
#sh3=2 "Shorthand 3 range"[0 10]
-- boolean by value
#sh4=false "Shortand 4 boolean"
-- empty subtitle is allowed
@subtitle
-- boolean by keyword
#sh5=1 "Shorthand 5 boolean"bool
-- table
#sh6=3 "Shorthand 6 table" { One Two 3 Four } table
-- enum
#sh7=0 "Shorthand 7 enum" { 1 2 Three 4 Five 6 }

-- something to simulate the body of the script
print('hello world')

-- END glued script
]])
		testlib.assert_eq(h:make_glue_tpl([[
-- glue goes here
   --[!glue:vars]
-- body here
   --[!glue:body]
]],{comment=false, camfile='test.lua'}),
[[
-- glue goes here
-- BEGIN menu glue
a=1
bee=8
boo=true
c=10000
sh1=-1
sh2=1000000
sh3=2
sh4=false
sh5=true
sh6={
 index=3,
 value="3"
}
sh7=0
-- END menu glue
-- body here
-- BEGIN glued script
loadfile("A/CHDK/SCRIPTS/test.lua")()
-- END glued script
]])
		testlib.assert_eq(h:make_glue_tpl([[
-- glue goes here
--[!glue:vars]
-- body here
--[!glue:body]
]],{comment=false,comment_glue=false, camfile='TEST/TEST.LUA'}),
[[
-- glue goes here
a=1
bee=8
boo=true
c=10000
sh1=-1
sh2=1000000
sh3=2
sh4=false
sh5=true
sh6={
 index=3,
 value="3"
}
sh7=0
-- body here
loadfile("A/TEST/TEST.LUA")()
]])
		-- version compat
		h=chdkmenuscript.new_header{text=[=[
--[[
@chdk_version 1.3.1
@title Menu param test
#item1=1 "Item 1"
]]

print('hello world')
]=]}
		testlib.assert_eq(h:make_glue_tpl(nil,{comment=false,comment_glue=false}),[=[
item1=1
require"wrap13"
--[[
@chdk_version 1.3.1
@title Menu param test
#item1=1 "Item 1"
]]

print('hello world')
]=])
		testlib.assert_eq(h:make_glue_tpl(nil,{comment=false,comment_glue=false,load_compat=false}),[=[
item1=1
--[[
@chdk_version 1.3.1
@title Menu param test
#item1=1 "Item 1"
]]

print('hello world')
]=])
		-- version compat, no version
		h=chdkmenuscript.new_header{text=[=[
--[[
@title Menu param test
#item1=1 "Item 1"
]]

print('hello world')
]=]}
		testlib.assert_eq(h:make_glue_tpl(nil,{comment=false,comment_glue=false}),[=[
item1=1
require"wrap13"
--[[
@title Menu param test
#item1=1 "Item 1"
]]

print('hello world')
]=])

		-- some glue template errors
		testlib.assert_thrown(function()
			h:make_glue_tpl([[
--[!glue:vars]
--[!glue:start]
]])
		end,{etype='parse',msg_eq ='line 2: glue:start after glue:vars or glue:body'})

		testlib.assert_thrown(function()
			h:make_glue_tpl([[
--[!glue:body]
]])
		end,{etype='parse',msg_eq ='line 1: glue:body before glue:vars'})

		testlib.assert_thrown(function()
			h:make_glue_tpl([[
--[!glue:vars]
--[!glue:vars]
]])
		end,{etype='parse',msg_eq ='line 2: multiple glue:vars'})

		testlib.assert_thrown(function()
			h:make_glue_tpl([[
--[!glue:vars]
--[!glue:body]
--[!glue:body]
]])
		end,{etype='parse',msg_eq ='line 3: multiple glue:body'})


		-- various warnings and edge cases
		s=[[
-- spaces are optional
@chdk_version1.6
@titleMenu param test2

-- invalid thing that looks like a keyword
@bloop de doop

@param a1 some extra text
@default a1 123 chdk ignores extra text here

@subtitleSpaces optional after subtitle

#sh1=1 "A table" {Option1 Option2} tablescanhavetrailingstuff
-- boolean too
#sh2=0 "A boolean!"boolean
-- out of range ranges
#sh3=-10 "Out of range" [1 11]
]]
		h=chdkmenuscript.new_header{text=s}
		testlib.assert_eq(h.title,'Menu param test2')
		testlib.assert_eq(h.chdk_version,'1.6')
		testlib.assert_eq(h.by_name.a1.val,123)
		testlib.assert_eq(h.by_name.a1.paramtype,'short')
		testlib.assert_eq(h.by_name.subtitle1.val,"Spaces optional after subtitle")
		testlib.assert_eq(h.by_name.subtitle1.paramtype,'subtitle')
		testlib.assert_eq(h.by_name.sh1.val,1)
		testlib.assert_eq(h.by_name.sh1.items[h.by_name.sh1.val],"Option1")
		testlib.assert_eq(h.by_name.sh1.paramtype,'table')
		testlib.assert_eq(h.by_name.sh2.val,false)
		testlib.assert_eq(h.by_name.sh2.paramtype,'bool')
		testlib.assert_eq(h.by_name.sh3.val,-10)
		testlib.assert_eq(h.by_name.sh3.paramtype,'short')
		testlib.assert_teq(h.by_name.sh3.range,{1,11})

		testlib.assert_eq(#w,4)
		testlib.assert_eq(w[1],'unknown @keyword line 6: @bloop de doop\n')
		testlib.assert_eq(w[2],'unexpected content after table line 13: #sh1=1 "A table" {Option1 Option2} tablescanhavetrailingstuff\n')
		testlib.assert_eq(w[3],'unexpected trailing content line 15: #sh2=0 "A boolean!"boolean\n')
		testlib.assert_eq(w[4],'item sh3 value -10 out of range 1 11\n')
		w={}

		-- some errors
		testlib.assert_thrown(function()
			chdkmenuscript.new_header{text=[[
@param
]]
			}
		end,{etype='parse',msg_eq ='failed to parse param line 1: @param'})

		testlib.assert_thrown(function()
			chdkmenuscript.new_header{text=[[
@param a Description
@default a
]]
			}
		end,{etype='parse',msg_eq ='failed to parse param line 2: @default a'})

		testlib.assert_thrown(function()
			chdkmenuscript.new_header{text=[[
@param a Description
@default a 1
@range a 1
]]
			}
		end,{etype='parse',msg_eq ='failed to parse range line 3: @range a 1'})

		testlib.assert_thrown(function()
			chdkmenuscript.new_header{text=[[
@param thing Description
@default thing truthy
]]
			}
		end,{etype='parse',msg_eq ='failed to parse default value line 2: @default thing truthy'})

		testlib.assert_thrown(function()
			chdkmenuscript.new_header{text=[[
#bogus=bogus "Hi"
]]
			}
		end,{etype='parse',msg_eq ='failed to parse value line 1: #bogus=bogus "Hi"'})

		testlib.assert_thrown(function()
			chdkmenuscript.new_header{text=[[
#bogus=1 "Broken range" [ 1 2 }
]]
			}
		end,{etype='parse',msg_eq='failed to parse range line 1: #bogus=1 "Broken range" [ 1 2 }'})

		testlib.assert_thrown(function()
			chdkmenuscript.new_header{text=[[
#bogus=1 "Broken range" [ 1 2 3]
]]
			}
		end,{etype='parse',msg_eq='failed to parse range line 1: #bogus=1 "Broken range" [ 1 2 3]'})

		testlib.assert_thrown(function()
			chdkmenuscript.new_header{text=[[
#bogus=1 "Broken enum" { One Two
]]
			}
		end,{etype='parse',msg_eq='failed to parse enum / table line 1: #bogus=1 "Broken enum" { One Two'})

		testlib.assert_thrown(function()
			chdkmenuscript.new_header{text=[[
#bogus=1 unquoted stuff
]]
			}
		end,{etype='parse',msg_eq='failed to parse description line 1: #bogus=1 unquoted stuff'})
		testlib.assert_eq(#w,0)
	end,
	cleanup=function()
		require'chdkmenuscript'.warnf=util.warnf
	end
},
{
	'anyfs',
	function(self)
		local anyfs=require'anyfs'
		testlib.assert_thrown(function()
				anyfs.readfile('A/bogus.txt')
		end,{etype='ptp',msg_eq='not connected'})
		testlib.assert_thrown(function()
				anyfs.writefile('A/bogus.txt','bogus')
		end,{etype='ptp',msg_eq='not connected'})
		testlib.assert_thrown(function()
				anyfs.writefile('./A/bogus.txt','bogus',{mkdir=false})
		end,{etype='io', errno=errno_vals.ENOENT})
		anyfs.writefile('./A/test.txt','test')
		testlib.assert_eq(anyfs.readfile('./A/test.txt'),'test')
	end,
	setup=function(self)
		-- tests expect not connected error
		if con:is_connected() then
			return false
		end
		if lfs.attributes('A') then
			error('local file/directory ./A exists')
		end
	end,
	cleanup=function(self)
		fsutil.rm_r('A')
	end,
	_data={}
},
{
	'camscript',
	function(self)
		local cfg1 = self._data.cfg1
		local script1 = self._data.script1
		local tpl1 = self._data.tpl1
		local tdir = self._data.tdir
		local oscript = self._data.oscript
		local ocfg = self._data.ocfg
		-- syntax check only
		testlib.assert_cli_ok(('camscript %s'):format(script1),{match='OK'})
		-- syntax, with conf
		testlib.assert_cli_ok(('camscript -quiet -cfg=%s %s'):format(cfg1,script1),{match='OK'})
		-- with menu opts
		testlib.assert_cli_ok(('camscript -savecfg=%s -save=%s %s opt_num=10 opt_enum.value=Three opt_table.value=Maybe'):format(ocfg,oscript,script1))
		testlib.assert_eq(fsutil.readfile(oscript,{bin=true}),[[
-- BEGIN menu glue
-- @chdk_version 1.5.1
-- #opt_num=5 "Number option"
opt_num=10
-- #opt_enum=0 "Enum option" {One 2 Three}
opt_enum=2
-- #opt_table=2 "Table option" {On Off Maybe} table
opt_table={
 index=3,
 value="Maybe"
}
-- END menu glue
-- BEGIN glued script
@chdk_version 1.5.1
#opt_num=5 "Number option"
#opt_enum=0 "Enum option" {One 2 Three}
#opt_table=2 "Table option" {On Off Maybe} table

print(opt_num,opt_enum,opt_table.value)
-- END glued script
]])
		testlib.assert_eq(fsutil.readfile(ocfg,{bin=true}),[[
#opt_num=10
#opt_enum=2
#opt_table=2
]])
		-- with cfg, menu opt override
		testlib.assert_cli_ok(('camscript -quiet -cfg=%s -savecfg=%s -save=%s %s opt_num=11'):format(cfg1,ocfg,oscript,script1))
		testlib.assert_eq(fsutil.readfile(oscript,{bin=true}),[[
-- BEGIN menu glue
-- @chdk_version 1.5.1
-- #opt_num=5 "Number option"
opt_num=11
-- #opt_enum=0 "Enum option" {One 2 Three}
opt_enum=2
-- #opt_table=2 "Table option" {On Off Maybe} table
opt_table={
 index=1,
 value="On"
}
-- END menu glue
-- BEGIN glued script
@chdk_version 1.5.1
#opt_num=5 "Number option"
#opt_enum=0 "Enum option" {One 2 Three}
#opt_table=2 "Table option" {On Off Maybe} table

print(opt_num,opt_enum,opt_table.value)
-- END glued script
]])
		testlib.assert_eq(fsutil.readfile(ocfg,{bin=true}),[[
#opt_num=11
#opt_enum=2
#opt_table=0
]])
		-- with tpl
		testlib.assert_cli_ok(('camscript -quiet -tpl=%s -save=%s %s'):format(tpl1,oscript,script1))
		testlib.assert_eq(fsutil.readfile(oscript,{bin=true}),[[
-- Glue file
-- BEGIN menu glue
-- @chdk_version 1.5.1
-- #opt_num=5 "Number option"
opt_num=5
-- #opt_enum=0 "Enum option" {One 2 Three}
opt_enum=0
-- #opt_table=2 "Table option" {On Off Maybe} table
opt_table={
 index=2,
 value="Off"
}
-- END menu glue
-- Main content
-- BEGIN glued script
@chdk_version 1.5.1
#opt_num=5 "Number option"
#opt_enum=0 "Enum option" {One 2 Three}
#opt_table=2 "Table option" {On Off Maybe} table

print(opt_num,opt_enum,opt_table.value)
-- END glued script
-- The end
]])
		-- with default load
		testlib.assert_cli_ok(('camscript -quiet -load -save=%s %s'):format(oscript,script1))
		testlib.assert_eq(fsutil.readfile(oscript,{bin=true}),[[
-- BEGIN menu glue
-- @chdk_version 1.5.1
-- #opt_num=5 "Number option"
opt_num=5
-- #opt_enum=0 "Enum option" {One 2 Three}
opt_enum=0
-- #opt_table=2 "Table option" {On Off Maybe} table
opt_table={
 index=2,
 value="Off"
}
-- END menu glue
-- BEGIN glued script
loadfile("A/CHDK/SCRIPTS/test.lua")()
-- END glued script
]])
		-- with explicit load
		testlib.assert_cli_ok(('camscript -quiet -load=FOO/bar.lua -save=%s %s'):format(oscript,script1))
		testlib.assert_eq(fsutil.readfile(oscript,{bin=true}),[[
-- BEGIN menu glue
-- @chdk_version 1.5.1
-- #opt_num=5 "Number option"
opt_num=5
-- #opt_enum=0 "Enum option" {One 2 Three}
opt_enum=0
-- #opt_table=2 "Table option" {On Off Maybe} table
opt_table={
 index=2,
 value="Off"
}
-- END menu glue
-- BEGIN glued script
loadfile("A/FOO/bar.lua")()
-- END glued script
]])
		--invalid menu option
		testlib.assert_cli_error(('camscript -quiet %s bogus=bogus'):format(script1),{match='unknown item bogus'})
		-- bad menu item syntax
		testlib.assert_cli_error(('camscript -quiet %s opt_num='):format(script1),{match='malformed menu option opt_num='})
		-- bad value
		testlib.assert_cli_error(('camscript -quiet %s opt_table.value=bogus'):format(script1),{match='item opt_table value bogus not found'})
		-- camera file
		testlib.assert_cli_error('camscript -quiet A/CHDK/SCRIPTS/bogus.lua',{match='not connected'})
		-- camera cfg
		testlib.assert_cli_error(('camscript -quiet -cfg=A/CHDK/DATA/bogus.0 %s'):format(script1),{match='not connected'})
	end,
	setup=function(self)
		-- tests expect not connected error
		if con:is_connected() then
			return false
		end
		local cfg1 = self._data.cfg1
		local script1 = self._data.script1
		local tpl1 = self._data.tpl1
		fsutil.writefile(cfg1,[[
#opt_num=1
#opt_enum=2
#opt_table=0
]],{bin=true})
		fsutil.writefile(script1,[[
@chdk_version 1.5.1
#opt_num=5 "Number option"
#opt_enum=0 "Enum option" {One 2 Three}
#opt_table=2 "Table option" {On Off Maybe} table

print(opt_num,opt_enum,opt_table.value)
]])
		fsutil.writefile(tpl1,[[
-- Glue file
--[!glue:vars]
-- Main content
--[!glue:body]
-- The end
]])
	end,
	cleanup=function(self)
		fsutil.rm_r(self._data.tdir)
	end,
	_data={
		tdir='chdkptp-test-data',
		cfg1='chdkptp-test-data/test.0',
		script1='chdkptp-test-data/test.lua',
		tpl1='chdkptp-test-data/tpl1.lua',
		oscript='chdkptp-test-data/out.lua',
		ocfg='chdkptp-test-data/out.0',
	}
},
-- ptp / eventproc interface, error conditions and other stuff that doesn't require connection
{
	'ptpevp_nocon',
	function()
		-- various ptpevp_call error conditions
		testlib.assert_thrown(
			function()
				con:ptpevp_call()
			end,
			{etype='bad_arg', msg_eq='expected name or args_prep'}
		)
		testlib.assert_thrown(
			function()
				con:ptpevp_call('bogus',{},{})
			end,
			{etype='bad_arg', msg_eq='argument 3: unexpected table'}
		)
		testlib.assert_thrown(
			function()
				con:ptpevp_call(1)
			end,
			{etype='bad_arg', msg_eq='argument 1: expected name string not number'}
		)
		testlib.assert_thrown(
			function()
				con:ptpevp_call('bogus',1,2,true)
			end,
			{etype='bad_arg', msg_eq='argument 4: unexpected type boolean'}
		)
		testlib.assert_thrown(
			function()
				con:ptpevp_call({args_prep='bogus'})
			end,
			{etype='bad_arg', msg_eq='expected args_prep to be lbuf'}
		)
		testlib.assert_thrown(
			function()
				con:ptpevp_call('bogus',{rtype='bogus'})
			end,
			{etype='bad_arg', msg_eq='invalid rtype bogus'}
		)
		testlib.assert_thrown(
			function()
				con:ptpevp_call('bogus',1,2,3)
			end,
			{etype='ptp', ptp_rc=ptp.RC.ERROR_NOT_CONNECTED}
		)
		-- various ptpevp_prepare error conditions
		testlib.assert_thrown(
			function()
				chdku.ptpevp_prepare('bogus',1,2,3,4,5,6,7,8,9,10,11)
			end,
			{etype='bad_arg', msg_eq="max args 10, got 11"}
		)
		testlib.assert_thrown(
			function()
				chdku.ptpevp_prepare(1)
			end,
			{etype='bad_arg', msg_eq="expected name string or lbuf, not number"}
		)
		testlib.assert_thrown(
			function()
				chdku.ptpevp_prepare('bogus',1,'',2)
			end,
			{etype='bad_arg', msg_eq="argument 2: zero length not supported"}
		)
		testlib.assert_thrown(
			function()
				chdku.ptpevp_prepare('bogus',1,false)
			end,
			{etype='bad_arg', msg_eq="argument 2: unsupported type boolean"}
		)
		-- ptpevp_prepare output
		-- no args
		local lb=chdku.ptpevp_prepare('System.Create')
		testlib.assert_eq(lb:len(),22)
		testlib.assert_eq(lb:string(1,14),'System.Create\0')
		testlib.assert_eq(lb:get_i32(14),0)
		testlib.assert_eq(lb:get_i32(18),0)

		local lb=chdku.ptpevp_prepare('Printf','hello %d %s%s\0',4,lbuf.new('world\0'),'\n\0')
		testlib.assert_eq(lb:len(),129)
		testlib.assert_eq(lb:string(1,7),'Printf\0')
		local off=7
		testlib.assert_eq(lb:get_i32(off),4)
		off = off+4
		-- arg 1
		testlib.assert_eq(lb:get_i32(off),4) -- type long
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- value, unused for long
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- 64 bit high word, unused
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- long index, 0
		off = off+4
		testlib.assert_eq(lb:get_i32(off),14) -- long size
		off = off+4
		-- arg 2
		testlib.assert_eq(lb:get_i32(off),2) -- type 32 bit
		off = off+4
		testlib.assert_eq(lb:get_i32(off),4) -- value
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- 64 bit high word, unused
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- long index, unused
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- long size, unused
		off = off+4
		-- arg 3
		testlib.assert_eq(lb:get_i32(off),4) -- type long
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- value, unused for long
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- 64 bit high word, unused
		off = off+4
		testlib.assert_eq(lb:get_i32(off),1) -- long index
		off = off+4
		testlib.assert_eq(lb:get_i32(off),6) -- long size
		off = off+4
		-- arg 4
		testlib.assert_eq(lb:get_i32(off),4) -- type long
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- value, unused for long
		off = off+4
		testlib.assert_eq(lb:get_i32(off),0) -- 64 bit high word, unused
		off = off+4
		testlib.assert_eq(lb:get_i32(off),2) -- long index
		off = off+4
		testlib.assert_eq(lb:get_i32(off),2) -- long size
		off = off+4
		-- num long args
		testlib.assert_eq(lb:get_i32(off),3)
		off = off+4
		-- long arg 1
		testlib.assert_eq(lb:get_i32(off),0) -- long index
		off = off+4
		testlib.assert_eq(lb:string(off+1,off+14),'hello %d %s%s\0') -- long value
		off = off+14
		-- long arg 2
		testlib.assert_eq(lb:get_i32(off),1) -- long index
		off = off+4
		testlib.assert_eq(lb:string(off+1,off+6),'world\0') -- long value
		off = off+6
		-- long arg 3
		testlib.assert_eq(lb:get_i32(off),2) -- long index
		off = off+4
		testlib.assert_eq(lb:string(off+1,off+2),'\n\0') -- long value
		testlib.assert_eq(lb:len(), off + 2)
	end,
	setup=function()
		if con:is_connected() then
			return false
		end
	end,
},
-- ptp_txn error conditions
{
	'ptp_txn_nocon',
	function()
		testlib.assert_thrown(
			function()
				con:ptp_txn()
			end,
			{etype='bad_arg', msg_eq='argument 1: expected opcode number, not nil'}
		)
		testlib.assert_thrown(
			function()
				con:ptp_txn(0x9999,{},{})
			end,
			{etype='bad_arg', msg_eq='argument 2: unexpected table'}
		)
		testlib.assert_thrown(
			function()
				con:ptp_txn(0x9999,false)
			end,
			{etype='bad_arg', msg_eq='argument 1: expected number not boolean:false'}
		)
		testlib.assert_thrown(
			function()
				con:ptp_txn(0x9999,1,"2",'bogus')
			end,
			{etype='bad_arg', msg_eq='argument 3: expected number not string:bogus'}
		)
		testlib.assert_thrown(
			function()
				con:ptp_txn(0x9999,0,{getdata='string',data='bogus'})
			end,
			{etype='bad_arg', msg_eq='getdata and data are mutually exclusive'}
		)
		testlib.assert_thrown(
			function()
				con:ptp_txn(0x9999,0,{getdata='bogus'})
			end,
			{etype='bad_arg', msg_eq='unexpected getdata bogus'}
		)
		testlib.assert_thrown(
			function()
				con:ptp_txn(0x9999,0)
			end,
			{etype='ptp', ptp_rc=ptp.RC.ERROR_NOT_CONNECTED}
		)
	end,
	setup=function()
		if con:is_connected() then
			return false
		end
	end,
},
{
	'ptpcodes',
	function()
		testlib.assert_eq(ptp.OC.GetObjectHandles,4103)
		testlib.assert_eq(ptp.OC_name[4103],'GetObjectHandles')
		testlib.assert_eq(ptp.CANON.OC.CHDK,0x9999)
		testlib.assert_eq(ptp.CANON.OC_name[0x9999],'CHDK')
		testlib.assert_eq(ptp.RC.OK,0x2001)
		testlib.assert_eq(ptp.RC_name[0x2001],"OK")
	end
},
}})

m.tests = tests
return m
