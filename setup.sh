#!/usr/bin/env bash

# grandFW v3.0 Wrapper Script
# This script calls the actual setup script in the scripts directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/scripts/setup.sh" ]]; then
    exec bash "${SCRIPT_DIR}/scripts/setup.sh" "$@"
else
    echo "Error: scripts/setup.sh not found!"
    exit 1
fi
