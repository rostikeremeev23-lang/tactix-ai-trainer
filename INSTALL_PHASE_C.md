# TACTIX THREAD — Manual Phase C patch

This patch continues the existing Phase A/B implementation. It must be applied over the
same project version that produced `TACTIX_THREAD_AUDIT.zip`.

## Install

1. Make a backup of `C:\Users\admin\Desktop\ai_trainer_mobile`.
2. Extract this ZIP into the project root and replace matching files.
3. Do NOT delete the existing database.
4. Before applying the migration to the Render/production database, make the normal DB backup.

## Windows validation

```powershell
cd "C:\Users\admin\Desktop\ai_trainer_mobile"
flutter pub get
flutter analyze
flutter test --concurrency=1

cd backend
python -m alembic heads
python -m pytest tests -q
```

Expected Alembic head after the patch:

```text
0006_thread_relations (head)
```

## Local backend migration

Only after the tests are green and the target DB is backed up:

```powershell
cd "C:\Users\admin\Desktop\ai_trainer_mobile\backend"
python -m alembic upgrade head
```

For Render, deploy the updated backend code and run your normal Alembic migration step.
Do not reset or recreate the database.

## New Phase C capability

Open TACTIX THREAD, create at least two Cases, open one Case and choose **Link Case**.
Then use **Graph** / **Open graph**. The graph is Flutter-native and works from cached
records offline. Server-backed relations synchronize through `/v1/thread/relations`.
