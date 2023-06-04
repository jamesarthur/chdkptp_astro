chdkptp works on MacOS High Sierra through Monterey. May work on older or newer versions but untested.

The CLI only build works on all versions.

The IUP/CD GUI works on High Sierra and Mojave; but requires manually building and patching the IUP and CD libraries.
See the setup-ext-libs-zip.bash and macports-tecmake.mak.patch files in the misc directory. Requires macports, and does not work with homebrew.
This has not been tested for a long time.

The LGI/GTK Gui works on at least Catalina through Monterey, and may work on other versions of MacOS; but is not tested.

Comments and corrections are welcome on the chdkptp development thread:
http://chdk.setepontos.com/index.php?topic=6231.0

========================

To setup for the LGI/GTK GUI on MacOS using homebrew
- brew install lua@5.3 libusb libusb-compat luarocks cairo pango readline gtk+3 pkg-config gobject-introspection adwaita-icon-theme
- luarocks --lua-dir=/usr/local/opt/lua@5.3 install lgi

On MacOS LGI uses a hard wired path to find the cairo library.
Run the command below to link the cairo library to the required place.
    ln -s /usr/local/lib/libcairo.dylib /usr/local/Cellar/gobject-introspection/1.66.1/lib/libcairo.2.dylib
Update the gobject-introspection version number as needed.
Note the link needs to be re-created if gobject-introspection is updated, and the luarocks lgi command may need to be re-run

Copy the config-sample-macos-gtk.mk file to config.mk and edit if needed.
Build with 'make'

If Lua is updated to 5.4 with homebrew then chdkptp will no longer build or run.
To re-install Lua 5.3 for chdkptp use the following commands:
    brew install lua@5.3
    luarocks --lua-dir=/usr/local/opt/lua@5.3 install lgi
Then set the values in config.mk to:
    LUA_INCLUDE_DIR=/usr/local/opt/lua@5.3/include/lua
    LUA_LIB_DIR=/usr/local/opt/lua@5.3/lib
After rebuilding chdkptp should work again.

========================

To create a cli-only build for for OSX 10.8 and later using homebrew.

- brew install lua libusb libusb-compat
- svn co http://subversion.assembla.com/svn/chdkptp/trunk/ chdkptp
- cp config-sample-macos-gtk.mk config.mk

Edit config.mk and set GTK_SUPPORT=0
Build with 'make'

========================

Running chdkptp on MacOS:

- Add the following line to you .bashrc or .zshrc file:
    export LUA_PATH="$LUA_PATH;./lua/?.lua;"

- To run from the chdkptp directory enter ./chdkptp

- To run from any directory copy the chdkptp-mac.sh file to a folder on your path, and rename to chdkptp.sh. Edit this file and set CHDKPTP_DIR to the correct location.

- For the LGI GUI, you may need to add lua_rocks directories to your LUA paths, like
    export LUA_PATH="$HOME/.luarocks/share/lua/5.3/?.lua;$CHDKPTP_DIR/lua/?.lua;;"
    export LUA_CPATH="$HOME/.luarocks/lib/lua/5.3/?.so;$CHDKPTP_DIR/?.so;;"


examples:
    chdkptp -h
    chdkptp -c

========================

Prevent PTPCamera from hogging (not required on Mojave or later):
    sudo chmod -x "/System/Library/Image Capture/Devices/PTPCamera.app/Contents/MacOS/PTPCamera"
    (more fine-grained control: https://github.com/mejedi/mac-gphoto-enabler/blob/master/gphoto-enable.sh)

========================

A user has also reported success building the IUP/CD GUI libraries in this post.
http://chdk.setepontos.com/index.php?topic=6231.msg96753#msg96753

Note this will no longer work as of Catalina.

========================
