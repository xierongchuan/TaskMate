# 🚀 TaskMate Dev Container - Quick Start

## Первый запуск (5 минут)

### 1. Откройте проект в Dev Container
```
F1 → "Dev Containers: Reopen in Container"
```

### 2. Дождитесь завершения установки
- Автоматически установятся все зависимости
- Появится сообщение "✨ Dev Container is ready!"

### 3. Инициализируйте проект

```bash
# Перейдите в Backend
cd TaskMateServer

# Запустите миграции
php artisan migrate --force

# Загрузите демо данные
php artisan db:seed-demo

# Создайте ссылку на storage
php artisan storage:link
```

### 4. Запустите разработку

**Терминал 1 - Backend:**
```bash
cd TaskMateServer
composer dev
```

**Терминал 2 - Frontend:**
```bash
cd TaskMateClient
npm run dev
```

### 5. Откройте в браузере
- Frontend: http://localhost:8099
- Backend API: http://localhost:8007

### 6. Войдите в систему
- **Admin:** `admin` / `password`
- **Manager:** `manager1` / `password`
- **Employee:** `emp1_1` / `password`

---

## ⚡ Горячие клавиши и команды

### Частые команды

```bash
# Laravel Artisan (используйте alias)
art migrate          # Миграции
art test            # Тесты
art tinker          # REPL
pint                # Форматирование PHP

# Docker
dc ps               # Статус сервисов
dcl backend_api     # Логи Backend
dcr postgres        # Перезапуск БД

# Навигация
backend             # cd TaskMateServer
frontend            # cd TaskMateClient
```

### VS Code shortcuts

- `Ctrl+Shift+P` - Command Palette
- `Ctrl+Shift+E` - Explorer
- `Ctrl+Shift+D` - Debug
- `Ctrl+Shift+G` - Git
- `Ctrl+J` - Toggle Terminal
- `Ctrl+B` - Toggle Sidebar

---

## 📊 Проверка работы

```bash
# Проверить статус сервисов
docker compose ps

# Проверить подключение к БД
psql -h postgres -U postgres -c "SELECT version();"

# Запустить тесты
cd TaskMateServer && php artisan test
```

---

## 🐛 Частые проблемы

### "Database connection failed"
```bash
docker compose restart postgres
# Подождите 10 секунд и повторите
```

### "Permission denied" для storage
```bash
cd TaskMateServer
chmod -R 775 storage bootstrap/cache
```

### Нужно пересобрать контейнер
```
F1 → "Dev Containers: Rebuild Container"
```

---

## 📚 Полная документация

См. [README.md](./.devcontainer/README.md) для подробной информации.
