import assert from "node:assert/strict"
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import test from "node:test"
import { collectReleaseErrors, validateRelease } from "./release.mjs"

const packages = ["doc-shell", "lint", "svelte", "vite"]

function fixture(options = {}) {
  const root = mkdtempSync(join(tmpdir(), "phoenix-assets-release-test-"))
  mkdirSync(join(root, "config"))
  mkdirSync(join(root, "npm"))
  writeFileSync(join(root, "mix.exs"), `@version "${options.mixVersion ?? "1.2.3"}"\n`)
  writeFileSync(
    join(root, "config/config.exs"),
    'repository_url: "https://github.com/futhr/phoenix-assets"\n',
  )
  writeFileSync(join(root, "README.md"), "https://github.com/futhr/phoenix-assets\n")
  writeFileSync(join(root, "CHANGELOG.md"), "https://github.com/futhr/phoenix-assets\n")

  for (const name of packages) {
    const directory = `npm/${name}`
    mkdirSync(join(root, directory))
    writeFileSync(
      join(root, directory, "package.json"),
      `${JSON.stringify(
        {
          name: `@phoenix-assets/${name}`,
          version: options.npmVersions?.[name] ?? "1.2.3",
          homepage: "https://github.com/futhr/phoenix-assets",
          repository: {
            type: "git",
            url: "git+https://github.com/futhr/phoenix-assets.git",
            directory,
          },
          publishConfig: { access: "public" },
        },
        null,
        2,
      )}\n`,
    )
  }
  return root
}

function withFixture(options, callback) {
  const root = fixture(options)
  try {
    callback(root)
  } finally {
    rmSync(root, { force: true, recursive: true })
  }
}

test("accepts one version and its exact tag across all five artifacts", () => {
  withFixture({}, (root) => {
    assert.equal(validateRelease(root, { checkGit: false, tag: "v1.2.3" }), "1.2.3")
  })
})

test("rejects npm version drift", () => {
  withFixture({ npmVersions: { svelte: "1.2.4" } }, (root) => {
    assert.ok(
      collectReleaseErrors(root, { checkGit: false, tag: "v1.2.3" }).some((error) =>
        error.includes("@phoenix-assets/svelte version 1.2.4 does not match Mix 1.2.3"),
      ),
    )
  })
})

test("rejects tag mismatch and untagged production releases", () => {
  withFixture({}, (root) => {
    assert.ok(
      collectReleaseErrors(root, { checkGit: false, tag: "v1.2.4" }).some((error) =>
        error.includes("tag v1.2.4 does not match release v1.2.3"),
      ),
    )
    assert.ok(
      collectReleaseErrors(root, { checkGit: false }).some((error) =>
        error.includes("production release requires"),
      ),
    )
    assert.equal(collectReleaseErrors(root, { allowUntagged: true, checkGit: false }).length, 0)
  })
})

test("rejects noncanonical repository metadata", () => {
  withFixture({}, (root) => {
    const manifestPath = join(root, "npm/vite/package.json")
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"))
    manifest.repository.url = `git+https://github.com/futhr/phoenix${"_assets"}.git`
    writeFileSync(manifestPath, `${JSON.stringify(manifest)}\n`)

    assert.ok(
      collectReleaseErrors(root, { checkGit: false, tag: "v1.2.3" }).some((error) =>
        error.includes("repository URL"),
      ),
    )
  })
})
