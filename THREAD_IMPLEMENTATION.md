# TACTIX THREAD checkpoint — 2026-09-30

This is an incremental Phase A / Phase B foundation in the existing application.
The full TACTIX THREAD definition of done has NOT been reached. Phases C–H remain.
Existing uncommitted work was retained; no deployment or live database migration ran.

## Targeted implementation map

| Area | Finding / reuse |
| --- | --- |
| COMPLETED / REUSABLE | Auth/session gates and server roles; HomeScreen Navigator routes; NEO tokens; deterministic Strategy Studio; scenarios; local archives/replay/comparison; PDF; instructor center; training assignments; authenticated PlatformApi and durable PlatformSync patterns |
| PARTIAL | Product-wide navigation consistency; mounted-screen synchronization; assignment-specific event history |
| MISSING AT START | Case/evidence domain, cross-entity thread relationships/graph, source compiler, Ask Thread, Branch, Pulse |

README.md, NEXT_GENERATION.md, pubspec.yaml, app/home/theme, training/assignment entry points, Strategy Studio/store/archive/sync/PDF, AIService, backend models/auth/router and migrations were inspected. PHASE2_PATCH_README.md and repository AGENTS.md were absent. Generated folders were excluded from the audit.

Initial copies of the first affected files and HEAD are in `.git/tactix-thread-before`.
This is a local file checkpoint, not a commit or full repository backup. A stalled
generated Flutter test cache was later preserved there separately.

## Implemented

### Phase A: Training / Simulation Lab

- TrainingHubScreen groups Simulation Lab, existing scenarios, assignments, interactive stories and server instructor access.
- Home training entries lead to this workspace. The isolated desktop Strategy destination is removed.
- SimulationLabScreen subclasses the existing StrategyStudioScreen. TactixStrategyScreen remains a compatible public alias with the original user/library/platform options.
- Visible simulator/library branding changes to Simulation Lab. Legacy class names, record IDs, local save namespaces, simulation engine and `/v1/strategy` APIs are retained.
- Thread is accessible from the home card, desktop sidebar and mobile navigation; profile and instructor entry points are retained.

### Phase B foundation: Cases, history and evidence

- Create and read Cases; update status with a required reason; flexible states including reopening. API creation supports type, priority, owner and due date; the initial UI uses self-owned Issue/Normal Cases.
- Actual local/server Case counts, cached Case search, desktop/tablet split view and mobile detail view. Empty state explains traceability and verification. No fabricated production data.
- Evidence metadata/notes with supporting context and source text; instructor/admin acceptance or rejection with a review note, reviewer and timestamp.
- Closure requires at least one evidence item, ALL evidence verified, and an instructor/admin. RESOLVED alone does not establish verification. Closed Cases must be reopened before evidence or verification changes.
- Append-only application event API; creation, status before/after, closure/reopening, evidence and review history. No event edit/delete routes. This is not a tamper-proof ledger against database administrators.
- Revision compare-and-swap and event append share a transaction. Failed requests roll back. Stable request UUIDs and payload hashes prevent duplicate events after lost acknowledgements; changed content under the same request ID returns 409.
- Case and event queries enforce organization access. Trainees see Cases they created or own; instructor/admin roles can view/manage their organization's Cases. Only staff can assign creation to another active member, verify evidence, close or reopen a closed Case.
- Case/event endpoints paginate. Evidence is bounded to 200 items per Case.
- Existing PlatformApi gains an optional API prefix, defaulting to `/v1/strategy`; Thread uses `/v1/thread`. Auth, refresh and transport errors are reused.
- Profile-specific durable Case mirror/outbox follows the existing two-generation SharedPreferences pattern, isolated from simulator payloads. Offline creation, status/evidence changes and pending review commands survive restart. Writes serialize; save failures restore the prior in-memory state.
- Synchronization runs on entry, foreground resume and every 30 seconds while Thread is mounted. Original UUIDs survive retries. Authorization/validation/conflict failures remain visible; one failed Case does not block other Cases.
- Conflict review shows confirmed server state separately from the local draft. Applying queued actions requires the exact reviewed server revision; earlier draft payloads/revisions remain in local conflict history. There is no silent last-write-wins replacement.
- Pending verification/closure never appears confirmed or green offline. Local demo users can create Cases/evidence but cannot establish server verification.
- Corrupt snapshots are preserved. With an older valid copy, recovery makes additional backups and displays a warning; with no valid copy, writes are blocked.

