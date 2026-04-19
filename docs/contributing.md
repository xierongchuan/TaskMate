# Руководство по контрибьютингу

[← Назад: Установка и развертывание](setup-deployment.md)

## Обзор

TaskMate — монолитное приложение с тремя модулями. Все изменения должны проходить через pull requests с обязательным ревью и тестами.

## Процесс разработки

### 1. Подготовка

```bash
# Клонировать репозиторий
git clone https://github.com/your-org/TaskMate.git
cd TaskMate

# Настроить submodules
git submodule update --init --recursive

# Быстрый старт
podman compose up -d --build
podman compose exec api composer install
podman compose exec api php artisan migrate --force
podman compose exec api php artisan db:seed-demo
```

### 2. Создание ветки

```bash
# Из main/develop
git checkout -b feature/add-task-comments

# Для bugfix
git checkout -b bugfix/fix-date-validation
```

### 3. Разработка

- **Backend изменения:** Запускать тесты после каждого изменения
- **Frontend изменения:** Проверять линтинг и E2E тесты
- **API изменения:** Синхронизировать с frontend и bot
- **Документация:** Обновлять docs/ при изменениях

### 4. Тестирование

```bash
# Backend тесты (ОБЯЗАТЕЛЬНО)
podman compose exec api php artisan test

# Frontend линтинг
podman run --rm -v ./TaskMateClient:/app:z -w /app node:22-alpine npm run lint

# E2E тесты
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test

# Форматирование PHP
podman compose exec api php vendor/bin/pint
```

### 5. Commit

```bash
# Добавить изменения
git add .

# Commit с описательным сообщением
git commit -m "feat: add comments to tasks

- Add comment field to Task model
- Update API endpoints for comments
- Add frontend form for comments
- Update E2E tests"
```

### 6. Push и PR

```bash
# Push ветки
git push origin feature/add-task-comments

# Создать PR на GitHub/GitLab
# - Заполнить описание
# - Прикрепить скриншоты если UI
# - Указать тестирование
```

## Правила для Pull Requests

### Название PR

```
type(scope): description

Types: feat, fix, docs, style, refactor, test, chore
```

### Описание PR

```markdown
## Что изменено

- Добавлено поле comments в Task модель
- Обновлены API эндпоинты /tasks/{id}/comments
- Добавлена форма комментариев во frontend

## Тестирование

- ✅ Backend тесты проходят
- ✅ E2E тесты обновлены
- ✅ Линтинг проходит

## Скриншоты

[Вставить скриншоты UI изменений]
```

### Checklist

- [ ] Тесты написаны/обновлены
- [ ] Линтинг проходит
- [ ] Документация обновлена
- [ ] Миграции проверены
- [ ] Синхронизация модулей проверена
- [ ] E2E тесты проходят

## Работа с модулями

### Синхронизация API

При изменении backend API:

1. **Обновить API ресурсы** в backend
2. **Проверить frontend** — обновить API модули и компоненты
3. **Проверить bot** — обновить httpx клиент и handlers
4. **Запустить все тесты**

### Submodules

```bash
# Обновить submodule
cd TaskMateClient
git pull origin main
cd ..
git add TaskMateClient
git commit -m "chore: update frontend submodule"

# Или cherry-pick
git cherry-pick <commit-hash>
```

## Code Review

### Критерии одобрения

- **Функциональность:** Код работает как описано
- **Тесты:** Полное покрытие, тесты проходят
- **Качество кода:** Следование конвенциям
- **Безопасность:** Нет уязвимостей
- **Производительность:** Нет degradation

### Ревью checklist

- [ ] SOLID принципы соблюдены
- [ ] Eager loading для N+1 prevention
- [ ] Валидация через Form Requests
- [ ] API Resources для сериализации
- [ ] usePermissions() вместо role checks
- [ ] Async code в bot
- [ ] Даты в UTC
- [ ] Тесты написаны

## Релизы

### Versioning

Использовать Semantic Versioning: `MAJOR.MINOR.PATCH`

### Релиз процесс

1. **Merge в main**
2. **Создать tag:** `git tag v1.2.3`
3. **Push tag:** `git push origin v1.2.3`
4. **CI/CD** автоматически собирает и развертывает

## Troubleshooting

### Submodule не обновляется

```bash
# Очистить и переинициализировать
git submodule deinit -f TaskMateClient
git rm --cached TaskMateClient
git submodule add <url> TaskMateClient
```

### Тесты не проходят

```bash
# Очистить кеш тестов
podman compose exec api php artisan test:clear

# Проверить базу данных
podman compose exec api php artisan migrate:fresh --seed
```

### Frontend не пересобирается

```bash
# Полная пересборка
podman compose build --no-cache svc-frontend
podman compose up -d svc-frontend
```

## Контакты

- **Tech Lead:** [Имя]
- **DevOps:** [Имя]
- **Slack:** #taskmate-dev

## Благодарность

Спасибо за контрибьютинг! Ваши изменения делают TaskMate лучше.

[← Назад: Установка и развертывание](setup-deployment.md)
