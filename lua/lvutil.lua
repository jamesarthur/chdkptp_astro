--[[
 Copyright (C) 2010-2021 <reyalp (at) gmail dot com>
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
module for handling live view frames and dumps
]]

local histoutil=require'histoutil'
local m = {
	LVDUMP_VER_MAJOR=1,
	LVDUMP_VER_MINOR=0,
	LVDUMP_HEADER_SIZE=16, -- chlv + ver header size + ver major + ver minor
}

--[[
arrays describing live protocol fields for wrappers
all assumed to be 32 bit signed ints for the moment, so index - 1 * 4 = offset
_map maps name to offset
v21 for compatibility with previous version
]]
m.live_fields_v21={
	'version_major',
	'version_minor',
	'lcd_aspect_ratio',
	'palette_type',
	'palette_data_start',
	'vp_desc_start',
	'bm_desc_start',
}

m.live_fields={
	'version_major',
	'version_minor',
	'lcd_aspect_ratio',
	'palette_type',
	'palette_data_start',
	'vp_desc_start',
	'bm_desc_start',
	'bmo_desc_start',
}

m.live_fb_desc_fields={
	'fb_type',
	'data_start',
	'buffer_width',

	'visible_width',
	'visible_height',

	'margin_left',
	'margin_top',
	'margin_right',
	'margin_bot',
}

m.live_fb_names_v21={
	'vp',
	'bm',
}

m.live_fb_names={
	'vp',
	'bm',
	'bmo',
}

-- frame type info
-- note "pixel" in bpp counted by Y values for YUV
m.live_fb_types={
	[0]={
 		-- LV_FB_YUV8     8 bit per element UYVYYY, used for live view
		chdk_name='LV_FB_YUV8',
		format='yuv411',
		desc='8 bit per element UYVYYY, used for live view before Digic 6',
		bpp=12,
		block_bytes=6,
	},
	[1]={
		-- LV_FB_PAL8     8 bit paletted, used for pre-digic 6 bitmap overlay
		chdk_name='LV_FB_PAL8',
		format='indexed',
		desc='8 bit paletted, pre-digic 6 bitmap overlay',
		bpp=8,
		block_bytes=1,
	},
	[2]={
		-- LV_FB_YUV8B    8 bit per element UYVY, used for live view and overlay on Digic 6/7
		chdk_name='LV_FB_YUV8B',
		format='yuv422',
		desc='8 bit per element UYVY, live view and overlay on Digic 6 and later',
		bpp=16,
		block_bytes=4,
	},
	[3]={
		-- LV_FB_YUV8C    8 bit per element UYVY, used for alternate Digic 6 live view
		chdk_name='LV_FB_YUV8C',
		format='yuv422',
		desc='8 bit per element UYVY, alternate (unused) live view on Digic 6 and later',
		bpp=16,
		block_bytes=4,
	},
	[4]={
		-- LV_FB_OPACITY8 8 bit opacity / alpha buffer
		chdk_name='LV_FB_OPACITY8',
		format='grayscale',
		desc='8 bit opacity / alpha buffer',
		bpp=8,
		block_bytes=1,
	},
}

-- values of the lcd_aspect_ratio field
m.aspect_ratios = {
	[0]=4/3,
	16/9,
	3/2,
}

m.aspect_ratio_names = {
	[0]="4:3",
	"16:9",
	"3:2",
}

m.live_frame_map={}
m.live_frame_map_v21={}
m.live_fb_desc_map={}

--[[
init name->offset mapping
]]
local function live_init_maps()
	for i,name in ipairs(m.live_fields) do
		m.live_frame_map[name] = (i-1)*4
	end
	for i,name in ipairs(m.live_fields_v21) do
		m.live_frame_map_v21[name] = (i-1)*4
	end
	for i,name in ipairs(m.live_fb_desc_fields) do
		m.live_fb_desc_map[name] = (i-1)*4
	end
end
live_init_maps()

local live_wrapper_meta={
	__index=function(t,key)
		-- rawget because frame may be nil, would recursively call index method
		local frame = rawget(t,'_frame')
		if not frame then
			return nil
		end
		local off = t._field_map[key]
		if off then
			return frame:get_i32(off)
		end
	end
}

local live_wrapper_methods={}
function live_wrapper_methods:clear_frame()
	self._frame = nil
	self._field_names = nil
	self._field_map = nil
	self._fb_field_names = nil
	self._fb_field_map = nil
	self._fb_names = nil
	for i,fb in ipairs(m.live_fb_names) do
		self[fb] = nil
	end
