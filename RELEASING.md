# Releasing Phoenix Assets

One `vX.Y.Z` tag identifies the Hex package and all four npm packages. The
release builds five artifacts once, tests those tarballs, and publishes the
verified bytes.
The release manifest binds every checksum to the source commit and version.
Its contract remains `phoenix-assets/release/v1`.

## Local qualification

Use the pinned toolchain and run the complete local gate before releasing:

```bash
mise exec -- mix deps.get
mise exec -- pnpm install --frozen-lockfile
mise exec -- mix check --no-retry
```

Also run warnings-as-errors compilation and ExUnit on Elixir 1.18 / OTP 27,
and the complete gate on Elixir 1.20 / OTP 29. Keep each toolchain's build and
PLT caches separate. The full gate includes both coverage floors, dependency
audits, docs, Dialyzer, package exports and a consumer of the built Hex tarball.
The Hex metadata must not constrain `phoenix_sync` or `electric`; each host
owns its backend. Development tests qualify the immutable Phoenix.Sync fork,
and the frontend tests use the actual Electric and TanStack packages.

Iteration and release qualification run locally. Ordinary pull requests
run one current-runtime lane. The second runtime, Dialyzer and exact-artifact
checks remain full local/release gates. Main and tag pushes do not start CI.
No paid GitHub feature or repository visibility change is required.

## Prepare the shared release

Conventional commits drive the shared version. From the Git root,
`mix git_ops.release` updates `mix.exs`, all four npm manifests, the changelog
and the tag. Never change a schema version merely to release the packages.

Build from the clean tagged commit, after local qualification:

```bash
mise exec -- mix git_ops.release
mise exec -- node scripts/release.mjs check --tag vX.Y.Z --network
mise exec -- node scripts/release.mjs build --tag vX.Y.Z --artifact-dir dist/release
mise exec -- node scripts/release.mjs smoke --tag vX.Y.Z --artifact-dir dist/release
mise exec -- node scripts/release.mjs publish --tag vX.Y.Z --artifact-dir dist/release --dry-run
```

Use the actual tag in place of `vX.Y.Z`. Untagged preparation can use
`--allow-untagged`; production publication requires the exact tag and a clean
worktree. Review the five artifacts, `release-manifest.json` and `SHA256SUMS`.
Retain this directory so interrupted publication can reuse the same bytes.

## Publish the locally verified bytes

Use an authorized npm publishing login/token and a dedicated Hex API key with
`api:write`. Keep credentials in the local credential store or process
environment; never commit them. npm must grant write access to the
`@phoenix-assets` packages. Complete any registry-required authentication.

```bash
mise exec -- node scripts/release.mjs verify --tag vX.Y.Z --artifact-dir dist/release
mise exec -- node scripts/release.mjs publish --tag vX.Y.Z --artifact-dir dist/release
mise exec -- mix hex.publish docs --yes
git push origin main
git push origin vX.Y.Z
```

The publisher checks every registry before its first write. Existing
versions with identical checksums are skipped; different bytes abort the run.
Publish only the artifacts that passed the exact-tarball smokes. Store the tag,
manifest and checksums with the release record.

## Recovery and optional hosted release

Registry publication is not atomic across npm and Hex. After a transport
failure, rerun the same local `publish` command with the retained artifact
directory. Do not rebuild artifacts, move the tag or bump a version to recover
an interrupted upload. Defective published bytes require a new release.

The manually dispatched Release workflow uses the same identity checks and
artifact smokes. It is reserved for releases rather than normal iteration. Its
`release` environment holds `HEX_API_KEY` and, when
needed, `NPM_TOKEN`. npm trusted publishing may instead use that workflow's
OIDC identity. Protected branch/tag settings and release reviewers are
maintainer-managed controls. Artifact checksums and source identity are
required; GitHub's paid private-repository attestation feature is not.

The manual Recover Hex workflow can resume an artifact from a prior hosted
release run. Local releases recover directly from their retained directory.
