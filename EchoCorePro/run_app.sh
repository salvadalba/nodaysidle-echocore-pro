#!/bin/bash

# Quick build and run script for EchoCorePro

set -e

echo "🚀 Building and running EchoCorePro..."

# Build the app
./build_app.sh

# Launch the app
echo "🎯 Launching EchoCorePro..."
open EchoCorePro.app
