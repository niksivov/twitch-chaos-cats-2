#!/usr/bin/env bash
set -uo pipefail

GODOT_BIN="${GODOT_BIN:-/usr/local/bin/godot}"
APP_DIR="${APP_DIR:-/app}"
GODOT_PORT="${GODOT_PORT:-8080}"
SESSION_IDLE_TIMEOUT="${SESSION_IDLE_TIMEOUT:-600}"

GODOT_PID=""
NODE_PID=""

cleanup() {
	trap - TERM INT
	if [ -n "$NODE_PID" ]; then
		kill "$NODE_PID" 2>/dev/null || true
	fi
	if [ -n "$GODOT_PID" ]; then
		kill "$GODOT_PID" 2>/dev/null || true
	fi
	if [ -n "$NODE_PID" ]; then
		wait "$NODE_PID" 2>/dev/null || true
	fi
	if [ -n "$GODOT_PID" ]; then
		wait "$GODOT_PID" 2>/dev/null || true
	fi
}
trap cleanup TERM INT

echo "START: Godot :${GODOT_PORT}, автоочистка сессий ${SESSION_IDLE_TIMEOUT} с"
"$GODOT_BIN" --headless --path "$APP_DIR" res://scenes/server.tscn -- \
	--port="$GODOT_PORT" \
	--session-idle-timeout="$SESSION_IDLE_TIMEOUT" &
GODOT_PID=$!

# Ждём, пока Godot откроет порт, чтобы Render не начал health-check слишком рано.
READY=0
for _ in $(seq 1 120); do
	if ! kill -0 "$GODOT_PID" 2>/dev/null; then
		echo "START: Godot завершился до открытия порта" >&2
		cleanup
		exit 1
	fi
	if (echo > "/dev/tcp/127.0.0.1/${GODOT_PORT}") 2>/dev/null; then
		READY=1
		break
	fi
	sleep 0.5
done
if [ "$READY" -ne 1 ]; then
	echo "START: Godot не открыл порт ${GODOT_PORT} за 60 секунд" >&2
	cleanup
	exit 1
fi

export WS_PORT="$GODOT_PORT"
node "$APP_DIR/tools/serve_web.js" &
NODE_PID=$!

# Render шлёт SIGTERM; ждём завершения любого из процессов.
set +e
wait -n "$GODOT_PID" "$NODE_PID"
STATUS=$?
set -e

if ! kill -0 "$GODOT_PID" 2>/dev/null; then
	echo "START: Godot завершился, останавливаю контейнер" >&2
	cleanup
	exit 1
fi
if ! kill -0 "$NODE_PID" 2>/dev/null; then
	echo "START: Node завершился с кодом ${STATUS}" >&2
	cleanup
	exit "$STATUS"
fi

# Сюда попадать не должны, но на всякий случай.
cleanup
exit "$STATUS"
