# Generates the Flutter web project files. Run once from the mobile folder:
#   powershell -ExecutionPolicy Bypass -File .\setup_web.ps1
$ErrorActionPreference = "Stop"
flutter config --enable-web
flutter create --platforms=web --project-name smart_office_queue .
flutter pub get
Write-Host "Done. Start the backend, then run:  flutter run -d chrome"
