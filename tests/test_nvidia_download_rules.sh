#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

expected="$tmpdir/expected.txt"
ledger="$tmpdir/ledger.txt"
yaml="$tmpdir/yaml.txt"
mrs="$tmpdir/mrs.txt"

printf '%s\n' \
  developer.download.nvidia.cn \
  developer.download.nvidia.com \
  download.nvidia.com \
  nvidia.download.com \
  | LC_ALL=C sort -u > "$expected"

awk -F '\t' 'NR>1 && $8=="yes" {print $2}' \
  "$repo_root/rulesets/nvidia_download_connectivity.tsv" \
  | LC_ALL=C sort -u > "$ledger"

awk '/^  - / {sub(/^  - /, ""); print}' \
  "$repo_root/rulesets/nvidia_download_direct.yaml" \
  | LC_ALL=C sort -u > "$yaml"

LC_ALL=C sort -u \
  "$repo_root/rulesets/mrs_src/nvidia_download_direct_from_mrs.txt" \
  > "$mrs"

diff -u "$expected" "$ledger"
diff -u "$expected" "$yaml"
diff -u "$expected" "$mrs"

printf 'PASS: NVIDIA ledger, YAML, and MRS export contain all required hosts\n'
