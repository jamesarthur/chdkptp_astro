--[[
 Copyright (C) 2016-2023 <reyalp (at) gmail dot com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  with chdkptp. If not, see <http://www.gnu.org/licenses/>.

various dev utils as cli commands
usage
!require'extras/devutil':init_cli()
use help for information about individual commands
--]]
local m={}
local proptools=require'extras/proptools'
local paramtools=require'extras/paramtools'
local vxromlog=require'extras/vxromlog'
local argparser = require'argparser'

m.stop_uart_log = function()
	if not m.logname then
		errlib.throw{etype='bad_arg',msg='log not started'}
	end
	con:execwait([[
require'uartr'.stop()
]])
end

m.resume_uart_log = function()
	if not m.logname then
		errlib.throw{etype='bad_arg',msg='log not started'}
	end
	con:execwait(string.format([[
require'uartr'.start('%s',false,0x%x)
]],m.logname,m.logsize+512))
end

m.init_cli = function()
	cli:add_commands{
	{
		names={'dlstart'},
		help='start uart log w/large log buffers',
		arghelp="[options] [file]",
		args=argparser.create{
			csize=0x6000,
			clevel=0x20,
			a=false,
			ckeep=false,
		},
		help_detail=[[
 [file] name for log file, default A/dbg.log
 options
  -csize=<n> camera log buffer size, default 0x6000
  -clevel=<n> camera log level, messages with matching bits set are logged. default 0x20
  -ckeep=<boolean> do not restart camera log (csize/clevel ignored)
  -a  append to existing log
 requires native calls enabled, camera with uart log support (all DryOS)
]],
		func=function(self,args)
			local logname=args[1]
			if not logname then
				logname='dbg.log'
			end
			opts = {
				logname=fsutil.make_camera_path(logname),
				overwrite=(args.a==false),
				logsize=tonumber(args.csize)+512,
				clevel=tonumber(args.clevel),
				csize=tonumber(args.csize),
				ckeep=args.ckeep,
			}
			con:execwait('opts='..serialize(opts)..[[

if not opts.ckeep then
	call_event_proc('StopCameraLog')
	sleep(200)
	call_event_proc('StartCameraLog',opts.clevel,opts.csize)
	sleep(100)
end
require'uartr'.start(opts.logname,opts.overwrite,opts.logsize)
sleep(100)
call_event_proc('Printf',
	'%s dlstart CameraLog 0x%x,0x%x Uart "%s",%s,0x%x\n',
	os.date('%Y%m%d %H:%M:%S'),
	opts.clevel,opts.csize,
	opts.logname,tostring(opts.overwrite),opts.logsize
	)
]])
			m.logname=logname
			m.logsize=args.csize
			return true,'log started: '..m.logname
		end
	},
	{
		names={'dlgetcam'},
		help='print camera log on uart, download uart log',
		arghelp="[local]",
		args=argparser.create{},
		help_detail=[[
 [local] name to download log to, default same as uart log
 log must have been started with dlstart
]],
		func=function(self,args)
			if not m.logname then
				return false,'log not started'
			end
			con:execwait([[
call_event_proc('Printf','%s dlgetcam\n',os.date('%Y%m%d %H:%M:%S'))
call_event_proc('ShowCameraLog')
call_event_proc('Printf','%s dlgetcam end\n',os.date('%Y%m%d %H:%M:%S'))
]])
			sys.sleep(1000) -- 500 was sometimes too short
			local dlcmd='download '..m.logname
			if args[1] then
				dlcmd = dlcmd..' '..args[1]
			end
			return cli:execute(dlcmd)
		end
	},
	{
		names={'dlget'},
		help='download uart log',
		arghelp="[local]",
		args=argparser.create{},
		help_detail=[[
 [local] name to download log to, default same as uart log
 log must have been started with startlog
]],

		func=function(self,args)
			if not m.logname then
				return false,'log not started'
			end
			local dlcmd='download '..m.logname
			if args[1] then
				dlcmd = dlcmd..' '..args[1]
			end
			return cli:execute(dlcmd)
		end
	},
	{
		names={'dlstop'},
		help='stop uart log',
		func=function(self,args)
			m.stop_uart_log()
			return true
		end
	},
	{
		names={'dlresume'},
		help='resume uart log',
		func=function(self,args)
			m.resume_uart_log()
			return true
		end
	},
	{
		names={'dpget'},
		help='get range of propcase values',
		arghelp="[options]",
		args=argparser.create{
			s=0,
			e=999,
			c=false,
		},
		help_detail=[[
 options:
  -s=<number> min prop id, default 0
  -e=<number> max prop id, default 999
  -c=<code> lua code to execute before getting props
]],

		func=function(self,args)
			args.e=tonumber(args.e)
			args.s=tonumber(args.s)
			if args.e < args.s then
				return false,'invalid range'
			end
			m.psnap=proptools.get(args.s, args.e + 1 - args.s,args.c)
			return true
		end
	},
	{
		names={'dpsave'},
		help='save propcase values obtained with dpget',
		arghelp="[file]",
		args=argparser.create{ },
		help_detail=[[
 [file] output file
]],

		func=function(self,args)
			if not m.psnap then
				return false,'no saved props'
			end
			if not args[1] then
				return false,'missing filename'
			end
			proptools.write(m.psnap,args[1])
			return true,'saved '..args[1]
		end
	},
	{
		names={'dpcmp'},
		help='compare current propcase values with last dpget',
		arghelp="[options]",
		args=argparser.create{
			c=false,
		},
		help_detail=[[
 options:
  -c=<code> lua code to execute before getting props
]],
		func=function(self,args)
			if not m.psnap then
				return false,'no saved props'
			end
			proptools.comp(m.psnap,proptools.get(m.psnap._min, m.psnap._max - m.psnap._min,args.c))
			return true
		end
	},
	{
		names={'dfpget'},
		help='get range of flash param values',
		arghelp="[options]",
		args=argparser.create{
			s=0,
			e=false,
			c=false,
		},
		help_detail=[[
 options:
  -s=<number> min param id, default 0
  -e=<number> max param id, default flash_params_count - 1
  -c=<code> lua code to execute before getting
]],

		func=function(self,args)
			args.s=tonumber(args.s)
			local count
			if args.e then
				args.e=tonumber(args.e)
				if args.e < args.s then
					return false,'invalid range'
				end
				count = args.e + 1 - args.s
			end
			m.fpsnap=paramtools.get(args.s,count,args.c)
			return true
		end
	},
	{
		names={'dfpsave'},
		help='save flash param values obtained with dfpget',
		arghelp="[file]",
		args=argparser.create{ },
		help_detail=[[
 [file] output file
]],

		func=function(self,args)
			if not m.fpsnap then
				return false,'no saved params'
			end
			if not args[1] then
				return false,'missing filename'
			end
			paramtools.write(m.fpsnap,args[1])
			return true,'saved '..args[1]
		end
	},
	{
		names={'dfpcmp'},
		help='compare current param values with last dfpget',
		arghelp="[options]",
		args=argparser.create{
			c=false,
		},
		help_detail=[[
 options:
  -c=<code> lua code to execute before getting params
]],
		func=function(self,args)
			if not m.fpsnap then
				return false,'no saved props'
			end
			paramtools.comp(m.fpsnap,paramtools.get(m.fpsnap._min, m.fpsnap._max - m.fpsnap._min,args.c))
			return true
		end
	},
	{
		names={'dsearch32'},
		help='search memory for specified 32 bit value',
		arghelp="[-l=<n>] [-c=<n>] [-cb=<n>] [-ca=<n>] <start> <end> <val>",
		args=argparser.create{
			l=false,
			c=false,
			cb=false,
			ca=false,
		},
		help_detail=[[
 <start> start address
 <end>   end address
 <val>   value to find
 options
  -l=<n> stop after n matches
  -c=<n> show N words before and after
  -cb=<n> show N words before match
  -ca=<n> show N words after match
]],
		func=function(self,args)
			local start=tonumber(args[1])
			local last=tonumber(args[2])
			local val=tonumber(args[3])
			if not start then
				return false, 'missing start address'
			end
			if not last then
				return false, 'missing end address'
			end
			if not val then
				return false, 'missing value'
			end
			local do_ctx
			local ctx_before = 0
			local ctx_after = 0
			if args.c then
				do_ctx=true
				ctx_before = tonumber(args.c)
				ctx_after = tonumber(args.c)
			end
			if args.cb then
				do_ctx=true
				ctx_before = tonumber(args.cb)
			end
			if args.ca then
				do_ctx=true
				ctx_after = tonumber(args.ca)
			end

			printf("search 0x%08x-0x%08x 0x%08x\n",start,last,val)
			local t={}
			-- TODO should have ability to save results since it's slow
			con:execwait(string.format([[
mem_search_word{start=0x%x, last=0x%x, val=0x%x, limit=%s}
]],start,last,val,tostring(args.l)),{libs='mem_search_word',msgs=chdku.msg_unbatcher(t)})
			for i,v in ipairs(t) do
				local adr=bit32.band(v,0xFFFFFFFF)
				if do_ctx then
					if adr > ctx_before then
						adr = adr - 4*ctx_before
					else
						adr = 0
					end
					local count=ctx_before + ctx_after + 1
					cli:print_status(cli:execute(('rmem -i32 0x%08x %d'):format(adr,count)))
				else
					printf("0x%08x\n",adr)
				end
			end
			return true
		end
	},
	{
		names={'dromlog'},
		help='get camera romlog',
		arghelp="[options] [dest]",
		args=argparser.create{
			p=false,
			pa=false,
			nodecode=false,
		},
		help_detail=[[
 [dest] path/name for downloaded file, default ROMLOG.LOG
 options
   -nodecode do not decode vxworks romlog
   -p        print error, registers, stack
   -pa       print full log

 GK.LOG / RomLogErr.txt will be prefixed with dst name if present
 Binary vxworks log will have .bin appended if decoding enabled

 requires native calls enabled
 existing ROMLOG.LOG, GK.LOG and RomLogErr.txt files on cam will be removed
]],
		func=function(self,args)
			local dst=args[1]
			local gkdst
			local errdst
			if dst then
				-- make GK log name based on dest
				local dstbase=fsutil.split_ext(dst)
				gkdst=dstbase..'-GK.LOG'
				errdst=dstbase..'-Err.LOG'
			else
				dst='ROMLOG.LOG'
				gkdst='GK.LOG'
				errdst='RomLogErr.txt'
			end
			local r = con:execwait([[
LOG_NAME="A/ROMLOG.LOG"
GKLOG_NAME="A/GK.LOG"
ERR_NAME="A/RomLogErr.txt"

if call_event_proc("SystemEventInit") == -1 then
    if call_event_proc("System.Create") == -1 then
        error("ERROR: SystemEventInit and System.Create failed")
    end
end
if os.stat(LOG_NAME) then
	os.remove(LOG_NAME)
end
if os.stat(GKLOG_NAME) then
	os.remove(GKLOG_NAME)
end
if os.stat(ERR_NAME) then
	os.remove(ERR_NAME)
end

-- first arg: filename, NULL for ROMLOG.TXT (dryos) or ROMLOG (vxworks)
-- second arg: if 0, shutdown camera after writing log
-- note, on vxworks the exception code, registers and stack trace are binary
call_event_proc("GetLogToFile",LOG_NAME,1)
-- get OS for log decoding
camos=get_buildinfo().os
if os.stat(ERR_NAME) then
	return {status=false, logname=ERR_NAME, os=camos}
end

if not os.stat(LOG_NAME) then
    error('logfile %s does not exist',LOG_NAME)
end
if os.stat(GKLOG_NAME) then
	return {status=true, logname=LOG_NAME, gklogname=GKLOG_NAME, os=camos}
else
	return {status=true, logname=LOG_NAME, os=camos}
end
]])
			if not r.status then
				cli.infomsg("%s->%s\n",r.logname,errdst)
				con:download(r.logname,errdst)
				return false,string.format("ROMLOG failed, error %s\n",errdst)
			end
			local dldst = dst
			if r.os == 'vxworks' and not args.nodecode then
				dldst = dldst..'.bin'
			end
			cli.infomsg("%s->%s\n",r.logname,dldst)
			con:download(r.logname,dldst)
			local vxlog
			if r.os == 'vxworks' and not args.nodecode then
				cli.infomsg("decode vxworks %s->%s\n",dldst,dst)
				vxlog=vxromlog.load(dldst)
				local fh=fsutil.open_e(dst,'wb')
				vxlog:print_all(fh)
				fh:close()
			end
			if r.gklogname then
				cli.infomsg("%s->%s\n",r.gklogname,gkdst)
				con:download(r.gklogname,gkdst)
			end
			if args.pa then
				if vxlog then
					vxlog:print_all()
				else
					printf("%s",fsutil.readfile(dst,{bin=true}))
				end
			elseif args.p then
				if vxlog then
					vxlog:print()
				else
					local fh=fsutil.open_e(dst,'rb')
					for l in fh:lines() do
						if l:match('^CameraConDump:') then
							break;
						end
						printf("%s\n",l)
					end
					fh:close();
				end
			end
			return true
		end
	},
	{
		names={'dscriptdisk'},
		help='make script disk',
		arghelp="",
		args=argparser.none,
		help_detail=[[
Prepare card as Canon Basic script disk. Requires native calls
]],
		func=function(self,args)
			con:execwait([[
if call_event_proc("SystemEventInit") == -1 then
	if call_event_proc("System.Create") ~= 0 then
		error('System eventproc reg failed')
	end
end

f=io.open("A/SCRIPT.REQ","w")
if not f then
	error("file open failed")
end
f:write("for DC_scriptdisk")
f:close()

if call_event_proc("MakeScriptDisk",0) ~= 0 then
	error('MakeScriptDisk failed')
end

]])
			return true, 'Script disk initialized'
		end
	},
	{
		names={'dvxromlog'},
		help='decode VxWorks ROMLOG',
		arghelp="<infile> [outfile]",
		args=argparser.create{
			all=false,
	 	},
		help_detail=[[
 <infile>  local path of VxWorks ROMLOG to decode
 [outfile] output file, default standard output
 options
  -all     include cameralog
]],
		func=function(self,args)
			local logname=args[1]
			local outfile=args[2]
			if not logname then
				error('missing log name')
			end
			local log=vxromlog.load(logname)
			local fh
			if outfile then
				fh=fsutil.open_e(outfile,'wb')
			end
			if args.all then
				log:print_all(fh)
			else
				log:print(fh)
			end
			if fh then
				fh:close()
			end
			return true
		end
	},
	{
		names={'dptpsendobj'},
		help='upload a file using standard PTP',
		arghelp="<src> <dst>",
		args=argparser.create{
			ofmt=0xbf01,
	 	},
		help_detail=[[
 <src> local file to upload
 <dst> name to upload to
 options
  -ofmt     object format code, default 0xbf01

NOTE:
Depending camera model dst must either be a bare filename, or start with A/
A540 (VxWorks) and Elph130 (DryOS r52) crash if A/ IS present
D10 (DryOS r31) crashes if A/ IS NOT present
Either crash is an assert in OpObjHdl.c

]],
		func=function(self,args)
			local src=args[1]
			local dst=args[2]
			if not src then
				return false,'missing src'
			end
			if not dst then
				return false,'missing dst'
			end
			local data=fsutil.readfile(src,{bin=true})
			local ofmt=tonumber(args.ofmt)
			cli.infomsg("SendObjectInfo(Filename=%s,ObjectFormat=0x%x,ObjectCompressedSize=%d)\n", dst,ofmt,data:len())
			local objh = con:ptp_send_object_info({
				Filename=dst,
				ObjectFormat=ofmt,
				ObjectCompressedSize=data:len()
			})
			cli.infomsg("Received handle 0x%x, sending data\n",objh)
			con:ptp_send_object(data)
			return true
		end
	},
	{
		names={'dptplistobjs'},
		help='List objects PTP objects',
		arghelp="[options] [handle1] ...",
		args=argparser.create{
			stid=0xFFFFFFFF,
			ofmt=0,
			assoc=0,
			h=false,
		},
		help_detail=[[
 [handle]   specify handles to list info for, default all
 options
  -stid     storage ID, default 0xFFFFFFFF (all)
  -ofmt     object format code, default 0 (any)
  -assoc    association, default 0 (any)
  -h		only list handles, do not query info

NOTE:
Listing all handles normally causes the camera display to go black and makes
switching to shooting mode fail unless event 4482 (DryOS) or 4418 (VxWorks)
is sent, USB is disconnected, or the camera is restarted

]],
		func=function(self,args)
			local oh
			if #args > 0 then
				oh={}
				for i,h in ipairs(args) do
					table.insert(oh,tonumber(h))
				end
			else
				oh=con:ptp_get_object_handles(args.stid,args.ofmt,args.assoc)
			end
			for i,h in ipairs(oh) do
				if args.h then
					printf('0x%x\n',h)
				else
					local oi = con:ptp_get_object_info(h)
					printf('0x%x:%s\n',h,util.serialize(oi,{pretty=true}))
				end
			end
			return true
		end
	},
	{
		names={'dptpstorageinfo'},
		help='List PTP storage info',
		arghelp="[storage id] | [-i]",
		args=argparser.create{
			i=false
		},
		help_detail=[[
 [storage id]   list only information for a specific storage id. Default all

 options
  -i only list IDs without querying info

]],
		func=function(self,args)
			local sids
			if args[1] then
				sids={tonumber(args[1])}
			else
				sids=con:ptp_get_storage_ids()
			end
			for i,sid in ipairs(sids) do
				if args.i then
					printf('0x%x\n',sid)
				else
					si = con:ptp_get_storage_info(sid)
					printf('0x%x:%s\n',sid,util.serialize(si,{pretty=true}))
				end
			end
			return true
		end
	},
	{
		names={'dptpdevinfo'},
		help='Display PTP device info',
		arghelp="[options]",
		args=argparser.create{
			s=false,
			oc=false,
			ec=false,
			ofc=false,
			dpc=false,
			mtp=false,
			ac=false,
			np=false,
			ptpevp=false,
			sn=false,
		},
		help_detail=[[
 options
  -s   summary (default if no code options)
  -oc  list supported operation codes
  -ec  list supported event codes
  -ofc list supported object format codes (image and capture)
  -dpc list supported device property codes
  -mtp list supported MTP object property codes, if MTP supported
  -ac  list all supported code types (default without -s or code options)
  -np  not paranoid, include serial and IP info
  -ptpevp  attempt to enable ptp eventproc api before getting devinfo
  -sn  sort code lists numerically

NOTES:
  -mtp will likely cause the cameras screen to go black, like GetObjectHandles
  If neither -s nor code options (-oc, -ec, -ofc, -dpc) given, default is -s -ac

]],
		func=function(self,args)
			if args.ptpevp then
				local status,err=con:ptpevp_initiate_pcall()
				if not status then
					if type(err) == 'table' and err.ptp_rc == ptp.RC.OperationNotSupported then
						printf('CANON.InitiateEventProc0 not supported\n')
					else
						error(err)
					end
				end
			end
			local di=con:get_ptp_devinfo(true)
			local anyopts
			for _,v in ipairs({'s','oc','ec','ofc','dpc','ac'}) do
				if args[v] then
					anyopts = true
					break
				end
			end
			if not anyopts then
				args.s = true
				args.ac = true
			end
			if args.s then
				printf('Model: %s\n',di.model)
				printf('Manufacturer: %s\n',di.manufacturer)
				printf('Device Version: %s\n',di.device_version)
				local ser = di.serial_number
				if not ser then
					ser='(none)'
				elseif not args.np then
					ser='(redacted)'
				end
				printf('Serial Number: %s\n',ser)
				printf('PTP Standard Version: %d\n',di.StandardVersion)
				printf('Vendor Extension ID: %s\n',ptp.vendor_ext_id_desc(di.VendorExtensionID) or '(none)')
				printf('Vendor Extension Version: %s\n',di.VendorExtensionVersion or '(none)')
				printf('Vendor Extension Description: %s\n',di.VendorExtensionDesc or '(none)')
				printf('Functional Mode: 0x%x\n',di.FunctionalMode);
				printf('\nConnection: \n')
				if con.condev.transport == 'usb' then
					printf(' USB bus=%s device=%s',con.condev.bus,con.condev.dev)
					printf(' vendor=0x%x product=0x%x\n',con.condev.vendor_id,con.condev.product_id)
				else
					if args.np then
						printf(' PTP/IP host=%s port=%s\n',con.condev.host,con.condev.port)
					else
						printf(' PTP/IP host=(redacted) port=(redacted)\n')
					end
				end
			end
			if args.ac then
				args.oc = true
				args.ec = true
				args.ofc = true
				args.dpc = true
				args.mtp = true
			end
			local exts = con:get_ptp_ext_code_ids()
			for _,cdesc in ipairs(ptp.devinfo_code_map) do
				printf('\n%s:\n',cdesc.desc)
				if args[string.lower(cdesc.cid)] then
					local codes = di[cdesc.devid]
					if args.sn then
						codes = util.extend_table({},codes)
						table.sort(codes)
					end
					for _,c in ipairs(codes) do
						printf(' %s\n',con:get_ptp_code_desc(cdesc.cid,c))
					end
				end
			end
			if args.mtp and util.in_table(exts,'MTP') then
				printf('\nMTP Object Properties Supported:\n')
				local ofc_list = di.ImageFormats
				if args.sn then
					ofc_list = util.extend_table({},ofc_list)
					table.sort(ofc_list)
				end

				for _, ofc in ipairs(ofc_list) do
					printf(' Format %s\n',con:get_ptp_code_desc('OFC',ofc))
					local lb=con:ptp_txn(ptp.MTP.OC.GetObjectPropsSupported,ofc,{getdata='lbuf'})
					local count = lb:get_i32(0)
					if lb:len() ~= count*2 + 4 then
						util.warnf("expected data size %d not %d\n",count*2 + 4,lb:len())
					end
					local opc_list = {lb:get_u16(4,(lb:len()-4)/2)}
					-- local opc_list = {lb:get_u16(4,count)}
					if args.sn then
						table.sort(opc_list)
					end
					local zcount = 0
					for i,v in ipairs(opc_list) do
						if v == 0 then
							zcount = zcount + 1
						else
							if zcount > 0 then
								printf("%d zeros\n",zcount)
								zcount = 0
							end
							printf('  %s\n',ptp.get_code_desc('OPC',v,'MTP'))
						end
					end
					if zcount > 0 then
						printf("  (%d zeros)\n",zcount)
					end
				end
			end
			return true
		end
	},
	{
		names={'dptpgetprop'},
		help='Display PTP device properties',
		arghelp="[propspec]",
		args=argparser.create{
		},
		help_detail=[[
 [propspec]
   Device Property code, or name specified like [VENDOR.]Name
   If not specified, all are displayed

]],
		func=function(self,args)
			local propid=args[1]
			local props
			if propid then
				props = tonumber(propid)
				if not props then
					local parts = util.string_split(args[1],'.',{plain=true,empty=false})
					-- ptp module structured like [VENDOR.]DPC.CODE
					if #parts == 1 then
						table.insert(parts,1,'DPC')
					elseif #parts == 2 then
						table.insert(parts,2,'DPC')
					else
						return false, 'invalid prop spec '..tostring(args[1])
					end
					props = ptp.get_code_by_name(table.concat(parts,'.'))
					if type(props) ~= 'number' then
						return false, 'unknown prop '..tostring(args[1])
					end
				end
				props = {props}
			else
				props = con.ptpdev.DevicePropertiesSupported
			end
			local pt=require'ptpprop'
			for i,v in ipairs(props) do
				local lb=con:ptp_txn(ptp.OC.GetDevicePropDesc,v,{getdata='lbuf'})
				local status,err = pcall(function()
					pt.bind(lb):describe(con.ptp_code_ids)
				end)
				-- some canon props seem to be malformed, like 0xd111 and 0xd112 on g7x
				if not status then
					printf('failed to bind prop %s\n%s\n',ptp.get_code_desc('DPC',v,con.ptp_code_ids),err)
					printf('length %d hexdump:\n%s\n',lb:len(),util.hexdump(lb:string()))
				end
				printf('\n')
			end
			return true
		end,
	},

}
end

return m
