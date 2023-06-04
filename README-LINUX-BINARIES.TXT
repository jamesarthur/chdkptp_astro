The Linux binary packages include GUI and CLI executables, named chdkptp_gui
and chdkptp respectively. To run these, use the corresponding .sh scripts.

The CLI binary should have no external dependencies that aren't part of the
standard system, although differing versions of shared libraries like libc
may still cause problems. You may need to install a libusb-0.1 compatibility
package (called libusb on Fedora, libusb-0.1 on Ubuntu)

These builds may or may not be compatible with distributions different
from the ones used to build. Building from source on the target distribution
using misc/setup-ext-libs.bash should be straightforward on most Linux
distributions and is recommended when possible.

The GUI executable requires IUP and CD libraries. Since these are generally
not available in standard Linux repositories and are non-trivial to build, a 
minimum set of libraries is included in the binary packages.

The GUI libraries may depend on system libraries (x11, gtk etc) which are not
present on your system. You can use ldd to identify the missing libraries, and
your systems package manager to add the required packages. Mismatched versions
may still be a problem.

The packages only include the shared library files. If you want to build
chdkptp from source, you need a full package.

The platforms used for the binaries builds are listed below:


Linux x86_64:
Built on Debian 10 (Buster) x86_64
Known to run on Ubuntu 20.04, Ubuntu 20.10, Fedora 31, Fedora 33
Does NOT run on Ubuntu 18.04

Linux i686:
Built on Debian 10 (Buster) i686

Raspberry pi:
Raspbian 10
Does NOT run on Raspbian 9

Libraries built locally on each platform:
 Lua 5.2.4 https://www.lua.org/ftp/lua-5.2.4.tar.gz
 CD 5.12 https://sourceforge.net/projects/canvasdraw/files/5.12/Docs%20and%20Sources/cd-5.12_Sources.tar.gz
 IUP IUP 3.27 https://sourceforge.net/projects/iup/files/3.27/Docs%20and%20Sources/iup-3.27_Sources.tar.gz

This package contains only runtime files. For raspberry pi, libraries and headers
necessary to build chdkptp with GUI from source are provided in
https://www.assembla.com/spaces/chdkptp/documents as chdkptp-raspbian-libs-20201116.zip
This is only needed if you DO NOT use misc/setup-ext-libs.bash