end
function live_wrapper_methods:set_frame(frame)
	-- no frame, reset to uninitialized
	if not frame then
		self:clear_frame()
		return
	end
	local new_major = frame:get_i32(0)
	local new_minor = frame:get_i32(4)
	if new_major < 2 then
		self:clear_frame()
		errlib.throw{
			etype='badversion',
			msg=string.format('incompatible live view protocol %s.%s',tostring(new_major),tostring(new_minor))
		}
	end

	-- check for version change, if not just replace frame data
	if self.version_major == new_major and self.version_minor == new_minor then
		self._frame = frame
		for i,fb in ipairs(self._fb_names) do
			if self[fb] then
				self[fb]:on_set_frame()
			end
		end
		return
	end
	-- if changing version make sure all old values/wrappers cleared
	self:clear_frame()
	self._frame = frame

	if new_major == 2 and new_minor < 2 then
		self._field_names = m.live_fields_v21
		self._field_map = m.live_frame_map_v21
		self._fb_names= m.live_fb_names_v21
	else
		self._field_names = m.live_fields
		self._field_map = m.live_frame_map
		self._fb_names = m.live_fb_names
	end

	-- fb desc fields don't currently vary by version
	self._fb_field_names = m.live_fb_desc_fields
	self._fb_field_map = m.live_fb_desc_map

	for i,fb in ipairs(self._fb_names) do
		if self[fb..'_desc_start'] ~= 0 then
			self[fb] = m.live_fb_desc_wrap(self,fb)
		end
	end
end
function live_wrapper_methods:has_vp()
	if not self._frame then
		return false
	end
	return (self.vp.data_start ~= 0)
end
function live_wrapper_methods:has_bm()
	if not self._frame then
		return false
	end
	return (self.bm.data_start ~= 0)
end
--[[
start lvdump to filname
initializes state and writes header
]]
function live_wrapper_methods:dump_start(filename)
	if not filename then
		filename = string.format('chdk_%x_%s.lvdump',tostring(con.condev.product_id),os.date('%Y%m%d_%H%M%S'))
	end
	self.dump_fh = fsutil.open_e(filename,"wb")

	-- used to write the size field of each frame
	self.dump_sz_buf = lbuf.new(4)

	-- header (magic, size of following data, version major, version minor)
	-- TODO this is ugly
	self.dump_fh:write('chlv') -- magic
	self.dump_sz_buf:set_u32(0,8) -- header size (version major, minor)
	self.dump_sz_buf:fwrite(self.dump_fh)
	self.dump_sz_buf:set_u32(0,m.LVDUMP_VER_MAJOR)
	self.dump_sz_buf:fwrite(self.dump_fh)
	self.dump_sz_buf:set_u32(0,m.LVDUMP_VER_MINOR)
	self.dump_sz_buf:fwrite(self.dump_fh)

	self.dump_size = m.LVDUMP_HEADER_SIZE

	self.dump_fn = filename
end
--[[
dump current frame, set with set_frame to dump initialized with dump_start
]]
function live_wrapper_methods:dump_frame()
	if not self.dump_fh then
		errlib.throw{ etype='bad_arg', msg='file not opened' }
	end
	if not self._frame then
		errlib.throw{ etype='bad_arg', msg='no frame' }
	end

	self.dump_sz_buf:set_u32(0,self._frame:len())
	self.dump_sz_buf:fwrite(self.dump_fh)
	self._frame:fwrite(self.dump_fh)
	self.dump_size = self.dump_size + self._frame:len() + 4
end
--[[
end lvdump
]]
function live_wrapper_methods:dump_end()
	if self.dump_fh then
		self.dump_fh:close()
		self.dump_fh=nil
	end
end
--[[
read a record from an lvdump file
optionally reusing lbuf 'lb'
]]
function live_wrapper_methods:replay_read_rec(lb)
	if not self.replay_recsize:fread(self.replay_fh) then
		errlib.throw{ etype='io', msg='at eof' }
	end
	local len = self.replay_recsize:get_u32()
	if self.replay_fh:seek() + len > self.replay_size then
		errlib.throw{ etype='io', msg='record size outside file' }
	end
	if not lb or lb:len() ~= len then
		lb = lbuf.new(len)
	end
	lb:fread(self.replay_fh)
	return lb
end
--[[
initialize replay from an lvdump file
opens file and parses header, does not load a frame
]]
function live_wrapper_methods:replay_load(filename)
	if self.replay_fh then
		errlib.throw{ etype='bad_arg', msg='replay already loaded' }
	end
	self.replay_fh = fsutil.open_e(filename,"rb")
	self.replay_size = self.replay_fh:seek('end')
	self.replay_fh:seek('set')

	if self.replay_size < m.LVDUMP_HEADER_SIZE then
		errlib.throw{ etype='file_format', msg='size < header' }
	end

	self.replay_fn = filename
	local magic = self.replay_fh:read(4)
	if magic ~= 'chlv' then
		errlib.throw{ etype='file_format', msg='unrecognized file' }
	end
	self.replay_recsize = lbuf.new(4)

	local header = self:replay_read_rec()

	if not header then
		errlib.throw{ etype='file_format', msg='failed to read header' }
	end
	self.replay_ver_major=header:get_u32()
	self.replay_ver_minor=header:get_u32(4)

	if self.replay_ver_major ~= m.LVDUMP_VER_MAJOR then
		errlib.throw{ etype='bad_version', msg=string.format("incompatible version %d\n",self.replay_ver_major) }
	end
	self.replay_pos = 0
