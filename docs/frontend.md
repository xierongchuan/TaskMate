# Frontend (React/TypeScript)

[← Назад: Backend](backend.md) | [Далее: Telegram Bot](telegram-bot.md)

## Обзор

Frontend — одностраничное приложение (SPA) на React 19 с TypeScript. Отвечает за интерфейс менеджеров и сотрудников автодилера.

## Стек технологий

- **React**: 19 (новая архитектура)
- **TypeScript**: 5.9 (строгая типизация)
- **Vite**: 7 (быстрая сборка и dev server)
- **Tailwind CSS**: 3.4 (стилизация)
- **TanStack Query**: 5 (серверные данные)
- **Zustand**: 5 (клиентское состояние)
- **React Hook Form**: 7 (формы)
- **Date-fns**: 4 (работа с датами)
- **Capacitor**: 8 (мобильное приложение)

## Структура проекта

```
src/
├── api/              # 15 модулей API клиентов
├── components/
│   ├── ui/           # UI библиотека (Button, Card, Modal)
│   ├── common/       # Общие компоненты (StatusBadge, UserSelector)
│   ├── layout/       # Layout, Sidebar, WorkspaceSwitcher
│   ├── tasks/        # TaskModal, TaskDetailsModal, VerificationPanel
│   └── [domain]/     # generators, shifts, users, dealerships
├── pages/            # 17 страниц-роутов
├── hooks/            # usePermissions, useWorkspace, useSettings
├── stores/           # Zustand stores (authStore, workspaceStore)
├── types/            # TypeScript определения типов
├── utils/            # dateTime.ts, errorHandling, rateLimitManager
├── context/          # ThemeContext (light/dark/system + accent)
└── main.tsx          # Точка входа
```

## Управление состоянием

### Два уровня состояния

#### Zustand — клиентское состояние

Для данных, не требующих синхронизации с сервером.

```typescript
// src/stores/authStore.ts
export const useAuthStore = create<AuthState>(
  persist((set) => ({
    user: null,
    login: (user: User) => set({ user }),
    logout: () => set({ user: null }),
  }), { name: 'auth-store' })
);
```

- **Persist**: Автоматическое сохранение в localStorage
- **Использование**: Auth, sidebar состояние, настройки UI

#### TanStack Query — серверные данные

Для всех данных из API.

```typescript
// ПРАВИЛЬНО: placeholderData предотвращает мигание
const { data: tasks } = useQuery({
  queryKey: ['tasks', dealershipId, filters],
  queryFn: () => tasksApi.getAll({ ...filters, dealership_id: dealershipId }),
  placeholderData: (prev) => prev, // Без мигания при смене фильтров
});
```

- **Query Key**: Всегда включает `dealershipId` для multi-tenant
- **Placeholder Data**: `(prev) => prev` для плавных обновлений

## Права доступа

### usePermissions() — обязательное использование

Никогда не проверять `user.role` напрямую.

```typescript
// src/hooks/usePermissions.ts
export const usePermissions = () => {
  const user = useAuthStore((state) => state.user);
  const dealershipId = useWorkspace().dealershipId;
  
  return {
    canManageTasks: user?.role >= Role.Manager,
    canCreateUsers: user?.role === Role.Owner,
    isOwner: user?.role === Role.Owner,
  };
};

// Использование
const { canManageTasks } = usePermissions();
{canManageTasks && <Button>Создать задачу</Button>}
```

## API интеграция

### Модули API

Типизированные клиенты в `src/api/`.

```typescript
// src/api/tasks.ts
export const tasksApi = {
  getAll: async (params: TaskFilters): Promise<PaginatedResponse<Task>> => {
    const response = await apiClient.get('/tasks', { params });
    return response.data;
  },
  create: async (data: CreateTaskPayload): Promise<ApiResponse<Task>> => {
    const response = await apiClient.post('/tasks', data);
    return response.data;
  },
};

// src/api/client.ts — базовый Axios клиент
const apiClient = axios.create({
  baseURL: '/api/v1',
  headers: { Authorization: `Bearer ${token}` },
});
```

### Запрещено

- Прямое использование axios вне модулей
- `keepPreviousData` (deprecated) — использовать `placeholderData: (prev) => prev`

## Работа с датами

### dateTime.ts — утилиты

Все даты конвертируются из UTC в локальный timezone.

```typescript
import { formatDateTime, toUtcIso, parseUtcDate } from '@/utils/dateTime';

// Backend → Frontend: UTC ISO → локальный формат
const date = parseUtcDate("2024-01-15T10:30:00Z");
formatDateTime(date);  // "15 янв 2024, 15:30"

// Frontend → Backend: локальный → UTC ISO
toUtcIso(localDate);   // "2024-01-15T10:30:00Z"

// Для input[type="datetime-local"]
utcToDatetimeLocal(utcString);   // UTC → value для input
datetimeLocalToUtc(value);       // value → UTC для отправки
```

