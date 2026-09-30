$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host 'Running backend tests...'
Push-Location backend
python -m pytest tests -q
if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'Backend tests failed; Phase E was NOT committed.' }
Pop-Location

Write-Host 'Running Flutter analysis...'
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed; Phase E was NOT committed.' }

Write-Host 'Running Flutter tests...'
flutter test --concurrency=1
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed; Phase E was NOT committed.' }

$files = @(
  'backend/app/thread_ai.py',
  'backend/server.py',
  'backend/tests/test_thread_ai.py',
  'lib/features/thread/thread_store.dart',
  'lib/features/thread/thread_screen.dart',
  'test/thread_store_test.dart',
  'THREAD_IMPLEMENTATION.md',
  'NEXT_GENERATION.md',
  'INSTALL_PHASE_E.md',
  'COMMIT_PHASE_E.ps1'
)

git add -- $files

Write-Host 'Staged Phase E changes:'
git diff --cached --stat

if (-not (git diff --cached --quiet)) {
  git commit -m 'feat(thread): add evidence-aware ASK THREAD'
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
  Write-Host 'Committed:'
  git log -1 --oneline
} else {
  Write-Host 'No staged Phase E changes found.'
}
