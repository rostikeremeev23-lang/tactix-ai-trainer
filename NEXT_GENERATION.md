# Latest checkpoint: TACTIX THREAD (2026-09-30)

See [THREAD_IMPLEMENTATION.md](THREAD_IMPLEMENTATION.md) for the current Phase A/B foundation, migration 0005, API/UI changes, verification, limits and exact continuation point. Historical results below describe earlier work.

# TACTIX NEO - final-evolution implementation update (2026-09-29)

This is the latest incremental implementation status. The repository was already dirty at the start of this cycle, so no reset or destructive Git checkpoint was made. No saved records, keys or local configuration were deleted.

## Completed in this cycle

- Introduced shared TACTIX NEO dark semantic color tokens, spacing/radius/motion constants, and bundled Noto Sans with its OFL license for Cyrillic coverage.
- Connected the existing Strategy multi-select/group controller to its screen: select several markers, name or rename a group, select an existing group, move selected members together, and use the existing undo/redo and local document persistence.
- Added an offline Russian Strategy PDF report built from the deterministic engine state. It includes scenario briefing, seed, score, conditional educational metrics, objective status, the real engine event log and reflection prompts. The bundled font is loaded locally. The report preview exposes system print/save and share actions through `printing`.
- Made Android release signing configurable through the ignored `android/key.properties` file. The build explicitly warns and falls back to the debug key when no release key is configured. A debug-signed APK is for local testing only and must not be distributed.
- Updated the README to remove obsolete claims that report export and Strategy synchronization do not exist.

## Audit findings and remaining work

Existing authentication, local saved sessions, deterministic simulation, instructor assignments/feedback, synchronization queues, AI consent flow and instructor dashboards remain in place. The latest Instructor Command Center implementation and its verification are documented in the section below.

This cycle did not redesign every screen. The launch/auth experience, home workspace, global responsive navigation, AI chat, legacy analytics/settings/profile screens, and visual screenshot review still need a dedicated design and verification pass. Comparison between runs exists in the archive UI, but comparison PDF export was not added here. Device-level Android interaction was not tested. No production keystore exists in the repository; the release APK fallback is debug-signed until an owner-generated key is configured.

## Release signing setup

Generate a private upload key locally; do not check in the resulting file or passwords:

```powershell
keytool -genkeypair -v -keystore android\tactix-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tactix
```