end
--[[
read a single frame from lvdump and set it as the current frame
]]
function live_wrapper_methods:replay_frame()
	self:set_frame(self:replay_read_rec(self._frame))
	self.replay_pos = self.replay_pos + 1
end
--[[
close lvdump file and clear replay state
]]
function live_wrapper_methods:replay_end()
	if self.replay_fh then
		self.replay_fh:close()
	end
	self.replay_size = nil
	self.replay_fh = nil
	self.replay_fn = nil
	self.replay_pos = nil
	self.replay_frame_count = nil
end
--[[
returns true if the current replay is at EOF
throws if no replay currently active
]]
function live_wrapper_methods:replay_eof()
	if not self.replay_fh then
		errlib.throw{ etype='bad_arg', msg='replay not loaded' }
	end
	return self.replay_fh:seek() == self.replay_size
end
--[[
reset current replay to start, as if replay_load had been called, before first replay_frame call
does not reset current frame
]]
function live_wrapper_methods:replay_restart()
	if not self.replay_fh then
		errlib.throw{ etype='bad_arg', msg='replay not loaded' }
	end
	self.replay_fh:seek('set',m.LVDUMP_HEADER_SIZE)
	self.replay_pos = 0
end
--[
-- skip forward by 'frames' frames, or to EOF
-- returns actual number of frames skipped
-- NOTE EOF corresponds to the file pointer being at EOF, *past* the final frame
--]]
function live_wrapper_methods:replay_skip(frames)
	if not self.replay_fh then
		errlib.throw{ etype='bad_arg', msg='replay not loaded' }
	end
	-- frames not specified = EOF
	-- actual frames guaranteed to be less than file byte size
	if not frames then
		frames = self.replay_size
	end
	if frames < 0 then
		errlib.throw{ etype='bad_arg', msg='invalid skip count' }
	end
	if frames == 0 then
		return 0
	end
	local newpos = self.replay_pos + frames
	local skipped = 0
	while self.replay_pos < newpos do
		if self:replay_eof() then
			-- cache frame count if at eof
			self.replay_frame_count = self.replay_pos
			return skipped
		end
		-- EOF inside size record is error
		if not self.replay_recsize:fread(self.replay_fh) then
			errlib.throw{ etype='io', msg='at eof' }
		end
		local len = self.replay_recsize:get_u32()
		-- incomplete record is error
		if self.replay_fh:seek() + len > self.replay_size then
			errlib.throw{ etype='io', msg='record size outside file' }
		end
		self.replay_fh:seek('cur',len)
		self.replay_pos = self.replay_pos + 1
		skipped = skipped + 1
	end
	return skipped
end
--[[
-- skip to an arbitrary frame in the replay, similar to file seek
-- out of bounds values care clamped to start or EOF
-- 'end', 0 sets to EOF, after the final frame. Use 'end',-1 to select final frame
--]]
function live_wrapper_methods:replay_seek(whence,frames)
	if not self.replay_fh then
		errlib.throw{ etype='bad_arg', msg='replay not loaded' }
	end
	if whence == 'cur' then
		if frames >= 0 then
			self:replay_skip(frames)
		else
			local n = self.replay_pos + frames
			self:replay_restart()
			if n > 0 then
				self:replay_skip(n)
			end
		end
		return
	end
	if whence == 'set' then
		if frames < 0 then
			errlib.throw{ etype='bad_arg', msg='negative offset not allowed with set' }
		end
		self:replay_restart()
		self:replay_skip(frames)
		return
	end
	if whence == 'end' then
		if frames > 0 then
			errlib.throw{ etype='bad_arg', msg='positive offset not allowed with end' }
		end
		self:replay_skip()
		if frames == 0 then
			return
		end
		local n = self.replay_pos + frames
		self:replay_restart()
		if n > 0 then
			self:replay_skip(n)
		end
	else
		errlib.throw{ etype='bad_arg', msg=string.format('invalid whence %s',tostring(whence)) }
	end
end
--[[
get number of frames in this replay
note, this traverses the entire file on the first call
]]
function live_wrapper_methods:replay_get_frame_count()
	if self.replay_frame_count then
		return self.replay_frame_count
	end
	if not self.replay_fh then
		errlib.throw{ etype='bad_arg', msg='replay not loaded' }
	end
	local file_pos = self.replay_fh:seek()
	local frame_pos = self.replay_pos
	-- stores frame count on eof
	self:replay_skip()
	-- restore positions instead of reading through file again
	self.replay_fh:seek('set',file_pos)
	self.replay_pos = frame_pos
	return self.replay_frame_count
