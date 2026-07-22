#!/usr/bin/env bash

set -u

SPEC_NAME="${1:-}"
TARGET_VERSION="${2:-}"

if [[ -z "$SPEC_NAME" || -z "$TARGET_VERSION" ]]; then
  echo "Usage: $0 <podspec_name> <target_version>"
  echo "Example: $0 AlgoLogger 1.2.3"
  exit 1
fi

echo "Checking pod spec version every 60 seconds..."
echo "Spec: $SPEC_NAME"
echo "Target version: $TARGET_VERSION"

while true; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running: pod repo update"
  pod repo update

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running: pod spec which $SPEC_NAME"
  SPEC_PATH="$(pod spec which "$SPEC_NAME" 2>/dev/null || true)"

  if [[ -n "$SPEC_PATH" ]]; then
    echo "Found spec path: $SPEC_PATH"

    if [[ "$SPEC_PATH" == *"$TARGET_VERSION"* ]]; then
      echo "Target version '$TARGET_VERSION' found in spec path."
      exit 0
    fi
  else
    echo "Spec not found yet."
  fi

  echo "Target version '$TARGET_VERSION' not matched yet. Sleeping 60 seconds..."
  sleep 60
done

echo -e "\a"
sleep 1
echo -e "\a"
sleep 1
echo -e "\a"
