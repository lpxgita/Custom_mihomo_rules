#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

SENTINEL="$OUT_DIR/nvidia_download_direct.yaml"
EXPECTED_SENTINEL="$OUT_DIR/nvidia_download_direct.expected"
printf 'payload:\n  - DOMAIN-SUFFIX,download.nvidia.com\n' > "$SENTINEL"
cp "$SENTINEL" "$EXPECTED_SENTINEL"

bash "$REPO_ROOT/scripts/split_rulesets.sh" "$REPO_ROOT/self_rule.txt" "$OUT_DIR"

if [[ ! -f "$SENTINEL" ]]; then
  echo "Expected dedicated NVIDIA YAML source to be preserved: $SENTINEL" >&2
  exit 1
fi

if ! cmp -s "$EXPECTED_SENTINEL" "$SENTINEL"; then
  echo "Expected dedicated NVIDIA YAML source content to remain unchanged" >&2
  exit 1
fi

for output in \
  direct_resolve_classical.yaml \
  direct_no_resolve_classical.yaml \
  reject_resolve_classical.yaml \
  reject_no_resolve_classical.yaml \
  analysis.tsv; do
  if [[ ! -f "$OUT_DIR/$output" ]]; then
    echo "Expected generated output to exist: $OUT_DIR/$output" >&2
    exit 1
  fi
done

echo "PASS: split preserves dedicated NVIDIA YAML and creates owned outputs"