end

-- functions for dumpimg, called at different points depending on options
local function dumpimg_nop() end
local function dumpimg_open_fh(self)
	-- state.varsubst.state.channel = state.channel
	local state = self.state
	if self.fh then
		errlib.throw{etype='bad_state',msg='file already open', critical=true}
	end

	-- record filename to allow caller to display
	if state.subst then
		self.filename = state.subst:run(self.filespec)
	else
		self.filename = state.filespec
	end
	if self.pipe then
		self.fh = fsutil.popen_e(self.filename,'wb')
	else
		-- ensure parent dir exists
		fsutil.mkdir_parent(self.filename)
		self.fh = fsutil.open_e(self.filename,'wb')
	end
end

local function dumpimg_close_fh(self)
	if not self.fh then
		errlib.throw{etype='bad_state',msg='file handle not open', critical=true}
	end
	self.fh:close()
	self.fh = nil
end
local function dumpimg_close_if_needed(self)
	if self.fh then
		self.fh:close()
		self.fh = nil
	end
end
--[[
for first image in combine, set fh on second and nil
]]
local function dumpimg_close_combine1_fh(self)
	self.state.bm.fh = self.fh
	self.fh = nil
end

local function dumpimg_get_reuse_data(self,i)
	if self.data and self.data[i] then
		return self.data[i].lb
	end
end

local function dumpimg_get_viewport_packed_rgb(self)
	self.pimg = liveimg.get_viewport_pimg(self.pimg,self.state.lv._frame,self.skip)
	if self.pimg then
		local width = self.pimg:width()
		if self.skip then
			width = width/2
		end
		self.data = {
			{
				lb=self.pimg:to_lbuf_packed_rgb(self:get_reuse_data(1)),
				width=width,
				height=self.pimg:height(),
			}
		}
	else
		self.data = {}
		-- ignore missing handled at higher level
		errlib.throw{etype='bad_state',msg='missing viewport data'}
	end
end

local function dumpimg_get_viewport_split_yuv(self)
	local lv = self.state.lv
	local y,u,v=liveimg.get_viewport_split_yuv(lv._frame, 3,
									self.full_buffer,
									self:get_reuse_data(1),
									self:get_reuse_data(2),
									self:get_reuse_data(3))

	local vp = lv.vp
	local height = vp.visible_height
	local y_width
	if self.full_buffer then
		y_width = vp.buffer_width
	else
		y_width = vp.visible_width
	end
	local uv_width
	if vp.fb_type_info.format=='yuv411' then
		uv_width = y_width/4
	elseif vp.fb_type_info.format=='yuv422' then
		uv_width = y_width/2
	else
		errlib.throw{ etype='bad_state',msg='invalid buffer format', critical=true }
	end
	if y_width*height ~= y:len() then
		errlib.throw{ etype='bad_state',msg='incorrect y buf size', critical=true }
	end
	if uv_width*height ~= u:len() then
		errlib.throw{ etype='bad_state',msg='incorrect u buf size', critical=true }
	end
	if uv_width*height ~= v:len() then
		errlib.throw{ etype='bad_state',msg='incorrect v buf size', critical=true }
	end

	self.data ={
		{
			lb=y,
			width=y_width,
			height=vp.visible_height,
			channel='y',
		},
		{
			lb=u,
			width=uv_width,
			height=vp.visible_height,
			channel='u',
		},
		{
			lb=v,
			width=uv_width,
			height=vp.visible_height,
			channel='v',
		}
	}
end

local function dumpimg_get_bitmap_packed_rgba(self)
	self.pimg = liveimg.get_bitmap_pimg(self.pimg,self.state.lv._frame,self.skip)
	if self.pimg then
		local width = self.pimg:width()
		if self.skip then
			width = width/2
		end
		self.data = {
			{
				lb=self.pimg:to_lbuf_packed_rgba(self:get_reuse_data(1)),
				width=width,
				height=self.pimg:height(),
			}
		}
	else
		self.data = {}
		-- ignore missing handled at higher level
		errlib.throw{etype='bad_state',msg='missing bitmap data'}
	end
end

local function dumpimg_write_ppm(self,data)
	self.fh:write(string.format('P6\n%d\n%d\n%d\n',
					data.width,
					data.height,255))
	data.lb:fwrite(self.fh)
end

local function dumpimg_write_lbuf_pgm(self,data)
	self.fh:write(string.format(
		'P5\n%d\n%d\n%d\n',
		data.width,
		data.height,
		255))
	data.lb:fwrite(self.fh)
end

