# TACTIX Phase I — Final Integration & Release Readiness

Phase I не добавляет миграций. Ожидаемый Alembic head: `0007_thread_branches`.

## После распаковки патча

Из `backend`:

```powershell
python -m alembic current
python -m pytest tests -q
```

Из корня Flutter-проекта:

```powershell
flutter analyze
flutter test --concurrency=1
```

После запуска приложения откройте **«Готовность системы»** из верхней панели или экрана «О системе TACTIX». Для локального backend `/ready` должен показать готовность базы и аутентификации. Если backend недоступен, экран показывает безопасное состояние ошибки без вывода секретов.

## Production

Перед production-сборкой изучите `RELEASE_READINESS_RU.md` и задайте `TACTIX_ENV`, `CORS_ORIGINS`, `TACTIX_RELEASE_ID`, `DATABASE_URL`, `JWT_SECRET_KEY` и необходимые параметры ИИ-контура.
