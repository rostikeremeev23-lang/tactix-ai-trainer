# TACTIX

Existing Flutter decision-training application with a Python/FastAPI backend.

TACTIX THREAD now has a working Case/evidence foundation with authorized history,
verification, closure and durable offline commands. The full Thread roadmap remains
in progress. See [current scope, migration, tests and launch commands](THREAD_IMPLEMENTATION.md).

Training -> Simulation Lab includes three fictional city scenarios, an offline vector map,
deterministic playback, editable plans, a local run archive and comparison.

See [implementation, scope and exact PowerShell commands](NEXT_GENERATION.md) and
[backend authentication setup](backend/AUTH.md).

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```
