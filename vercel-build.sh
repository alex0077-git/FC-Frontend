#!/bin/bash
set -e
git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter_sdk
export PATH="$PATH:$(pwd)/_flutter_sdk/bin"
flutter --version
flutter pub get
flutter build web --release
