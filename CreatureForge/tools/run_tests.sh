#!/usr/bin/env bash
# Lance les tests hors Studio. Nécessite le CLI `luau` (https://github.com/luau-lang/luau/releases).
# Usage : LUAU=/chemin/vers/luau tools/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
TMP="$(mktemp -d)"
status=0
for t in test_shapes test_pipeline test_studio test_ui; do
	python3 tools/bundle_tests.py "tests/$t.lua" > "$TMP/$t.lua"
	if out="$("$LUAU" "$TMP/$t.lua" 2>&1)"; then
		echo "✓ $t — $(echo "$out" | tail -1)"
	else
		echo "✗ $t"
		echo "$out" | tail -20
		status=1
	fi
done
rm -rf "$TMP"
exit $status
