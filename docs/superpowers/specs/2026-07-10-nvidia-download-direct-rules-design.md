# NVIDIA Download Direct Rule Set Design

## Goal

Create a dedicated Mihomo domain rule set for NVIDIA's core binary download infrastructure. The rule set will cover graphics drivers, data-center drivers, CUDA, and cuDNN only when a hostname is supported by an NVIDIA-owned source and passes direct-connectivity tests from the current machine.

The final change will be committed and pushed directly to `main`, as explicitly approved for this repository.

## Scope

Candidate download paths include:

- Windows and Linux graphics driver binaries, including regional NVIDIA mirrors.
- NVIDIA data-center driver redistributions.
- CUDA local installers, package repositories, and redistributable archives.
- Current cuDNN redistributable archives and still-accessible historical archives.
- The mainland China mirrors for the same NVIDIA-hosted download paths.

The following are excluded unless they unexpectedly prove necessary for the binary transfer itself:

- Marketing, documentation, and developer portal pages.
- Driver discovery APIs that return a URL but do not carry the binary.
- Telemetry, advertising, authentication, and unrelated NVIDIA services.
- Third-party distribution channels such as PyPI, conda-forge, or Anaconda.
- CDN CNAME targets that are not requested directly by the client.

## Rule Granularity

Use exact requested hostnames rather than broad NVIDIA suffixes. A hostname enters the rule set only when all three conditions hold:

1. An official NVIDIA page, guide, repository index, manifest, or download response identifies it as part of a core download path.
2. It carries a binary, repository artifact, redistributable manifest, or other file required to obtain the binary.
3. It passes the direct-connectivity test described below.

This intentionally prefers a smaller auditable allowlist over speculative coverage of every current or future `nvidia.com` subdomain.

## Artifacts

The implementation will add:

- `rulesets/nvidia_download_direct.yaml`: readable source using Mihomo `domain` behavior syntax.
- `rulesets/nvidia_download_direct.mrs`: generated binary rule set.
- `rulesets/nvidia_download_connectivity.tsv`: evidence for every tested candidate, including excluded candidates.

The TSV will record at least product category, sample official URL, requested hostname, hostname role, direct DNS/TCP/TLS/HTTP outcome, repeated result, inclusion decision, reason, and test timestamp.

## Direct-Connectivity Test

Testing must not rely only on an HTTP status. For each candidate:

1. Record the current proxy environment and macOS system proxy state.
2. Clear HTTP, HTTPS, and SOCKS proxy environment variables for the request.
3. Force curl to bypass proxy selection with `--noproxy '*'`.
4. Record DNS answers and reject Fake-IP or reserved-range results as proof of physical reachability.
5. Validate TCP 443 and TLS with the requested SNI.
6. Follow redirects while recording the ordered redirect chain.
7. Use HEAD when supported and a small Range GET to avoid downloading large installers.
8. Repeat the file request at least twice and record failures at the stage where they occur.

If the host can only be reached through a system TUN, transparent proxy, or Fake-IP path that cannot be ruled out, the evidence will say so and the host will not be described as proven physical direct connectivity.

## MRS Generation and Verification

Mihomo supports `.mrs` only for `domain` and `ipcidr` behaviors. This rule set uses `domain`.

Generation will use:

```text
mihomo convert-ruleset domain yaml rulesets/nvidia_download_direct.yaml rulesets/nvidia_download_direct.mrs
```

Verification will convert the generated `.mrs` back to text and compare the exported entries with the YAML source. Additional checks will verify valid YAML, unique/sorted hostnames, a non-empty `.mrs`, and a clean Git diff.

## Error Handling

- Redirect-only entry points are recorded but excluded when the final file hostname is sufficient.
- A candidate that resolves but fails TLS or the Range GET is excluded.
- A `403`, `404`, or method-specific HEAD failure is not automatically treated as unreachable; a small GET against a known current file determines the final result.
- Historical mirrors remain excluded unless a known historical artifact is still retrievable directly.
- An unavailable Mihomo binary blocks `.mrs` generation; the implementation may download a verified official Mihomo release binary locally, but must not commit that executable.

## Source Baseline

The initial official-source baseline is:

- NVIDIA cuDNN installation documentation and redist archives under `developer.download.nvidia.com/compute/cudnn/`.
- NVIDIA CUDA repositories and redist archives under `developer.download.nvidia.com/compute/cuda/`.
- NVIDIA data-center driver redistributions under `developer.download.nvidia.com/compute/nvidia-driver/redist/`.
- NVIDIA graphics driver downloads under `download.nvidia.com` and documented regional variants.
- NVIDIA's mainland mirror under `developer.download.nvidia.cn`.
- Mihomo rule-provider documentation for `domain` behavior and `.mrs` conversion.

Research may discover additional candidates, but the inclusion gate remains unchanged.

## Acceptance Criteria

- Every included hostname has an official NVIDIA source and a successful repeated direct file test.
- Every tested hostname appears in the TSV with an explicit inclusion or exclusion reason.
- The YAML contains exact hostnames only and has no duplicates.
- The generated `.mrs` round-trips to the same hostname set.
- No unrelated existing rule set is modified.
- The final commit is pushed to `origin/main` through the repository's configured GitHub remote.
