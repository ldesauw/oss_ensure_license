# Contributing

Thanks for taking the time to contribute!

## What this repository is

This repository is the **OSS Ensure License** GitHub Action. The moving parts are:

- [`action.yml`](action.yml) — the composite action interface (inputs/outputs).
- [`hack/gen-licenses.sh`](hack/gen-licenses.sh) — the generator that produces
  the `LICENSES/` folder. All real logic lives here.
- [`testdata/example-module/`](testdata/example-module) — a small Go module that
  exists only to exercise the action in CI. It is not part of the action.

## Running the generator locally

You need Go and `bash`. From any Go module:

```bash
GEN_LICENSES_WORKDIR="$PWD" /path/to/hack/gen-licenses.sh
```

Or, against the bundled example module:

```bash
cd testdata/example-module
GEN_LICENSES_WORKDIR="$PWD" ../../hack/gen-licenses.sh
git status LICENSES     # review the result
```

`go-licenses` is installed automatically at the pinned version if it is not
already on your `PATH`.

## Making a change

1. Fork and create a branch.
2. Make your change. If you touch the generator, regenerate the example
   module's `LICENSES/` folder (above) and commit the result — CI
   (`check-licenses`) fails otherwise.
3. Keep the shell script POSIX-friendly `bash` and `set -euo pipefail`-clean;
   run `bash -n hack/gen-licenses.sh` before pushing.
4. Open a pull request describing the change and the motivation.

## Reporting bugs and requesting features

Please use the issue templates. Include the action version, your workflow
snippet, and the relevant logs.

## Licence

By contributing, you agree that your contributions are licensed under the
[Apache License 2.0](LICENSE).