local function dumpimg_write_lbuf(self,data)
	data.lb:fwrite(self.fh)
end

local function dumpimg_write_pam(self,data)
	self.fh:write(string.format(
		'P7\nWIDTH %d\nHEIGHT %d\nDEPTH %d\nMAXVAL %d\nTUPLTYPE RGB_ALPHA\nENDHDR\n',
		data.width,
		data.height,
		4,255))
	data.lb:fwrite(self.fh)
end

local dumpimg_defaults = {
	vp={
		name='viewport',
		formats={
			ppm={
				ext='.ppm',
				allow_skip=true,
				get_data=dumpimg_get_viewport_packed_rgb,
				write_data=dumpimg_write_ppm,
			},
			['yuv-s-pgm']={
				ext='.pgm',
				split=true,
				get_data=dumpimg_get_viewport_split_yuv,
				write_data=dumpimg_write_lbuf_pgm,
			},
			['yuv-s-raw']={
				ext='.bin',
				split=true,
				get_data=dumpimg_get_viewport_split_yuv,
				write_data=dumpimg_write_lbuf,
			},
		},
		opts={
			format='ppm',
			pipe=false,
		},
	},
	bm={
		name='bitmap',
		formats={
			pam={
				ext='.pam',
				allow_skip=true,
				get_data=dumpimg_get_bitmap_packed_rgba,
				write_data=dumpimg_write_pam,
			}
		},
		opts={
			format='pam',
			pipe=false,
		},
	},
}

local function dumpimg_fbs_idata(self)
	local i = 1
	return function()
		local r = self.data[i]
		i = i+1
		return r
	end
end

local function dumpimg_fbs_on_missing_data(self,state)
	if state.missing == 'error' then
		errlib.throw{etype='no_data',msg='missing data for '..tostring(self.name)}
	end
	if state.missing == 'info' then
		cli.infomsg('%s missing frame %d, skipped\n',self.name,state.frame_count)
	elseif type(self.missing) == 'function' then
		state.missing(self,state)
	end
end

-- default fbs methods
local dumpimg_default_fbs_methods = {
	-- file open / close handling default to nop
	start_seq = dumpimg_nop,
	end_seq = dumpimg_nop,
	start_file = dumpimg_nop,
	end_file = dumpimg_nop,
	start_frame = dumpimg_nop,
	end_frame = dumpimg_nop,
	-- user supplied callbacks for status
	on_file_complete = dumpimg_nop,
	on_frame_complete = dumpimg_nop,
	-- other defaults
	cleanup = dumpimg_close_if_needed,
	idata = dumpimg_fbs_idata,
	on_missing_data = dumpimg_fbs_on_missing_data,
	get_reuse_data = dumpimg_get_reuse_data,
}

