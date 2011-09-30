#!/bin/bash

start_dir=$PWD
PROJECT_PATH=$start_dir
if [ $1 ]
then
	PROJECT_PATH=$1
	mkdir -p $PROJECT_PATH
fi
DEP_PATH=$PROJECT_PATH/3rdparty
mkdir -p $DEP_PATH
echo "Project path is $PROJECT_PATH, dependencies will be placed to $DEP_PATH"


COMPILER_PATH=$HOME/toolchains/mingw_w64
mkdir -p $COMPILER_PATH
CROSS_HOST=x86_64-w64-mingw32
CROSS_TRIPLET=${CROSS_HOST}-

tmpdir="$start_dir/.tmp"

mkdir -p $tmpdir
cd $tmpdir

function get_archive {
  url=$1
	arc=$2
	md5=$3
  if [ -f $arc ] && [ `md5sum $arc|cut -d ' ' -f1` == $md5 ]
  then
    echo "$arc already downloaded"
  else 
		wget $url -O $arc
	fi
}

# install cross-toolchain
echo "Starting installation of cross-compiler"

mingw_date='20110822'
mingw_arc="mingw-w64-1.0-bin_x86_64-linux_${mingw_date}.tar.bz2"
mingw_url="http://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win64/Automated%20Builds/${mingw_arc}"
mingw_md5='a8f9f7648ea9847f4b691c1e032c2ce0'
patch0="float_h.patch"
get_archive $mingw_url $mingw_arc $mingw_md5
cd $COMPILER_PATH
tar xjf $tmpdir/$mingw_arc

echo "Applying changes to cross-compiler..."
patch -p0 -f < $start_dir/$patch0 > $start_dir/patch.log

# create symbolic link to avoid case-sensitivity issue in openssl #includes 
ln -s $COMPILER_PATH/$CROSS_HOST/include/winioctl.h $COMPILER_PATH/$CROSS_HOST/include/WinIoCtl.h

echo "Done"
cd -
export PATH=$COMPILER_PATH/bin:$PATH
CXX=x86_64-w64-mingw32-g++

echo "Installed cross-compiler"
$CXX --version

# adding libraries and headers to compiler
echo "Installing additional libs for cross-toolchain"

### install zlib to mingw

echo "Installing zlib"
zlib_ver='1.2.5'
zlib_arc="zlib-$zlib_ver.tar.gz"
zlib_url="http://www.zlib.net/$zlib_arc"
zlib_md5='c735eab2d659a96e5a594c9e8541ad63'
get_archive $zlib_url $zlib_arc $zlib_md5
tar xzf $zlib_arc
cd "zlib-$zlib_ver"
echo $PWD
CROSS_PREFIX=$CROSS_TRIPLET ./configure --prefix $COMPILER_PATH/$CROSS_HOST --64 --static 
sed -i -e "/cp\ \$(SHAREDLIBV)/d" Makefile
make
make install
cd -
echo "zlib installed"
###

### install bzlib to mingw

echo "Installing bzlib"
bzlib_ver='1.0.6'
bzlib_arc="bzip2-$bzlib_ver.tar.gz"
bzlib_url="http://www.bzip.org/$bzlib_ver/$bzlib_arc"
bzlib_md5='00b516f4704d4a7cb50a1d97e6e8e15b'
get_archive $bzlib_url $bzlib_arc $bzlib_md5
tar xzf $bzlib_arc
cd "bzip2-$bzlib_ver"
echo $PWD
make CC=${CROSS_TRIPLET}gcc AR=${CROSS_TRIPLET}ar RANLIB=${CROSS_TRIPLET}ranlib \
   "CFLAGS=-Wall -Winline -O2 -D_FILE_OFFSET_BITS=64" \
   libbz2.a -B
 
install -m 644 libbz2.a $COMPILER_PATH/$CROSS_HOST/lib/
install -m 644 bzlib.h $COMPILER_PATH/$CROSS_HOST/include/

cd -

echo "bzlib installed"
###

### install expat to mingw
echo "Installing expat"
expat_ver='2.0.1'
expat_arc="expat-$expat_ver.tar.gz"
expat_url="http://downloads.sourceforge.net/project/expat/expat/$expat_ver/$expat_arc"
expat_md5='ee8b492592568805593f81f8cdf2a04c'
get_archive $expat_url $expat_arc $expat_md5
tar xzf $expat_arc
cd "expat-$expat_ver"
echo $PWD
./configure --prefix=${COMPILER_PATH}/${CROSS_HOST} --host=${CROSS_HOST}
make && make install
cd -
echo "expat installed"
###

### install freetype to mingw
echo "Installing freetype"
freetype_ver='2.4.4'
freetype_arc="freetype-$freetype_ver.tar.gz"
freetype_url="http://download.savannah.gnu.org/releases/freetype/$freetype_arc"
freetype_md5='9273efacffb683483e58a9e113efae9f'
get_archive $freetype_url $freetype_arc $freetype_md5
tar xzf $freetype_arc
cd "freetype-$freetype_ver"
echo $PWD
./configure --prefix=${COMPILER_PATH}/${CROSS_HOST} --host=${CROSS_HOST} --enable-static --disable-shared
make && make install
cd -
C_FREETYPE_INCLUDE=${COMPILER_PATH}/${CROSS_HOST}/include/freetype2
echo "freetype installed"
###

### install fontconfig to mingw
echo "Installing fontconfig"
fontconfig_ver='2.8.0'
fontconfig_arc="fontconfig-$fontconfig_ver.tar.gz"
fontconfig_url="http://fontconfig.org/release/$fontconfig_arc"
fontconfig_md5='77e15a92006ddc2adbb06f840d591c0e'
get_archive $fontconfig_url $fontconfig_arc $fontconfig_md5
tar xzf $fontconfig_arc
cd "fontconfig-$fontconfig_ver"
echo $PWD
./configure --prefix=${COMPILER_PATH}/${CROSS_HOST} --host=${CROSS_HOST} --enable-static --disable-shared \
	--with-freetype-config=${COMPILER_PATH}/bin/freetype-config --with-arch=x86_64 CFLAGS="-I${C_FREETYPE_INCLUDE}" LDFLAGS="-lfreetype"
sed -i -e "/\$(INSTALL)\ .libs\/libfontconfig.dll.a/d" src/Makefile # we are not trying to install shared lib
make && make install
cd -
echo "fontconfig installed"
###

echo "All additional libs were installed into toolchain"
#########

exit 0 # REMOVE IT 

# build project dependencies

# openssl
echo "Installing openssl"
ssl_ver='1.0.0a'
ssl_arc="openssl-$ssl_ver.tar.gz"
ssl_url="http://www.openssl.org/source/$ssl_arc"
ssl_md5='e3873edfffc783624cfbdb65e2249cbd'
echo "Downloading openssl package"
get_archive $ssl_url $ssl_arc $ssl_md5
ssl_build_dir="openssl-$ssl_ver"
tar xzf $ssl_arc
cd $ssl_build_dir
./Configure no-shared --cross-compile-prefix=$CROSS_TRIPLET --prefix=$DEP_PATH/openssl mingw64
make && make install 
cd -
echo "openssl installed"
###

# dbcxx

###

# pthread

###

# boost

###

# qt

###

#########

# clone project
cd $project_path
bqt_url="https://github.com/laanwj/bitcoin-qt.git"
echo "Cloning project to project_path"
git clone $bqt_url bitcoin-qt
echo "Project cloned from $bqt_url"
#########

# build project

#########

cd $start_dir
