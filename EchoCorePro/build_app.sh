#!/bin/bash

# Build EchoCorePro as a standalone macOS app

set -e

echo "🚀 Building EchoCorePro..."

# Clean previous builds
rm -rf .build/
rm -rf EchoCorePro.app

# Build the executable
swift build -c release

# Create app bundle structure
echo "📦 Creating app bundle..."
mkdir -p "EchoCorePro.app/Contents/MacOS"
mkdir -p "EchoCorePro.app/Contents/Resources"

# Copy executable
cp .build/release/EchoCorePro "EchoCorePro.app/Contents/MacOS/"

# Create Info.plist
cat > "EchoCorePro.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>EchoCorePro</string>
    <key>CFBundleIdentifier</key>
    <string>com.echocore.EchoCorePro</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>EchoCorePro</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>EchoCorePro needs access to your microphone for voice recording and transcription.</string>
</dict>
</plist>
EOF

# Make executable
chmod +x "EchoCorePro.app/Contents/MacOS/EchoCorePro"

echo "✅ EchoCorePro.app created successfully!"
echo "📍 Location: $(pwd)/EchoCorePro.app"
echo ""
echo "To run the app, double-click EchoCorePro.app or run:"
echo "   open EchoCorePro.app"
