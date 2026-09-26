#!/usr/bin/env bash
# Lance la suite de tests hors Studio avec la CLI luau.
# Prérequis : `luau` dans le PATH (https://github.com/luau-lang/luau/releases).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
python3 tests/bundle.py > build/test_bundle.luau
luau build/test_bundle.luau
