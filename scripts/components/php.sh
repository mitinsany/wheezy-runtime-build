#!/bin/sh
set -eu

src="$WORK/php"
cp -R "$SRC/upstream/php" "$src"
cd "$src"
./buildconf --force
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export LD_LIBRARY_PATH="$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export ac_cv_header_immintrin_h=no
export CFLAGS='-O0 -g'
export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
export LIBS='-lrt'
./configure --prefix=/usr/local/wheezy-php84 --with-pic \
    --with-config-file-path=/etc/wheezy-php84 --with-config-file-scan-dir=/etc/wheezy-php84/conf.d \
    --with-apxs2="$PREFIX/apache24/bin/apxs" \
    --disable-opcache --with-openssl --with-curl --enable-mbstring --enable-bcmath \
    --enable-calendar --enable-exif --enable-ftp --with-gettext \
    --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --enable-pcntl \
    --with-snmp="$PREFIX" --enable-soap --enable-sockets --enable-shmop \
    --enable-sysvmsg --enable-sysvsem --enable-sysvshm --with-bz2 --with-zlib
make -j"$NPROC"
mkdir -p "$PREFIX/bin" "$PREFIX/apache24/modules"
cp sapi/cli/php "$PREFIX/bin/php"
cp libs/libphp.so "$PREFIX/apache24/modules/libphp.so"