## Additive migration

`backend/migrations/versions/0005_thread_cases.py`, following `0004_instructor_center`:

- `thread_cases`
- `thread_case_events`
- `thread_evidence`

Existing migrations/tables are unchanged. The migration was exercised against a
disposable SQLite auth database with existing users; model-column parity was checked.
The existing full-chain PostgreSQL offline SQL test passed. No live PostgreSQL upgrade
was executed. Back up the target database before running the upgrade command below.

## Added API routes

All routes use existing authenticated identity/organization dependencies.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/v1/thread/cases?after=UUID&limit=40` | Authorized paginated Cases |
| POST | `/v1/thread/cases` | Idempotent creation |
| GET | `/v1/thread/cases/{id}` | Case including evidence metadata |
| PATCH | `/v1/thread/cases/{id}` | Revisioned status change / close / reopen |
| GET | `/v1/thread/cases/{id}/events?after=REVISION&limit=50` | Append-only paginated history |
| POST | `/v1/thread/cases/{id}/evidence` | Add evidence metadata |
| POST | `/v1/thread/cases/{id}/evidence/{evidence_id}/verify` | Staff verification/rejection |

Creation takes a client `id` and `request_id`. Mutations take `request_id` and
`base_revision`. Full request/response schemas are in FastAPI `/docs`. Neither
Case deletion nor evidence deletion is exposed; historical records are retained.

## Files changed in this session

New:

- `lib/screens/training/training_hub_screen.dart`
- `lib/features/thread/thread_store.dart`
- `lib/features/thread/thread_screen.dart`
- `backend/app/thread.py`
- `backend/migrations/versions/0005_thread_cases.py`
- `backend/tests/test_thread.py`
- `test/training_navigation_test.dart`
- `test/thread_store_test.dart`
- `test/thread_ui_test.dart`
- `THREAD_IMPLEMENTATION.md`

Modified (some already contained user work):

- `lib/screens/home/home_screen.dart`
- `lib/screens/strategy/strategy_screen.dart`
- `lib/widgets/strategy_spotlight.dart`
- `lib/features/strategy/studio/presentation/city_library.dart`
- `lib/features/strategy/studio/presentation/studio_screen.dart`
- `lib/features/strategy/studio/data/platform_sync.dart`
- `backend/app/models.py`
- `backend/server.py`
- `README.md`
- `NEXT_GENERATION.md`

Other dirty files predated this session. No dependencies were added and no secrets
or signing keys were created or committed.

## Verification actually executed

- Phase A navigation + spotlight + existing city UI: **9 passed** after correcting a new test's widget class name.
- Thread store + UI: **9 passed** after fixing an empty-state overflow and a synchronous exception assertion.
- `flutter pub get`: **passed**; no new package dependency.
- `flutter analyze`: **passed, no issues** after correcting brace/import lint findings.
- `flutter test --concurrency=1 --reporter expanded`: **108 passed**, exit 0, 53 seconds.
- Default concurrent `flutter test`: interrupted after 103 passes without completion. Structured retry stalled in suite compilation. Generated test cache was preserved and serial execution passed. The default run is NOT reported as passing.
- `python -m pytest tests -q` from backend: **28 passed**, **1 existing Starlette/httpx deprecation warning**, 7.65 seconds.
- `python -m alembic heads`: **0005_thread_cases (head)**.
- `git diff --check`: **passed**, with line-ending normalization warnings only.
- Release build results are appended below after completion.

Backend tests exercise actual FastAPI with disposable SQLite databases. Flutter sync
tests use a synthetic transport and UI tests use fictional records. They do not prove
live two-device synchronization, live PostgreSQL concurrency or physical Android behavior.

## Current limits

- No ThreadRelation entity/graph, task engine, source-document parsing/compiler, provenance navigation, Case-to-training/simulation linkage, automatic result return, Ask Thread, AI trace, Branch, Pulse/process intelligence, event-stream filters, notifications or resettable full demo flow yet.
- Training integration remains the existing Training/Simulation Lab experience; no Case-to-training completion loop is claimed.
- Case edits currently change status/reason. UI metadata editing, reassignment, due-date controls, tags and comments remain. Evidence is metadata/context, not uploaded binary attachments. Source text is not a verified document link.
- Staff visibility is organization-wide. Finer instructor-roster/unit ACLs need an explicit policy before wider deployment.
- Sync is active while Thread is mounted; there is no OS background service. Counts reflect cached/projected records, not a server-wide reporting aggregate. Sync pages through all authorized Cases; large deployments need incremental cursors and bounded client caching.
- Timeline timestamps are server receipt times. Client occurrence timestamps and durable device/system event history are future work.
- Local JSON outbox is separate because simulator PlatformSync validates StudioDocument payloads; no simulator store was generalized destructively. Further extraction into a reusable generic outbox can be done with tests.
- Conflict history is retained locally but has no dedicated viewer. Creation-ID conflicts require investigation; there is no discard/delete control that could silently lose work.
- Demo is local-only and never acquires staff verification rights. Onboarding is an empty-state introduction, not yet a persisted first-run sequence.
- Full NEO motion/graph polish, high-contrast/large-text acceptance, physical Android testing and live multi-user network acceptance remain.

## Exact PowerShell launch commands

Use the existing Python environment with DATABASE_URL and JWT_SECRET_KEY configured.
The first block starts the backend after the additive migration; it changes the target
database, so first make the normal database backup for that environment.

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile\backend
if (!$env:DATABASE_URL -or !$env:JWT_SECRET_KEY) { throw 'Configure DATABASE_URL and JWT_SECRET_KEY using your existing backend setup first.' }
python -m alembic current
python -m alembic upgrade head
python -m uvicorn server:app --host 127.0.0.1 --port 8000
```

