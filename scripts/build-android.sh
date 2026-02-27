#!/bin/bash
# =============================================================
# Сборка TaskMate Android APK и деплой через ADB Wi-Fi
#
# Использование:
#   ./scripts/build-android.sh                    # Debug APK (error overlay включён)
#   ./scripts/build-android.sh --release          # Release APK (production, без overlay)
#   ./scripts/build-android.sh --deploy           # Debug + установка
#   ./scripts/build-android.sh --release --deploy # Release + установка
#   ./scripts/build-android.sh --pair --deploy    # Pairing + debug + установка
#
# Переменные окружения:
#   ANDROID_API_URL   - API URL, вшиваемый в APK (из .env или вручную)
#   ADB_PAIR_TARGET   - IP:port для adb pair (из "Сопряжение через код")
#   ADB_PAIR_CODE     - 6-значный код сопряжения с устройства
#   ADB_CONNECT       - IP:port для adb connect (из "IP-адрес и порт" на экране Отладки по Wi-Fi)
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Определяем: podman или docker
if command -v podman &> /dev/null; then
    COMPOSE="podman compose"
else
    COMPOSE="docker compose"
fi

DO_DEPLOY=false
DO_PAIR=false
DO_RELEASE=false
for arg in "$@"; do
    case $arg in
        --deploy)  DO_DEPLOY=true ;;
        --pair)    DO_PAIR=true ;;
        --release) DO_RELEASE=true ;;
    esac
done

# Режим сборки: debug (development) или release (production)
if $DO_RELEASE; then
    VITE_MODE="production"
    GRADLE_TASK="assembleRelease"
    APK_PATH="android/app/build/outputs/apk/release/app-release-unsigned.apk"
    BUILD_LABEL="release"
else
    VITE_MODE="development"
    GRADLE_TASK="assembleDebug"
    APK_PATH="android/app/build/outputs/apk/debug/app-debug.apk"
    BUILD_LABEL="debug"
fi

cd "$PROJECT_ROOT"

# ---- Запуск builder-контейнера ----
echo "==> Запуск android-builder..."
$COMPOSE --profile android up -d android-builder

EXEC="$COMPOSE --profile android exec android-builder"
ADB_EXEC="$COMPOSE --profile android exec -T android-builder"

# ---- ADB pairing (одноразово для каждого устройства) ----
if $DO_PAIR; then
    if [ -z "${ADB_PAIR_TARGET:-}" ] || [ -z "${ADB_PAIR_CODE:-}" ]; then
        echo "ОШИБКА: --pair требует ADB_PAIR_TARGET и ADB_PAIR_CODE"
        echo "  Пример: ADB_PAIR_TARGET=192.168.1.100:37015 ADB_PAIR_CODE=123456 ADB_CONNECT=192.168.1.100:45678 $0 --pair --deploy"
        exit 1
    fi
    echo "==> Запуск ADB-сервера..."
    $ADB_EXEC adb kill-server 2>/dev/null || true
    $ADB_EXEC adb start-server
    echo "==> Сопряжение с устройством $ADB_PAIR_TARGET..."
    $ADB_EXEC adb pair "$ADB_PAIR_TARGET" "$ADB_PAIR_CODE"
fi

# ---- ADB connect (подключение к устройству) ----
if $DO_DEPLOY; then
    if ! $DO_PAIR; then
        $ADB_EXEC adb kill-server 2>/dev/null || true
        $ADB_EXEC adb start-server
    fi
    if [ -n "${ADB_CONNECT:-}" ]; then
        echo "==> Подключение к устройству $ADB_CONNECT..."
        $ADB_EXEC adb connect "$ADB_CONNECT"
    fi
    # Ждём пока устройство появится (mDNS discovery)
    echo "==> Ожидание устройства..."
    sleep 2
    $ADB_EXEC adb devices
    DEVICE_COUNT=$($ADB_EXEC bash -c 'adb devices | grep -c "device$"' || true)
    if [ "${DEVICE_COUNT:-0}" -lt 1 ]; then
        echo "ОШИБКА: Нет подключённых устройств."
        echo "  Укажите ADB_CONNECT=<IP:port> из 'IP-адрес и порт' на экране Отладки по Wi-Fi"
        echo "  Пример: ADB_CONNECT=192.168.1.38:45678 $0 --deploy"
        exit 1
    fi
fi

# ---- npm install ----
echo "==> Установка npm-зависимостей..."
$EXEC npm ci

# ---- Vite build ----
# development → error overlay в index.html (для отладки на устройстве без DevTools)
# production  → без overlay, минифицированный код
echo "==> Сборка web-ассетов (mode: $VITE_MODE, API: ${ANDROID_API_URL:-из .env})..."
$EXEC npx vite build --mode "$VITE_MODE"

# ---- Capacitor sync ----
echo "==> Синхронизация Capacitor..."
$EXEC npx cap sync android

# ---- Gradle build ----
echo "==> Сборка $BUILD_LABEL APK..."
$EXEC bash -c "cd android && ./gradlew $GRADLE_TASK"

echo "==> APK собран: TaskMateClient/$APK_PATH"

# ---- Деплой на устройство ----
if $DO_DEPLOY; then
    # Определяем целевое устройство (ADB_CONNECT или первое найденное)
    if [ -n "${ADB_CONNECT:-}" ]; then
        ADB_DEVICE="-s $ADB_CONNECT"
    else
        ADB_DEVICE=""
    fi
    echo "==> Установка APK на устройство..."
    $ADB_EXEC adb $ADB_DEVICE install -r "$APK_PATH"
    echo "==> Запуск приложения..."
    $ADB_EXEC adb $ADB_DEVICE shell am start -n com.server.app/.MainActivity
    echo "==> Готово! Приложение установлено и запущено."
else
    echo "==> Готово! APK: TaskMateClient/$APK_PATH"
    echo "    Для деплоя: $0 --deploy (устройство должно быть сопряжено)"
fi
