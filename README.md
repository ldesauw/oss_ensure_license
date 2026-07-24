# Endure Licence

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Marketplace](https://img.shields.io/badge/GitHub%20Marketplace-Endure%20Licence-blue?logo=github)](https://github.com/marketplace/actions/endure-licence)

A GitHub Action that generates and verifies a `LICENSES/` folder for a Go
module, following the [OVH](https://github.com/ovh) convention:

```
LICENSES/
├── LICENSES.txt                       # summary: unique licences + per-package list
└── go/
    ├── github.com/google/uuid/LICENSE
    ├── github.com/hashicorp/go-version/LICENSE
    └── ...                             # one LICENSE file per dependency
```

Exactly **one `LICENSE` file per dependency**, whatever the licence type.
Reciprocal licences (MPL-2.0, ...) are treated like permissive ones — their
source is **not** vendored — matching repos like
[`ovh/terraform-provider-ovh`](https://github.com/ovh/terraform-provider-ovh/tree/master/LICENSES)
and [`ovh/okms-cli`](https://github.com/ovh/okms-cli/tree/main/LICENSES/go).

Under the hood it uses [`google/go-licenses`](https://github.com/google/go-licenses)
(pinned) via [`hack/gen-licenses.sh`](hack/gen-licenses.sh), which you can also
run locally.

## Usage

### Check on pull requests

Fail the build when the committed `LICENSES/` folder no longer matches the
current dependencies:

```yaml
name: check-licenses
on:
  pull_request:
    paths: ["go.mod", "go.sum", "LICENSES/**"]
permissions:
  contents: read
jobs:
  check-licenses:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ovh/oss_ensure_license@v1
        with:
          mode: check
```

### Auto-update via pull request

Regenerate on `main` and let the action open (or update) a PR when anything
changed — no extra action required:

```yaml
name: update-licenses
on:
  push:
    branches: [main]
    paths: ["go.mod", "go.sum"]
  workflow_dispatch:
permissions:
  contents: write
  pull-requests: write
jobs:
  update-licenses:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ovh/oss_ensure_license@v1
        with:
          mode: pr
          pr-labels: "dependencies,licenses"
```

The action commits the regenerated folder to `pr-branch` (default
`chore/update-licenses`), pushes it, and opens a PR — or updates the existing
one on later runs. If nothing changed, no PR is created.

> [!NOTE]
> Opening a PR with the default `GITHUB_TOKEN` requires **Settings → Actions →
> General → "Allow GitHub Actions to create and approve pull requests"**
> enabled. Otherwise pass a PAT or GitHub App token via the `token:` input.
> This is a GitHub restriction on `GITHUB_TOKEN`, independent of how the PR is
> created.

## Inputs

| Input | Default | Description |
|---|---|---|
| `mode` | `check` | `check` fails on drift; `write` regenerates in place; `pr` regenerates and opens/updates a PR. |
| `packages` | `./...` | Go packages to scan. |
| `output-dir` | `LICENSES` | Output folder, relative to `working-directory`. |
| `working-directory` | `.` | Go module directory (monorepo / subdir). |
| `go-version` | *(empty)* | Go version for `setup-go`; empty ⇒ use `go-version-file`. |
| `go-version-file` | `go.mod` | File to read the Go version from. |
| `go-licenses-version` | `v2.0.1` | Pinned `go-licenses/v2` version. |
| `fail-on-licenses` | *(empty)* | Comma-separated SPDX ids to forbid, e.g. `GPL-3.0,AGPL-3.0`. |

### Pull-request options (`mode: pr`)

| Input | Default | Description |
|---|---|---|
| `token` | `GITHUB_TOKEN` | Token to push the branch and open the PR. |
| `pr-branch` | `chore/update-licenses` | Head branch for the PR. |
| `pr-base` | *(current ref)* | Base branch of the PR. |
| `pr-title` | `chore: update LICENSES folder` | PR title. |
| `pr-body` | *(see action.yml)* | PR body. |
| `pr-labels` | *(empty)* | Comma-separated labels to apply (must already exist). |
| `commit-message` | `chore: update LICENSES folder` | Commit message. |
| `git-user-name` / `git-user-email` | `github-actions[bot]` | Commit author identity. |

> `mode: pr` creates the branch, commit, and PR entirely through the GitHub
> REST API (`curl` + `jq`, both preinstalled on GitHub-hosted runners). The
> commit is therefore signed by GitHub and shows as **Verified**, and no git
> push credentials are needed.

## Outputs

| Output | Description |
|---|---|
| `changed` | `"true"` if regeneration changed the folder. |
| `summary` | Path to the generated `LICENSES.txt`. |
| `licenses` | Comma-separated unique licences found. |
| `pull-request-url` | URL of the PR opened/updated in `mode: pr` (empty otherwise). |

## Local use

```bash
./hack/gen-licenses.sh          # regenerate LICENSES/ in the current module
git status LICENSES             # review the diff
```

Environment variables (`GEN_LICENSES_WORKDIR`, `GEN_LICENSES_OUTPUT_DIR`,
`GEN_LICENSES_PACKAGES`, `GEN_LICENSES_VERSION`, `GEN_LICENSES_FAIL_ON`)
override the defaults; see the script header.

## Module in a subdirectory

For a Go module that is not at the repository root, set `working-directory`:

```yaml
- uses: ovh/oss_ensure_license@v1
  with:
    mode: check
    working-directory: services/api
```

The `LICENSES/` folder is written inside that directory. This repository uses
the same mechanism to self-test the action against
[`testdata/example-module`](testdata/example-module) — see
[`.github/workflows`](.github/workflows).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Participation is governed by our
[Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities per
[SECURITY.md](SECURITY.md).

## License

Licensed under the [Apache License 2.0](LICENSE). Copyright © OVH SAS.