In a second PowerShell window:

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile
flutter pub get
flutter run -d windows --dart-define=TACTIX_API_URL=http://127.0.0.1:8000 --dart-define=AI_BACKEND_URL=http://127.0.0.1:8000
```

Use an existing server account. Trainees create a Case and add evidence; an instructor
or admin in the same organization opens Thread, reviews the evidence, accepts it and
closes the Case. Offline actions show under Pending actions until accepted. Local demo
profiles can create records but cannot verify them.

For Android emulator development, use `http://10.0.2.2:8000` instead of `127.0.0.1`.
A physical device needs the reachable server address and appropriate network setup.

```powershell
Set-Location C:\Users\admin\Desktop\ai_trainer_mobile
flutter analyze
flutter test --concurrency=1
flutter build windows
flutter build apk --release
Set-Location backend
python -m pytest tests -q
```

## Exact continuation point

Start Phase C from this Case/evidence foundation. Read this document and preserve the
existing local keys, server routes and all migrations.

1. Add `0006_thread_relations` with typed relationship endpoints and immutable relation events. Enforce access to BOTH endpoints and reject cross-organization/unauthorized entity traversal.
2. Extend the durable Thread commands for relationship creation and endpoint resolution; test restart, conflict and lost acknowledgement behavior.
3. Build the native interactive graph from a bounded server/local neighborhood: pan/zoom, focus/open, expansion/collapse, type filters and evidence/unresolved paths. Reuse the current Case timeline rather than replacing it.
4. Phase D: link the existing StrategyAssignment/StrategyRecord and legacy training records, add Case training actions, and return server-validated completed results as evidence. Do not duplicate simulation engines or assignment models.
5. Phase E: source references/document confirmation flow and deterministic authorized Ask Thread before optional model passes.
6. Continue F (Branch), G (Pulse/process/event stream), then H (responsive polish, global sync lifecycle, security/load/network/device acceptance and release validation).

The full source -> Case -> task -> training -> result -> verified closure demo remains
the final acceptance target. The current tested loop is Case -> evidence -> staff
verification -> closure -> reopen, with durable offline commands.

## Manual continuation — Phase C foundation (ChatGPT, 2026-09-30)

After the Codex limit was exhausted, Phase C was continued manually from the tested
Phase A/B checkpoint.

Implemented in this patch:

- Added `ThreadRelation` and immutable `ThreadRelationEvent` backend models.
- Added migration `0006_thread_relations` on top of `0005_thread_cases`.
- Added idempotent typed relation creation with authorization checks on BOTH endpoints.
- Initial relation endpoint types: `CASE`, `EVIDENCE`.
- Initial relationship vocabulary: `CREATED_FROM`, `REQUIRES`, `VERIFIES`, `PRODUCED`,
  `SUPPORTED_BY`, `TRAINED_BY`, `RESULTED_IN`, `SUPERSEDES`, `RELATED_TO`.
- Added Case-scoped relation listing and relation event history.
- Extended the local Thread outbox/mirror so relation creation survives restart and can
  synchronize later without incrementing Case revisions.
