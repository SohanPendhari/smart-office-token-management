#!/usr/bin/env bash
# Same as setup_web.ps1 for macOS / Linux / Git Bash.
set -e
cd "$(dirname "$0")"
flutter config --enable-web
flutter create --platforms=web --project-name smart_office_queue .
flutter pub get
echo "Done. Start the backend, then run: flutter run -d chrome"
