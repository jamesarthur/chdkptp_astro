--[[
 Copyright (C) 2010-2022 <reyalp (at) gmail dot com>

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
get command args of the form -a[=value] -bar[=value] .. [wordarg1] [wordarg2] [wordarg...]
--]]

local argparser = { }

-- utility functions
--[[
return true if s contains characters that would need quoting
]]
function argparser.needs_quote(s)
	return s:match('[%c%s"\'\\]') ~= nil
end
--[[
quote string
]]
function argparser.quote(s)
	-- cli currently doesn't support escaped newlines
	if s:match('[\r\n]') then
		errlib.throw{etype='bad_arg',msg='unsupported charcaters'}
	end
	-- escape backslashes and double quotes, then quote entire string
	return '"'..s:gsub('["\\]',{['\\']='\\\\',['"']='\\"'}) .. '"'
end

function argparser.quote_if_needed(s)
	if argparser.needs_quote(s) then
		return argparser.quote(s)
	end
	return s
end

-- trim leading spaces
function argparser:trimspace(str)
	local s, e = string.find(str,'^[%c%s]*')
	return string.sub(str,e+1)
end
--[[
get a 'word' argument, either a sequence of non-white space characters, or a quoted string
inside " \ is treated as an escape character
return word, end position on success or false, error message
]]
function argparser:get_word(str)
	local result = ''
	local esc = false
	local qchar = false
	local pos = 1
	while pos <= string.len(str) do
		local c = string.sub(str,pos,pos)
		-- in escape, append next character unconditionally
		if esc then
			result = result .. c
			esc = false
		-- inside double quote, start escape and discard backslash
		elseif qchar == '"' and c == '\\' then
			esc = true
		-- character is the current quote char, close quote and discard
		elseif c == qchar then
			qchar = false
		-- not hit a space and not inside a quote, end
		elseif not qchar and string.match(c,"[%c%s]") then
			break
		-- hit a quote and not inside a quote, enter quote and discard
		elseif not qchar and (c == '"' or c == "'") then
			qchar = c
		-- anything else, copy
		else
			result = result .. c
		end
		pos = pos + 1
	end
	if esc then
		return false,"unexpected \\"
	end
	if qchar then
		return false,"unclosed " .. qchar
	end
	return result,pos
end

function argparser:parse_words(str)
	local words={}
	str = self:trimspace(str)
	while string.len(str) > 0 do
		local w,pos = self:get_word(str)
		if not w then
			return false,pos -- pos is error string
		end
		table.insert(words,w)
		str = string.sub(str,pos)
		str = self:trimspace(str)
	end
	return words
end

--[[
parse a command string into switches and word arguments
switches are in the form -swname[=value]
word arguments are anything else
any portion of the string may be quoted with '' or ""
inside "", \ is treated as an escape
on success returns table with args as array elements and switches as named elements
on failure returns false, error
defs defines the valid switches and their default values. Can also define default values of numeric args
TODO enforce switch values, number of args, integrate with help
]]
function argparser:parse(str)
	-- default values
	local results=util.extend_table({},self.defs)
	local words,errmsg=self:parse_words(str)
	if not words then
		return false,errmsg
	end
	for i, w in ipairs(words) do
		-- look for -name
		local s,e,swname=string.find(w,'^-(%a[%w_-]*)')
		-- found a switch
		if s then
			if type(self.defs[swname]) == 'nil' then
				return false,'unknown switch '..swname
			end
			local swval
			-- no value
			if e == string.len(w) then
				swval = true
			elseif string.sub(w,e+1,e+1) == '=' then
				-- note, may be empty string but that's ok
				swval = string.sub(w,e+2)
			else
				return false,"invalid switch value "..string.sub(w,e+1)
			end
			results[swname]=swval
		else
			table.insert(results,w)
		end
	end
	return results
end

-- for comands that want the raw string
argparser.nop = {
	parse=function(self,str)
		return str
	end
}

-- for comands that expect no args
argparser.none = {
	parse=function(self,str)
		if string.len(str) ~= 0 then
			return false,'command takes no arguments'
		end
		return str
	end
}

function argparser.create(defs)
	local r={ defs=defs }
	return util.mt_inherit(r,argparser)
end

argparser_text=util.extend_table({},argparser)

-- overrides
function argparser_text.create(defs)
	local r={ defs=defs }
	return util.mt_inherit(r,argparser_text)
end

--[[
Get a freeform text arg for lua code etc
if first non-whitespace is <, read from file, otherwise pass as is
--]]
function argparser_text:parse(arg)
	local s, e = string.find(arg,'^[%c%s]*<')
	if not s then
		return {text=arg}
	end
	local fn = string.sub(arg,e+1)
	local words,errmsg=self:parse_words(fn)
	if not words then
		return false,errmsg
	end
	if #words ~= 1 then
		return false,'expected exactly one filename'
	end
	return {input=words[1]}
end

return argparser
