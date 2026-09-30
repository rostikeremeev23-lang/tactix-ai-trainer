# TACTIX THREAD — Phase G / PULSE

Phase G adds a read-only process intelligence layer over existing THREAD data.

## What changed

- TACTIX PULSE dashboard for staff users.
- Deterministic metrics for active, overdue, due-soon, stale and verification-waiting Cases.
- Evidence, Branch and Training backlog counters.
- Current-stage backlog cards based on Case update age.
- Unified Event Stream across Case, Branch, relation and Simulation Lab activity.
- Alerts open the related Case directly.
- PULSE data is cached locally for review, but refresh requires the server.
- No AI is used to calculate PULSE metrics or alerts.
- No new database migration is required; Alembic remains at `0007_thread_branches`.

## Install

Extract the patch into:

`C:\Users\admin\Desktop\ai_trainer_mobile`

and allow replacement of existing files.

## Verify

```powershell
cd "C:\Users\admin\Desktop\ai_trainer_mobile\backend"
python -m alembic heads
python -m alembic current
python -m pytest tests -q

cd "C:\Users\admin\Desktop\ai_trainer_mobile"
flutter analyze
flutter test --concurrency=1
```

Expected Alembic head/current: `0007_thread_branches (head)`.

The packaging environment executed the backend suite successfully: **42 passed**.
Flutter must be verified on the Windows development machine before commit/tag.

## Commit

After all checks are green:

```powershell
cd "C:\Users\admin\Desktop\ai_trainer_mobile"
.\COMMIT_PHASE_G.ps1
```

If PowerShell blocks scripts:

```powershell
powershell -ExecutionPolicy Bypass -File ".\COMMIT_PHASE_G.ps1"
```
