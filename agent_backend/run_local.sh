#!/usr/bin/env bash
set -e

# MetalCraft Local Agent Backend Launcher
echo "=================================================="
echo "  MetalCraft — Local Agent Backend (Gemini + MCP) "
echo "=================================================="

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "Creating local Python virtual environment..."
    python3 -m venv venv
    ./venv/bin/pip install --upgrade pip
    ./venv/bin/pip install -r requirements.txt
fi

echo "Starting Agent Backend on http://0.0.0.0:8080 ..."
./venv/bin/python app.py
