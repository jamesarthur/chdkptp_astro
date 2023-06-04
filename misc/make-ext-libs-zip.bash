#!/bin/bash
# make a zip of the build files in extlibs/built
name=`basename "$0"`

function error_exit {
	echo "$name error: $1" >&2
	exit 1
}

function warn {
	echo "$name warning: $1" >&2
}

function usage {
	[ "$1" ] && warn "$1"
	cat >&2 <<EOF
make a zip of the build files in extlibs/built
usage:
  $name [options]
options:
 -pretend: print actions without doing them

EOF
	exit 1
}

arg="$1"
pretend=""

distutildir="$(dirname "$(readlink -f "$0")")"
srcroot="$(dirname $distutildir)"
libroot="./extlibs/built"

while [ ! -z "$arg" ] ; do
	case $arg in
	-pretend)
		pretend="1"
	;;
	*)
		usage "unknown option $arg"
	;;
	esac
	shift
	arg="$1"
done

if [ -z "$pretend" ] ; then
	rm=rm
	zip=zip
	cp=cp
else
	rm="echo rm"
	zip="echo zip"
	cp="echo cp"
fi
OSTYPE=`uname -o`
ARCH=`uname -m`
if [ "$OSTYPE" = "Msys" ] ; then
	OS="win"
else 
	OS=`uname -s`
fi
OSARCH="$OS-$ARCH"

cd $srcroot || error_exit "cd $srcroot failed O_o"

if [ ! -d "$libroot" ] ; then
	error_exit "missing $libroot"
fi

ZIPNAME="chdkptp-$OSARCH-libs-`date +%Y%m%d`".zip

READMENAME="README-chdkptp-$OSARCH-libs.txt"
$cp misc/README-EXT-LIBS-ZIP.TXT $READMENAME
echo $ZIPNAME
if [ -f "$ZIPNAME" ] ; then
	$rm -f "$ZIPNAME"
fi
tozip="$libroot/lua52 $libroot/cd $libroot/iup $READMENAME"

$zip -9 -r "$ZIPNAME" $tozip
