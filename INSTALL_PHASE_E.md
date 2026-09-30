# TACTIX THREAD — Phase E install

Baseline expected: `tactix-thread-phase-d-green` / commit `0335729`.

1. Extract the Phase E patch directly into the repository root:
   `C:\Users\admin\Desktop\ai_trainer_mobile`
2. Allow overwrite of the listed source files.
3. Phase E has no new Alembic migration; the expected database head remains `0006_thread_relations`.
4. Run:

```powershell
cd "C:\Users\admin\Desktop\ai_trainer_mobile"
flutter analyze
flutter test --concurrency=1
cd .\backend
python -m pytest tests -q
python -m alembic current
```

Expected backend tests after this patch: `37 passed`.
Expected Alembic head: `0006_thread_relations (head)`.

ASK THREAD uses the existing backend AI provider configuration (Gemini cloud with the existing Ollama fallback). Do not put provider secrets into Flutter or commit `.env` files.

When all checks are green, return to repository root and run `COMMIT_PHASE_E.ps1`.
