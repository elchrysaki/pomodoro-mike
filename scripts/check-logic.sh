#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
output_path="/tmp/mike-timer-check"

swiftc \
    "$project_dir/Sources/Mike/TimerModels.swift" \
    "$project_dir/Tests/TimerSequenceCheck/main.swift" \
    -o "$output_path"
"$output_path"
