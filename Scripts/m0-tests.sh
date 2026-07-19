#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

python3 -m unittest discover -s Tests -p 'test_*.py' -v
python3 -m compileall -q Tools/ProtocolProbe Tests