--[[
initialize state to dump live frames to various image formats
opts:
	vp: {
		filespec:string -- optional, specifying filename or pipe command
		pipe:string -- optional, specifying filespec is command to pipe
					-- one of 'frame', 'split', 'oneproc', default none
		format:string -- optional specifying output format
		skip:bool -- downsample by 50% in x direction (not implemented for yuv)
		on_file_complete: -- fbs method to call after file end
		on_frame_complete: -- fbs method to call after frame end
	}
	bm: {
		-- as above, note only pam format implemented
		filespec:string
		pipe:string
		skip:bool
		on_file_complete: -- fbs method to call after file end
		on_frame_complete: -- fbs method to call after frame end
	}
	nosubst:bool -- use varsubst to generate names/commands
	con: connection -- connection for subst state, or nil if reading from file
	missing:string -- how to handle when requested framebuffer not in stream
					-- 'error' = throw
					-- 'info' = cli.infomsg
					-- function = called with fbs state
					-- other = ignore

]]
function live_wrapper_methods:dumpimg_init(opts)
	-- dump state
	local s={
		fblist={}, -- array for ordered iteration
		frame_count=0,
		lv = self,
		missing = opts.missing,
	}

	if not opts.nosubst then
		local subst=varsubst.new(util.extend_table_multi({
			frame=varsubst.format_state_val('frame','%06d'),
			time=varsubst.format_state_val('time','%d'),
			date=varsubst.format_state_date('date','%Y%m%d_%H%M%S'),
			channel=varsubst.format_state_val('channel','%s'),
		},{
			varsubst.string_subst_funcs,
			chdku.con_subst_funcs,
		}))
		-- fake cons subst if using infile
		if not opts.con then
			subst.state.serial = ''
			subst.state.pid = 0
		else
			opts.con:set_subst_con_state(subst.state)
		end
		subst.state.channel = ''
		s.subst = subst
	end
	for i,fbname in ipairs{'vp','bm'} do
		local fbd = dumpimg_defaults[fbname]
		local fbo = opts[fbname]
		if fbo then
			-- allow vp=true for defaults
			if fbo == true then
				fbo = {}
			end
			local fbs = util.extend_table_multi({},{fbd.opts,dumpimg_default_fbs_methods,fbo})
			fbs.name = fbd.name
			fbs.fmt_desc = fbd.formats[fbs.format]
			fbs.state = s
			if not fbs.fmt_desc then
				errlib.throw{etype='bad_arg',msg='invalid format '..tostring(fbs.format)}
			end
			if fbs.skip and not fbs.fmt_desc.allow_skip then
				errlib.throw{etype='bad_arg',msg='skip not available with format '..tostring(fbs.format)}
			end

			if not fbs.filespec then
				if fbs.pipe then
					if fbs.pipe ~= 'combine' then
						errlib.throw{etype='bad_arg',msg='must specify command with pipe option '..tostring(fbs.pipe)}
					end
				else
					fbs.filespec = fbname .. '_${time,%014.3f}'
					if fbs.fmt_desc.split then
						fbs.filespec = fbs.filespec..'-${channel}'..fbs.fmt_desc.ext
					else
						fbs.filespec = fbs.filespec .. fbs.fmt_desc.ext
					end
				end
			end
			if fbs.filespec and not opts.nosubst then
				s.subst:validate(fbs.filespec)
			end
			if fbs.pipe then
				-- functionally identical, normalize
				if fbs.pipe == 'split' and not fbs.fmt_desc.split then
					errlib.throw{etype='bad_arg',msg='pipe split only valid for split format'}
				end
				if fbs.pipe == 'combine' then
					if fbname ~= 'bm' then
						errlib.throw{etype='bad_arg',msg='pipe combine only valid for bm'}
					end
				end
				if fbs.pipe == 'oneproc' then
					fbs.start_seq = dumpimg_open_fh
					fbs.end_seq = dumpimg_close_fh
				elseif fbs.pipe == 'frame' then
					fbs.start_frame = dumpimg_open_fh
					fbs.end_frame = dumpimg_close_fh
				elseif fbs.pipe == 'split' then
					fbs.start_file = dumpimg_open_fh
					fbs.end_file = dumpimg_close_fh
				elseif fbs.pipe == 'combine' then
					-- fbs.start_frame = dumpimg_nop -- will be passed fh by vp close
					fbs.end_frame = dumpimg_close_fh
					-- corresponding vp functions overridden after both setup
				else
					errlib.throw{etype='bad_arg',msg='invalid pipe option '..tostring(fbs.pipe)}
				end
			else
				if fbs.format.split then
					fbs.start_frame = dumpimg_open_fh
					fbs.end_frame = dumpimg_close_fh
				else
					fbs.start_file = dumpimg_open_fh
					fbs.end_file = dumpimg_close_fh
				end
			end
			if fbname == 'vp' then
				fbs.data_available = function()
					return self:has_vp()
				end
			elseif fbname == 'bm' then
				fbs.data_available = function()
					return self:has_bm()
				end
			end
			fbs.get_data = fbs.fmt_desc.get_data
			fbs.write_data = fbs.fmt_desc.write_data

			s[fbname] = fbs
			table.insert(s.fblist,fbs)
		end
	end
	if s.bm and s.bm.pipe == 'combine' then
		if not s.vp or s.vp.pipe ~= 'frame' then
			errlib.throw{etype='bad_arg',msg='pipe combine requires vp pipe frame'}
		end
		s.vp.end_frame = dumpimg_close_combine1_fh -- don't close on end of vp
	end

	self.dumpimg_state = s
end

function live_wrapper_methods:dumpimg_ifbs()
	if not self.dumpimg_state then
		errlib.throw{etype='bad_state',msg='dumpimg not initialized', critical=true}
	end

	local i = 1
	return function()
		local r = self.dumpimg_state.fblist[i]
		i = i+1
		return r
	end
end

function live_wrapper_methods:dumpimg_frame()
	local state = self.dumpimg_state
	state.frame_count = state.frame_count + 1
	if state.subst then
		state.subst.state.frame = state.frame_count
		-- set time state once per frame to avoid varying between viewport and bitmap
		state.subst.state.date = os.time()
		state.subst.state.time = ustime.new():float()
	end
	if state.frame_count == 1 then
		for fbs in self:dumpimg_ifbs() do
			fbs:start_seq()
		end
	end
	for fbs in self:dumpimg_ifbs() do
		if fbs:data_available() then
			fbs:get_data()
			fbs:start_frame()
			for d in fbs:idata(self) do
				if d.channel then
					state.subst.state.channel = d.channel
				else
					state.subst.state.channel = ''
				end
				fbs:start_file()
				fbs:write_data(d)
				fbs:end_file()
				fbs:on_file_complete()
			end
			fbs:end_frame()
			fbs:on_frame_complete()
		else
			fbs:on_missing_data(state)
		end
	end
