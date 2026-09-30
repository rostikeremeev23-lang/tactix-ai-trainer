# TACTIX — готовность к пилотной эксплуатации

Phase I переводит проект из режима активной разработки в режим контролируемой подготовки релиза. Цель этапа — не добавлять ещё один большой модуль, а сделать состояние системы наблюдаемым, конфигурацию предсказуемой и сборку воспроизводимой.

## Что считается готовым

TACTIX считается готовым к пилотному запуску, когда одновременно выполнены условия:

- backend отвечает на `/ready` со статусом `ready`;
- PostgreSQL доступна и актуальна до `0007_thread_branches`;
- `JWT_SECRET_KEY` настроен и имеет длину не менее 32 байт;
- production CORS задан явно через `CORS_ORIGINS`;
- `python -m pytest tests -q` проходит без ошибок;
- `flutter analyze` не находит проблем;
- полный `flutter test --concurrency=1` проходит;
- Android/Windows release-сборка создаётся с явными `dart-define` параметрами;
- секреты не вшиты в исходный код и не попадают в Git.

## Серверные переменные окружения

Обязательные для рабочего server-контурa:

- `DATABASE_URL` — PostgreSQL;
- `JWT_SECRET_KEY` — секрет подписи сессий;
- `TACTIX_ENV=production` — включает production-поведение конфигурации;
- `CORS_ORIGINS=https://...` — разрешённые origin через запятую;
- `TACTIX_RELEASE_ID=...` — идентификатор конкретного релиза.

ИИ-контур является дополнительным: можно задать `GEMINI_API_KEY` либо локальный `OLLAMA_URL`. При его отсутствии основные модули TACTIX остаются диагностируемыми, а клиент может использовать автономные функции.

## Клиентские параметры сборки

Пример для Windows:

```powershell
flutter build windows --release `
  --dart-define=TACTIX_API_URL=https://YOUR-BACKEND `
  --dart-define=AI_BACKEND_URL=https://YOUR-BACKEND `
  --dart-define=TACTIX_RELEASE_ID=1.0.0-rc1 `
  --dart-define=TACTIX_BUILD_CHANNEL=pilot
```

Пример для Android:

```powershell
flutter build apk --release `
  --dart-define=TACTIX_API_URL=https://YOUR-BACKEND `
  --dart-define=AI_BACKEND_URL=https://YOUR-BACKEND `
  --dart-define=TACTIX_RELEASE_ID=1.0.0-rc1 `
  --dart-define=TACTIX_BUILD_CHANNEL=pilot
```

Release APK должен подписываться штатным release-ключом организации. Phase I не создаёт и не распространяет ключи подписи.

## Диагностика

В интерфейсе доступен экран **«Готовность системы»**. Он показывает только безопасную техническую сводку:

- доступность базы данных;
- готовность аутентификации;
- состояние ИИ-контура как дополнительного компонента;
- версию и окружение backend;
- перечень возможностей текущего релиза.

Пароли, токены, API-ключи, `DATABASE_URL` и другие секреты endpoint `/ready` не возвращает.

## Роли

Текущая серверная модель разграничивает роли `trainee`, `instructor` и `admin`. Права на операции должны проверяться backend-ом; скрытие кнопки во Flutter является только UX-слоем и не заменяет серверную авторизацию.

## Перед пилотом

Перед передачей сборки пилотной группе необходимо создать отдельную production/staging БД, применить Alembic до `head`, создать администраторскую учётную запись штатным инструментом, проверить восстановление после потери сети и отдельно пройти сценарии входа, синхронизации, Digital Thread, Training, Simulation Lab, ASK TACTIX, Branch и PULSE.
