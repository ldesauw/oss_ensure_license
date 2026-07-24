#!/usr/bin/env bash
#
# Regenerate the LICENSES/ folder for the current Go module.
#
#   LICENSES/go/<module-path>/LICENSE   one LICENSE file per dependency
#   LICENSES/LICENSES.txt               summary (unique licences + per-package list)
#
# Layout mirrors https://github.com/ovh/okms-k8s-encryption-provider/tree/main/LICENSES
# Run locally with `./hack/gen-licenses.sh` or in CI (see .github/workflows/update-licenses.yml).
set -euo pipefail

# Packages to scan (default: every package of the current module).
PKGS="${1:-./...}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/LICENSES"
GO_DIR="${OUT_DIR}/go"
SUMMARY="${OUT_DIR}/LICENSES.txt"

# Ensure go-licenses is installed and on PATH.
if ! command -v go-licenses >/dev/null 2>&1; then
  echo ">> installing github.com/google/go-licenses"
  go install github.com/google/go-licenses@latest
  export PATH="$(go env GOPATH)/bin:${PATH}"
fi

# 1. Save every dependency's LICENSE file, laid out by import path.
echo ">> saving dependency LICENSE files to ${GO_DIR}"
rm -rf "${GO_DIR}"
mkdir -p "${GO_DIR}"
go-licenses save "${PKGS}" --save_path="${GO_DIR}" --force

# 2. Build the LICENSES.txt summary.
echo ">> writing summary to ${SUMMARY}"
TPL="$(mktemp)"
trap 'rm -f "${TPL}"' EXIT
cat > "${TPL}" <<'EOF'
{{range .}}{{.Name}}; {{if .LicenseName}}{{.LicenseName}}{{else}}Unknown{{end}}
{{end}}
EOF

# One "package; Licence" line per dependency, sorted and blank-line-free.
PKG_LIST="$(go-licenses report "${PKGS}" --template "${TPL}" 2>/dev/null | sed '/^[[:space:]]*$/d' | sort)"

{
  echo "Licences:"
  printf '%s\n' "${PKG_LIST}" | sed 's/.*; //' | sort -u
  echo ""
  echo "Packages:"
  printf '%s\n' "${PKG_LIST}"
} > "${SUMMARY}"

echo ">> done"
