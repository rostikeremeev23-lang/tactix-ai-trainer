# TACTIX THREAD — Phase H

Phase H: Russian UX + Product Definition + Final Integration.

## Что входит

- русификация основных пользовательских экранов TACTIX;
- `THREAD / Digital Thread` → `Цифровой контур`;
- `ASK THREAD` → `Анализ TACTIX`;
- `Training` → `Подготовка`;
- `Simulation Lab` → `Центр моделирования`;
- `Branch` → `Вариант плана`;
- `PULSE` → `Контроль процессов`;
- русские статусы, приоритеты, виды связей, события и подписи графа;
- отдельный экран `О системе TACTIX` с определением продукта;
- `PRODUCT_DEFINITION_RU.md` для документации и доклада;
- сохранение внутренних API-кодов на английском, чтобы не ломать backend-протокол.

## Установка

Распаковать содержимое ZIP в корень:

`C:\Users\admin\Desktop\ai_trainer_mobile`

с заменой файлов.

## Проверка

```powershell
cd "C:\Users\admin\Desktop\ai_trainer_mobile\backend"
python -m alembic current
python -m pytest tests -q

cd "C:\Users\admin\Desktop\ai_trainer_mobile"
flutter analyze
flutter test --concurrency=1
```

Phase H не добавляет миграций. Ожидаемый Alembic head: `0007_thread_branches`.

После зелёных тестов:

```powershell
.\COMMIT_PHASE_H.ps1
```