Create `android\key.properties` locally with these properties and real secret values:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=tactix
storeFile=tactix-upload.jks
```

`android/.gitignore` excludes `key.properties` and `*.jks`. Keep secure backups of the generated key. With the key configured, `flutter build apk --release` uses it; without it, the command emits a warning and produces a debug-signed artifact.

## Current verification

- `flutter pub get`: passed after adding `pdf` and `printing`.
- `flutter analyze`: passed with no issues.
- `flutter test`: 94 passed, including new group persistence and offline Cyrillic-PDF tests.
- `python -m pytest tests -q`: 22 passed; one existing Starlette/httpx deprecation warning.
- `python -m alembic heads`: `0004_instructor_center`.
- `git diff --check`: passed (Git reported line-ending normalization warnings only).
- `flutter build windows`: passed; produced `build/windows/x64/runner/Release/TACTIX.exe` (56.9 s).
- `flutter build apk --release`: passed after validating the updated Gradle configuration; produced `build/app/outputs/flutter-apk/app-release.apk` (66.6 MB). No production key is configured, so this artifact uses the debug key and is not distributable.
- No physical Android device, external AI request, production database upgrade, or live two-device synchronization test was run.

## PowerShell launch and build

Run from the repository root:

```powershell
flutter pub get
flutter run -d windows
flutter build windows
flutter build apk --release
```

Android release signing must be configured as described above before distributing an APK.

---
# Instructor Command Center — completed implementation stage (2026-09-29)

This section is the current status and supersedes the instructor-related limitations
in the historical sections below. This stage extends the existing Strategy platform,
authentication and durable synchronization queue. No replacement backend or mock
production dashboard was introduced.

## Audit before implementation

Relevant existing checks were rerun before editing: 22 Flutter authentication/sync tests
and 19 backend tests passed. The existing Strategy UI exposed roster management,
individual assignments, manual progress submission, server-replayed results, feedback,
cancellation and cloud records, but only as a long list. Deadlines, activity timestamps,
overview dashboards and educational comparisons were missing. Migration head was 0003.

Legacy text-based training screens and their assignments remain available. This center
manages fictional Strategy assignments; it does not merge unrelated legacy contracts.

## Implemented

- Direct home entry for server accounts: **ЦЕНТР ИНСТРУКТОРА** for instructor/admin,
  **УЧЕБНЫЙ МАРШРУТ** for trainees. The existing Strategy status bar also opens the center.
- Responsive overview, assignments, results, roster (staff only) and cloud archive.
  Phones use bottom navigation; tablets use a navigation rail; larger screens use an
  extended rail. Dark surfaces and gold/cyan accents reuse the existing TACTIX theme.
- Overview counts assigned trainees, active/completed assignments, pending feedback
  and completion percentage; recent submitted sessions open the existing report.
- Assignment creation selects a managed trainee and one of three fictional city scenarios
  or the current valid map scenario. Optional deadlines can be set, changed or cleared.
  Search, status filters and per-trainee history are available.
- Dates are serialized in UTC with an explicit timezone and displayed in device-local
  time. Overdue work is labeled but can still be submitted; no punitive automatic grade.
- Trainees open assigned scenarios, resume the matching current local exercise,
  send progress or a completed result, inspect reports and read synchronized feedback.
  Opening a different record continues to archive the current local exercise first.
- Per-assignment history records creation, progress, final submission, feedback and
  deadline changes. Earlier feedback text remains in the history.
- Results show dated 0–100 score bars for the last 12 completed sessions, a full completed
  session list, completion statistics and two-session comparison. Comparison shows
  participant, scenario, seed, duration, starting resources and game score.
- Completion = submitted / non-cancelled assignments. Progress = confirmed tick /
  scenario duration. Scores use the existing deterministic server replay. The UI
  explains that differing scenarios/settings affect comparison and that these are
  educational game metrics, not assessments of real-world professional suitability.
- Queued actions and rejected requests remain visible. Feedback drafts survive restart.
  Explicit conflict retry shows current server feedback/status/deadline before the user
  chooses to apply their queued action against the latest known revision.
- Feedback/deadline writes carry stable request UUIDs. Server retries with the same UUID
  and payload return the existing result without duplicating history or mutation.
  Reusing a UUID for a different payload returns 409.
- Successful sequential queued changes advance dependent revisions only when the server
  confirms exactly the next revision; external changes still produce a visible conflict.
- Instructor/admin controls are gated by server-linked roles in the client. The backend
  enforces organization visibility, assigned learner submission and owner/admin writes.
  Trainees cannot change deadlines or feedback. A former trainee promoted to instructor
  does not gain write permission over their former teacher's assignment.

## Data and API compatibility

New migration: **0004_instructor_center**, following **0003_strategy_platform**.
It adds nullable due_at, submitted_at, feedback_at and history columns to
strategy_assignments. Existing IDs, scenarios, submissions, scores, feedback and local
save keys are preserved. No old migration was rewritten.

POST /v1/strategy/assignments gains optional due_at.
PATCH /v1/strategy/assignments/{id}/deadline is the only new endpoint.
Existing feedback accepts optional request_id; all older payloads remain supported.
Assignment responses add timestamps and history without removing existing fields.

Old assignments have no invented historical events. Older completed sessions without
submitted_at fall back to updated_at for display/order; that may reflect a later edit.
New sessions use their actual submission time. Deploy the migration before starting the
updated backend. No migration was applied to a user's live database during this task.

## Actual verification

- flutter analyze: **passed, no issues**.
- flutter test: **92 passed** (86 prior tests + 6 new instructor tests).
- python -m pytest tests -q: **22 passed**, one existing Starlette/httpx deprecation warning.
- python -m alembic heads: **0004_instructor_center (head)**.
- Additive migration test preserves an existing assignment and existing users on SQLite.
- PostgreSQL offline SQL generation for the complete migration chain passes; no live
  PostgreSQL upgrade/downgrade was executed.
- New UI workflow test: instructor creates -> trainee receives -> deterministic scenario
  completes -> offline submission -> application/sync restart -> instructor reviews ->
  feedback -> trainee restart receives feedback.
- New actual FastAPI workflow test independently verifies deadline conversion, late
  submission, persisted scores/feedback/history, repeat login and idempotent retries.
- New tests also cover role denial, stale revisions, timezone validation, preserved
  conflict drafts, transparent statistics and comparison at 390x844, 1024x768, 1440x900.
- UI snapshots were generated and visually inspected:
  artifacts/instructor/overview_390.png, overview_1024.png, overview_1440.png,
  analytics_390.png, analytics_1024.png, analytics_1440.png.
- git diff --check: passed.
- Windows/Android builds were not rerun for this stage. Earlier build results below
  describe the previous stage, not these updated sources.
- No physical Android test, live two-device network acceptance test or external AI
  call was performed. Widget tests use a synthetic transport; FastAPI tests exercise
  the actual API independently with a disposable database.

## Modified files in this stage

- backend/app/models.py
- backend/app/strategy.py
- backend/migrations/versions/0004_instructor_center.py (new)
- backend/tests/test_strategy.py
- lib/features/strategy/studio/data/platform_sync.dart
- lib/features/strategy/studio/domain/training_summary.dart (new)
- lib/features/strategy/studio/presentation/platform_screen.dart
- lib/features/strategy/studio/presentation/studio_screen.dart
- lib/screens/strategy/strategy_screen.dart
- lib/screens/home/home_screen.dart
- test/strategy/studio/instructor_center_test.dart (new)
- test/strategy/studio/platform_sync_test.dart
- NEXT_GENERATION.md

Existing unrelated work, local secrets, assets and saved-data files were retained.

## PowerShell: migration, verification and launch

Use the existing backend environment with DATABASE_URL and JWT_SECRET_KEY configured.
Back up an existing database before applying its next migration.

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile\backend
python -m pytest tests -q
python -m alembic current
python -m alembic upgrade head
python -m uvicorn server:app --host 127.0.0.1 --port 8000
```

