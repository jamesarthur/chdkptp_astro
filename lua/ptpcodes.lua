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
--]]
--[[
module for PTP name / code mappings
]]
local m={
	vendor_ext_ids = {
		EASTMAN_KODAK = 0x00000001,
		SEIKO_EPSON = 0x00000002,
		AGILENT = 0x00000003,
		POLAROID = 0x00000004,
		AGFA_GEVAERT = 0x00000005,
		MICROSOFT = 0x00000006, -- also used for MTP
		EQUINOX	= 0x00000007,
		VIEWQUEST = 0x00000008,
		STMICROELECTRONICS = 0x00000009,
		NIKON = 0x0000000A,
		CANON = 0x0000000B,
		FOTONATION = 0x0000000C,
		PENTAX = 0x0000000D,
		FUJI = 0x0000000E,
		NDD_MEDICAL_TECHNOLOGIES = 0x00000012,
		SAMSUNG	= 0x0000001a,
		PARROT = 0x0000001b,
		PANASONIC = 0x0000001c,
		SONY = 0x00000011, -- non-standard
		MTP = 0xffffffff, -- supposedly used by some MTP
	},
	-- standard code lists (not including MTP OPC)
	codetypes = {
		'RC', -- response
		'OC', -- operation
		'EC', -- event
		'OFC', -- object format
		'DPC', -- device property
	},
	devinfo_code_map = {
		{cid='OC',desc='Operations Supported', devid='OperationsSupported'},
		{cid='EC',desc='Events Supported', devid='EventsSupported'},
		{cid='OFC',desc='Image Formats Supported', devid='ImageFormats'},
		{cid='OFC',desc='Capture Formats Supported', devid='CaptureFormats'},
		{cid='DPC',desc='Device Properties Supported', devid='DevicePropertiesSupported'},
	},
	CHDK={
		CMD_name = {
			[0]='Version',
			'GetMemory',
			'SetMemory',
			'CallFunction',
			'TempData',
			'UploadFile',
			'DownloadFile',
			'ExecuteScript',
			'ScriptStatus',
			'ScriptSupport',
			'ReadScriptMsg',
			'WriteScriptMsg',
			'GetDisplayData',
			'RemoteCaptureIsReady',
			'RemoteCaptureGetData',
		},
	},
}

m.vendor_ext_id_names = util.flip_table(m.vendor_ext_ids)
m.CHDK.CMD = util.flip_table(m.CHDK.CMD_name)

function m.vendor_ext_id_desc(id)
	id = tonumber(id)
	if not id then
		errlib.throw{etype='bad_arg',msg='expected number id'}
	end
	local name = m.vendor_ext_id_names[id]
	if not name then
		return ('0x%x (unknown)'):format(id)
	end
	if id == 6 then
		return ('0x%x (MICROSOFT / MTP)'):format(id)
	end
	return ('0x%x (%s)'):format(id,name)
end

--[[
return string name and group ID for code in groups specified by groups
codetype is one of 'OC', 'EC', 'OFC', 'DPC' or 'RC'
code is numeric code ID
returns name, group id if found, otherwise false
]]

function m.get_code_info(codetype, code, groups)
	if not groups then
		groups = {'STD'}
	elseif type(groups) == 'string' then
		groups = {groups}
	end
	for _, gname in ipairs(groups) do
		local name = m[gname][codetype..'_name'][code]
		if name then
			return name, gname
		end
	end
	return false
end

--[[
return a string describing code
code = numeric code value
name = name, or nil
gname = group of code, or nil for standard
]]
function m.fmt_code_desc(code, name, gname)
	if name then
		if gname and gname ~= 'STD' then
			return ('0x%04x %s.%s'):format(code,gname,name)
		end
		return ('0x%04x %s'):format(code,name)
	elseif tonumber(code) then
		return ('0x%04x'):format(code)
	else
		return ('(invalid:%s)'):format(tostring(code))
	end
end

function m.get_code_desc(codetype, code, groups)
	return m.fmt_code_desc(code,m.get_code_info(codetype,code,groups))
end

--[[
return id of named code specified like [GROUP.]CODETYPE.CODE, or nil
]]
function m.get_code_by_name(name)
	return util.table_pathstr_get(m,name)
end

m.groups = chdk.get_ptp_code_groups()
for id,gdesc in pairs(m.groups) do
	local codes=chdk.get_ptp_codes(id)
	-- all available as m.group....
	m[id] = codes
	-- code to name mappings
	for _,v in ipairs(m.codetypes) do
		m[id][v..'_name'] = util.flip_table(m[id][v])
	end
	-- special for MTP OPCs
	if id == 'MTP' then
		m[id]['OPC_name'] = util.flip_table(m[id]['OPC'])
	else -- allows OPCs to be treated uniformly
		m['OPC'] = {}
		m['OPC_name'] = {}
	end

	-- standard codes accessible as m.OC.SomeOperationCode
	if id == 'STD' then
		util.extend_table(m,m[id])
	end
end

return m