- Added explicit Case-to-Case linking in the Thread UI.
- Added a Flutter-native `Digital Thread` graph with pan/zoom, focus/all-cached modes,
  relationship filters, Case nodes, Evidence nodes and offline rendering. No WebView or
  graph dependency was added.
- The graph uses explicit `ThreadRelation` edges and visually shows the structural
  Case→Evidence ownership edge for the selected Case.

Backend verification actually executed after this manual patch:

- `python -m alembic heads`: `0006_thread_relations (head)`
- `python -m pytest tests -q`: **32 passed**, exit 0.

Flutter SDK is not installed in the current ChatGPT execution environment, so
`flutter analyze`, Flutter widget tests and release builds for this patch were NOT
executed here. New/updated Flutter tests were added and must be run on the user's
Windows development machine before merging/deploying.

Next safe continuation point:

1. Run Flutter analysis/tests on Windows and fix any SDK-specific issues.
2. Extend relation endpoints from Case/Evidence to authorized existing Training/
   Strategy Assignment/Strategy Record references.
3. Build Phase D: Case → training action → existing assignment/simulation → validated
   result → Evidence → verification loop.
4. Then continue Source References / Document Compiler / Ask Thread.

## Phase D — Training / Simulation Lab integration

Implemented manually after Phase C.

### End-to-end loop now supported
- Open a THREAD Case.
- Use **Create training action** to open `Training -> Simulation Lab` directly in the instructor platform view.
- Create an existing Simulation Lab assignment.
- The created assignment is linked back to the originating Case through a typed `CASE --TRAINED_BY--> TRAINING` relation.
- Linked assignments are shown in the Case detail and in the Digital Thread graph.
- A submitted Simulation Lab result can be imported into the Case as `TRAINING_RECORD` evidence.
- Import creates `TRAINING --PRODUCED--> EVIDENCE`, records a `TRAINING_COMPLETED` Case event, and moves the Case to `WAITING_FOR_VERIFICATION`.
- Existing Evidence verification and Case closure rules remain the final human verification step.

### Backend additions
- `TRAINING` Thread endpoint type.
- `GET /v1/thread/cases/{case_id}/training`.
- `POST /v1/thread/cases/{case_id}/training/{assignment_id}/evidence`.
- Authorization for linked Strategy assignments.
- Training-result provenance stored as `strategy_assignment:<id>`.
- No new DB migration is required; Phase D reuses Strategy assignments plus Phase C Thread relations/evidence.

### Offline behavior
The Case-to-Training relation is created through the existing THREAD queue. The relation may be queued before the separately queued Strategy assignment reaches the backend; staff-authored `TRAINED_BY` edges tolerate that short-lived state without dropping the local intent. Existing conflict/retry behavior remains in place.

### Verification performed in the packaging environment
- Backend: `34 passed`.
- Flutter SDK was not available in the packaging environment, so `flutter analyze` / `flutter test` must be run on the development machine before committing Phase D.

## Phase E — ASK THREAD + evidence-aware source references

Implemented manually on top of the Phase D green checkpoint.

### ASK THREAD
- Added `POST /v1/thread/cases/{case_id}/ask`.
- The endpoint authorizes the Case before any AI call is made.
- The server builds a bounded source pack from the Case, Evidence, immutable Case timeline, and linked Simulation Lab training records.
- Every returned source reference is intersected with a server-generated allow-list; fabricated source IDs are discarded.
- AI remains read-only: ASK THREAD cannot mutate a Case, Evidence, relations, training, or verification state.
- Local unsynchronized Case mutations block ASK THREAD so the server and UI cannot analyze different evidence states.

### Two-pass evidence pipeline
1. Draft pass answers only from the server-generated source pack.
2. Verification pass removes/rewrites unsupported claims and returns approved source references.
3. The response exposes confidence, approved sources, unsupported/removed claims, open questions, Case revision, and generation metadata.

Unverified/rejected Evidence can be shown as context, but the prompt explicitly prevents it from being treated as an authoritative fact. The existing human verification workflow remains authoritative.

### Client behavior
- Added ASK THREAD action inside Case detail.
- Shows answer confidence, approved source cards, verification state, provenance string, unsupported claims, and open questions.
- Last ASK THREAD results are cached per Case for offline review; generation itself requires a server connection.
- Up to 12 recent ASK THREAD entries are retained per Case in the existing durable local Thread state.

