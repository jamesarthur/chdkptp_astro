--[[
 Copyright (C) 2021-2022 <reyalp (at) gmail dot com>
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
framework for running tests
]]

local m = {
	test_methods = {},
}

local test_methods = m.test_methods

--[[
return a field value from the first test in hierarchy that defines it
--]]
function test_methods:get_prop(name, default)
	if self[name] then
		return self[name]
	end
	if self.parent then
		return self.parent:get_prop(name,default)
	end
	return default
end

--[[
return a table of tests, starting from the top or the root to this test
--]]
function test_methods:get_path_table(top)
	if not self.parent then
		return {self}
	end
	if self == top then
		return {self}
	end
	local t = self.parent:get_path_table()
	table.insert(t,self)
	return t
end

--[[
return a subtest specified by path, either array of names or dot delimited string
path should NOT include self
returns nil if not found
--]]
function test_methods:get_subtest(path)
	if type(path) == 'string' then
		path = util.string_split(path,'.',{plain=true})
	end
	if type(path) ~= 'table' then
		error('expected table')
	end
	local t = self
	for _, name in ipairs(path) do
		if not t.subtests then
			return
		end
		t = t.subtests.byname[name]
		if not t then
			return
		end
	end
	return t
end

function test_methods:msg(level,fmt,...)
	if self:get_prop(verbose,1) >= level then
		util.printf(fmt,...)
	end
end

function test_methods:infomsg(fmt,...)
	self:msg(1,self.path..': '..fmt,...)
end

function test_methods:ensure_connected(opts)
	self.step_opts_run.setup.fail_abort_all = true
	if con:is_connected() then
		return
	end
	local devspec = opts.connect_dev
	local cmd = 'connect'
	if devspec then
		cmd = cmd .. ' ' .. devspec
	end
	m.assert_cli_ok(cmd,{echo=true,echo_res=true})

	self.step_opts_run.setup.fail_abort_all = false
end

-- for easy test declaration
-- setup=testlib.setup_ensure_connected
m.setup_ensure_connected = test_methods.ensure_connected

function test_methods:ensure_connected_rec(opts)
	self:ensure_connected(opts)
	if not con:execwait([[return get_mode()]]) then
		m.assert_cli_ok('rec',{echo=true,echo_res=true})
		sys.sleep(250)
	end
end
m.setup_ensure_connected_rec = test_methods.ensure_connected_rec

function test_methods:ensure_connected_play(opts)
	self:ensure_connected(opts)
	if con:execwait([[return get_mode()]]) then
		m.assert_cli_ok('play',{echo=true,echo_res=true})
		sys.sleep(250)
	end
end
m.setup_ensure_connected_play = test_methods.ensure_connected_play

function test_methods:should_skip(opts)
	return opts and (util.in_table(opts.skip_names,self.name) or util.in_table(opts.skip_paths,self.path))
end

function test_methods:do_cleanup_substeps()
	local failmsgs = {}
	for i, substep in ipairs(self.cleanup_substeps) do
		local status,msg = xpcall(substep,errutil.format_traceback,self)
		if not status then
			table.insert(failmsgs,('substep %d: %s\n'):format(i,tostring(msg)))
		end
	end
	if #failmsgs > 0 then
		errlib.throw{etype='cleanup_substep',msg=table.concat(failmsgs)}
	end
end

function test_methods:do_step(step,opts)
	-- is test excluded by opts?
	if step == 'setup' and self:should_skip(opts) then
		self:set_skipped()
		return true
	end
	-- all steps are optional
	if not self[step] then
		return true
	end
	local status,fstatus = xpcall(self[step],errutil.format_traceback,self,opts)
	if step == 'setup' and status and fstatus == false then
		self:set_skipped()
		return true
	end
	table.insert(self.results,{pass=status,step=step,msg=fstatus})
	if not status then
		self.failed = true
		-- steps or runtime options can signal failures end run
		-- TODO could match particular error type
		if self.step_opts[step].fail_abort_all then
			self.abort_all = true
		end
		if self.step_opts[step].fail_abort_group then
			self.abort_group = true
		end
	end
	return status
