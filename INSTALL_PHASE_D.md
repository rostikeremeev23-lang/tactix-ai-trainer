# TACTIX THREAD — Phase D patch

Apply only after the Phase C baseline is green (`0006_thread_relations (head)`, backend tests green, Flutter tests green).

1. Back up or commit the current Phase C state.
2. Extract this ZIP directly into the project root:
   `C:\Users\admin\Desktop\ai_trainer_mobile`
3. Replace files when Windows asks.
4. No Alembic migration is added by Phase D.
5. Verify:

```powershell
cd "C:\Users\admin\Desktop\ai_trainer_mobile"
flutter analyze
flutter test --concurrency=1

cd ".\backend"
python -m pytest tests -q
python -m alembic current
```

Expected backend migration remains:
`0006_thread_relations (head)`

Expected backend tests for this patch in the packaging environment: `34 passed`.
