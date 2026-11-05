#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

swift build -c release

app_dir="$project_dir/.build/Mike.app"
contents_dir="$app_dir/Contents"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$project_dir/.build/release/Mike" "$contents_dir/MacOS/Mike"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"
chmod +x "$contents_dir/MacOS/Mike"

codesign --force --deep --sign - "$app_dir"
print "$app_dir"