In a separate terminal:

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile
flutter analyze
flutter test
flutter run -d windows --dart-define=TACTIX_API_URL=http://127.0.0.1:8000 --dart-define=AI_BACKEND_URL=http://127.0.0.1:8000
```

For screenshot reproduction on Windows with Arial installed:

```powershell
flutter test test/strategy/studio/instructor_center_test.dart --dart-define=CAPTURE_INSTRUCTOR=true
```

Use a server instructor/admin account to manage trainees, and the assigned server
trainee account to submit. Local demonstration accounts do not acquire server roles.

## Remaining boundaries

- Sync still runs while Strategy is mounted and on foreground resume; no OS background
  service was added. Cached assignments/feedback remain available offline.
- Pending offline creation is visible in the action queue and becomes a confirmed
  assignment after the server accepts it. Analytics uses confirmed server results.
- The center uses an instructor's existing roster; named cohorts and bulk assignments
  are outside this stage. All assignment history is retained without artificial truncation;
  very large organizations will need server pagination/retention work.
- Token-group controls and Russian PDF reporting remain separate unfinished stages.
  Production signing, CORS/environment hardening and physical Android validation also
  remain as previously documented.
- No deployment, production migration, signing-key creation or change to AI consent.

---

# TACTIX Next Generation — Phase 2 continuation

## Current verified stage — 2026-09-29

This delivery completes a tested Strategy synchronization integration stage.
It does **not** complete all eight requested phases. Existing uncommitted work,
assets, local configuration, saved-data namespaces and API contracts were preserved.
No signing key was created, database upgraded in place, or deployment performed.

### Audit and implementation checklist

| Area | Current finding / status |
| --- | --- |
| Offline city scenarios, deterministic engine, replay, local archive, comparisons | Already implemented; existing Flutter tests still pass |
| Strategy backend | Existing authenticated records, participants, assignments, submission replay and feedback endpoints were present and registered |
| Frontend synchronization | Queue and platform screen existed but were unreachable from Studio; connected in this stage |
| Offline changes and recovery | Profile-specific durable queue, retry timer, foreground retry, two-generation recovery and visible status connected and tested |
| Cross-device progress | Downloaded plans/runs can be opened explicitly from the platform; current local game is archived first |
| Conflicts | Both versions retained; user chooses primary version and the alternative becomes a separate record |
| Instructor workflow | Existing roster, individual assignment, progress submission, result review, feedback and cancellation UI now reachable from Strategy |
| Instructor Command Center completion | Partial: named groups, group assignment, deadlines, longitudinal educational comparison and a dedicated premium workspace remain |
| Token groups | Controller multiselect/group movement methods and renderer selection support already exist, but main-screen controls and group dragging are not fully wired; group labels/rotation work |
| PDF / Phase 2.1 patch | PHASE2_PATCH_README.md, PDF implementation/dependencies and bundled Cyrillic PDF fonts were not found in the active project |
| Visual redesign | Strategy and shared theme are present; application-wide redesign remains |
| Migration | One head: 0003_strategy_platform, following 0002_invite_codes; adds isolated tables. Tested additive upgrade against SQLite auth fixtures; production PostgreSQL migration not executed |
| Android signing | android/key.properties absent; release explicitly uses debug signing; no production signing configuration added in this stage |
| Security | Existing secure refresh-token store and backend role checks retained; development HTTP defaults, wildcard CORS and production configuration still require hardening |

### Architecture and completed changes

- Studio now creates the existing PlatformSync only for a server-linked profile.
  Local demonstration profiles keep their existing offline behavior.
- Controller save and archive hooks feed the existing queue; old local archives are
  captured when Strategy opens. Sync starts after queue restoration and local capture.
- A Russian status/navigation bar opens the platform from both the library and editor.
  Instructor controls use the server role; authorization remains enforced by FastAPI.
- Current snapshots use a persisted per-device UUID, preventing two devices from
  automatically replacing one another's current exercise. Archive record IDs and
  all existing record IDs remain supported.
- Downloaded records stay in the durable platform mirror. Opening a remote record is
  explicit and archives the current exercise before replacement; it does not
  silently mutate a running simulation or fill the 40-entry local archive.
- Archive capture treats entries as immutable and no longer reapplies an old local
  snapshot after a remote deletion or accepted conflict resolution.
- Edits made during upload keep their newer payload and advance their base revision.
  Lost upload acknowledgements use the backend's existing idempotent record writes.
- Record validation errors remain visible with a retry action without blocking
  downloads. HTTP 408/429 assignment failures remain retryable.
- Queue restoration checks record structure and document validity. Downloaded pages
  are persisted before later assignment requests, reducing loss on subsequent failure.
- All data remains in the existing SharedPreferences / FastAPI architecture.
  No competing sync service or package dependency was introduced.

### Verification performed in this workspace

| Command / check | Result |
| --- | --- |
| flutter pub get | Passed |
| flutter analyze | Passed, no issues after fixing formatting-related lint findings |
| flutter test | 86 passed: 75 existing + 11 new synchronization/UI tests |
| flutter build windows | Passed; build/windows/x64/runner/Release/TACTIX.exe |
| flutter build apk --release | Passed; build/app/outputs/flutter-apk/app-release.apk, 59.2 MB, debug signed |
| python -m pytest tests -q (backend) | 19 passed; existing Starlette/httpx deprecation warning |
| python -m alembic heads (backend) | 0003_strategy_platform (head) |
| git diff --check | Passed |
| flutter devices | Windows, Chrome and Edge only; no connected physical Android device |

New tests cover durable offline recovery, lost acknowledgements, both conflict choices,
remote tombstones, concurrent editing during upload, cross-device simulation restoration,
corrupt generations, profile isolation, rejected records, throttled assignment retries
and opening a remote plan at 390x844. Backend additions cover 100-record pagination,
owner isolation and preservation of existing users during the additive Strategy migration.

Existing tests exercise authentication, role authorization, assignment submission,
simulation completion, reports, replay and saving/restoration. These are automated
component/API/widget checks, **not** a live two-device authentication-to-submission
acceptance test. No PDF test, physical Android profiling, production PostgreSQL upgrade,
real-device cross-device test or live AI-provider test was performed.
Android build emitted Java native-access and Android SDK XML-version warnings.

### Files changed in this continuation

- lib/features/strategy/studio/data/platform_sync.dart
- lib/features/strategy/studio/presentation/platform_screen.dart
- lib/features/strategy/studio/presentation/studio_screen.dart
- test/strategy/studio/platform_sync_test.dart (new)
- backend/tests/test_strategy.py
- NEXT_GENERATION.md

Other modified/untracked files were already present at the beginning of this task;
they were not discarded, committed or claimed as newly implemented here.

### Configuration and exact PowerShell commands

Local Windows development, with backend environment already configured:

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile
flutter pub get
flutter analyze
flutter test
flutter run -d windows --dart-define=TACTIX_API_URL=http://127.0.0.1:8000 --dart-define=AI_BACKEND_URL=http://127.0.0.1:8000
flutter build windows
flutter build apk --debug
flutter build apk --release
```

