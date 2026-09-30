$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host 'Checking Alembic head...'
Push-Location backend
$heads = python -m alembic heads
if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'Alembic head check failed; Phase G was NOT committed.' }
if ($heads -notmatch '0007_thread_branches') { Pop-Location; throw "Expected Alembic head 0007_thread_branches, got: $heads" }

Write-Host 'Running backend tests...'
python -m pytest tests -q
if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'Backend tests failed; Phase G was NOT committed.' }
Pop-Location

Write-Host 'Running Flutter analysis...'
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed; Phase G was NOT committed.' }

Write-Host 'Running Flutter tests...'
flutter test --concurrency=1
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed; Phase G was NOT committed.' }

$files = @(
  'backend/app/thread_pulse.py',
  'backend/server.py',
  'backend/tests/test_thread_pulse.py',
  'lib/features/thread/thread_store.dart',
  'lib/features/thread/thread_screen.dart',
  'test/thread_store_test.dart',
  'THREAD_IMPLEMENTATION.md',
  'NEXT_GENERATION.md',
  'INSTALL_PHASE_G.md',
  'COMMIT_PHASE_G.ps1'
)

git add -- $files

Write-Host 'Staged Phase G changes:'
git diff --cached --stat

if (-not (git diff --cached --quiet)) {
  git commit -m 'feat(thread): add TACTIX PULSE process intelligence'
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
  Write-Host 'Committed:'
  git log -1 --oneline
} else {
  Write-Host 'No staged Phase G changes found.'
}
