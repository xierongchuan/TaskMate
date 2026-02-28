# AGENTS.md — Code Mode

This file provides non-obvious coding rules discovered by reading the codebase.

## Client Rules

### State Management — Two Layers
- **Zustand** — client state (auth, workspace, sidebar). Persist in localStorage.
- **TanStack Query** — server data. ALWAYS use `dealershipId` in queryKey.

```typescript
// CORRECT: placeholderData prevents UI flickering on filter changes
useQuery({
  queryKey: ['tasks', dealershipId, filters],
  queryFn: () => tasksApi.getAll({ ...filters, dealership_id: dealershipId }),
  placeholderData: (prev) => prev,
});

// WRONG: without placeholderData — UI flickers on every request
useQuery({ queryKey: ['tasks'], queryFn: tasksApi.getAll });
```

### Permissions
- ALWAYS use `usePermissions()` — NEVER check `user.role` directly
```typescript
const { canManageTasks, canCreateUsers, isOwner } = usePermissions();
{canManageTasks && <Button onClick={handleCreate}>Создать</Button>}
```

### Dates
- Server sends UTC ISO with Z suffix: `"2024-01-15T10:30:00Z"`
- Use utilities from `src/utils/dateTime.ts`:
```typescript
import { formatDateTime, toUtcIso, parseUtc } from '@/utils/dateTime';
```

### API Modules
- Use modules from `src/api/` — NEVER use axios directly
- Pattern: object with methods, typed response
```typescript
export const tasksApi = {
  getAll: async (params?: Filters): Promise<PaginatedResponse<Task>> => {
    const response = await apiClient.get('/tasks', { params });
    return response.data;
  },
};
```

## Server Rules

### Controller → Service → Model
- Business logic in Services, thin Controllers
- Models use `toApiArray()` for responses — NOT API Resources (except User, Shift)

### Eager Loading — Mandatory
```php
// CORRECT: prevents N+1
$tasks = Task::with(['creator', 'assignments.user', 'responses.proofs'])->get();

// WRONG: lazy loading causes N+1
$tasks = Task::all();
foreach ($tasks as $task) { $task->creator->name; }
```

### Validation
- ALWAYS use Form Requests in `app/Http/Requests/Api/V1/`
- NEVER validate in controller via `$request->validate()`

### Dates
- All dates UTC. Use `TimeHelper`:
```php
use App\Helpers\TimeHelper;
$now = TimeHelper::nowUtc();
$iso = TimeHelper::toIsoZulu($carbon); // "2024-01-15T10:30:00Z"
```

## Security Rules

### Server Security (PHP/Laravel)
- **SQL Injection Prevention**: Always use parameter bindings, never concatenate SQL
```php
// CORRECT
$tasks = Task::where('dealership_id', $dealershipId)->get();

// WRONG - vulnerable to SQL injection
$tasks = Task::whereRaw("dealership_id = $dealershipId")->get();
```

- **XSS Prevention**: Escape output in responses
```php
// For API JSON responses - Laravel's json() automatically escapes strings
return response()->json(['message' => $userInput]);

// If manual escaping needed, use e() helper
return response()->json(['message' => e($userInput)]);
```

- **Command Injection Prevention**: NEVER use `exec()`, `shell_exec()`, `system()` with user input
```php
// WRONG
$filename = $request->input('filename');
exec("rm /tmp/{$filename}");

// Use whitelist approach instead
$allowedActions = ['cleanup', 'archive'];
$action = $request->input('action');
if (!in_array($action, $allowedActions)) {
    abort(403);
}
```

- **File Upload Security**
```php
// Always validate MIME type and extension
$request->validate([
    'file' => 'required|file|mimes:jpg,png,pdf|max:10240',
]);

// Generate random filename
$filename = Str::random(40) . '.' . $request->file('file')->getClientOriginalExtension();
```

- **Memory Safety**
```php
// Use chunking for large datasets
Task::chunk(100, function ($tasks) {
    foreach ($tasks as $task) {
        // Process in batches
    }
});

// Limit query results
$tasks = Task::limit(1000)->get();
```

### Client Security (React/TypeScript)

- **XSS Prevention**: Never use `dangerouslySetInnerHTML` with user data
```tsx
// WRONG
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// Use textContent or React's automatic escaping
<div>{userContent}</div>
```

- **Memory Leak Prevention**
```tsx
// Always clean up subscriptions and timers
useEffect(() => {
  const subscription = api.subscribe(data => setData(data));
  const timer = setInterval(fetchData, 5000);
  
  return () => {
    subscription.unsubscribe();
    clearInterval(timer);
  };
}, []);

// Use WeakMap for caching large objects
const cache = new WeakMap<object, Data>();
```

- **Secure API Calls**
```tsx
// Always validate response data
const { data } = await apiClient.get('/tasks');
const tasks = z.array(TaskSchema).parse(data);

// Use parameterized queries for search
const params = { search: searchTerm };
// Never: `/api/tasks?filter=${searchTerm}`
// Always: `/api/tasks?filter=${encodeURIComponent(searchTerm)}`
```

### Best Practices

1. **Defense in Depth** - Validate on both client AND server
2. **Least Privilege** - Request minimum permissions needed
3. **Fail Securely** - Default deny, fail gracefully
4. **Don't Break Existing Functionality** - Security changes must not break features

## Forbidden

- Direct role checks (`user.role === 'owner'`) — use `usePermissions()`
- Server data in Zustand — use TanStack Query
- `keepPreviousData` (deprecated) — use `placeholderData: (prev) => prev`
- MySQL-compatible SQL — use COALESCE not IFNULL
- Logic in controllers — move to Services
- Storage access directly — use `task_proofs` disk + signed URLs (60 min)
