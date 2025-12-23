#!/bin/bash
set -e

echo "Starting Vercel Build Script..."
echo "Current Directory: $(pwd)"

# Install Flutter
if [ -d "flutter" ]; then
    echo "Flutter directory exists. Pulling latest..."
    cd flutter
    git pull
    cd ..
else
    echo "Cloning Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add flutter to path
echo "Adding Flutter to PATH..."
export PATH="$PATH:$(pwd)/flutter/bin"

echo "Checking Flutter version..."
flutter --version

# Build web
echo "Building Flutter Web..."
flutter build web --release
echo "Build complete."
