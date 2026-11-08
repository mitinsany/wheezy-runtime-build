#!/bin/sh
set -eu

# Run once when preparing or explicitly upgrading a source pin.
pin() {
    name=$1 url=$2 tag=$3
    if [ ! -e "upstream/$name/.git" ]; then
        git submodule add --depth 1 "$url" "upstream/$name"
    fi
    git -C "upstream/$name" fetch --depth 1 origin "refs/tags/$tag:refs/tags/$tag"
    git -C "upstream/$name" checkout --detach "$tag"
    git add "upstream/$name"
}

pin php https://github.com/php/php-src.git php-8.4.27
pin zlib https://github.com/madler/zlib.git v1.4
pin openssl https://github.com/openssl/openssl.git openssl-3.5.9
pin sqlite https://github.com/sqlite/sqlite.git version-3.54.1
pin curl https://github.com/curl/curl.git curl-8_22_0
pin libxml2 https://github.com/GNOME/libxml2.git v2.14.6
pin oniguruma https://github.com/kkos/oniguruma.git v6.9.10
pin pcre2 https://github.com/PCRE2Project/pcre2.git pcre2-10.49
pin net-snmp https://github.com/net-snmp/net-snmp.git v5.9.5.2
pin apr https://github.com/apache/apr.git 1.7.6
pin apr-util https://github.com/apache/apr-util.git 1.6.6
pin httpd https://github.com/apache/httpd.git 2.4.70