end

function test_methods:do_subtests(opts)
	if not opts then
		opts = {}
	end
	if self.subtests then
		for _,test in ipairs(self.subtests.list) do
			test:do_test(opts)
			if test.failed then
				self.subs_failed = self.subs_failed + 1
				self.subs_total_failed = self.subs_total_failed + 1
			end
			if test.subs_total_failed > 0 then
				self.subs_total_failed = self.subs_total_failed + test.subs_total_failed
			end
			if test.subs_total_skipped > 0 then
				self.subs_total_skipped = self.subs_total_skipped + test.subs_total_skipped
			end
			if test.skipped then
				self.subs_skipped = self.subs_skipped + 1
				self.subs_total_skipped = self.subs_total_skipped + 1
			else
				self.subs_run = self.subs_run + 1
				self.subs_total_run = self.subs_total_run + 1 + test.subs_total_run
			end
			-- setup or test can set abort_all to stop
			if test.abort_all then
				self.abort_all = true
				break
			end
			if test.abort_group then
				break
			end
		end
	end
end

function test_methods:do_report()
	for _, r in ipairs(self.results) do
		if not r.pass then
			self:infomsg('failed %s: %s\n',r.step,tostring(r.msg))
		end
	end
	if self.skipped then
		self:infomsg('skipped\n')
	else
		if self.subs_total_run > 0 then
			if self.subs_total_failed > 0 then
				self:infomsg('subtests run %d failed %d skipped %d\n',
								self.subs_total_run,
								self.subs_total_failed,
								self.subs_total_skipped)
			else
				self:infomsg('subtests passed %d skipped %d\n',
								self.subs_total_run,
								self.subs_total_skipped)
			end
		elseif not self.failed then
			self:infomsg('passed\n')
		end
	end
end

function test_methods:reset_results()
	self.results = {}
	self.failed = false
	self.skipped = false
	self.subs_failed = 0
	self.subs_run = 0
	self.subs_skipped = 0
	self.subs_total_failed = 0
	self.subs_total_run = 0
	self.subs_total_skipped = 0
	self.abort_all = false
	self.abort_group = false
	self.step_opts_run = util.extend_table({},self.step_opts)
end

function test_methods:set_skipped()
	self.skipped = true
	table.insert(self.results,{pass=true,skipped=true,step=step,msg='skipped'})
end

function test_methods:do_test(opts)
	if not opts then
		opts = {}
	end
	self:infomsg('start\n')
	self:reset_results()

	local status = self:do_step('setup',opts)
	if not self.skipped then
		-- skip if setup step fails
		if status then
			self:do_step('run',opts)
			self:do_subtests(opts)
		end
		-- cleanup runs if setup failed, may have got part through
		-- but not if skipped
		-- TODO may want a skip on fail option (but tests can also check failed)
		self:do_step('cleanup',opts)
	end
	self:do_report()
	return self.failed
end

function test_methods:do_subtest_recursive(tests,opts)
	local t = table.remove(tests,1)
	if #tests == 0 then
		t:do_test(opts)
		return
	end
	self:infomsg('setup\n')
	self:reset_results()
	local status = self:do_step('setup')
	-- skip if setup step fails
	if not self.skipped then
		if status then
			t:do_subtest_recursive(tests,opts)
		end
		-- cleanup runs if setup failed, may have got part through
		-- but not if skipped
		-- TODO may want a skip on fail option (but tests can also check failed)
		self:do_step('cleanup')
	end
	self:do_report()
end

--[[
run subtest specified by path, including setup / cleanup for all parent tests
note, starts from this test, not the absolute root
--]]
function test_methods:do_subtest(path,opts)
	local subtest=self:get_subtest(path)
	if not subtest then
		error('test not found: '..tostring(path))
	end
	local tests = subtest:get_path_table(self)
	local t = table.remove(tests,1)
	t:do_subtest_recursive(tests,opts)
end

