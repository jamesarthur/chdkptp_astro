###############################################################################
# Sample config.mk for MacOS with GTK GUI
###############################################################################

# configurable build settings
# these can be set on the command line or config.mk
# paths in the various _DIR variables should be absolute paths, not relative

# Lua version
# Lua 5.2
#USE_LUA_VER=52
# Lua 5.3 (default)
USE_LUA_VER=53

# GTK GUI
GTK_SUPPORT=1

# Disable IUP & CD
IUP_SUPPORT=0
CD_SUPPORT=0
CD_PLUS_SUPPORT=0

# include gnu readline support (command history+editing)
# may require libreadline-dev or similar package
READLINE_SUPPORT=1

# the following may be set if your readline is not in a standard location
READLINE_LIB_DIR=/usr/local/opt/readline/lib
# note code expects for find readline/readline.h
READLINE_INCLUDE_DIR=/usr/local/opt/readline/include
# library names for -llibfoo, only needed to override defaults
READLINE_LIB=readline history

# for distro provided Lua, you probably want something like this
# exact paths may vary depending on distro and Lua version
LUA_INCLUDE_DIR=/usr/local/include/lua
LUA_LIB_DIR=/usr/local/lib

# compile with debug support
DEBUG=1

LIBUSB_INCLUDE_DIR=/usr/local/include
LIBUSB_LIB_DIR=/usr/local/lib

# build optional signal module, for automation applications
# not used by default, but source included and should build on any linux
LUASIGNAL_SUPPORT=1

# include svn revision in build number
#USE_SVNREV=1

# You don't need to set this unless you are doing protocol development
# if not set, included copies in the chdk_headers directory will be used
# Used to locate CHDK ptp.h and live_view.h
# this intentionaly uses the ROOT of the CHDK tree, to avoid header name conflicts
# so core/ptp.h should be found relative to this
#CHDK_SRC_DIR=$(TOPDIR)/chdk_headers

# Skip Apple devices (iPhone, iPad, etc)
#CFLAGS+=-DSKIP_VENDORS='0x05AC'