## Multi-tenant архитектура

### useWorkspace() — единственный источник dealershipId

```typescript
// src/hooks/useWorkspace.ts
export const useWorkspace = () => {
  const { user } = useAuthStore();
  
  // Employee: только свой dealership
  // Manager: назначенные dealerships
  // Owner: все или выбранный
  const dealershipId = user?.dealership_id || selectedDealershipId;
  
  return { dealershipId, dealerships, setSelectedDealership };
};
```

## Компоненты

### UI библиотека

Стандартизированные компоненты в `src/components/ui/`.

```typescript
// src/components/ui/Button.tsx
interface ButtonProps {
  variant?: 'primary' | 'secondary';
  size?: 'sm' | 'md' | 'lg';
  children: ReactNode;
}

export const Button = ({ variant = 'primary', size = 'md', children }: ButtonProps) => (
  <button className={cn(buttonVariants({ variant, size }))}>
    {children}
  </button>
);
```

### Страницы

17 роутов в `src/pages/`.

```typescript
// src/pages/TasksPage.tsx
export const TasksPage = () => {
  const { canManageTasks } = usePermissions();
  const { dealershipId } = useWorkspace();
  
  const { data: tasks } = useQuery({
    queryKey: ['tasks', dealershipId],
    queryFn: () => tasksApi.getAll({ dealership_id: dealershipId }),
  });

  return (
    <div>
      {canManageTasks && <CreateTaskButton />}
      <TasksList tasks={tasks} />
    </div>
  );
};
```

## Темы и стилизация

### Tailwind CSS + dark mode

```typescript
// tailwind.config.js
module.exports = {
  darkMode: 'class', // class strategy
  theme: {
    extend: {
      colors: {
        primary: 'var(--color-primary)',
        accent: 'var(--color-accent)',
      },
    },
  },
};
```

### ThemeContext

```typescript
// src/context/ThemeContext.tsx
export const ThemeProvider = ({ children }: { children: ReactNode }) => {
  const [theme, setTheme] = useState<'light' | 'dark' | 'system'>('system');
  const [accentColor, setAccentColor] = useState('#3b82f6');
  
  return (
    <ThemeContext.Provider value={{ theme, accentColor, setTheme, setAccentColor }}>
      {children}
    </ThemeContext.Provider>
  );
};
```

## E2E тестирование (Playwright)

### Структура тестов

```
tests/
├── setup/
│   ├── auth.setup.ts     # Аутентификация для 4 ролей
│   └── helpers.ts        # Пути к storageState
├── auth/
│   └── login.spec.ts     # Тесты логина
├── pages/                # 16 тестов страниц (owner роль)
│   ├── dashboard.spec.ts
│   ├── tasks.spec.ts
│   └── ...
├── roles/                # 5 ролевых проверок
│   ├── navigation.role-check.spec.ts
│   └── ...
└── .auth/                # Storage state (gitignored)
```

### Конвенции

- **Аутентификация**: `setup/auth.setup.ts` генерирует storageState для всех ролей
- **Waits**: `waitForLoadState('networkidle')` после навигации
- **Локаторы**: Предпочитать `getByRole()`, `getByText()`, `locator('a[href="..."]')`
- **Именование**: `pages/<page>.spec.ts`, `roles/<page>.role-<role>.spec.ts`

### Пример теста

```typescript
// tests/pages/tasks.spec.ts
test('owner can create task', async ({ page }) => {
  await page.goto('/tasks');
  await page.getByRole('button', { name: 'Создать задачу' }).click();
  
  await page.getByLabel('Название').fill('Test Task');
  await page.getByRole('button', { name: 'Сохранить' }).click();
  
  await expect(page.getByText('Test Task')).toBeVisible();
});
```

### Запуск тестов

```bash
# Все тесты (через контейнер)
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test

# Конкретный файл
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test dashboard

# Список тестов
podman run --rm --network host -v ./TaskMateClient:/app:z -w /app mcr.microsoft.com/playwright:v1.58.0-noble npx playwright test --list
```

## Мобильное приложение (Capacitor)

### Сборка APK

```bash
# Debug APK (Vite development mode)
podman compose --profile android build android-builder
./scripts/build-android.sh

# Release APK (Vite production mode)
./scripts/build-android.sh --release
```

### Настройка API URL

```env
# Через туннель
ANDROID_API_URL=http://173.212.212.236/api/v1

# Через LAN
ANDROID_API_URL=http://192.168.1.100:8099/api/v1
```

## Производительность

- **Code Splitting**: Динамические импорты для страниц
- **Memoization**: React.memo для компонентов
- **Query Optimization**: Правильные queryKey и placeholderData
- **Bundle Analysis**: Оптимизация размера бандла

[← Назад: Backend](backend.md) | [Далее: Telegram Bot](telegram-bot.md)
