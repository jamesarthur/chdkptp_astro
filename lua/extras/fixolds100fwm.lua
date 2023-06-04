--[[
fix DNGs affected by bug in s100 port prior to r3497
https://chdk.setepontos.com/index.php?topic=7887.msg114303#msg114303
usage:
!require'extras/fixols100fwm.lua'
single file
!fixfwm('IMG_1105.DNG','IMG_1105-fix.DNG')
current directory, to ../fixed
!for f in lfs.dir('.') do if f:match('%.DNG$') then fixfwm(f,'../fixed/'..f) end end

]]
function fixfwm(infile,outfile)
	local dnglib=require'dng'
	local d,err=dnglib.load(infile)
	if not d then
		error(string.format('error %s loading input',tostring(err)))
	end
	local ifd=d:get_ifd{0}
	local oldfwm2 = ifd.byname.ForwardMatrix2:getel(3)
	if oldfwm2[1] == 188 then
		ifd.byname.ForwardMatrix2:setel({1880,10000},3)
		local fh,err = io.open(outfile,'wb')
		if not fh then
			error(string.format('error %s opening output',tostring(err)))
		end
		printf("patched %s -> %s\n",infile,outfile)
		d._lb:fwrite(fh)
		fh:close()
	else
		printf("skipping %s, ForwardMatrix2[3] ~= 188\n",infile)
	end
end