function test_methods:add_subtests(test_defs)
	if not self.subtests then
		self.subtests = {
			list = {},
			byname = {},
		}
	end
	for i,test_def in ipairs(test_defs) do
		local test = m.new_test(test_def,self)

		if self.subtests.byname[test.name] then
			error('duplicate test name: '..tostring(test.name))
		end
		table.insert(self.subtests.list,test)
		self.subtests.byname[test.name] = test
	end
end

--[[
m.new_test({
	string, -- name
	function|table, -- test function or array of subtest definitions

	-- optional, verify / configure any prerequisites.
	-- return false to skip (i.e. unsupported feature)
	setup=function(self)
	end,
	-- cleanup, optional
	cleanup=function(self)
	end,
	-- optional
	step_opts={
		setup: {},
		run: {},
		cleanup: {},
	}
},[parent])
]]
function m.new_test(test_def,parent)
	local name = test_def[1]
	if not name then
		error('test requires name')
	end

	local action = test_def[2]

	local t=util.extend_table_multi({
		name=name,
		step_opts={
			setup={},
			run={},
			cleanup={},
		}
	},{test_methods,test_def})
	t[1] = nil
	t[2] = nil
	if parent then
		t.parent = parent
		t.path = parent.path ..'.' .. t.name
	else
		t.path = t.name
	end
	if type(action) == 'function' then
		t.run = action
	elseif type(action) == 'table' then
		t:add_subtests(action)
	else
		error('test requires function or subtest array')
	end
	-- cleanup generally should run all steps, and fail at the end if any failed
	if type(t.cleanup) == 'table' then
		t.cleanup_substeps = t.cleanup
		t.cleanup = t.do_cleanup_substeps
	end
	return t
end

-- utility functions
-- create a file with the specified content
function m.makefile(path,content)
	fsutil.mkdir_parent(path)
	fsutil.writefile(path,content,{bin=true})
end

-- read contents of file to string, asserting on errors
function m.readfile(path)
	assert(lfs.attributes(path,'mode') == 'file')
	local content=fsutil.readfile(path,{bin=true})
	assert(content)
	return content
end

--[[
call f and verify that the expected error is thrown
match may be
nil,false: any error
string: pattern match for error() string
table: match for errlib error or error string
{
	str_match -- equivalent to string
	str_eq -- string exactly equal
	etype:string -- expected etype, nil for any
	msg_match:string -- pattern matching expected message
	msg_eq:string -- string exactly equal to expected message
	errno:number -- expected errno field
	ptp_rc:number -- expected PTP error code
}

--]]
function m.assert_thrown(f,match)
	local status,err=pcall(f)
	if status then
		error('expected error',2)
	end
	if not match then
		return
	end
	if type(match) == 'string' then
		if type(err) ~= 'string' then
			error('expected error string not '..type(err)..' "'..tostring(err)..'"',2)
		end
		if not string.match(err,match) then
			error('expected msg matching "'..tostring(match)..'" not "'..tostring(err)..'"',2)
		end
		return
	end
	if type(match) ~= 'table' then
		error('match must be false, string or table',2)
	end

	if (match.str_match or match.str_eq) then
		if type(err) ~= 'string' then
			error('expected error string not '..type(err)..' "'..tostring(err)..'"',2)
		end
		if match.str_match and match.str_match:match(err) then
			error('expected msg matching "'..tostring(match.str_match)..'" not "'..tostring(err)..'"',2)
		end
		if match.str_eq and match.str_eq ~= err then
			error('expected msg equal "'..tostring(match.str_eq)..'" not "'..tostring(err)..'"',2)
		end
		return
	end

	if type(err) ~= 'table' then
		error('expected errlib object, not '..type(err)..' "'..tostring(err)..'"',2)
	end

	if match.etype then
		if match.etype ~= err.etype then
			error('expected etype="'..tostring(match.etype).. '" not "'..tostring(err.etype)..'" msg "'..tostring(err.msg)..'"',2)
		end
	end
	if match.msg_match then
		if not err.msg then
			error('expected msg',2)
		end
		if not string.match(err.msg,match.msg_match) then
			error('expected msg matching "'..tostring(match.msg_match)..'" not "'..tostring(err.msg)..'"',2)
		end
	end
	if match.msg_eq then
		if not err.msg then
			error('expected msg',2)
		end
		if err.msg ~= match.msg_eq then
			error('expected msg "'..tostring(match.msg_eq)..'" not "'..tostring(err.msg)..'"',2)
		end
	end
	if match.errno_eq then
		if not err.errno then
			error('expected errno',2)
		end
		if err.errno ~= match.errno_eq then
			error('expected errno "'..tostring(match.errno_eq)..'" not "'..tostring(err.errno)..'"',2)
		end
	end
	if match.ptp_rc then
		if not err.ptp_rc then
			error('expected ptp_rc',2)
		end
		if err.ptp_rc ~= match.ptp_rc then
			error('expected ptp_rc "'..tostring(match.ptp_rc)..'" not "'..tostring(err.ptp_rc)..'"',2)
		end
	end
