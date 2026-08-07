$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Stop-StaleBuildProcesses {
    Write-Host "Stopping stale build processes (python/dart/flutter)..."
    Get-Process python,dart,flutter -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Remove-BuildArtifacts {
    if (Test-Path ".\build\flutter-packages-temp") {
        Write-Host "Removing stale flutter-packages-temp..."
        Remove-Item -Recurse -Force ".\build\flutter-packages-temp"
    }

    if (Test-Path ".\build\flutter-packages") {
        Write-Host "Removing stale flutter-packages..."
        Remove-Item -Recurse -Force ".\build\flutter-packages"
    }
}

Stop-StaleBuildProcesses

if (Test-Path ".\build") {
    Write-Host "Removing previous build directory..."
    Remove-Item -Recurse -Force ".\build"
}

$fletExe = $null
if (Test-Path (Join-Path $repoRoot ".venv\Scripts\flet.exe")) {
    $fletExe = Join-Path $repoRoot ".venv\Scripts\flet.exe"
} elseif (Test-Path (Join-Path $repoRoot ".venv312\Scripts\flet.exe")) {
    $fletExe = Join-Path $repoRoot ".venv312\Scripts\flet.exe"
} else {
    throw "No repo-level flet executable found. Create the project venv at the repository root and install dependencies first."
}

for ($attempt = 1; $attempt -le 3; $attempt++) {
    Write-Host "Running clean Windows build (attempt $attempt of 3)..."

    & $fletExe build -v windows

    if ($LASTEXITCODE -eq 0) {
        exit 0
    }

    if ($attempt -eq 3) {
        throw "Windows build failed. See output above."
    }

    Write-Host "Windows build failed. Cleaning generated extension folders and retrying..."
    Stop-StaleBuildProcesses
    Remove-BuildArtifacts
}