The last command currently makes a **debug-signed release-mode APK** for local testing.
It is not a production signing workflow. Production signing remains a release gate:
generate a private upload key locally only when approved, keep it outside version control,
supply ignored android/key.properties, and replace Gradle's debug release signing.
Do not overwrite any existing key. No key-generation command was executed.

For a configured HTTPS backend:

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile
$tactixApi = Read-Host 'Backend HTTPS URL without trailing slash'
flutter run -d windows "--dart-define=TACTIX_API_URL=$tactixApi" "--dart-define=AI_BACKEND_URL=$tactixApi"
flutter build windows "--dart-define=TACTIX_API_URL=$tactixApi" "--dart-define=AI_BACKEND_URL=$tactixApi"
flutter build apk --release "--dart-define=TACTIX_API_URL=$tactixApi" "--dart-define=AI_BACKEND_URL=$tactixApi"
```

Backend, in a separate PowerShell terminal:

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile\backend
python -m pip install -r requirements.txt
python -m pytest tests -q
python -m alembic heads
# Set DATABASE_URL and JWT_SECRET_KEY through your local secret environment.
# Back up an existing database and verify its current revision before upgrading.
python -m alembic current
python -m alembic upgrade head
python -m uvicorn server:app --host 127.0.0.1 --port 8000
```

