#!/usr/bin/env bash
# Fixed setup script for EchoCore Pro OpenVoice server
# This script handles the PyAV compilation issue

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔧 Setting up OpenVoice server for EchoCore Pro..."

# Remove old venv if exists
if [ -d "venv" ]; then
    echo "🗑️  Removing old venv..."
    rm -rf venv
fi

# Create venv with Python 3.11
echo "📦 Creating Python 3.11 venv..."
python3.11 -m venv venv

# Activate venv
source venv/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip setuptools wheel

# Install PyAV with pre-built wheel (avoids compilation)
echo "🎬 Installing PyAV (pre-built wheel)..."
# Try installing av with only binary - if that fails, use conda-compatible approach
pip install --only-binary=:all: av || {
    echo "⚠️  Pre-built av not available, installing with ffmpeg linking..."
    # Set FFmpeg paths for Homebrew installation
    export FFMPEG_INCLUDE_PATHS="/opt/homebrew/include"
    export FFMPEG_LIB_PATHS="/opt/homebrew/lib"
    pip install av || {
        echo "❌ Failed to install av. Trying alternative method..."
        # Install a version that has known good wheels
        pip install "av<13" || {
            echo "❌ Still failing. Please run: brew install ffmpeg"
            exit 1
        }
    }
}

# Install core dependencies
echo "📚 Installing core dependencies..."
pip install fastapi uvicorn numpy soundfile python-multipart

# Install PyTorch with MPS support (Apple Silicon)
echo "🔥 Installing PyTorch with MPS support..."
pip install torch torchvision torchaudio

# Install audio processing libraries
echo "🎵 Installing audio libraries..."
pip install librosa pydub

# Install OpenVoice from GitHub
echo "🎤 Installing OpenVoice from GitHub..."
pip install git+https://github.com/myshell-ai/OpenVoice.git

echo ""
echo "✅ Setup complete!"
echo ""
echo "To run the server:"
echo "  cd $SCRIPT_DIR"
echo "  source venv/bin/activate"
echo "  python openvoice_server.py"
echo ""
