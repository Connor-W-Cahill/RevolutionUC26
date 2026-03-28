#!/usr/bin/env bash
# Serve the web mockup on port 3000
set -e
cd "$(dirname "$0")"
echo "Serving web mockup at http://localhost:3000"
python3 -m http.server 3000
