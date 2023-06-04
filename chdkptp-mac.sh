#!/bin/sh
# copy this file to chdkptp.sh and adjust for your configuration
# chdkptp binary
CHDKPTP_EXE=chdkptp

CHDKPTP_DIR=?    'edit and set location where the chdkptp exeutable can be found'

# path for shared libraries
export DYLD_LIBRARY_PATH="$CHDKPTP_DIR/lib"

export LUA_PATH="$CHDKPTP_DIR/lua/?.lua;;"
export LUA_CPATH="$CHDKPTP_DIR/?.so;;"

# for LGI GUI, you may need something like the following
# export LUA_PATH="$HOME/.luarocks/share/lua/5.3/?.lua;$CHDKPTP_DIR/lua/?.lua;;"
# export LUA_CPATH="$HOME/.luarocks/lib/lua/5.3/?.so;$CHDKPTP_DIR/?.so;;"
# or use eval `luarocks --lua-dir=/usr/local/opt/lua@5.3 path` to set luarocks paths

"$CHDKPTP_DIR/$CHDKPTP_EXE" "$@"
