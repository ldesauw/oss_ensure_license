# Go LICENSES folder action

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
      - uses: ldesauw/oss_ensure_license@v1
        with:
          mode: check
```

### Auto-update via pull request

Regenerate on `main` and open a PR when anything changed:

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
      - uses: ldesauw/oss_ensure_license@v1
        with:
          mode: write
      - uses: peter-evans/create-pull-request@v7
        with:
          commit-message: "chore: update LICENSES folder"
          title: "chore: update LICENSES folder"
          branch: chore/update-licenses
          add-paths: LICENSES
```

> [!NOTE]
> `peter-evans/create-pull-request` needs **Settings → Actions → General →
> "Allow GitHub Actions to create and approve pull requests"** enabled, or a
> PAT / GitHub App token passed via its `token:` input.

## Inputs

| Input | Default | Description |
|---|---|---|
| `mode` | `check` | `check` fails on drift; `write` regenerates in place. |
| `packages` | `./...` | Go packages to scan. |
| `output-dir` | `LICENSES` | Output folder, relative to `working-directory`. |
| `working-directory` | `.` | Go module directory (monorepo / subdir). |
| `go-version` | *(empty)* | Go version for `setup-go`; empty ⇒ use `go-version-file`. |
| `go-version-file` | `go.mod` | File to read the Go version from. |
| `go-licenses-version` | `v2.0.1` | Pinned `go-licenses/v2` version. |
| `fail-on-licenses` | *(empty)* | Comma-separated SPDX ids to forbid, e.g. `GPL-3.0,AGPL-3.0`. |

## Outputs

| Output | Description |
|---|---|
| `changed` | `"true"` if regeneration changed the folder. |
| `summary` | Path to the generated `LICENSES.txt`. |
| `licenses` | Comma-separated unique licences found. |

## Local use

```bash
./hack/gen-licenses.sh          # regenerate LICENSES/ in the current module
git status LICENSES             # review the diff
```

Environment variables (`GEN_LICENSES_WORKDIR`, `GEN_LICENSES_OUTPUT_DIR`,
`GEN_LICENSES_PACKAGES`, `GEN_LICENSES_VERSION`, `GEN_LICENSES_FAIL_ON`)
override the defaults; see the script header.
