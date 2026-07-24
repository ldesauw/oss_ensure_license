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

# Pinned go-licenses version (module path is /v2 since v2.0.0).
GO_LICENSES_VERSION="v2.0.1"

# Packages to scan (default: every package of the current module).
PKGS="${1:-./...}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
OUT_DIR="${ROOT_DIR}/LICENSES"
GO_DIR="${OUT_DIR}/go"
SUMMARY="${OUT_DIR}/LICENSES.txt"

# Ensure the pinned go-licenses is installed and on PATH.
if ! command -v go-licenses >/dev/null 2>&1; then
  echo ">> installing github.com/google/go-licenses/v2@${GO_LICENSES_VERSION}"
  go install "github.com/google/go-licenses/v2@${GO_LICENSES_VERSION}"
  export PATH="$(go env GOPATH)/bin:${PATH}"
fi

# 1. Save every dependency's LICENSE file, laid out by import path.
#    This includes the main module's own LICENSE at go/<module>/LICENSE.
echo ">> saving dependency LICENSE files to ${GO_DIR}"
rm -rf "${GO_DIR}"
mkdir -p "${GO_DIR}"
go-licenses save "${PKGS}" --save_path="${GO_DIR}" --force

# 2. Collect "<package>; <Licence>" lines for every dependency.
echo ">> writing summary to ${SUMMARY}"
TPL="$(mktemp)"
trap 'rm -f "${TPL}"' EXIT
cat > "${TPL}" <<'EOF'
{{range .}}{{.Name}}; {{if .LicenseName}}{{.LicenseName}}{{else}}Unknown{{end}}
{{end}}
EOF

PKG_LIST="$(go-licenses report "${PKGS}" --template "${TPL}" 2>/dev/null | sed '/^[[:space:]]*$/d' | sort)"

# 3. For the main module, use the licence declared in the repository itself
#    (its root LICENSE file) instead of leaving it as "Unknown".
MODULE="$(go list -m 2>/dev/null | head -n1 || true)"
if [ -n "${MODULE}" ]; then
  main_lic="$(printf '%s\n' "${PKG_LIST}" | awk -F'; ' -v m="${MODULE}" '$1==m {print $2; exit}')"
  if [ -z "${main_lic}" ] || [ "${main_lic}" = "Unknown" ]; then
    # Prefer an SPDX identifier declared in the root LICENSE, if present.
    spdx=""
    if [ -f "${ROOT_DIR}/LICENSE" ]; then
      spdx="$(grep -m1 -oiE 'SPDX-License-Identifier:[[:space:]]*[^[:space:]]+' "${ROOT_DIR}/LICENSE" \
        | sed -E 's/.*:[[:space:]]*//' || true)"
    fi
    if [ -n "${spdx}" ]; then
      main_lic="${spdx}"
    elif [ -f "${ROOT_DIR}/LICENSE" ]; then
      # Licence text present but not machine-identifiable: point at the file.
      main_lic="Unknown. See go/${MODULE}/LICENSE file"
    else
      main_lic="Unknown"
    fi
    # Substitute the resolved licence into the main module's line.
    PKG_LIST="$(printf '%s\n' "${PKG_LIST}" \
      | awk -F'; ' -v m="${MODULE}" -v l="${main_lic}" 'BEGIN{OFS="; "} $1==m{$2=l} {print}')"
  fi
fi

# 4. Emit the two-section summary. In the unique "Licences:" list, collapse any
#    "Unknown. See ... file" pointer back to the short token "Unknown".
{
  echo "Licences:"
  printf '%s\n' "${PKG_LIST}" | sed -E 's/.*; //; s/^Unknown\..*/Unknown/' | sort -u
  echo ""
  echo "Packages:"
  printf '%s\n' "${PKG_LIST}"
} > "${SUMMARY}"

echo ">> done"
