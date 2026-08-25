# Releasing Phoenix Assets

One `vX.Y.Z` tag identifies the Hex package and all four npm packages. The release workflow rejects
version drift, builds the registry artifacts once, installs and imports those exact tarballs in
throwaway consumers, records their checksums, and only then enters the protected `release`
environment.

## One-time repository and registry setup

1. Protect `main`: require the current CI jobs, require the branch to be up to date, disable
   administrator bypass, and forbid force pushes and deletion.
2. Protect `v*` with a no-bypass ruleset that restricts tag creation to maintainers and forbids
   tag update and deletion.
3. Create a GitHub environment named `release` with administrator bypass disabled, required
   reviewers, and deployment restricted to tags matching `v*`.
4. Add `HEX_API_KEY` to that environment. Generate a dedicated Hex key with only `api:write`:
   `mix hex.user key generate --key-name phoenix-assets-ci --permission api:write`.
5. Create the `phoenix-assets` npm organization and make the publishing account an owner. Bootstrap
   the four packages with a short-lived granular `NPM_TOKEN` configured exactly as follows:
   **Packages and scopes** = **Read and write**, **Only select packages and scopes** =
   `@phoenix-assets`, **Bypass two-factor authentication** = enabled, and no IP restriction. The
   separate **Organizations** permission may remain **No access**: npm documents that organization
   access manages membership and settings but does not grant permission to publish packages. Store
   the token in the GitHub `release` environment, not as a repository-wide secret.
6. After the first npm publish, configure each package's npm trusted publisher for
   `futhr/phoenix-assets`, workflow `release.yml`, environment `release`, and publish permission.
   Remove `NPM_TOKEN` after all four packages use OIDC.
7. GitHub artifact attestations for private repositories require GitHub Enterprise Cloud. The
   publish job deliberately fails before registry mutation when attestations are unavailable;
   enable the repository feature or make the source repository public before the first production
   release.

If a tagged run publishes npm artifacts but fails while publishing Hex or HexDocs, repair that
immutable release from its already-attested artifact and tagged source instead of moving the tag or
rebuilding bytes:

```bash
gh workflow run recover-hex.yml \
  --field release_tag=v0.1.0 \
  --field source_run_id=32740503072
```

After the recovery succeeds, rerun the original release job. Its registry preflight skips artifacts
whose published bytes match the manifest and finishes the GitHub release record.

Verify the GitHub controls before every production release:

```bash
gh api repos/futhr/phoenix-assets/environments/release
gh api repos/futhr/phoenix-assets/environments/release/deployment-branch-policies
gh api repos/futhr/phoenix-assets/branches/main/protection
gh api repos/futhr/phoenix-assets/rulesets
```

No GitHub personal access token is needed. The workflow's short-lived `GITHUB_TOKEN` only reads the
repository, writes the GitHub release, and records attestations. npm uses OIDC after bootstrap; Hex
uses its registry-specific, least-privilege key.

## Prepare and dry-run

Conventional commits drive the shared version. `git_ops` updates `mix.exs`, all four npm manifests,
the changelog, and the tag in one release commit:

```bash
git rm CHANGELOG.md           # first release only: remove the bootstrap placeholder
mix git_ops.release --initial # GitOps recreates the changelog in the release commit
# or: mix git_ops.release
node scripts/release.mjs check --tag "$(git describe --tags --exact-match)" --network
```

The tracked changelog before the first release is only a bootstrap placeholder used by package and
documentation checks. Remove it immediately before the initial GitOps release; do not commit the
deletion separately.

Push the release commit without its tag, then dispatch the **Release** workflow on `main` with
`dry_run` enabled. It runs the complete Elixir 1.18/OTP 27 and Elixir 1.20/OTP 29 matrix, creates all
five artifacts, verifies package exports, and runs exact-artifact consumer smokes without changing
a registry.

Push only the tag after the dry run is green (`git push` does not push tags unless asked):

```bash
git push origin "vX.Y.Z"
```

The tag run repeats the supported matrix from the tagged commit. The protected publish job verifies
the downloaded artifact checksums, records build provenance, publishes those exact bytes, and
attaches the artifacts, manifest, and checksums to the GitHub release.

## Partial failure and recovery

Registry publication cannot be atomic across npm and Hex. The orchestrator therefore performs all
registry reads before its first write. A version already present with the exact local tarball
checksum is skipped; the same version with different bytes aborts the whole run.

If a network or registry failure interrupts publishing, rerun the same tag job. It resumes at the
first missing artifact and never rebuilds or overwrites a published artifact. Do not create a new
tag for a transport failure.

If the bytes themselves are defective, stop instead of rerunning. Within Hex's allowed window,
`mix hex.publish --revert X.Y.Z` can revert the Hex release; otherwise retire it. Deprecate affected
npm versions rather than relying on unpublish, fix forward with a new version, and record the
incident on the GitHub release.

## Local release contract checks

```bash
pnpm test:release
pnpm check:release
node scripts/release.mjs build --allow-untagged --artifact-dir dist/release
node scripts/release.mjs smoke --allow-untagged --artifact-dir dist/release
node scripts/release.mjs publish --allow-untagged --artifact-dir dist/release --dry-run
```

The production workflow never uses `--allow-untagged`.
