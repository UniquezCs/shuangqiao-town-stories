#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_godot() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		printf '%s\n' "$GODOT_BIN"
		return
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return
	fi
	if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
		printf '%s\n' "/Applications/Godot.app/Contents/MacOS/Godot"
		return
	fi
	printf 'Godot executable not found. Set GODOT_BIN=/path/to/Godot or install a godot command.\n' >&2
	return 1
}

GODOT="$(find_godot)"
ALLOW_RESOURCE_LEAKS="${GODOT_ALLOW_RESOURCE_LEAKS:-0}"

if [[ "$#" -gt 0 ]]; then
	tests=("$@")
else
	tests=()
	while IFS= read -r test_scene; do
		tests+=("$test_scene")
	done < <(cd "$ROOT" && find tests -maxdepth 1 -type f -name '*_test.tscn' | sort)
fi

if [[ "${#tests[@]}" -eq 0 ]]; then
	printf 'No test scenes found.\n' >&2
	exit 1
fi

for test_scene in "${tests[@]}"; do
	printf 'Running %s\n' "$test_scene"
	output_file="$(mktemp)"
	status=0
	"$GODOT" --headless --path "$ROOT" "$test_scene" >"$output_file" 2>&1 || status=$?
	cat "$output_file"
	if [[ "$status" -ne 0 ]] || grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$output_file"; then
		rm -f "$output_file"
		exit 1
	fi
	if [[ "$ALLOW_RESOURCE_LEAKS" != "1" ]] && grep -Eq 'resources still in use|RID allocations of type|RIDs of type ".+" were leaked|ObjectDB instances leaked' "$output_file"; then
		rm -f "$output_file"
		exit 1
	fi
	if grep '^ERROR:' "$output_file" | grep -Ev "resources still in use|RID allocations of type" >/dev/null; then
		rm -f "$output_file"
		exit 1
	fi
	rm -f "$output_file"
done