JWT_SECRET_KEY must satisfy the existing backend requirements; see backend/AUTH.md.
Server synchronization requires a server account and the Strategy migration. Local
demo profiles do not upload. Retries run every 30 seconds while Strategy is mounted
and on foreground resume; this is not an OS background synchronization service.
The mirror/outbox remains local JSON storage, not encrypted application data storage.

### Clean continuation point / remaining implementation

1. Finish the instructor workspace: named groups, group assignments, deadlines,
   historical sessions and educational trend comparison. Retain server authorization.
2. Wire and test existing token multiselect/group movement controls, naming/renaming,
   touch selection feedback, undo/redo and saved group restoration.
3. Add Russian PDF export, bundled licensed Cyrillic fonts, decisions/timelines,
   run comparison, local save and native sharing. AI must remain optional.
4. Apply the common visual system to home, navigation, assistant, analytics and
   training workflows; verify mobile/tablet layouts and map/playback performance.
5. Configure explicit production release signing, HTTPS/environment enforcement,
   CORS and error reporting; retain debug development builds.
6. Test live PostgreSQL migrations and a two-device account/assignment journey.
   Test physical Android performance and sharing.
7. Further sync hardening: server retention/quota management (current record cap 500),
   background scheduling if required, richer per-record server-error explanations,
   and idempotent feedback retries after lost responses. Current conflicting/rejected
   actions are retained visibly for review, not silently dropped.

## Historical local-slice notes (superseded by the status above)

The following original implementation notes and original test counts describe the
prior slice. Current completion status, test results and limitations are above.

# TACTIX — Next Generation: local playable slice

This increment extends the existing Strategy Studio, rather than replacing TACTIX.
It is a working offline game slice, not completion of the entire Next Generation specification.

## Repository audit and implementation plan

The app uses Flutter, ChangeNotifier controllers, shared_preferences, secure refresh-token
storage and a Python/FastAPI backend with SQLAlchemy, JWT authentication and organization roles.
The public Strategy route already opened Strategy Studio; a legacy strategy module is retained.
Studio already supplied a deterministic pure-Dart engine, authored events, replay, reports,
AI review adapter and two-generation local session recovery. There were 66 passing Flutter tests.

The implemented plan was to reuse that engine/store, add a three-scenario city catalogue,
version-compatible model fields, a profile-specific archive, native vector map, library/setup,
editor history, comparison and regression tests. The backend schema and existing integrations
were deliberately not migrated in this slice.

## What is implemented

- The existing Strategy route now opens a responsive Russian library with briefing and setup.
- Three fictional scenarios: district resilience, service continuity and multi-sector coordination.
- Difficulty changes available time/resources. Seed controls scripted event timing through stable
  integer arithmetic. The stored event schedule plus command log is authoritative for replay.
- Synthetic ASTRA vector map: river, three sectors, invented bridges, buildings, parks,
  abstract architectural silhouettes; no network tiles or real infrastructure coordinates.
