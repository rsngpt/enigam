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

echo "Adding Flutter to PATH..."
export PATH="$PATH:$(pwd)/flutter/bin"

echo "Checking Flutter version..."
flutter --version

echo "Running Flutter Doctor..."
flutter doctor -v

echo "Enabling Web..."
flutter config --enable-web

# Create .env file if missing (required for build assets)
if [ ! -f .env ]; then
    echo "Creating .env file from environment variables..."
    touch .env
    if [ ! -z "$SUPABASE_URL" ]; then
        echo "SUPABASE_URL=$SUPABASE_URL" >> .env
    fi
    if [ ! -z "$SUPABASE_ANON_KEY" ]; then
        echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
    fi
    
    # Check if empty (no env vars provided)
    if [ ! -s .env ]; then
         echo "Warning: No environment variables found. Creating dummy .env to satisfy build asset requirement."
         echo "SUPABASE_URL=https://example.supabase.co" >> .env
         echo "SUPABASE_ANON_KEY=dummy_key" >> .env
    fi
fi

# Build web
echo "Building Flutter Web..."
# Use --verbose to see detailed errors if it fails
flutter build web --release --verbose
echo "Build complete."
