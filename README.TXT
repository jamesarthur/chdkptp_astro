=Introduction=
chdkptp is a tool to access the custom PTP extension of the CHDK firmware addon
for Canon cameras.

chdkptp builds are labeled "alpha", but it is stable enough for everyday use.
Protocol, functionality, APIs, commands, command line options are
all subject to change.

Source is available from http://subversion.assembla.com/svn/chdkptp/trunk
Binary snapshot builds are available from http://www.assembla.com/spaces/chdkptp/documents
Changelog is at http://www.assembla.com/wiki/show/chdkptp/Changelog

This README is primarily intended for developers.

See INSTALL.TXT for installation information

See USAGE.TXT for end-user documentation

See README-LINUX-BINARIES.TXT for information about the Linux builds (including raspberry pi)

For information about CHDK, see http://chdk.fandom.com/wiki/CHDK
For information about the CHDK PTP extension, see http://chdk.fandom.com/wiki/PTP_Extension

chdkptp is forked from libptp and ptpcam, as modified by mweerden, the chdkde project
developers and others. All source is released under GPL or MIT licenses

The original ptpcam source, written by Mariusz Woloszyn < emsi[A@T]ipartners.pl >
is available from http://libptp.sourceforge.net/

mweerdens modified version can be found at https://github.com/mweerden/CHDK/tree/ptp

The CHDKDE ptpcam source may be found at https://app.assembla.com/spaces/chdkde/subversion/source/HEAD/trunk/tools/ptpcam

chdkptp includes software from several other projects, see THANKS.TXT for details.

=Dependencies=
==All builds==
- Lua version 5.3 http://www.lua.org/versions.html
  Lua 5.2 is supported, but minimally tested
  Lua 5.1 is not supported, although it may work
  Lua 5.4 is not supported

==Windows==
- libusb-win32 1.2.6.0  (Windows only)
  From https://sourceforge.net/projects/libusb-win32/files/libusb-win32-releases/1.2.6.0/
  Some earlier and later versions will also probably work, however versions
  before 1.2.4.6 used a different name for the header file.

==Linux / MacOS==
- libusb 0.1 compatibility
  Usually a package like libusb-dev, (libusb-compat on MacOS)
- GNU readline
  Optional, but highly recommended for CLI on Linux / MacOS

==Optional IUP/CD GUI==
- IUP version 3.30 http://www.tecgraf.puc-rio.br/iup/
  Earlier 3.x versions may also work, 3.21 or later is required on linux with
  GTK newer than 3.18
- CD Version 5.14 http://www.tecgraf.puc-rio.br/cd/
  Optional, required for IUP GUI
  Earlier 5.x versions may also work

==Optional LGI GUI==
- LGI https://github.com/pavouk/lgi
  Installing from package manager is recommended

