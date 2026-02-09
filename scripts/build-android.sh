#!/bin/bash
# =============================================================
# Сборка TaskMate Android APK и деплой через ADB Wi-Fi
#
# Использование:
#   ./scripts/build-android.sh                  # Только сборка
#   ./scripts/build-android.sh --deploy         # Сборка + установка
#   ./scripts/build-android.sh --pair --deploy  # Pairing + сборка + установка
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
for arg in "$@"; do
    case $arg in
        --deploy) DO_DEPLOY=true ;;
        --pair)   DO_PAIR=true ;;
    esac
done

cd "$PROJECT_ROOT"

# ---- Запуск builder-контейнера ----
echo "==> Запуск android-builder..."
$COMPOSE --profile android up -d android-builder

EXEC="$COMPOSE --profile android exec android-builder"

# ---- ADB pairing (одноразово для каждого устройства) ----
if $DO_PAIR; then
    if [ -z "${ADB_PAIR_TARGET:-}" ] || [ -z "${ADB_PAIR_CODE:-}" ]; then
        echo "ОШИБКА: --pair требует ADB_PAIR_TARGET и ADB_PAIR_CODE"
        echo "  Пример: ADB_PAIR_TARGET=192.168.1.100:37015 ADB_PAIR_CODE=123456 ADB_CONNECT=192.168.1.100:45678 $0 --pair --deploy"
        exit 1
    fi
    echo "==> Сопряжение с устройством $ADB_PAIR_TARGET..."
    $EXEC adb pair "$ADB_PAIR_TARGET" "$ADB_PAIR_CODE"
fi

# ---- ADB connect (подключение к устройству) ----
if $DO_DEPLOY; then
    if [ -n "${ADB_CONNECT:-}" ]; then
        echo "==> Подключение к устройству $ADB_CONNECT..."
        $EXEC adb connect "$ADB_CONNECT"
    fi
    # Ждём пока устройство появится (mDNS discovery)
    echo "==> Ожидание устройства..."
    sleep 2
    $EXEC adb devices
    DEVICE_COUNT=$($EXEC bash -c 'adb devices | grep -c "device$"' || true)
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

# ---- Vite build с Android API URL ----
echo "==> Сборка web-ассетов (API: ${ANDROID_API_URL:-из .env})..."
$EXEC bash -c 'npm run build'

# ---- Capacitor sync ----
echo "==> Синхронизация Capacitor..."
$EXEC npx cap sync android

# ---- Gradle assembleDebug ----
echo "==> Сборка debug APK..."
$EXEC bash -c 'cd android && ./gradlew assembleDebug'

APK_PATH="android/app/build/outputs/apk/debug/app-debug.apk"
echo "==> APK собран: TaskMateClient/$APK_PATH"

# ---- Деплой на устройство ----
if $DO_DEPLOY; then
    echo "==> Установка APK на устройство..."
    $EXEC adb install -r "$APK_PATH"
    echo "==> Запуск приложения..."
    $EXEC adb shell am start -n ru.andcrm.vfp/.MainActivity
    echo "==> Готово! Приложение установлено и запущено."
else
    echo "==> Готово! APK: TaskMateClient/$APK_PATH"
    echo "    Для деплоя: $0 --deploy (устройство должно быть сопряжено)"
fi
