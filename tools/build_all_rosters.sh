#!/usr/bin/env bash
# Bakes every rival roster: drag, hill climb, then derby (see build_rival_roster.gd).
set -e
cd "$(dirname "$0")/.."
# Registers any new class_name scripts the bakers use.
godot --headless --import > /dev/null 2>&1
modes=("" --hill --derby)
for i in "${!modes[@]}"; do
	godot --headless --fixed-fps 60 res://tools/build_rival_roster.tscn -- ${modes[$i]} --stage=$((i + 1))/${#modes[@]} --no-save
done
