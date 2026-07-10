# NVIDIA Download Direct Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and publish an auditable Mihomo `.mrs` domain rule set containing only directly reachable NVIDIA core download hostnames.

**Architecture:** Treat NVIDIA's official pages and download indexes as candidate discovery evidence, then test each requested hostname through a proxy-bypassed DNS/TCP/TLS/HTTP path. Store the decision ledger in TSV, keep a readable Mihomo domain YAML source, compile it to `.mrs`, and prove the binary round-trips to the same hostname set.

**Tech Stack:** POSIX shell tools, curl, macOS `scutil`/`route`/`dig`, Mihomo `convert-ruleset`, YAML, TSV, Git.

## Global Constraints

- Include only exact requested hostnames; do not add broad `nvidia.com` or `download.nvidia.com` suffix rules.
- Require both an NVIDIA official source and a successful repeated proxy-bypassed file request.
- Exclude marketing pages, documentation pages, discovery-only APIs, telemetry, authentication, and third-party package ecosystems.
- Do not modify existing direct or reject rule sets.
- Keep the Mihomo executable untracked.
- Push the final verified commits directly to `origin/main`, as explicitly approved.

## File Map

- Create `rulesets/nvidia_download_connectivity.tsv`: auditable candidate and direct-connectivity decision ledger.
- Create `rulesets/nvidia_download_direct.yaml`: exact hostnames accepted by the ledger, in Mihomo domain behavior YAML.
- Create `rulesets/nvidia_download_direct.mrs`: generated Mihomo binary ruleset.
- Create `rulesets/mrs_src/nvidia_download_direct_from_mrs.txt`: round-trip export used to verify the generated binary.
- Modify no existing rule source or generated artifact.

---

### Task 1: Discover and Probe NVIDIA Download Hosts

**Files:**
- Create: `rulesets/nvidia_download_connectivity.tsv`

**Interfaces:**
- Consumes: NVIDIA official download indexes and documentation.
- Produces: TSV rows with columns `product`, `hostname`, `role`, `sample_url`, `dns`, `tls`, `http_attempts`, `included`, `reason`, `tested_at`.

- [ ] **Step 1: Record proxy and route evidence before testing**

Run:

```bash
env | rg -i '^(http|https|all|no)_proxy=' || true
scutil --proxy
route -n get default
```

Expected: output is captured in the task log. Any enabled macOS HTTP/HTTPS/SOCKS proxy, TUN default route, or Fake-IP DNS result is explicitly reported and prevents describing the result as proven physical direct connectivity.

- [ ] **Step 2: Establish the concrete candidate matrix from official sources**

Test these exact request hosts and seed URLs:

```text
download.nvidia.com|graphics_driver|https://download.nvidia.com/XFree86/Linux-x86_64/latest.txt
us.download.nvidia.com|graphics_driver_region|https://us.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
cn.download.nvidia.com|graphics_driver_region|https://cn.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
uk.download.nvidia.com|graphics_driver_region|https://uk.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
jp.download.nvidia.com|graphics_driver_region|https://jp.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
international.download.nvidia.com|graphics_driver_region|https://international.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
developer.download.nvidia.com|cuda_cudnn_driver_redist|https://developer.download.nvidia.com/compute/cudnn/redist/
developer.download.nvidia.cn|cuda_cudnn_mirror|https://developer.download.nvidia.cn/compute/cudnn/redist/
gfwsl.geforce.com|driver_discovery|https://gfwsl.geforce.com/
gfwsl.geforce.cn|driver_discovery|https://gfwsl.geforce.cn/
```

Expected: discovery-only hosts remain candidates for an explicit exclusion row, not automatic rule entries.

- [ ] **Step 3: Resolve each hostname without trusting Fake-IP answers**

Run:

```bash
for hostname in \
  download.nvidia.com \
  us.download.nvidia.com \
  cn.download.nvidia.com \
  uk.download.nvidia.com \
  jp.download.nvidia.com \
  international.download.nvidia.com \
  developer.download.nvidia.com \
  developer.download.nvidia.cn \
  gfwsl.geforce.com \
  gfwsl.geforce.cn
do
  printf '%s\n' "$hostname"
  dig +short A "$hostname"
  dig +short AAAA "$hostname"
  dig +short CNAME "$hostname"
done
```

