#!/bin/bash
set -e

echo "=== Installing Flutter SDK ==="
FLUTTER_VERSION="3.27.4"
curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" | tar xJ -C /tmp
export PATH="/tmp/flutter/bin:/tmp/flutter/bin/cache/dart-sdk/bin:$PATH"

echo "=== Flutter Version ==="
flutter --version

echo "=== Building Flutter Web ==="
cd frontend
flutter pub get
flutter build web --release --base-href "/" \
  --dart-define=SUPABASE_URL=https://bjcozlqatjmpxtepqjpr.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJqY296bHFhdGptcHh0ZXBxanByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ4MTc3NjAsImV4cCI6MjEwMDM5Mzc2MH0.7rQJgMGP2K3Alu0t6by7vZMbsUyFgqRnLuDqF7nCIo8

echo "=== Build Complete ==="
ls -la build/web/
