This file contains headers and pre-compiled Lua, IUP and CD libraries needed
to build chdkptp. This is provided because building IUP and CD on can be
difficult on platforms like raspberry pi. A static Lua build is also included
to avoid conflicts with distro provided Lua packages.

Where practical, it is recommended that you use misc/setup-ext-libs.bash 
from the chdkptp source instead.

Information about chdkptp can be found at:
http://www.assembla.com/wiki/show/chdkptp

For information about Lua, CD and IUP, see
http://www.lua.org/
http://www.tecgraf.puc-rio.br/iup/
http://www.tecgraf.puc-rio.br/cd/

The zip is arranged into the directory structure expected by the chdkptp
makefiles with a subdirectory under extlibs/built for each library:
lua52, cd and iup respectively

See COPYRIGHT file or doc subdirectory in each directory for copyright
information.

These files are intended to allow you to build your own chdkptp without
building the GUI libraries.  Some files not required by CHDK may be included,
but these are not complete distributions of Lua, CD and IUP, and are not
thoroughly tested. 

Using the libraries to build chdkptp:
Just unzip the file into the root of the chdkptp source tree. No config.mk
settings are required, but if you have an existing config.mk you should
verify that it does not override the expected library locations.