Expected: at least one public A or AAAA address for an includable host. Answers in `198.18.0.0/15`, RFC1918 space, loopback, link-local, or unique-local IPv6 are marked `fake_or_reserved` and are not sufficient evidence.

- [ ] **Step 4: Test TLS and two proxy-bypassed HTTP requests**

Run:

```bash
while IFS='|' read -r hostname product url; do
  for attempt in 1 2; do
    printf '%s\t%s\t%s\t' "$hostname" "$product" "$attempt"
    env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
      curl --noproxy '*' --connect-timeout 10 --max-time 30 --retry 0 \
      --silent --show-error --location --range 0-1023 \
      --output /dev/null --write-out '%{url_effective}\t%{http_code}\t%{remote_ip}\t%{ssl_verify_result}\t%{size_download}\t%{time_connect}\t%{time_starttransfer}\n' \
      "$url"
  done
done <<'EOF'
download.nvidia.com|graphics_driver|https://download.nvidia.com/XFree86/Linux-x86_64/latest.txt
us.download.nvidia.com|graphics_driver_region|https://us.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
cn.download.nvidia.com|graphics_driver_region|https://cn.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
uk.download.nvidia.com|graphics_driver_region|https://uk.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
jp.download.nvidia.com|graphics_driver_region|https://jp.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
international.download.nvidia.com|graphics_driver_region|https://international.download.nvidia.com/XFree86/Linux-x86_64/latest.txt
developer.download.nvidia.com|cuda_cudnn_driver_redist|https://developer.download.nvidia.com/compute/cudnn/redist/
developer.download.nvidia.cn|cuda_cudnn_mirror|https://developer.download.nvidia.cn/compute/cudnn/redist/
gfwsl.geforce.com|driver_discovery|https://gfwsl.geforce.com/
gfwsl.geforce.cn|driver_discovery|https://gfwsl.geforce.cn/
EOF
```

Repeat the command once. Expected for an includable host: both attempts complete, TLS verification is `0`, the response is a useful `200` or `206`, and at least one response transfers data. A `403` or `404` on an index must be followed by a known file URL before declaring failure.

- [ ] **Step 5: Follow driver index data to an actual binary**

For each region whose `latest.txt` succeeds, fetch its returned relative `.run` path and issue the same two Range GETs against that hostname.

Run:

```bash
for hostname in \
  download.nvidia.com \
  us.download.nvidia.com \
  cn.download.nvidia.com \
  uk.download.nvidia.com \
  jp.download.nvidia.com \
  international.download.nvidia.com
do
  printf '%s\t' "$hostname"
  env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
    curl --noproxy '*' --silent --show-error --fail \
    "https://$hostname/XFree86/Linux-x86_64/latest.txt" || true
done
```

Expected: a version and relative installer path. Only regions whose actual installer Range GET also succeeds can be included.

- [ ] **Step 6: Follow CUDA and cuDNN indexes to actual artifacts**

Use the official directory indexes to select one current CUDA redistrib JSON, one current cuDNN redistrib JSON or archive, and one data-center-driver redistrib manifest. Repeat the Range GET test against the resulting `developer.download.nvidia.com` URL and the corresponding `.cn` URL when the mirror exposes the same path.

Expected: the final requested hostname remains the NVIDIA developer download host, and both attempts meet the TLS/HTTP criteria. Record missing mirror paths as exclusions rather than assuming parity.

- [ ] **Step 7: Create the TSV ledger with every tested candidate**

Use `apply_patch` to create a tab-separated file with this exact header:

```text
product\thostname\trole\tsample_url\tdns\ttls\thttp_attempts\tincluded\treason\ttested_at
```

For each candidate, set `included` to `yes` only when the official-source, role, DNS, TLS, and repeated file-request gates all pass. Set it to `no` with a concrete failure or exclusion reason otherwise.

- [ ] **Step 8: Validate the ledger before rule generation**

Run:

```bash
awk -F '\t' 'NR==1 { exit !($1=="product" && $2=="hostname" && $8=="included") } NR>1 { if (NF!=10 || ($8!="yes" && $8!="no")) bad=1 } END { exit bad }' rulesets/nvidia_download_connectivity.tsv
awk -F '\t' 'NR>1 && $8=="yes" {print $2}' rulesets/nvidia_download_connectivity.tsv | sort | uniq -d
```

Expected: both commands exit `0`; the duplicate-host output is empty.

- [ ] **Step 9: Commit the evidence ledger**

Run:

```bash
git add rulesets/nvidia_download_connectivity.tsv
git diff --cached --check
git commit -m "docs: record NVIDIA download connectivity"
```

Expected: one commit containing only the TSV ledger.

---

### Task 2: Build and Round-Trip the Mihomo Rule Set

**Files:**
- Create: `rulesets/nvidia_download_direct.yaml`
- Create: `rulesets/nvidia_download_direct.mrs`
- Create: `rulesets/mrs_src/nvidia_download_direct_from_mrs.txt`

**Interfaces:**
- Consumes: rows where column `included` is `yes` in `rulesets/nvidia_download_connectivity.tsv`.
- Produces: Mihomo domain YAML and `.mrs` files containing exactly the same sorted unique hostnames.

- [ ] **Step 1: Prove the rule source does not exist yet**

Run:

```bash
test ! -e rulesets/nvidia_download_direct.yaml
test ! -e rulesets/nvidia_download_direct.mrs
```

Expected: both commands exit `0` before implementation.

- [ ] **Step 2: Create the readable YAML source**

First print the exact required source content:

```bash
printf 'payload:\n'
awk -F '\t' 'NR>1 && $8=="yes" {print $2}' rulesets/nvidia_download_connectivity.tsv | LC_ALL=C sort -u | sed 's/^/  - /'
```

Then use `apply_patch` to create `rulesets/nvidia_download_direct.yaml` with exactly that output. Do not add `+.` suffix rules or any hostname absent from an `included=yes` TSV row.

- [ ] **Step 3: Validate YAML-to-ledger equality before conversion**

Run:

```bash
awk -F '\t' 'NR>1 && $8=="yes" {print $2}' rulesets/nvidia_download_connectivity.tsv | LC_ALL=C sort -u > /tmp/nvidia-ledger-hosts.txt
awk '/^  - / {sub(/^  - /, ""); print}' rulesets/nvidia_download_direct.yaml | LC_ALL=C sort -u > /tmp/nvidia-yaml-hosts.txt
diff -u /tmp/nvidia-ledger-hosts.txt /tmp/nvidia-yaml-hosts.txt
```

Expected: `diff` exits `0` with no output.

- [ ] **Step 4: Obtain a trusted Mihomo converter if `./mihomo` is absent**

First run:

```bash
test -x ./mihomo && ./mihomo -v
```

If absent, download the correct macOS release asset from the official MetaCubeX/mihomo GitHub release, verify its published checksum when available, unpack it as `./mihomo`, and confirm `.gitignore` excludes it.

Expected: `./mihomo -v` exits `0`, and `git status --short --ignored` shows the executable as ignored rather than staged.

- [ ] **Step 5: Convert YAML to MRS and export it back to text**

Run:

```bash
./mihomo convert-ruleset domain yaml rulesets/nvidia_download_direct.yaml rulesets/nvidia_download_direct.mrs
./mihomo convert-ruleset domain mrs rulesets/nvidia_download_direct.mrs rulesets/mrs_src/nvidia_download_direct_from_mrs.txt
```

Expected: both commands exit `0`; the `.mrs` is non-empty and the text export lists the accepted hostnames.

- [ ] **Step 6: Verify the round-trip set**

Run:

```bash
LC_ALL=C sort -u rulesets/mrs_src/nvidia_download_direct_from_mrs.txt > /tmp/nvidia-mrs-hosts.txt
diff -u /tmp/nvidia-ledger-hosts.txt /tmp/nvidia-mrs-hosts.txt
test -s rulesets/nvidia_download_direct.mrs
```