end

function live_wrapper_methods:dumpimg_frame_pcall()
	local status,err = pcall(function()
		self:dumpimg_frame()
	end)
	if not status then
		self:dumpimg_cleanup()
	end
	return status,err
end

function live_wrapper_methods:dumpimg_finish()
	if not self.dumpimg_state then
		return
	end
	for fbs in self:dumpimg_ifbs() do
		fbs:end_seq()
	end
	self:dumpimg_cleanup()
end

function live_wrapper_methods:dumpimg_cleanup()
	if not self.dumpimg_state then
		return
	end
	for fbs in self:dumpimg_ifbs() do
		fbs:cleanup()
	end
	self.dumpimg_state = nil
end

local live_fb_desc_meta={
	__index=function(t,key)
		local frame = t._lv._frame
		if not frame then
			return
		end
		-- allow fb bytes to be indexed directly
		if type(key) == 'number' then
			if key >= 0 and key < t.total_bytes then
				return frame:get_u8(t.data_start + key)
			end
		else
			local off = t._lv._fb_field_map[key]
			if off then
				return frame:get_i32(t:offset()+off)
			end
		end
	end
}

local function vp_y_histo_411(self)
	local h=histoutil.new_histo(256)
	local row_offset = 0
	local row_inc = self.buffer_byte_width
	for y=0,self.visible_height-1,1 do
		-- UYVYYY start at 1
		for i=1,self.visible_width-1,6 do
			local o = row_offset+i
			local v=self[o]
			h[v] = h[v] + 1
			v = self[o + 2]
			h[v] = h[v] + 1
			v = self[o + 3]
			h[v] = h[v] + 1
			v = self[o + 4]
			h[v] = h[v] + 1
		end
		row_offset = row_offset + row_inc
	end
	h.total = h:range(0,255)
	return h
end

local function vp_y_histo_422(self)
	local h=histoutil.new_histo(256)
	local row_offset = 0
	local row_inc = self.buffer_byte_width
	for y=0,self.visible_height-1,1 do
		-- UYVY, just sample every odd byte
		for i=1,self.visible_width-1,2 do
			local v=self[row_offset + i]
			h[v] = h[v] + 1
		end
		row_offset = row_offset + row_inc
	end
	h.total = h:range(0,255)
	return h
end

local function split_yuv422(self,opts)
	opts = util.extend_table({
		full_buf=false,
		y=true,
		uv=true,
	},opts)
	local width
	if opts.full_buf then
		byte_width = self.buffer_byte_width
		width = self.buffer_width
	else
		-- note assumes width is an even number of pixels
		byte_width = (self.visible_width*self.fb_type_info.bpp)/8
		width = self.visible_width
	end
	local y_size = width*self.visible_height
	local uv_size = y_size / 2
	local yb, uvb
	local yi, uvi
	if opts.y then
		yb = lbuf.new(y_size)
		yi = 0
	end
	if opts.uv then
		ub = lbuf.new(uv_size)
		vb = lbuf.new(uv_size)
		uvi = 0
	end
	local row_offset = 0
	local row_inc = self.buffer_byte_width
	for y=0,self.visible_height-1,1 do
		for i=0,byte_width-1,self.fb_type_info.block_bytes do
			if yi then
				local y1 = self[row_offset + i + 1]
				local y2 = self[row_offset + i + 3]
				yb:set_u8(yi,y1,y2)
				yi = yi + 2
			end
			if uvi then
				local u = self[row_offset + i]
				local v = self[row_offset + i + 2]
				ub:set_u8(uvi,u)
				vb:set_u8(uvi,v)
				uvi = uvi + 1
			end
		end
		row_offset = row_offset + row_inc
	end
	if yi and uvi then
		return yb,ub,vb
	elseif yi then
		return yb
	else
		return uv,vb
	end
end

local live_fb_desc_methods={
	get_screen_width = function(self)
		return self.margin_left + self.visible_width + self.margin_right;
	end,
	get_screen_height = function(self)
		return self.margin_top + self.visible_height + self.margin_bot;
	end,
	offset = function(self)
		return self._lv[self._offset_name]
	end,
	-- update values derived from current fb desc
	on_set_frame = function(self)
		self.fb_type_info = m.live_fb_types[self.fb_type]
		-- TODO doesn't check if actually divisible by 8
		if self.data_start then
			self.buffer_byte_width = (self.buffer_width * self.fb_type_info.bpp)/8
			self.total_bytes = self.buffer_byte_width * self.visible_height
		else
			self.buffer_byte_width = 0
			self.total_bytes = 0
		end
		-- TODO doesn't need to update every frame, only per connection
		if self.fb_type_info.format == 'yuv411' then
			self.get_histo_y = vp_y_histo_411
			self.split_yuv = nil
		elseif self.fb_type_info.format == 'yuv422' then
			self.get_histo_y = vp_y_histo_422
			self.split_yuv = split_yuv422
		else
			self.get_histo_y = nil
			self.split_yuv = nil
		end
	end,
	describe=function(self)
		return string.format([[
%s %s %d bpp
buffer  %dx%d
visible %dx%d
screen  %dx%d %s offset %d,%d
]],self.fb_type_info.chdk_name,self.fb_type_info.format,self.fb_type_info.bpp,
		self.buffer_width, self.visible_height,
		self.visible_width, self.visible_height,
		self:get_screen_width(),self:get_screen_height(),
		m.aspect_ratio_names[self._lv.lcd_aspect_ratio],
		self.margin_left,self.margin_top)
	end
}

