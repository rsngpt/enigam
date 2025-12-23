#!/bin/bash

# Install Flutter
if [ -d "flutter" ]; then
    cd flutter
    git pull
    cd ..
else
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add flutter to path
export PATH="$PATH:`pwd`/flutter/bin"

# Build web
flutter build web --release
