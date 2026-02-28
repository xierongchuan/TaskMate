# AGENTS.md — Debug Mode

This file provides non-obvious debugging discoveries in this codebase.

## Debugging Tools

### Frontend Debug
- **Auth debugging**: Set `localStorage.setItem('DEBUG_AUTH', 'true')` to enable auth logging in console
- Check `TaskMateClient/src/utils/debug.ts` for debug utilities

### Backend Debug
- Laravel debug mode enabled via `.env` (APP_DEBUG=true)
- RabbitMQ queue monitoring: http://localhost:15672 (guest/guest)

## Common Debugging Scenarios

### Date/Time Issues
- ALWAYS check if dates are in UTC with Z suffix: `"2024-01-15T10:30:00Z"`
- If dates appear wrong, check `TimeHelper::toIsoZulu()` on backend or `dateTime.ts` on frontend
- Timezone issues: dealership-specific timezone affects date comparisons

### Permission Issues
- Use `usePermissions()` hook in frontend — never check roles directly
- Backend uses `HasDealershipAccess` trait for authorization

### N+1 Query Issues
- Check for lazy loading: `$task->creator->name` in loops
- Always use eager loading: `Task::with(['creator', 'assignments.user'])`

### File Upload Issues
- Files stored in `storage/app/private/task_proofs/`
- Access via signed URLs only (60 min expiry)
- Check `TaskProofService` for upload logic

## Log Locations

- Backend: `storage/logs/laravel.log`
- Workers: podman compose logs for each worker service
- Frontend: Browser console + Network tab

## Testing

```bash
# Run specific test
podman compose exec api php artisan test --filter=TaskControllerTest

# Run with coverage
podman compose exec api composer test:coverage
```
