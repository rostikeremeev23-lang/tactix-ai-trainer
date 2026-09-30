$ErrorActionPreference = "Stop"

Write-Host "Checking Alembic head..." -ForegroundColor Cyan
Push-Location backend
$heads = python -m alembic heads
if ($LASTEXITCODE -ne 0) { throw "Alembic heads failed" }
if ($heads -notmatch "0007_thread_branches") {
    throw "Unexpected Alembic head. Expected 0007_thread_branches."
}

Write-Host "Running backend tests..." -ForegroundColor Cyan
python -m pytest tests -q
if ($LASTEXITCODE -ne 0) { throw "Backend tests failed" }
Pop-Location

Write-Host "Running Flutter analysis..." -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { throw "Flutter analyze failed" }

Write-Host "Running Flutter tests..." -ForegroundColor Cyan
flutter test --concurrency=1
if ($LASTEXITCODE -ne 0) { throw "Flutter tests failed" }

$files = @(
  "backend/app/config.py",
  "backend/app/readiness.py",
  "backend/server.py",
  "backend/tests/test_readiness.py",
  "lib/services/system_readiness_service.dart",
  "lib/screens/about/system_readiness_screen.dart",
  "lib/screens/about/product_definition_screen.dart",
  "lib/screens/home/home_screen.dart",
  "test/system_readiness_test.dart",
  "RELEASE_READINESS_RU.md",
  "INSTALL_PHASE_I.md",
  "NEXT_GENERATION.md",
  "THREAD_IMPLEMENTATION.md",
  "COMMIT_PHASE_I.ps1"
)

git add -- $files
if ($LASTEXITCODE -ne 0) { throw "git add failed" }

Write-Host "Staged Phase I changes:" -ForegroundColor Cyan
git diff --cached --stat

if (-not (git diff --cached --quiet)) {
  git commit -m "chore: prepare TACTIX release readiness"
  if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
} else {
  Write-Host "Nothing to commit." -ForegroundColor Yellow
}

Write-Host "Committed:" -ForegroundColor Green
git log -1 --oneline
