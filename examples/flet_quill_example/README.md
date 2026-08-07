# Flet app

A simple Flet app.

To run the app when using `uv`:

```
uv run flet run [app_directory]
```

To run the app whenin using `pip`:

```
flet run [app_directory]
```

## Build on Windows

When packaging on Windows you might hit a lock error like `WinError 32` for
`build\\flutter-packages-temp`. That is usually caused by stale `python`,
`dart`, or `flutter` processes holding files in the previous build directory.

Run a clean build with:

```
powershell -ExecutionPolicy Bypass -File .\build_windows.ps1
```

The script:

- stops stale build-related processes,
- removes `.\\build` plus stale Flutter extension staging folders,
- retries the build when Flet hits the transient `flutter-packages-temp` lock, and
- runs `flet build -v windows` from the repository virtual environment.