### Verification performed in the packaging environment
- Backend: `37 passed`.
- Flutter SDK is not installed in the packaging environment. Run `flutter analyze` and `flutter test --concurrency=1` on the Windows development machine before committing/tagging Phase E.

### Next safe continuation
Phase F can add Branch/version comparison for administrative/training plans. Do not let Branch bypass Evidence verification or mutate historical Case/Relation events.

## Phase F — TACTIX BRANCH / Compare / Merge / conflict detection

Implemented manually on top of the Phase E green checkpoint.

### Branch model
- Staff-only planning variants are stored separately from the live Case.
- Each Branch freezes a base Case snapshot and has its own revision/history.
- Draft fields: Case description, priority, non-closing status, owner, due date, plus planned TASK/TRAINING/REVIEW items.
- Branch editing never mutates the live Case.

### Deterministic three-way compare
The server compares:
1. Branch base snapshot.
2. Current live Case.
3. Current Branch draft.

A live Case may advance after a Branch was created. If live and Branch changed different fields, merge remains possible and preserves the unrelated live changes. If both changed the same field differently, merge is blocked with `FIELD_DIVERGED`.

Additional deterministic checks:
- closed Case blocks merge;
- proposed owner / plan-item assignee must still be active organization members;
- invalid dates block merge;
- past due dates, duplicate plan items, plan items after Case due, and linked training after Case due are surfaced as warnings.

### Merge semantics
- Merge never sets `CLOSED`; closure remains controlled by the existing Evidence verification path.
- Only fields changed by the Branch relative to its base are applied.
- A successful merge increments the Case revision and appends immutable `BRANCH_MERGED` details, including accepted plan items and warnings.
- The Branch becomes `MERGED` and records its own immutable merge event.

### API / persistence
- `GET /v1/thread/cases/{case_id}/branch-options`
- `GET /v1/thread/cases/{case_id}/branches`
- `POST /v1/thread/cases/{case_id}/branches`
- `GET /v1/thread/branches/{branch_id}`
- `PUT /v1/thread/branches/{branch_id}`
- `GET /v1/thread/branches/{branch_id}/compare`
- `POST /v1/thread/branches/{branch_id}/merge`
- `GET /v1/thread/branches/{branch_id}/events`
- migration `0007_thread_branches`

### Client
- TACTIX BRANCH panel in Case detail.
- Create, edit, compare and merge actions.
- Organization-member owner/assignee picker.
- Planned task/training/review items.
- Branches and compare results are cached for offline review; create/edit/compare/merge remain server-authoritative.

### Verification performed in the packaging environment
- `python -m alembic heads`: `0007_thread_branches (head)`.
- Backend: **40 passed**.
- Flutter SDK is unavailable in the packaging environment. Run `flutter analyze` and `flutter test --concurrency=1` on Windows before commit/tag.

## Phase G — TACTIX PULSE / Process Intelligence / Event Stream

Implemented on top of the Phase F green checkpoint.

### Purpose
PULSE is a read-only health view over the existing TACTIX workflow. It does not create a second analytics database and does not let AI decide what should be done. Metrics are recomputed from authoritative THREAD, Evidence, Branch and Simulation Lab records.

### Backend
- `GET /v1/thread/pulse`
  - staff-only;
  - active/closed/overdue/due-soon/stale counts;
  - waiting-for-verification and Evidence counters;
  - draft Branch and pending Training counters;
  - seven-day created/closed throughput;
  - current-status backlog age summary;
  - deterministic alert list.
- `GET /v1/thread/event-stream`
  - staff-only;
  - unified Case / Branch / Relation / Training activity;
  - organization-scoped and time-window bounded;
  - newest-first ordering.

### Flutter client
- Added a third THREAD view: `PULSE` next to Cases and Graph.
- PULSE shows metrics, attention queue, current-stage backlog and Event Stream.
- Alerts and events with a Case reference can open that Case directly.
- The latest snapshot is persisted in the existing durable local Thread state.
- Refresh requires server access; cached data remains reviewable offline.

### Safety / integrity
- No AI is used for metric or alert calculation.
- PULSE is read-only and never mutates Case, Evidence, Branch, Relation or Training state.
- No new database migration is required. Alembic remains `0007_thread_branches`.

### Verification performed in the packaging environment
- Backend: **42 passed**.
- Flutter SDK is unavailable in the packaging environment. Run `flutter analyze` and `flutter test --concurrency=1` on Windows before committing/tagging Phase G.