- Existing valley scenarios retain their raster map, geometry and old save keys.
- Selection, placement, long-press drag, zoom/pan, layers, rename, readiness, rotation and group/sector
  labels. Undo/redo covers up to 100 planning edits; it cannot change live/replayed history.
- Ten object categories, including objectives/facilities and eight mobile game-token categories.
  Newly added categories share abstract group movement rules. Group/sector labels and rotation are
  organizational/visual metadata, not collective commands or simulated capabilities.
- Play, pause, step, 1x/2x/4x speed, mandatory event decisions, history scrubbing and retry.
- Per-profile archive of up to 40 plans, paused sessions or completed runs; no silent eviction.
  Completed runs archive automatically. Changing scenarios/retrying first archives the current record.
  Two validated generations and a serialized write queue protect the local archive. Corruption of
  both generations fails visibly without overwriting them. Existing autosave still resumes sessions.
- Archive opens any saved plan/session and compares two completed runs using engine-derived metrics.
  Comparison shows names, seeds and starting settings; it does not imply differently configured runs
  are a controlled experiment. No automatic matching or statistical causal conclusions.
- After-action view lists reached/missed objectives, hold time, resources, explicit score rules,
  confirmed event journal and deterministic reflection questions. Copying the text report is supported.
- AI review remains an optional explanation only. The report requires explicit consent before sending
  its name, game log and metrics through the configured AI service. Scores/events never come from AI.
  The existing offline adapter and local report remain available when AI is absent.
- Shared theme uses restrained warm-metal/cyan colors and consistent button shapes. Existing modules
  remain available; their individual screens have not all been redesigned.

## Game rules and limits

All distances, readiness values, resources and time units are fictional game quantities. Tokens move
on straight lines and can cross visual rivers/buildings; roads and bridges are illustrative, not a
route-planning graph. There is no weapons, terrain-passability, collision or combat model.

Objectives contribute up to 50 points. Defense uses the fraction of ticks with all objectives occupied;
other scenarios use the fraction visited. Remaining score is safety x 0.2 + coordination x 0.2 +
remaining resources x 0.1, rounded. Success additionally requires completion, score >=75 and all
objectives visited (defense: all occupied for at least half the duration). Occupancy radius is 0.055
normalized map units. Readiness affects movement speed; a new route consumes one resource.
Event decisions expose immediate/delayed costs before selection. No real-world assessment is implied.

The editor is a sandbox: objectives, tokens and resources are editable. Scores are local educational
feedback, not tamper-resistant instructor grades. Time stops for event decisions; no real-time
reaction-time scoring or information-uncertainty estimator has been added.

## Verification

Verified in this workspace on 2026-09-28: `flutter analyze` has no issues;
`flutter test` passes all 75 tests (66 existing + 9 new); backend `python -m pytest tests -q`
passes 14 tests with one existing Starlette/httpx deprecation warning. `flutter build windows`
succeeds and produces `build/windows/x64/runner/Release/TACTIX.exe`.
`flutter build apk --release` also succeeds (58.9 MB). Android tooling emits Java native-access
and SDK XML-version warnings, but these did not prevent compilation. The APK uses the repository's
existing debug signing configuration; it is not a store-ready signed release. The final comparison
scrolling change additionally passes the four city UI tests, including comparison on a 390px phone.


New tests cover all 3 scenarios x 3 difficulties, reachable success and worse alternatives,
seed variation, exact replay, backward-compatible saves, archive isolation/concurrent writes/recovery,
undo/redo, touch dragging and the library/save/archive journey at 390x844, 1024x768 and 1440x900.
The retry/compare/report/replay path is also tested on a 390x844 phone. Existing tests cover the full live decision flow
and old scenarios. Screenshot capture is optional and requires Windows Arial for this test harness:

```powershell
flutter test test/strategy/studio/city_ui_test.dart --dart-define=CAPTURE_CITY=true
```

Screenshots go to `artifacts/strategy/city_*.png` (not committed).

## Windows PowerShell: run and build

