param([int]$WindowWidth = 1440, [int]$WindowHeight = 900, [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Name = 'native')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type (@'
using System;
using System.Runtime.InteropServices;
public static class StrategyWindow {
  [StructLayout(LayoutKind.Sequential)]
  public struct Rect { public int Left, Top, Right, Bottom; }
  [DllImport(QUOTEuser32.dllQUOTE)] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
  [DllImport(QUOTEuser32.dllQUOTE)] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int w, int h, uint flags);
  [DllImport(QUOTEuser32.dllQUOTE)] public static extern bool SetForegroundWindow(IntPtr hwnd);
  [DllImport(QUOTEuser32.dllQUOTE)] public static extern IntPtr GetForegroundWindow();
}
'@.Replace('QUOTE', [string][char]34))
$strategyRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$strategyExe = Join-Path $strategyRoot 'build/windows/x64/runner/Debug/TACTIX.exe'
$strategyProcess = Get-Process TACTIX | Where-Object { $_.Path -eq $strategyExe } | Select-Object -First 1
if (-not $strategyProcess -or $strategyProcess.MainWindowHandle -eq 0) { throw 'Native Strategy preview not running' }
$strategyWindow = $strategyProcess.MainWindowHandle
[void][StrategyWindow]::SetWindowPos($strategyWindow, [IntPtr]::Zero, 20, 20, $WindowWidth, $WindowHeight, 0)
[void][StrategyWindow]::SetForegroundWindow($strategyWindow)
Start-Sleep -Milliseconds 600
$strategyRect = New-Object StrategyWindow+Rect
[void][StrategyWindow]::GetWindowRect($strategyWindow, [ref]$strategyRect)
if ([StrategyWindow]::GetForegroundWindow() -ne $strategyWindow) { throw 'Test window is not foreground' }
$strategyBitmap = New-Object System.Drawing.Bitmap(($strategyRect.Right - $strategyRect.Left), ($strategyRect.Bottom - $strategyRect.Top))
$strategyGraphics = [System.Drawing.Graphics]::FromImage($strategyBitmap)
try {
  $strategyGraphics.CopyFromScreen($strategyRect.Left, $strategyRect.Top, 0, 0, $strategyBitmap.Size)
  $strategyOutput = Join-Path $strategyRoot ('artifacts/strategy/' + $Name + '.png')
  $strategyBitmap.Save($strategyOutput, [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Output $strategyOutput
} finally {
  $strategyGraphics.Dispose()
  $strategyBitmap.Dispose()
}