function m.live_fb_desc_wrap(lv,fb_pfx)
	local t=util.extend_table({
		_offset_name = fb_pfx .. '_desc_start',
		_lv = lv,
	},live_fb_desc_methods);
	setmetatable(t,live_fb_desc_meta)
	t:on_set_frame()
	return t
end

--[[
create a new live view data wrapper
]]
function m.live_wrapper()
	local t=util.extend_table({},live_wrapper_methods)
	setmetatable(t,live_wrapper_meta)
	return t
end

--[[
helper functions for live image dump
open file or pipe for pbm / pam dump
opts are from lvdump.live_dump_*
TODO this isn't really live dump specific
]]
local function live_dump_img_open(opts)
	if opts.filehandle then
		return opts.filehandle
	end
	if not opts.filename then
		error('no filename or filehandle')
	end

	local fh
	if opts.pipe then
		fh = fsutil.popen_e(opts.filename,'wb')
		if opts.pipe_oneproc then
			opts.filehandle = fh
		end
	else
		-- ensure parent dir exists
		fsutil.mkdir_parent(opts.filename)
		fh = fsutil.open_e(opts.filename,'wb')
	end
	return fh
end
local function live_dump_img_close(fh,opts)
	-- open was passed a handle, don't mess with it
	if opts.filehandle then
		return
	end
	fh:close()
end

--[[
write viewport data to an unscaled pbm image
frame: live view frame
opts:{
	filename=string -- filename or pipe command
	pipe=bool -- filename is a command to pipe to
	pipe_oneproc=bool -- start pipe process once and use for all subsequent writes,
						caller must close opts.filehandle when done
	filehandle=handle -- already open handle to write to, filename ignored
	lb=lbuf -- lbuf for image to re-use, created and set if not given
	pimg=pimg -- pimg to re-use, created if and set if not given
	skip=bool -- downsample image width 50% in X (faster, rough aspect correction for some cams)
}
]]
function m.dump_vp_pbm(frame,opts)
	opts.pimg = liveimg.get_viewport_pimg(opts.pimg,frame,opts.skip)
	-- TODO may be null if video selected on startup
	if not opts.pimg then
		error('no viewport data')
	end
	opts.lb = opts.pimg:to_lbuf_packed_rgb(opts.lb)
	local width = opts.pimg:width()
	if opts.skip then
		width = width/2
	end

	local fh = live_dump_img_open(opts)
	fh:write(string.format('P6\n%d\n%d\n%d\n',
		width,
		opts.pimg:height(),255))
	opts.lb:fwrite(fh)
	live_dump_img_close(fh,opts)
end
--[[
write bitmap data to an unscaled RGBA pam image
opts as above
]]
function m.dump_bm_pam(frame,opts)
	opts.pimg = liveimg.get_bitmap_pimg(opts.pimg,frame,opts.skip)
	opts.lb = opts.pimg:to_lbuf_packed_rgba(opts.lb)

	local width = opts.pimg:width()
	if opts.skip then
		width = width/2
	end

	local fh = live_dump_img_open(opts)

	fh:write(string.format(
		'P7\nWIDTH %d\nHEIGHT %d\nDEPTH %d\nMAXVAL %d\nTUPLTYPE RGB_ALPHA\nENDHDR\n',
		width,
		opts.pimg:height(),
		4,255))
	opts.lb:fwrite(fh)
	live_dump_img_close(fh,opts)
end

function m.write_lbuf_pgm8(lb,opts)
	if not opts then
		errlib.throw{ etype='bad_arg',msg='missing opts' }
	end
	if not (opts.width and opts.height) then
		errlib.throw{ etype='bad_arg',msg='missing width or height' }
	end
	if opts.width*opts.height ~= lb:len() then
		errlib.throw{ etype='bad_arg',msg='mismatched size/dimensions' }
	end
	local fh = live_dump_img_open(opts)
	fh:write(string.format(
		'P5\n%d\n%d\n%d\n',
		opts.width,
		opts.height,
		255))
	lb:fwrite(fh)
	live_dump_img_close(fh,opts)
end

return m
