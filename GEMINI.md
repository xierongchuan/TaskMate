# ♊ GEMINI Project Knowledge Base

## Обзор проекта

TaskMate - это комплексная система управления задачами с веб-интерфейсом.

## 🛠 Технологический стек

### Frontend (`TaskMateFrontend`)

- **Framework**: React 19.1
- **Build Tool**: Vite 7.1
- **Language**: TypeScript 5.9
- **State Management**: Zustand 5
- **Styling**: TailwindCSS 3.4
- **Routing**: React Router 7.9
- **API/Query**: TanStack Query (React Query) v5
- **Forms**: React Hook Form
- **Icons**: Heroicons

### Backend (`TaskMateBackend`)

- **Framework**: Laravel 12
- **Language**: PHP 8.4
- **API Auth**: Laravel Sanctum
- **Cache/Queue**: Valkey (Redis-compatible) via Predis
- **Testing**: Pest PHP
- **Database**: PostgreSQL 18

### Infrastructure

- **Containerization**: Docker Compose
- **Application Server**: FrankenPHP v1 (Caddy-based)
- **Reverse Proxy**: Nginx (frontend + SSL termination)
- **Database**: PostgreSQL 18
- **Cache**: Valkey (Redis-compatible)
- **SSL**: Certbot (Let's Encrypt)

## 📂 Структура проекта

- `TaskMateFrontend/`: Исходный код веб-приложения (React).
- `TaskMateBackend/`: Исходный код бэкенда REST API (Laravel).
- `nginx/`: Конфигурации Nginx для dev и prod.
- `docker-compose*.yml`: Оркестрация контейнеров.

## 🚀 Основные команды

### Запуск (Docker)

```bash
docker compose up -d --build
```

### Тестирование

**Backend (Pest):**

```bash
docker compose exec backend_api php artisan test
```

## ⚠️ Правила разработки (User Rules)

1. **Язык**: Русский.
2. **Backend**:
   - При любых изменениях **ВСЕГДА** запускать тесты.
   - Проверять актуальность тестов.
   - Обновлять README.md после успешных изменений.
3. **Frontend & API**:
   - При изменении Backend проверять совместимость с Frontend и документацией API.
   - При изменении Frontend сверяться с документацией API.

## 📝 Заметки

- Проект использует **Laravel 12** и **PHP 8.4**.
- Используется **React 19** для фронтенда.
- При работе с инструментами окружения используй всё через docker контейнеры.
