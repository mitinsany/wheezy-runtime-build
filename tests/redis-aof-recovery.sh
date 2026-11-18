#!/bin/sh
set -eu

: "${REDIS_BIN_DIR:?Set REDIS_BIN_DIR to the directory containing redis-server and redis-cli}"
work=$(mktemp -d)
trap '"$REDIS_BIN_DIR/redis-cli" -s "$work/redis.sock" shutdown nosave >/dev/null 2>&1 || :; rm -rf "$work"' EXIT HUP INT TERM

# Legacy single-file RESP AOF containing one complete and one truncated command.
printf '*2\r\n$6\r\nSELECT\r\n$1\r\n0\r\n*3\r\n$3\r\nSET\r\n$4\r\ntest\r\n$2\r\nok\r\n*3\r\n$3\r\nSET\r\n$7\r\npartial\r\n$4\r\n' > "$work/appendonly.aof"
"$REDIS_BIN_DIR/redis-server" --port 0 --unixsocket "$work/redis.sock" \
    --daemonize yes --pidfile "$work/redis.pid" --logfile "$work/redis.log" \
    --dir "$work" --appendonly yes --appendfilename appendonly.aof \
    --aof-load-truncated yes --save ''

attempt=0
while [ "$attempt" -lt 50 ]; do
    if "$REDIS_BIN_DIR/redis-cli" -s "$work/redis.sock" ping 2>/dev/null | grep -qx PONG; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done
if [ "$attempt" -eq 50 ]; then
    cat "$work/redis.log" >&2
    exit 1
fi
test "$("$REDIS_BIN_DIR/redis-cli" -s "$work/redis.sock" get test)" = ok
grep -qi 'truncated' "$work/redis.log"
"$REDIS_BIN_DIR/redis-cli" -s "$work/redis.sock" shutdown nosave
"$REDIS_BIN_DIR/redis-server" --port 0 --unixsocket "$work/redis.sock" \
    --daemonize yes --pidfile "$work/redis.pid" --logfile "$work/redis.log" \
    --dir "$work" --appendonly yes --appendfilename appendonly.aof \
    --aof-load-truncated yes --save ''
attempt=0
while [ "$attempt" -lt 50 ]; do
    if "$REDIS_BIN_DIR/redis-cli" -s "$work/redis.sock" ping 2>/dev/null | grep -qx PONG; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done
if [ "$attempt" -eq 50 ]; then
    cat "$work/redis.log" >&2
    exit 1
fi
test "$("$REDIS_BIN_DIR/redis-cli" -s "$work/redis.sock" get test)" = ok
echo 'Redis loaded legacy AOF with truncated tail'