=Windows development environment=
MSYS2 (https://www.msys2.org/) is the primary development environment.
All instructions below assume you are using this.
Using a mingw bash shell for development is suggested. Note when running
chdkptp CLI, using the standard windows command prompt console is recommended
over alternative terminals such as mintty, i.e starting with
 msys2_shell.cmd -mingw64 -defterm

It may be possible to build chdkptp with other mingw/msys environments, however,
the current pre-built IUP and CD libraries require a relatively modern GCC

==Installing msys2==
Configure as described on https://github.com/msys2/msys2/wiki/MSYS2-installation

Development tools can be installed with something like
pacman -S --needed base-devel
pacman -S --needed mingw-w64-x86_64-toolchain
Feel free to deselect, Ada, Fortran etc. C++ support should be included
See https://github.com/msys2/msys2/wiki/MSYS2-introduction for general
information about msys2 development environments

==Libusb-win32 runtime==
To use libusb-win32 programs, the driver must be installed. The recommended way
to do this is with Zadig (http://zadig.akeo.ie/) as described on
http://chdk.fandom.com/wiki/PTP_Extension#Installing_LibUSB_using_Zadig

=Linux development environment=
A working GCC environment and some development libraries are required. The
procedure to install them will vary depending on distro.
Generally: (Deb = Debian-ish package names, Fed=Fedora-ish, YMMV)
* Normal development stuff
 Deb: build-essential
 Fed: groups "Development Tools", "C Development Tools and Libraries"
* Development packages
 All builds
  Deb: libusb-dev, libreadline-dev
  Fed: libusb-devel, readline-devel
  A separate package for libusb 0.1 compatibility may be required
 GUI, CD/IUP precompiled
  Deb: libfreetype6-dev
  Fed: freetype-devel
 GUI, CD/IUP from source
  Deb: g++ libfreetype6-dev libgtk-3-dev libx11-dev libxpm-dev libxmu-dev libxft-dev
  Fed: gcc-c++ freetype-devel gtk3-devel libX11-devel libXpm-devel libXmu-devel libXft-devel
 Readline is optional in chdkptp, but highly recommended and expected by the default Lua build
* GUI, LGI from OS packages
 Lua development packges
  Deb: liblua5.2-dev or liblua5.3-dev
  Fed: Fedora 33 does not appear to offer compatible packages
 LGI runtime
  Deb: lua-lgi

=Downloading and building dependencies=
If building the IUP GUI or a CLI-only executable, the recommended way to obtain
external dependencies is the shell script
 misc/setup-ext-libs.bash
Passing -h displays help describing options and prerequisites

To build the LGI GUI, using OS provided Lua and LGI packages is recommended. In
this case, you must configure config.mk manually, as described in
"Configuring Makefiles" below.

setup-ext-libs.bash downloads current recommended 3rd party libraries, building
as required.  No additional makefile configuration should be required on Linux
or msys2. On MacOS 11 (and likely other versions), it can be used to build Lua
for a cli-only binary with -nogui, but cannot be used to build the GUI files
on any recent MacOS version.

Development and OS package manager supplied dependencies described above
should be installed first.

On windows and 64 bit Linux, setup-ext-libs.bash downloads pre-built IUP and CD
libraries. On other platforms, it downloads source and builds as required. On
non-windows platforms -force-tec-src can be used to force building from source.

Use -lua-ver=52 to download and build with Lua 5.2 instead of 5.3

You can use -pretend to show the commands that would be run, including links
to download the files. Additional options are documented in the help.

By default, following directory structure is configured under the chdkptp source
directory
 extlibs/
  archive/ - downloaded packages
  built/ - built or extracted compile time libraries and compile logs
   cd/ - CD libraries, plus headers in include/
   iup/ - IUP libraries, plus headers in include/
   lua5x/ - a Lua install tree
  src/ - extracted source trees
 lib/ - runtime shared libraries (except windows)


==Configuring dependencies manually==
Generally, you need the libraries described in 'dependencies' above,
and to either place them in the structure misc/setup-ext-libs.bash would use
or create config.mk based on the config-*-sample.mk files to set options
and file locations

===Lua===
It is recommend that you build Lua from source, unless using the the LGI GUI
Get the Lua source from http://www.lua.org/download.html

For windows, use something like
make mingw
make local

NOTE:
it's very important that Lua be linked to exactly the same C runtime library
as chdkptp itself. The lbuf file routines expect to be able to fread and fwrite on
a FILE * opened by Lua io.open()

This condition probably won't be met if you use a pre-compiled Lua dll on windows.
It's probably OK with a shared Lua in typical Linux environments.
If in doubt, build your own Lua with the same compiler you build chdkptp with.

===LibUSB===
On Linux, install libusb development package, typically called something like
libusb-dev or libusb-1.0-dev, along with any dependencies.

On windows, download the zip from
https://sourceforge.net/projects/libusb-win32/files/libusb-win32-releases/1.2.6.0/

To run chdkptp on windows, the driver must also be installed as described in
"Libusb-win32 runtime" above.

===GUI Libraries: CD and IUP===
Where available, using pre-built libraries will be simpler to use,
but may on Linux there maybe compatibility issues or graphical glitches
if the binaries weren't built for the same distro and library versions

Pre-built IUP libraries are available from
http://sourceforge.net/projects/iup/files/

Pre-built CD libraries are available from
http://sourceforge.net/projects/canvasdraw/files/

For each package, you must download the main library package, called something
like iup-3.21_Linux313_64_lib.tar.gz and the Lua library from the LuaNN
subdirectory of the Lua version you want to use, called something like
iup-3.21-Lua52_Linux313_64_lib.tar.gz

The LinuxNNN number refers to the kernel version. An exact match for the kernel
you are running is generally not required, but a closer number is usually
preferred.

Unpack all the packages, with both the main library and Lua contents in the
same directory. If you put them in the same structure as would be created
by setup-ext-libs.bash, you won't need to adjust config.mk

===Building IUP and CD===
See the commands used in setup-ext-libs.bash -pretend and instructions under
Guide / Building The Library on the IUP and CD web pages.
Note IUP and CD contain many components not required by chdkptp. Build time
and complexity are significantly reduced by individually building the required
components, as done in setup-ext-libs.bash

===GNU readline===
You need the development package, usually called something like
libreadline-dev

===Configuring makefiles===
Note: This is only required if libraries are installed outside of the default
structure generated by setup-ext-libs.bash, or if other non-standard options
are needed.

Copy config-sample-<platform>.mk to config.mk and edit the values to to reflect
the installation directories of the above packages and desired compile time
options.

To build with Lua 5.3, set USE_LUA_VER=53

If building the IUP GUI, adjust IUP_LIB_DIR, IUP_INCLUDE_DIR,
CD_LIB_DIR and CD_INCLUDE_DIR in config.mk to point to where you unpacked
the packages.

If building the LGI GUI, set
GTK_SUPPORT=1
and make sure the IUP/CD options are unset.

If using distro-provided Lua packages, set the Lua path variables like
LUA_INCLUDE_DIR=/usr/include/lua5.3
LUA_LIB=lua5.3
This may vary depending on the distro and Lua version.

Paths for library and include directories should be absolute, not relative.

==Mac development==
See README-MACOS.TXT but beware it may be incomplete and outdated.
The alternate LGI based GUI can be used on Mac. The IUP/CD GUI likely cannot.

=Building chdkptp=
Run make in the source directory to build chdkptp.

In the default configuration, you can use GUI=1 to build the GUI executable.
Use GUI_SFX=_gui to build a separate gui executable, as used used in the binary
packages.

Use make clean when build configuration has changed or switching between
GUI and CLI builds.

To build a complete zip package, use the script misc/bin-snapshot.bash
On Linux, this defaults to creating a zip with both GUI and CLI executables.
To create a zip with only a CLI executable use
 misc/bin-snapshot.bash -nogui

=Testing your build=
To test some internal functions use
chdkptp -e"exec require'tests':runall()"

This will create a directory call chdkptp-test-data in the current directory,
and delete it when the test completes.

To test functions that connect to the camera, use
chdkptp -e"exec require'camtests'.runbatch{bench=true,filexfer=true}"

If more than one camera is connected to the system, a random one will be used
unless you also specify devspec="<options for connect>"

The filexfer tests will create and delete a local directory called camtests
in the current working directory. If you already have a directory of this name,
it will be deleted when the test completes.

You can add shoot=true to the camtests command to test some shooting related
functions. This will attempt to switch to record mode and shoot. It may fail
on some cameras which have issues with CHDK remoteshoot. Some files
will be created on the camera.

Camtests will also create and delete some files and directories on the camera.

The final line of output from both test modules should mention only passed
and skipped, with no failures

None of the above is a comprehensive test of chdkptp functionality.

=Running=
On windows, double click chdkptp.exe in explorer or run it from the command prompt.
On Linux, chdkptp is normally invoked using the shell script chdkptp.sh, which
sets some required environment variables.

See USAGE.TXT for additional details