From the repository root, using the installed Flutter SDK compatible with pubspec.yaml:

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows
flutter devices
$tactixDevice = Read-Host 'Android device ID from flutter devices'
flutter run -d $tactixDevice
flutter build apk --debug
flutter build apk --release
```

Enter the Android identifier reported by `flutter devices` when prompted. The city game itself does not
need a server or an AI key. Use an existing local/demo profile or a previously cached authenticated
profile for offline access. Windows output: `build/windows/x64/runner/Release/TACTIX.exe`;
Android output: `build/app/outputs/flutter-apk/app-release.apk` when Android tooling is available.

For a configured backend, pass both existing URL settings. This example prompts for your own HTTPS
service and does not assume that any demonstration deployment is available:

```powershell
$tactixApi = Read-Host 'Backend HTTPS URL (no trailing slash)'
flutter run -d windows "--dart-define=TACTIX_API_URL=$tactixApi" "--dart-define=AI_BACKEND_URL=$tactixApi"
flutter build apk --release "--dart-define=TACTIX_API_URL=$tactixApi" "--dart-define=AI_BACKEND_URL=$tactixApi"
```

Backend setup retains its current environment contract. Set `DATABASE_URL` and `JWT_SECRET_KEY`
through your secret manager/environment (JWT secret at least 32 UTF-8 bytes), then:

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile\backend
python -m pip install -r requirements.txt
python -m alembic upgrade head
python -m pytest tests -q
python -m uvicorn server:app --host 127.0.0.1 --port 8000
```

See `backend/AUTH.md` for initial organization/admin creation. Gemini uses `GEMINI_API_KEY` and
`AI_MODEL`; existing Ollama configuration is retained. Do not embed provider keys in Flutter builds.
For local Windows development, supply `http://127.0.0.1:8000` to both Dart URL defines and choose
local AI mode with the server URL in settings. A physical Android device needs a reachable host URL.

## Remaining work / release gates

- Strategy archive is local only. No new FastAPI endpoints, cross-device synchronization, conflict
  resolution, instructor assignments/progress views or server-authoritative game-score verification.
- PDF export is not implemented. Reports are selectable/copyable text and in-app views.
- No collective group movement, drag from palette, sector/objective assignment domain model,
  category-specific resource allocation, richer uncertainty model or cinematic camera direction.
- Russian UI is implemented, but project-wide ARB localization extraction is still needed.
- Shared theme refinements are not a complete redesign of authentication/training/instructor/analytics.
- Production hardening remains: auth still has development URL fallbacks, AI retains its existing
  cloud/local routing defaults, Android release currently uses the repository's debug signing config,
  backend CORS/rate-limiting need review, and upload consent must be audited across all older workflows.
  The new Strategy consent is not a claim that every existing AI entry point has been secured.
- No physical Android performance profiling or live Gemini/Ollama/cross-device verification in this slice.
- The archive is small local JSON storage; it is not an encrypted database or a production sync queue.

## Source map

- `lib/features/strategy/studio/domain/city_scenarios.dart`: catalogue, difficulty and seeded timing.
- `domain/scenario.dart`, `domain/engine.dart`: compatible fields and explicit success criteria.
- `data/studio_archive.dart`: validated local archive and serialized persistence.
- `presentation/studio_controller.dart`: editing history, archive/reopen, automatic completed-run save.
- `presentation/city_library.dart`, `archive_screen.dart`, `city_map.dart`: new connected screens/rendering.
- `presentation/studio_screen.dart`, `terrain_view.dart`, `context_panel.dart`, `scenario_editor.dart`,
  `exercise_report.dart`: integrated controls, touch manipulation and review.
- `lib/screens/strategy/strategy_screen.dart`: existing public entry point retained.
- `lib/app/theme.dart`: shared colors and control styling.
- `test/strategy/studio/city_test.dart`, `city_ui_test.dart`: new domain/store/controller/journey checks.
- Existing `test/strategy/studio/ui_test.dart`: retains old full-flow coverage through explicit direct-editor entry.

## 2026-09-30 — TACTIX THREAD Phase D

THREAD is now connected to the existing Training / Simulation Lab workflow instead of operating as an isolated case-management module.

Implemented:
- Case -> Simulation Lab assignment linking.
- Linked training panel inside Case detail.
- Training nodes in Digital Thread Graph.
- Import of completed Simulation Lab result as traceable Evidence.
- `TRAINING_COMPLETED` Case timeline event and `WAITING_FOR_VERIFICATION` transition.
- Backend authorization and provenance checks.
- Offline durable `TRAINED_BY` relation queue.

Backend verification: 34 tests passed in the packaging environment. Run the full Flutter test suite locally before release/commit.
