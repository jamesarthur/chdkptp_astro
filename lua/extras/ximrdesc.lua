--[[
 Copyright (C) 2021 <reyalp (at) gmail dot com>

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
code for extracting captured ximr data into human readable text
see: https://chdk.setepontos.com/index.php?topic=12788.msg146511#msg146511
--]]

local m = {
	dump_rec_size = 0x310,
}
m.ximr_layer = {
	{'unk1',{'u8',7}},
	{'scale','u8'},
    {'unk2','u32'},
	{'color_type','u16'},
    {'visibility','u16'},
    {'unk3','u16'},
    {'src_y','u16',fmt='%d'},
    {'src_x','u16',fmt='%d'},
    {'src_h','u16',fmt='%d'},
    {'src_w','u16',fmt='%d'},
    {'dst_y','u16',fmt='%d'},
    {'dst_x','u16',fmt='%d'},
    {'enabled','u16'},
    {'marv_sig','u32'},
    {'bitmap','u32'},
    {'opacity','u32'},
    {'color','u32'},
    {'width','u32',fmt='%d'},
    {'height','u32',fmt='%d'},
    {'unk4','u32'},
}
m.dump_rec_header = {
	_align = m.dump_rec_size,
	{'count','u32',fmt='%d'},
	{'tick','u32',fmt='%d'},
	{'displaytype','u32',fmt='%d'},
	{'m_id','u32'},
}
m.ximr_context = {
    {'unk1','u16'},
    {'width1','u16',fmt='%d'},
    {'height1','u16',fmt='%d'},
    {'unk2',{'u16',17}},
    {'output_marv_sig','u32'},
    {'output_buf','u32'},
    {'output_opacitybuf','u32'},
    {'output_color','u32'},
    {'buffer_width','i32',fmt='%d'},
    {'buffer_height','i32',fmt='%d'},
    {'unk3',{'u32',2}},
    {'layers',{m.ximr_layer,8}},
    {'unk4',{'u32',7}},
	{'height2','u16',fmt='%d'},
	{'width2','u16',fmt='%d'},
    {'unk4b',{'u32',16}},
    {'denomx','u8',fmt='%d'},
    {'numerx','u8',fmt='%d'},
    {'denomy','u8',fmt='%d'},
    {'numery','u8',fmt='%d'},
    {'unk5','u32'},
    {'width','u16',fmt='%d'},
    {'height','u16',fmt='%d'},
    {'unk6',{'u32',27}},
}
m.ximr_context_dry52 = {
    {'unk1','u16'},
    {'width1','u16',fmt='%d'},
    {'height1','u16',fmt='%d'},
    {'unk2',{'u16',17}},
    {'output_marv_sig','u32'},
    {'output_buf','u32'},
    {'output_opacitybuf','u32'},
    {'output_color','u32'},
    {'buffer_width','i32',fmt='%d'},
    {'buffer_height','i32',fmt='%d'},
    {'unk3',{'u32',2}},
    {'layers',{m.ximr_layer,8}},
    {'unk4',{'u32',14}},
--[[
    {'unk4',{'u32',7}},
	{'height2','u16',fmt='%d'},
	{'width2','u16',fmt='%d'},
    {'unk4b',{'u32',16}},
--]]
    {'denomx','u8',fmt='%d'},
    {'numerx','u8',fmt='%d'},
    {'denomy','u8',fmt='%d'},
    {'numery','u8',fmt='%d'},
    {'unk5','u32'},
    {'width','u16',fmt='%d'},
    {'height','u16',fmt='%d'},
    {'unk6',{'u32',27}},
}

function m.export(infile,outbase,opts)
	opts = util.extend_table({
		dry_ver = 54, -- all known >52 seems to use the same layout
	},opts)
	if not outbase then
		outbase = fsutil.basename(infile,fsutil.get_ext(infile))
	end
	local context_desc
	if opts.dry_ver == 52 then
		context_desc = m.ximr_context_dry52
		-- note dump rec size *could* change too
	elseif opts.dry_ver > 52 and opts.dry_ver <= 59 then
		context_desc = m.ximr_context
	else
		errlib.throw{etype='bad_arg','unexpected dryos version '..dry_ver}
	end
	local lbu = require'lbufutil'
	local data = lbu.loadfile(infile)
	local num_recs = math.floor(data:len()/m.dump_rec_size)
	for i=0,num_recs - 1 do
		local offset = i*m.dump_rec_size
		local dhdr = lbu.desc_extract(data,m.dump_rec_header,{offset=offset})
		local fname = ('%s-%02d-%08d.txt'):format(outbase,dhdr.count,dhdr.tick)
		printf('%d %s\n',i,fname)
		local fh = fsutil.open_e(fname,'wb')
		util.fprintf(fh,"header:\n")
		lbu.desc_text(data,m.dump_rec_header,
			{
				offset=offset,
				offsets='rel',
				printf=function(fmt,...)
					util.fprintf(fh,fmt,...)
				end,
			})
		-- use seperate prints so offests are relative to struct
		util.fprintf(fh,"\nximr_context:\n")
		lbu.desc_text(data,context_desc,
			{
				offset=offset + 16, -- header size
				offsets='rel',
				printf=function(fmt,...)
					util.fprintf(fh,fmt,...)
				end,
			})
		fh:close()
	end
end
return m
