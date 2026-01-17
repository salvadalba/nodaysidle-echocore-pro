#!/usr/bin/env bash
# Quick start script for OpenVoice server (Fish shell compatible)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🎤 Starting OpenVoice Server..."
echo ""
echo "To activate the venv manually in fish shell:"
echo "   source $SCRIPT_DIR/venv/bin/activate.fish"
echo ""
echo "Starting server on http://127.0.0.1:8765"
echo "   API docs: http://127.0.0.1:8765/docs"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Use Python directly from venv (works in any shell)
./venv/bin/python openvoice_server.py
