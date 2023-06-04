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
chdkptp lua module to build camera side scripts with modules inlined
This allows maintaining re-usable modules while packaging them into a
single standalone script for distribution

use --[!inline] after require like
 require'module' --[!inline]
or
 var = require'module' --[!inline]

Any assignment must be on the same line, with no other code.
local is allowed

inlining is applied recursively, so modules loaded inline may have
their own inline requires. Modules are only inlined once, the return
value is stored in package.loaded, so subsequent requires are unchanged
except for a comment.

module content before a line consisting of
--[!inline:module_start]
and after
--[!inline:module_end]

is excluded from inlining
--]]
local m = {}

function m.process_string(instr,opts)
	opts = util.extend_table({
		modpath='.',
		source_name='(unknown)',
		level=0,
		max_level=10,
		seen={},
	},opts)

	if opts.verbose then
		printf('processing %s %d\n',opts.source_name,opts.level)
	end

	if opts.level > opts.max_level then
		error('too many nested requires %s %s',opts.source_name,modname)
	end
	outstr = instr:gsub('([^\r\n]*)require%s*%(?%s*[\'"]([^\'"]+)[\'"]%s*%)?%s*%-%-%[!inline%]',
		function(pfx,modname)
			if opts.seen[modname] then
				if opts.verbose then
					printf('already inlined %s\n',modname)
				end
				return("%srequire'%s' -- previously inlined"):format(pfx,modname)
			end

			opts.seen[modname] = true
			local loadval, assignstr
			local islocal, varname = pfx:match('%s*(local)%s*([%a_][%a%d_]*)%s*=%s*')
			if islocal then
				assignstr = 'local '..varname..'='
			else
				varname = pfx:match('%s*([%a_][%a%d_]*)%s*=%s*')
				if varname then
					assignstr = varname..'='
				else
					assignstr = ';' -- prevent parens around function from being interpreted as call in preceding line
				end
			end
			if varname then
				loadval = varname
			else
				loadval = 'true' -- package.loaded value when no assignment
			end
			local modfile = fsutil.joinpath(opts.modpath,modname..'.lua')
			if opts.verbose then
            	printf('inline %s %s\n',modname,modfile)
			end
			modstr = fsutil.readfile(modfile)
			-- allow trimming headers
			modstr = modstr:gsub('^.-%-%-%[!inline:module_start%]\r?\n?','')
			modstr = modstr:gsub('%-%-%[!inline:module_end%].*$','')
			opts.source_name = modfile
			opts.level = opts.level + 1
			modstr = m.process_string(modstr,opts)
			opts.level = opts.level - 1
			return ([[
%s(function() -- inline %s
%s
end)()
package.loaded['%s']=%s -- end inline %s]]):format(assignstr,modname,modstr,modname,loadval,modname)
		end)
	return outstr
end
function m.process_file(infile_name, outfile_name, opts)
	if infile_name == outfile_name then
		error(('refusing to overwrite input file %s'):format(infile_name))
	end

	local instr = fsutil.readfile(infile_name)
	opts.source_name = infile_name
	outstr = m.process_string(instr,opts)
	fsutil.writefile(outfile_name,outstr,{bin=true})
end

return m

