#!/usr/bin/env bash
set -euo pipefail

# TaskMate reverse tunnel: доступ к локальному dev через удалённый сервер.
# Использование: ./scripts/tunnel.sh [start|stop|status|restart]

REMOTE_USER="root"
REMOTE_HOST="173.212.212.236"
REMOTE_PORT="9099"
LOCAL_PORT="8099"
SSH_KEY="$HOME/.ssh/dev_tunnel"
PID_FILE="/tmp/taskmate-tunnel.pid"

start_tunnel() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Туннель уже запущен (PID: $(cat "$PID_FILE"))"
        echo "Доступ: http://$REMOTE_HOST"
        return 0
    fi

    echo "Запуск reverse tunnel..."
    echo "  Локальный:  localhost:$LOCAL_PORT"
    echo "  Удалённый:  $REMOTE_HOST:$REMOTE_PORT -> tunnel -> localhost:$LOCAL_PORT"
    echo "  Доступ:     http://$REMOTE_HOST"

    ssh -f -N \
        -R "127.0.0.1:${REMOTE_PORT}:localhost:${LOCAL_PORT}" \
        -i "$SSH_KEY" \
        -o "ServerAliveInterval=30" \
        -o "ServerAliveCountMax=3" \
        -o "ExitOnForwardFailure=yes" \
        -o "StrictHostKeyChecking=accept-new" \
        -o "ConnectionAttempts=3" \
        "${REMOTE_USER}@${REMOTE_HOST}"

    # Найти PID SSH-процесса
    PID=$(pgrep -f "ssh.*-R.*${REMOTE_PORT}:localhost:${LOCAL_PORT}.*${REMOTE_HOST}" | head -1)

    if [ -n "$PID" ]; then
        echo "$PID" > "$PID_FILE"
        echo "Туннель запущен (PID: $PID)"
        echo ""
        echo "Откройте http://$REMOTE_HOST в браузере"
    else
        echo "ОШИБКА: не удалось запустить туннель"
        return 1
    fi
}

stop_tunnel() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "Останавливаю туннель (PID: $PID)..."
            kill "$PID"
            rm -f "$PID_FILE"
            echo "Туннель остановлен."
        else
            echo "Туннель не запущен (устаревший PID-файл). Очистка."
            rm -f "$PID_FILE"
        fi
    else
        echo "Туннель не запущен."
    fi
}

status_tunnel() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Туннель ЗАПУЩЕН (PID: $(cat "$PID_FILE"))"
        echo "Доступ: http://$REMOTE_HOST"
    else
        echo "Туннель НЕ запущен."
        [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
    fi
}

case "${1:-start}" in
    start)  start_tunnel ;;
    stop)   stop_tunnel ;;
    status) status_tunnel ;;
    restart)
        stop_tunnel
        sleep 1
        start_tunnel
        ;;
    *)
        echo "Использование: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
