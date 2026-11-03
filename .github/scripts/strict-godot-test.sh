#!/usr/bin/env bash
set -u
if [ "$#" -ne 3 ]; then
  echo "Usage: bash strict-godot-test.sh <res://test.gd> <success-marker> <quit-after-frames>" >&2
  exit 2
fi
test_script="$1"
success_marker="$2"
quit_after="$3"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
set +e
timeout 100s godot --headless --path . --script "$test_script" --quit-after "$quit_after" >"$log" 2>&1
status=$?
set -e
cat "$log"
if [ "$status" -ne 0 ]; then
  echo "::error::Godot test subprocess returned $status for $test_script" >&2
  exit 1
fi
if grep -Fq "SCRIPT ERROR:" "$log"; then
  echo "::error::Godot emitted SCRIPT ERROR despite process exit 0: $test_script" >&2
  exit 1
fi
if ! grep -Fq "$success_marker" "$log"; then
  echo "::error::Godot did not reach the success assertion marker: $test_script" >&2
  exit 1
fi
echo "Strict test confirmed: $test_script"
