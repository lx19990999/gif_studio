@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT_DIR=%~dp0"
set "APP_NAME=gif_studio"
set "DIST_DIR=%ROOT_DIR%dist\windows"
set "BUILD_DIR=%ROOT_DIR%build\windows\x64\runner\Release"
set "ARCHIVE_PATH=%DIST_DIR%\%APP_NAME%-windows-x64.zip"
set "PROXY_URL=http://127.0.0.1:65000"

where flutter >nul 2>nul
if errorlevel 1 (
  echo [build_win] flutter not found in PATH
  exit /b 1
)

pushd "%ROOT_DIR%"

echo [build_win] Running flutter pub get
call flutter pub get
if errorlevel 1 (
  echo [build_win] Command failed, retrying with proxy: %PROXY_URL%
  set "HTTP_PROXY=%PROXY_URL%"
  set "HTTPS_PROXY=%PROXY_URL%"
  set "http_proxy=%PROXY_URL%"
  set "https_proxy=%PROXY_URL%"
  call flutter pub get
  if errorlevel 1 goto fail
)

echo [build_win] Building Windows release bundle
call flutter build windows --release
if errorlevel 1 (
  echo [build_win] Command failed, retrying with proxy: %PROXY_URL%
  set "HTTP_PROXY=%PROXY_URL%"
  set "HTTPS_PROXY=%PROXY_URL%"
  set "http_proxy=%PROXY_URL%"
  set "https_proxy=%PROXY_URL%"
  call flutter build windows --release
  if errorlevel 1 goto fail
)

if not exist "%BUILD_DIR%" (
  echo [build_win] Expected build directory not found: %BUILD_DIR%
  goto fail
)

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
if exist "%ARCHIVE_PATH%" del /f /q "%ARCHIVE_PATH%"

echo [build_win] Packing bundle to %ARCHIVE_PATH%
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Compress-Archive -Path '%BUILD_DIR%\*' -DestinationPath '%ARCHIVE_PATH%' -Force"
if errorlevel 1 goto fail

echo [build_win] Done
echo [build_win] Bundle directory: %BUILD_DIR%
echo [build_win] Archive: %ARCHIVE_PATH%
popd
exit /b 0

:fail
set "EXIT_CODE=%errorlevel%"
popd
exit /b %EXIT_CODE%
