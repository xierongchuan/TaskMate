---
name: new-endpoint
description: Создание нового API endpoint в TaskMate. Вызывается автоматически при задачах на новый endpoint, route, контроллер.
---

При создании нового API endpoint в TaskMate строго следуй архитектуре проекта.

## Обязательная структура

### 1. Route
Файл: `TaskMateServer/routes/api_v1.php`
- Группировка по ресурсу
- RESTful naming: `index`, `show`, `store`, `update`, `destroy`
- Middleware: `auth:sanctum` + role-based где нужно

### 2. Form Request (валидация)
Файл: `TaskMateServer/app/Http/Requests/Api/V1/<Resource>/<Action>Request.php`
- Метод `authorize()` — проверка доступа
- Метод `rules()` — правила валидации
- Метод `messages()` — русские сообщения ошибок (если нужны кастомные)

### 3. Controller
Файл: `TaskMateServer/app/Http/Controllers/Api/V1/<Resource>Controller.php`
- Тонкий контроллер — только принимает Request, вызывает Service, возвращает Response
- Используй Resource/Collection для форматирования ответа
- НЕ пиши бизнес-логику в контроллере

### 4. Service
Файл: `TaskMateServer/app/Services/<Resource>Service.php`
- Вся бизнес-логика здесь
- Eager loading для связей (`->with([...])`)
- Даты через `TimeHelper::nowUtc()`, `TimeHelper::toIsoZulu()`

### 5. Resource (API Response)
Файл: `TaskMateServer/app/Http/Resources/V1/<Resource>Resource.php`
- Форматирование ответа
- Даты в ISO 8601 с `Z`

### 6. Тесты
Файл: `TaskMateServer/tests/Feature/<Resource>/<Action>Test.php`
- Pest `describe()/it()` синтаксис
- Покрыть: успех, валидация, авторизация, edge cases
- Минимум 50% покрытие нового кода

## Чеклист перед завершением

- [ ] Route зарегистрирован в `routes/api_v1.php`
- [ ] Form Request создан с правилами валидации
- [ ] Controller тонкий, логика в Service
- [ ] Eager loading для всех связей
- [ ] Даты в UTC
- [ ] Resource для форматирования ответа
- [ ] Тесты написаны и проходят
- [ ] `php vendor/bin/pint` — стиль чистый
