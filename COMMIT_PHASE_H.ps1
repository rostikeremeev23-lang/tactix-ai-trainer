$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host "Checking Alembic head..."
Push-Location backend
$head = python -m alembic heads
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Alembic heads failed" }
if (($head | Out-String) -notmatch "0007_thread_branches") { Pop-Location; throw "Unexpected Alembic head: $head" }

Write-Host "Running backend tests..."
python -m pytest tests -q
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Backend tests failed" }
Pop-Location

Write-Host "Running Flutter analysis..."
flutter analyze
if ($LASTEXITCODE -ne 0) { throw "Flutter analyze failed" }

Write-Host "Running Flutter tests..."
flutter test --concurrency=1
if ($LASTEXITCODE -ne 0) { throw "Flutter tests failed" }

$files = @(
  "COMMIT_PHASE_H.ps1",
  "INSTALL_PHASE_H.md",
  "PRODUCT_DEFINITION_RU.md",
  "NEXT_GENERATION.md",
  "THREAD_IMPLEMENTATION.md",
  "lib/features/thread/thread_screen.dart",
  "lib/features/thread/thread_graph.dart",
  "lib/screens/home/home_screen.dart",
  "lib/screens/profile/profile_screen.dart",
  "lib/screens/training/training_hub_screen.dart",
  "lib/screens/about/product_definition_screen.dart",
  "test/thread_ui_test.dart",
  "test/training_navigation_test.dart",
  "test/product_definition_test.dart"
)

git add -- $files
Write-Host "Staged Phase H changes:"
git diff --cached --stat

if (-not (git diff --cached --quiet)) {
  git commit -m "feat: Russian UX and TACTIX product definition"
  if ($LASTEXITCODE -ne 0) { throw "Git commit failed" }
  Write-Host "Committed:"
  git log -1 --oneline
} else {
  Write-Host "Nothing to commit."
}
