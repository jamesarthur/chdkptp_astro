###############################################################################
# NOTE if misc/setup-ext-libs.bash is used
# a custom config.mk should not be required
# examples below may be out of date
###############################################################################

# configurable build settings
# these can be set on the command line or config.mk
# paths in the various _DIR variables should be absolute paths, not relative

# Lua version
# Lua 5.1 is no longer supported by chdkptp, but it might work
#USE_LUA_VER=51
# Lua 5.3 (experimental)
#USE_LUA_VER=53
# Lua 5.2 (default)
USE_LUA_VER=52

# use GUI=1 on the make command line or uncomment here for GUI support
#GUI=1
ifdef GUI
# should support for the LGI / GTK GUI
#GTK_SUPPORT=1
ifndef GTK_SUPPORT
# should IUP GUI be built ?
IUP_SUPPORT=1
# should CD support be built
CD_SUPPORT=1
# enable "plus" context support for better live view rendering
# some GTK version may use cairo for plus support, requiring libcairo2-dev or similar
#CD_USE_PLUS=cairo
CD_USE_PLUS=1
# suffix for gui enabled executable, used with misc/bin-snapshot.bash to make
# distribution zips with both executables
#EXE_EXTRA=_gui
endif
endif

# include gnu readline support (command history+editing)
# may require libreadline-dev or similar package
READLINE_SUPPORT=1

# should readline be statically linked
# can improve compatibility for binary distribution
#READLINE_STATIC=1
# the follwing may be set if your readline is not in a standard location
#READLINE_LIB_DIR=/path/to/readline/libs
# note code expects for find readline/readline.h
#READLINE_INCLUDE_DIR=/path/to/readline/headers
# library names for -llibfoo, only needed to override defaults
#READLINE_LIB=readline history

# for distro provided Lua (recommended only if using distro provided LGI),
# you probably want something like this. Exact paths may vary depending on
# distro and Lua version, below valid for Debian based distros
ifeq ("$(USE_LUA_VER)","52")
#LUA_INCLUDE_DIR=/usr/include/lua5.2
#LUA_LIB=lua5.2
endif
ifeq ("$(USE_LUA_VER)","53")
#LUA_INCLUDE_DIR=/usr/include/lua5.3
#LUA_LIB=lua5.3
endif

# for self built lua, use something like
#LUA_INCLUDE_DIR=/path/to/installed/lua/include
#LUA_LIB_DIR=/path/to/installed/lua/lib

# compile with debug support
DEBUG=1

# GUI lib paths - only needed if building GUI
# and you haven't installed libs in system directories
#IUP_LIB_DIR=/path/to/iup
#IUP_INCLUDE_DIR=/path/to/iup/include
#CD_LIB_DIR=/path/to/cd
#CD_INCLUDE_DIR=/path/to/cd/include

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

