$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

Write-Host "Stopping stale build processes (python/dart/flutter)..."
Get-Process python,dart,flutter -ErrorAction SilentlyContinue | Stop-Process -Force

if (Test-Path ".\build") {
    Write-Host "Removing previous build directory..."
    Remove-Item -Recurse -Force ".\build"
}

$fletExe = $null
if (Test-Path ".\.venv\Scripts\flet.exe") {
    $fletExe = ".\.venv\Scripts\flet.exe"
} elseif (Test-Path ".\.venv312\Scripts\flet.exe") {
    $fletExe = ".\.venv312\Scripts\flet.exe"
} else {
    throw "No local flet executable found. Create/activate the project venv and install dependencies first."
}

Write-Host "Running clean Windows build..."
& $fletExe build -v windows
