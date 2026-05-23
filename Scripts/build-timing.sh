#!/usr/bin/env bash
# Runs a clean build of the App scheme and saves a timing report under .build-reports/.
# Usage: ./Scripts/build-timing.sh [scheme]   (default: App)
set -euo pipefail

SCHEME="${1:-App}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORTS_DIR="$REPO_ROOT/.build-reports"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_FILE="$REPORTS_DIR/${TIMESTAMP}-${SCHEME}.txt"

mkdir -p "$REPORTS_DIR"

echo "=== Build Timing Report ==="
echo "Scheme:    $SCHEME"
echo "Date:      $(date -u)"
echo "Host:      $(uname -n)"
echo "Xcode:     $(xcodebuild -version | tr '\n' ' ')"
echo ""

{
  echo "=== Build Timing Report ==="
  echo "Scheme:    $SCHEME"
  echo "Date:      $(date -u)"
  echo "Host:      $(uname -n)"
  echo "Xcode:     $(xcodebuild -version | tr '\n' ' ')"
  echo ""
} > "$REPORT_FILE"

echo "Cleaning..."
xcodebuild \
  -workspace "$REPO_ROOT/ModularProject.xcworkspace" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  clean 2>&1 | tail -1

echo "Building (this will take a while)..."
xcodebuild \
  -workspace "$REPO_ROOT/ModularProject.xcworkspace" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  -showBuildTimingSummary \
  build 2>&1 | tee -a "$REPORT_FILE" | grep --line-buffered -E "(=== BUILD TARGET|warning:|error:|Build Timing Summary|seconds|SUCCEEDED|FAILED)"

echo ""
echo "Report saved: $REPORT_FILE"
