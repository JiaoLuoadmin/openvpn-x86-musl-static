#!/bin/bash

set -e
set -x

mkdir ~/openvpn && cd ~/openvpn

DEST=`pwd`
SRC=$DEST/src

WGET="wget --prefer-family=IPv4"

CC=$DEST/bin/musl-gcc
LDFLAGS="-L$DEST/lib -Wl,-rpath,$DEST/lib"
CPPFLAGS="-I$DEST/include"
CFLAGS="-D_GNU_SOURCE -D_BSD_SOURCE"
CXXFLAGS=$CFLAGS
CONFIGURE="./configure --prefix=$DEST"

MAKE="make -j`nproc`"
mkdir -p $SRC

######## ####################################################################
# MUSL # ####################################################################
######## ####################################################################

mkdir $SRC/musl && cd $SRC/musl
$WGET http://www.musl-libc.org/releases/musl-1.1.5.tar.gz
tar zxvf musl-1.1.5.tar.gz
cd musl-1.1.5

./configure \
--prefix=$DEST \
--exec-prefix=$DEST \
--syslibdir=$DEST/lib

$MAKE
make install

########## ##################################################################
# KERNEL # ##################################################################
########## ##################################################################

mkdir $SRC/kernel && cd $SRC/kernel
$WGET https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.2.60.tar.xz
tar xvJf linux-3.2.60.tar.xz
cd linux-3.2.60
cp -rf ./include $DEST
ln -s asm-generic $DEST/include/asm
cd $DEST/include/netinet

sed -i 's,struct ethhdr {,\/*\nstruct ethhdr {,g' if_ether.h
sed -i 's,#include <net/ethernet.h>,*/\n\n#include <net/ethernet.h>,g' if_ether.h

######## ####################################################################
# ZLIB # ####################################################################
######## ####################################################################

mkdir $SRC/zlib && cd $SRC/zlib
$WGET http://zlib.net/zlib-1.2.8.tar.gz
tar zxvf zlib-1.2.8.tar.gz
cd zlib-1.2.8

CC=$CC \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE

$MAKE
make install

####### #####################################################################
# LZO # #####################################################################
####### #####################################################################

mkdir $SRC/lzo2 && cd $SRC/lzo2
$WGET http://www.oberhumer.com/opensource/lzo/download/lzo-2.08.tar.gz
tar zxvf lzo-2.08.tar.gz
cd lzo-2.08

CC=$CC \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-shared

$MAKE
make install

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

mkdir $SRC/openssl && cd $SRC/openssl
$WGET https://www.openssl.org/source/openssl-1.0.1i.tar.gz --no-check-certificate
tar zxvf openssl-1.0.1i.tar.gz
cd openssl-1.0.1i

cat << "EOF" > openssl-musl.patch
--- a/crypto/ui/ui_openssl.c    2013-09-08 11:00:10.130572803 +0200
+++ b/crypto/ui/ui_openssl.c    2013-09-08 11:29:35.806580447 +0200
@@ -190,9 +190,9 @@
 # undef  SGTTY
 #endif

-#if defined(linux) && !defined(TERMIO)
-# undef  TERMIOS
-# define TERMIO
+#if defined(linux)
+# define TERMIOS
+# undef  TERMIO
 # undef  SGTTY
 #endif
EOF

patch -p1 < openssl-musl.patch

./Configure linux-x86_64 \
-D_GNU_SOURCE -D_BSD_SOURCE \
-Wl,-rpath,$DEST/lib \
--prefix=$DEST shared zlib zlib-dynamic \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=$CC
make CC=$CC install

########### #################################################################
# OPENVPN # #################################################################
########### #################################################################

mkdir $SRC/openvpn && cd $SRC/openvpn
$WGET http://swupdate.openvpn.org/community/releases/openvpn-2.3.4.tar.gz
tar zxvf openvpn-2.3.4.tar.gz
cd openvpn-2.3.4

LZO_CFLAGS="-I$DEST/include" \
LZO_LIBS="-L$DEST/lib" \
OPENSSL_SSL_CFLAGS="-I$DEST/include" \
OPENSSL_SSL_LIBS="-L$DEST/lib" \
OPENSSL_CRYPTO_CFLAGS="-I$DEST/include" \
OPENSSL_CRYPTO_LIBS="-L$DEST/lib" \
CC=$CC \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--sysconfdir=/etc \
--localstatedir=/var \
--with-crypto-library=openssl \
--disable-plugin-auth-pam \
--enable-password-save

$MAKE LIBS="-all-static -lssl -lcrypto -llzo2"
make install