end

--[[
assert v1 == v2, including values in error output
for simple values
]]
function m.assert_eq(v1,v2,level)
	if v1 == v2 then
		return
	end
	if not level then
		level = 2
	end
	-- TODO truncate / ellipsis very long strings?
	error('expected "'..tostring(v1) .. '" == "' .. tostring(v2)..'"',level)
end

--[[
assert v1 == v2, including values in error output
as above, but using compare_values and serialize, mainly for tables
]]
function m.assert_teq(v1,v2,level)
	local sopts={
		err_type=false, -- bad type, e.g. function, userdata
		err_cycle=false, -- cyclic references
		pretty=true, -- indents and newlines
		fix_bignum=false,
		forceint=false, -- convert numbers to integer, by rounding
	}
	if util.compare_values(v1,v2) then
		return
	end
	if not level then
		level = 2
	end
	error('expected '..util.serialize(v1,sopts) .. ' == ' .. util.serialize(v2,sopts),level)
end

-- assert file contents are identical
function m.assert_file_eq(path1,path2)
	local mode=lfs.attributes(path1,'mode')
	assert(mode == lfs.attributes(path2,'mode'))
	if mode ~= 'file' then
		return
	end
	assert(m.readfile(path1)==m.readfile(path2))
end

-- assert cli returned error, optionally matching string
-- returns error message if passed
function m.assert_cli_error(cmd,opts)
	opts = util.extend_table({
		level=2,
		match=false,
		eq=false,
		echo=false, -- TODO module or test level setting for debug
	},opts)
	if opts.echo then
		printf("cli: %s\n",cmd)
	end
	local status,err=cli:execute(cmd)
	if not status then
		if opts.match or opts.eq then
			if not err then
				error('expected error message',opts.level)
			end
			if type(err) == 'table' and err.etype then
				err=tostring(err)
			elseif type(err) ~= 'string' then
				error('expected error object or string',opts.level)
			end
			if opts.match and not err:match(opts.match) then
				error('error:\n"'..err..'"\ndoes not match:\n"'..tostring(opts.match)..'"\n',opts.level)
			end
			if opts.eq and err ~= opts.eq then
				error('error:\n"'..err..'"\nnot equal:\n"'..tostring(opts.eq)..'"\n',opts.level)
			end
		end
		return err
	end
	error('command succeeded when expected to fail',opts.level)
end

-- assert cli returned success, optionally matching output
-- returns output on success
function m.assert_cli_ok(cmd,opts)
	opts = util.extend_table({
		level=2,
		match=false,
		echo=false, -- TODO module or test level setting for debug
		echo_res=false,
	},opts)
	if opts.echo then
		printf("cli: %s\n",cmd)
	end
	local status,err=cli:execute(cmd)
	if not status then
		error(err,opts.level)
	end
	if opts.match then
		if not err then
			error('expected output',opts.level)
		end
		err=tostring(err)
		if type(err) ~= 'string' then
			error('output convertable to string',opts.level)
		end
		if not err:match(opts.match) then
			error('output:\n"'..err..'"\ndoes not match:\n"'..tostring(opts.match)..'"\n',opts.level)
		end
	end
	if opts.echo_res then
		cli:print_status(true,err)
	end
	return err
end

return m
