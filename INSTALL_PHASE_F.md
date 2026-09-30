# TACTIX THREAD — Phase F

Phase F adds **TACTIX BRANCH**: isolated planning variants for administrative and training Case work.

## What changes

- Staff can fork a live THREAD Case into a named planning Branch.
- A Branch can propose Case description, priority, status, owner and due date changes.
- A Branch can hold up to 40 planned TASK / TRAINING / REVIEW items with assignee, due date and note.
- Compare is deterministic and server-side.
- Merge uses a three-way comparison: Branch base vs current live Case vs Branch draft.
- Unrelated live changes are preserved automatically.
- Overlapping divergent edits block merge.
- Warnings cover past due dates, plan items after Case due date, duplicate items, and linked training scheduled after the proposed Case due date.
- A successful merge writes an immutable `BRANCH_MERGED` Case event; Branch history is also immutable.
- Branch cannot close a Case or bypass Evidence verification.

## Database migration

Phase F adds migration:

`0007_thread_branches`

After copying the patch into the project, run from `backend` with your existing `DATABASE_URL`:

```powershell
python -m alembic upgrade head
python -m alembic current
```

Expected head:

`0007_thread_branches (head)`

## Verification

```powershell
cd C:\Users\admin\Desktop\ai_trainer_mobile\backend
python -m pytest tests -q

cd ..
flutter analyze
flutter test --concurrency=1
```

Packaging-environment backend verification: **40 passed**.
Flutter SDK is not installed in the packaging environment; run Flutter verification on the Windows development machine before committing.

## Commit

When migration and tests are green:

```powershell
cd C:\Users\admin\Desktop\ai_trainer_mobile
.\COMMIT_PHASE_F.ps1
```

If PowerShell blocks scripts:

```powershell
powershell -ExecutionPolicy Bypass -File ".\COMMIT_PHASE_F.ps1"
```

Recommended tag after commit:

```powershell
git tag -a tactix-thread-phase-f-green -m "Stable checkpoint: Phase F TACTIX BRANCH"
git push origin master
git push origin --tags
```
