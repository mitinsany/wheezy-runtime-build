#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
package_dir=${PACKAGE_DIR:-"$root/out/debs"}
if [ ! -d "$package_dir" ]; then
    echo "No .deb packages: directory does not exist: $package_dir" >&2
    exit 1
fi
package_dir=$(CDPATH= cd -- "$package_dir" && pwd)
set -- "$package_dir"/*.deb
if [ ! -f "$1" ]; then
    echo "No .deb packages in $package_dir" >&2
    exit 1
fi

docker run --rm --platform linux/386 --mount "type=bind,src=$package_dir,dst=/packages,readonly" \
    -i debian/eol@sha256:bddcd5525189f4afeb098fba34e3131c1483fe7f54aebfad9befcb481bd8f9ed /bin/sh -s <<'CONTAINER'
set -eu
export DEBIAN_FRONTEND=noninteractive
fail() { echo "Smoke test failed: $*" >&2; exit 1; }

[ "$(dpkg --print-architecture)" = i386 ] || fail 'container is not i386'
[ "$(cat /etc/debian_version)" = 7.11 ] || fail 'container is not Debian Wheezy 7.11'
printf '%s\n' 'deb http://archive.debian.org/debian wheezy main' \
    'deb http://archive.debian.org/debian-security wheezy/updates main' > /etc/apt/sources.list
printf '%s\n' 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive
apt-get update
printf '%s\n' \
    'bf3b1df44c6b8a752c270c22b0057af6fcb301b814f9c594e249f86ccaec6a63  /var/lib/apt/lists/archive.debian.org_debian_dists_wheezy_Release' \
    'a52b27ca2ac5b0b2bdbbae2444ca857c819b0116120df40dba2ee45d949381bd  /var/lib/apt/lists/archive.debian.org_debian-security_dists_wheezy_updates_Release' \
    '4ae2e7ccb87e74d8f2ca09fbc2641d2f9fedbc8b31a33c7cc81e3bac4d418714  /var/lib/apt/lists/archive.debian.org_debian_dists_wheezy_main_binary-i386_Packages.gz' \
    'cab43f54c0c371be2d938c7354cac5225e001bc1bd2b3cdaf2b88504080321d9  /var/lib/apt/lists/archive.debian.org_debian-security_dists_wheezy_updates_main_binary-i386_Packages.gz' | sha256sum -c -
apt-get install -y --no-install-recommends php5-cli php5-sqlite libbz2-1.0 libuuid1 libexpat1 procps file

old_php=$(command -v php)
[ -n "$old_php" ] || fail 'original PHP is missing'
sha256sum "$(readlink -f "$old_php")" > /tmp/old-php.sha256
php -v > /tmp/old-php-version
php -m > /tmp/old-php-modules
php --ini > /tmp/old-php-ini
readlink /lib/i386-linux-gnu/libz.so.1 > /tmp/old-zlib-link
readlink /usr/lib/i386-linux-gnu/libsqlite3.so.0 > /tmp/old-sqlite-link

cat > /usr/sbin/policy-rc.d <<'POLICY'
#!/bin/sh
echo "$*" >> /tmp/service-start-attempts
exit 101
POLICY
chmod 755 /usr/sbin/policy-rc.d
mv /sbin/start-stop-daemon /sbin/start-stop-daemon.real
cat > /sbin/start-stop-daemon <<'DAEMON'
#!/bin/sh
for arg do
    case "$arg" in
        --start|-S) echo "$*" >> /tmp/service-start-attempts; exit 1 ;;
    esac
done
exec /sbin/start-stop-daemon.real "$@"
DAEMON
chmod 755 /sbin/start-stop-daemon

: > /tmp/packages-list
for deb in /packages/*.deb; do
    [ -f "$deb" ] || fail 'no packages found in container'
    name=$(dpkg-deb -f "$deb" Package) || fail "invalid package: $deb"
    arch=$(dpkg-deb -f "$deb" Architecture) || fail "invalid architecture: $deb"
    [ -n "$name" ] || fail "missing package name: $deb"
    [ "$arch" = i386 ] || [ "$arch" = all ] || fail "unexpected architecture $arch: $deb"
    if grep -F -x -q "$name" /tmp/packages-list; then fail "duplicate package: $name"; fi
    echo "$name" >> /tmp/packages-list
done
sqlite_deb=''
zlib_deb=''
for deb in /packages/*.deb; do
    case "$(dpkg-deb -f "$deb" Package)" in
        wr-sqlite) sqlite_deb=$deb ;;
        wr-zlib) zlib_deb=$deb ;;
    esac
done
[ -n "$sqlite_deb" ] && [ -n "$zlib_deb" ] || fail 'SQLite or zlib package missing'
dpkg --unpack "$sqlite_deb"
if dpkg --configure wr-sqlite >/tmp/sqlite-dependency-check.log 2>&1; then
    fail 'SQLite configured without its zlib package'
fi
dpkg -i "$zlib_deb" "$sqlite_deb"
if ldd /usr/lib/i386-linux-gnu/libsqlite3.so.3 | grep -q 'not found'; then
    fail 'SQLite dependency is missing'
fi
dpkg -i /packages/*.deb
audit=$(dpkg --audit) || fail 'dpkg audit failed'
[ -z "$audit" ] || fail 'dpkg reports incomplete packages'
while IFS= read -r name; do
    [ "$(dpkg-query -W -f='${Status}' "$name")" = 'install ok installed' ] || fail "package not installed: $name"
done < /tmp/packages-list

[ ! -s /tmp/service-start-attempts ] || fail 'package attempted to start a service'
ps -eo pid,comm > /tmp/processes || fail 'cannot inspect running processes'
awk 'NR > 1 && $1 != 1 && $2 != "ps" { print; found=1 } END { exit found }' /tmp/processes || fail 'unexpected running process after installation'
[ "$(command -v php)" = "$old_php" ] || fail 'original PHP command changed'
sha256sum -c /tmp/old-php.sha256
php -v > /tmp/new-old-php-version
php -m > /tmp/new-old-php-modules
php --ini > /tmp/new-old-php-ini
cmp /tmp/old-php-version /tmp/new-old-php-version || fail 'original PHP version changed'
cmp /tmp/old-php-modules /tmp/new-old-php-modules || fail 'original PHP modules changed'
cmp /tmp/old-php-ini /tmp/new-old-php-ini || fail 'original PHP configuration changed'
[ "$(readlink /lib/i386-linux-gnu/libz.so.1)" = "$(cat /tmp/old-zlib-link)" ] || fail 'original zlib link changed'
[ "$(readlink /usr/lib/i386-linux-gnu/libsqlite3.so.0)" = "$(cat /tmp/old-sqlite-link)" ] || fail 'original SQLite link changed'
php -r '$db = new PDO("sqlite::memory:"); if ($db->query("select sqlite_version()")->fetchColumn() !== "3.7.13") exit(1);' || fail 'original SQLite changed'
/usr/local/bin/openssl-wheezy list -provider legacy -providers >/dev/null || fail 'OpenSSL legacy provider did not load'
printf abc | /usr/local/bin/openssl-wheezy dgst -sha256 | grep -q 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' || fail 'OpenSSL SHA-256 result is incorrect'

php84=/usr/local/bin/php84-wheezy
[ -x "$php84" ] || fail 'PHP 8.4 executable missing'
file "$php84" | grep -q 'ELF 32-bit.*Intel 80386' || fail 'PHP executable is not i386'
"$php84" --ini | grep -F '/etc/wheezy-php84' >/dev/null || fail 'PHP configuration path points outside the runtime installation'
"$php84" -n -r 'if (strpos(ini_get("extension_dir"), "/stage") !== false) exit(1);' || fail 'PHP extension path points into the build stage'
export MIBDIRS=/usr/share/wheezy-runtime/snmp/mibs MIBS=IF-MIB
"$php84" -r '
if (PHP_MAJOR_VERSION !== 8 || PHP_MINOR_VERSION !== 4) { exit(1); }
if (!extension_loaded("pdo_sqlite") || !extension_loaded("sqlite3") || !extension_loaded("zlib")) { exit(2); }
$db = new PDO("sqlite::memory:");
$db->exec("CREATE TABLE smoke (value TEXT); INSERT INTO smoke VALUES (\x27runtime\x27)");
if ($db->query("SELECT value FROM smoke")->fetchColumn() !== "runtime") { exit(3); }
$data = str_repeat("runtime SQLite zlib ", 100);
$compressed = gzencode($data);
if ($compressed === false || gzdecode($compressed) !== $data) { exit(4); }
echo "PHP ", PHP_VERSION, "; SQLite ", SQLite3::version()["versionString"], "; zlib ", ZLIB_VERSION, "\n";
' || fail 'PHP 8.4, SQLite, or zlib check failed'

mkdir -p /tmp/www
cat > /tmp/httpd.conf <<'HTTPD'
ServerRoot "/opt/wheezy-httpd"
ServerName localhost
Listen 127.0.0.1:18888
PidFile /tmp/httpd.pid
ErrorLog /tmp/httpd.log
LoadModule unixd_module modules/mod_unixd.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule mime_module modules/mod_mime.so
LoadModule php_module modules/libphp.so
User www-data
Group www-data
DocumentRoot "/tmp/www"
TypesConfig /dev/null
<Directory "/tmp/www">
    Require all granted
</Directory>
AddHandler application/x-httpd-php .php
HTTPD
printf '%s\n' '<?php echo PHP_VERSION;' > /tmp/www/index.php
/opt/wheezy-httpd/bin/httpd -d /opt/wheezy-httpd -f /tmp/httpd.conf -t || fail 'Apache configuration failed'
/opt/wheezy-httpd/bin/httpd -d /opt/wheezy-httpd -f /tmp/httpd.conf -k start || fail 'Apache did not start'
"$php84" -r 'if (file_get_contents("http://127.0.0.1:18888/index.php") !== PHP_VERSION) exit(1);' || fail 'Apache did not execute PHP'
/opt/wheezy-httpd/bin/httpd -d /opt/wheezy-httpd -f /tmp/httpd.conf -k stop || fail 'Apache did not stop'
echo 'Wheezy package smoke test passed'
CONTAINER