Expected: `diff` exits `0` with no output and the non-empty check exits `0`.

- [ ] **Step 7: Commit the rule artifacts**

Run:

```bash
git add rulesets/nvidia_download_direct.yaml rulesets/nvidia_download_direct.mrs rulesets/mrs_src/nvidia_download_direct_from_mrs.txt
git diff --cached --check
git commit -m "feat: add NVIDIA download direct ruleset"
```

Expected: one commit containing only the YAML source, `.mrs`, and round-trip export.

---

### Task 3: Final Verification and Publish

**Files:**
- Verify: `docs/superpowers/specs/2026-07-10-nvidia-download-direct-rules-design.md`
- Verify: `docs/superpowers/plans/2026-07-10-nvidia-download-direct-rules.md`
- Verify: `rulesets/nvidia_download_connectivity.tsv`
- Verify: `rulesets/nvidia_download_direct.yaml`
- Verify: `rulesets/nvidia_download_direct.mrs`
- Verify: `rulesets/mrs_src/nvidia_download_direct_from_mrs.txt`

**Interfaces:**
- Consumes: all completed evidence and generated artifacts.
- Produces: a clean, verified `main` pushed to `origin/main`.

- [ ] **Step 1: Run the complete acceptance check**

Run:

```bash
set -e
test -s rulesets/nvidia_download_connectivity.tsv
test -s rulesets/nvidia_download_direct.yaml
test -s rulesets/nvidia_download_direct.mrs
test -s rulesets/mrs_src/nvidia_download_direct_from_mrs.txt
awk -F '\t' 'NR==1 { exit !($1=="product" && $2=="hostname" && $8=="included") } NR>1 { if (NF!=10 || ($8!="yes" && $8!="no")) bad=1 } END { exit bad }' rulesets/nvidia_download_connectivity.tsv
awk -F '\t' 'NR>1 && $8=="yes" {print $2}' rulesets/nvidia_download_connectivity.tsv | LC_ALL=C sort -u > /tmp/nvidia-ledger-hosts.txt
awk '/^  - / {sub(/^  - /, ""); print}' rulesets/nvidia_download_direct.yaml | LC_ALL=C sort -u > /tmp/nvidia-yaml-hosts.txt
LC_ALL=C sort -u rulesets/mrs_src/nvidia_download_direct_from_mrs.txt > /tmp/nvidia-mrs-hosts.txt
diff -u /tmp/nvidia-ledger-hosts.txt /tmp/nvidia-yaml-hosts.txt
diff -u /tmp/nvidia-ledger-hosts.txt /tmp/nvidia-mrs-hosts.txt
git diff --check
git status -sb
```

Expected: all checks exit `0`, both diffs are empty, and the worktree contains no uncommitted rule changes.

- [ ] **Step 2: Verify branch and remote state immediately before push**

Run:

```bash
git branch --show-current
git remote -v
git log --oneline --decorate origin/main..main
```

Expected: branch is `main`, remote is `git@github.com:lpxgita/Custom_mihomo_rules.git`, and the outgoing commits are only the approved design, plan, connectivity evidence, and rule artifacts.

- [ ] **Step 3: Push through the verified SSH path**

Because the local SSH config references a missing `~/.ssh/id_ed25519`, use the already verified RSA identity and GitHub's verified `ssh.github.com:443` host key through a per-command `GIT_SSH_COMMAND`; do not edit global SSH config.

Run:

```bash
GIT_SSH_COMMAND='ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes -o UserKnownHostsFile=/tmp/github-ssh-ed25519.pub -o StrictHostKeyChecking=yes -p 443' \
  git push origin main
```

Expected: Git reports `main -> main` without a non-fast-forward or authentication error.

- [ ] **Step 4: Verify remote synchronization after push**

Run:

```bash
GIT_SSH_COMMAND='ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes -o UserKnownHostsFile=/tmp/github-ssh-ed25519.pub -o StrictHostKeyChecking=yes -p 443' \
  git fetch origin main
git rev-parse main
git rev-parse origin/main
git status -sb
```

Expected: the two revisions are identical and status is `## main...origin/main` with no ahead/behind marker.
