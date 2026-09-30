$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path ".git")) {
    Write-Host "No .git directory found in this project." -ForegroundColor Yellow
    Write-Host "Create/restore the repository first; this script will not initialize Git automatically."
    exit 2
}

Write-Host "Running backend tests..." -ForegroundColor Cyan
Push-Location backend
python -m pytest tests -q
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Backend tests failed. Commit aborted." }
Pop-Location

Write-Host "Running Flutter analysis..." -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed. Commit aborted." }

Write-Host "Running Flutter tests..." -ForegroundColor Cyan
flutter test --concurrency=1
if ($LASTEXITCODE -ne 0) { throw "Flutter tests failed. Commit aborted." }

$files = @(
  "backend/app/thread.py",
  "backend/tests/test_thread_relations.py",
  "lib/features/strategy/studio/presentation/platform_screen.dart",
  "lib/features/strategy/studio/presentation/studio_screen.dart",
  "lib/features/thread/thread_graph.dart",
  "lib/features/thread/thread_screen.dart",
  "lib/features/thread/thread_store.dart",
  "lib/screens/strategy/strategy_screen.dart",
  "test/thread_store_test.dart",
  "THREAD_IMPLEMENTATION.md",
  "NEXT_GENERATION.md",
  "INSTALL_PHASE_D.md",
  "COMMIT_PHASE_D.ps1"
)

git add -- $files
Write-Host "Staged Phase D changes:" -ForegroundColor Cyan
git diff --cached --stat

git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw "git diff --check failed. Commit aborted." }

$staged = git diff --cached --name-only
if (-not $staged) {
    Write-Host "Nothing to commit." -ForegroundColor Yellow
    exit 0
}

git commit -m "feat(thread): connect cases to Simulation Lab training"
if ($LASTEXITCODE -ne 0) { throw "Git commit failed." }

Write-Host "Committed:" -ForegroundColor Green
git log -1 --oneline
