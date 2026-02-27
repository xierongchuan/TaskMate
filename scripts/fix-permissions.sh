#!/bin/bash
# fix-permissions.sh — Универсальная настройка прав для TaskMateServer
# Использование: ./scripts/fix-permissions.sh (БЕЗ sudo!)
#
# Результат:
#   - Хост-юзер (temur) владеет ВСЕМИ файлами → git, редактор, всё работает
#   - Контейнерный www-data получает доступ через ACL → PHP читает код, пишет в storage
#   - Не нужен podman unshare, не нужен sudo

set -euo pipefail

DIR="TaskMateServer"

if [ ! -d "$DIR" ]; then
    echo "Ошибка: директория $DIR не найдена. Запускайте из корня TaskMate."
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "Ошибка: не запускайте от root/sudo."
    exit 1
fi

# --- Вычисление host UID для www-data (uid 33 в контейнере) ---
SUBUID_START=$(grep "^$(whoami):" /etc/subuid | head -1 | cut -d: -f2)
if [ -z "$SUBUID_START" ]; then
    echo "Ошибка: не найден subuid для $(whoami) в /etc/subuid"
    exit 1
fi
# Container uid 0 → host uid (current user)
# Container uid 1 → host subuid_start
# Container uid 33 → host subuid_start + 32
WWW_DATA_HOST_UID=$((SUBUID_START + 32))

echo "=== Настройка прав для $DIR ==="
echo "    Хост-юзер: $(whoami) (uid $(id -u))"
echo "    www-data на хосте: uid $WWW_DATA_HOST_UID"
echo ""

# --- 1. Вернуть владение хост-юзеру ---
# podman unshare нужен только здесь — чтобы забрать файлы у 524320 обратно
echo "[1/6] Возврат владения хост-юзеру..."
podman unshare chown -R 0:0 "$DIR"

# --- 2. Базовые права ---
# Директории: rwxr-xr-x (755), файлы: rw-r--r-- (644)
echo "[2/6] Базовые права (755/644)..."
find "$DIR" -type d -exec chmod 755 {} +
find "$DIR" -type f -exec chmod 644 {} +

# --- 3. Исполняемые файлы ---
echo "[3/6] Исполняемые файлы..."
chmod 755 "$DIR/artisan"
[ -d "$DIR/vendor/bin" ] && find "$DIR/vendor/bin" -type f -exec chmod 755 {} + || true

# --- 4. Защита .env ---
echo "[4/6] Защита .env (640)..."
[ -f "$DIR/.env" ] && chmod 640 "$DIR/.env"
[ -f "$DIR/.env.testing" ] && chmod 640 "$DIR/.env.testing"

# --- 5. ACL: www-data чтение кода (для bind-mount) ---
echo "[5/6] ACL: www-data читает проект..."
# Сброс старых ACL
setfacl -R -b "$DIR"
# Чтение + переход по директориям (rX)
setfacl -R -m u:"$WWW_DATA_HOST_UID":rX "$DIR"
setfacl -R -d -m u:"$WWW_DATA_HOST_UID":rX "$DIR"

# --- 6. ACL: www-data запись в storage и bootstrap/cache ---
echo "[6/6] ACL: www-data пишет в storage и bootstrap/cache..."
setfacl -R -m u:"$WWW_DATA_HOST_UID":rwX "$DIR/storage" "$DIR/bootstrap/cache"
setfacl -R -d -m u:"$WWW_DATA_HOST_UID":rwX "$DIR/storage" "$DIR/bootstrap/cache"
# .env — только чтение для www-data
[ -f "$DIR/.env" ] && setfacl -m u:"$WWW_DATA_HOST_UID":r "$DIR/.env"
[ -f "$DIR/.env.testing" ] && setfacl -m u:"$WWW_DATA_HOST_UID":r "$DIR/.env.testing"

echo ""
echo "=== Готово! ==="
echo ""
echo "Владелец всех файлов: $(whoami) (uid $(id -u))"
echo "ACL для www-data (uid $WWW_DATA_HOST_UID):"
echo ""
echo "  Путь                         Права     Описание"
echo "  ─────────────────────────     ─────     ──────────────────────────"
echo "  $DIR/                    rX        чтение кода"
echo "  $DIR/storage/            rwX       запись логов, кеша, загрузок"
echo "  $DIR/bootstrap/cache/    rwX       запись кеша конфигурации"
echo "  $DIR/.env                r         чтение конфигурации"
echo "  $DIR/artisan             r-x       исполнение"
echo ""
echo "Проверка: getfacl $DIR/storage"
