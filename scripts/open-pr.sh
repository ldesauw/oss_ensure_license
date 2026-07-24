#!/usr/bin/env bash
#
# Copyright (c) OVH SAS. Licensed under the Apache License, Version 2.0.
#
# Open or update a pull request for the regenerated licence folder, entirely
# through the GitHub REST API (like peter-evans/create-pull-request):
#
#   blob(s) -> tree -> commit -> update ref -> create/find pull request
#
# The commit is created by the API, so it is signed by GitHub ("Verified") and
# no git push credentials are needed. Requires: git, curl, jq, base64.
#
# Configuration (all via the environment; the action sets these):
#   GH_TOKEN          token with contents:write + pull-requests:write
#   GH_REPO           "owner/repo"
#   API_URL           GitHub API base, e.g. https://api.github.com
#   OUT               licence folder, relative to the current directory
#   PR_BRANCH         head branch to create/update
#   PR_BASE           base branch (falls back to DEFAULT_BASE)
#   DEFAULT_BASE      fallback base branch (the workflow ref)
#   PR_TITLE PR_BODY PR_LABELS
#   COMMIT_MESSAGE
#   GIT_USER_NAME GIT_USER_EMAIL   commit author/committer identity
#   GITHUB_OUTPUT     (optional) file to write the pull-request-url output to
set -euo pipefail

BASE="${PR_BASE:-$DEFAULT_BASE}"
OWNER="${GH_REPO%%/*}"

for bin in git curl jq base64; do
  command -v "$bin" >/dev/null 2>&1 || { echo "::error::missing required tool: $bin" >&2; exit 1; }
done

# --- Locate the licence folder relative to the repository root. -------------
OUT_ABS="$(cd "${OUT}" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
OUT_REL="${OUT_ABS#"${ROOT}"/}"
cd "${ROOT}"

# --- Minimal GitHub API helper. ---------------------------------------------
HTTP_CODE=""
API_BODY=""
api() { # api <METHOD> <PATH> [<JSON body>]
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -w $'\n%{http_code}' -X "${method}"
    -H "Authorization: Bearer ${GH_TOKEN}"
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28")
  [ -n "${body}" ] && args+=(-d "${body}")
  local resp
  resp="$(curl "${args[@]}" "${API_URL}${path}")"
  HTTP_CODE="${resp##*$'\n'}"
  API_BODY="${resp%$'\n'*}"
}
ok() { # ok <context> -- fail unless HTTP 2xx
  case "${HTTP_CODE}" in
    2*) : ;;
    *) echo "::error::GitHub API ${1} failed (HTTP ${HTTP_CODE}): ${API_BODY}" >&2; exit 1 ;;
  esac
}

# --- Build the tree of changed files under the licence folder. --------------
BASE_COMMIT="$(git rev-parse HEAD)"
BASE_TREE="$(git rev-parse 'HEAD^{tree}')"

entries="$(mktemp)"
trap 'rm -f "${entries}"' EXIT
changed=0
while IFS= read -r path; do
  [ -z "${path}" ] && continue
  changed=1
  if [ -f "${path}" ]; then
    sha="$(api POST "/repos/${GH_REPO}/git/blobs" \
      "$(jq -n --arg c "$(base64 -w0 "${path}")" '{content:$c, encoding:"base64"}')"; ok "create blob"; \
      jq -r '.sha' <<<"${API_BODY}")"
    jq -n --arg p "${path}" --arg s "${sha}" \
      '{path:$p, mode:"100644", type:"blob", sha:$s}' >> "${entries}"
  else
    # Deleted file: a null sha removes it from the tree.
    jq -n --arg p "${path}" \
      '{path:$p, mode:"100644", type:"blob", sha:null}' >> "${entries}"
  fi
# -uall lists new files individually; without it git collapses a new directory
# to a single entry and its files would be missed.
done < <(git status --porcelain -uall -- "${OUT_REL}" | cut -c4-)

if [ "${changed}" -eq 0 ]; then
  echo "No changes under ${OUT_REL}; nothing to do."
  exit 0
fi

# --- tree -> commit -> ref. --------------------------------------------------
api POST "/repos/${GH_REPO}/git/trees" \
  "$(jq -s --arg base "${BASE_TREE}" '{base_tree:$base, tree:.}' "${entries}")"; ok "create tree"
NEW_TREE="$(jq -r '.sha' <<<"${API_BODY}")"

api POST "/repos/${GH_REPO}/git/commits" \
  "$(jq -n --arg m "${COMMIT_MESSAGE}" --arg t "${NEW_TREE}" --arg p "${BASE_COMMIT}" \
       --arg an "${GIT_USER_NAME}" --arg ae "${GIT_USER_EMAIL}" \
       '{message:$m, tree:$t, parents:[$p], author:{name:$an,email:$ae}, committer:{name:$an,email:$ae}}')"; ok "create commit"
NEW_COMMIT="$(jq -r '.sha' <<<"${API_BODY}")"

api GET "/repos/${GH_REPO}/git/ref/heads/${PR_BRANCH}"
if [ "${HTTP_CODE}" = "200" ]; then
  api PATCH "/repos/${GH_REPO}/git/refs/heads/${PR_BRANCH}" \
    "$(jq -n --arg s "${NEW_COMMIT}" '{sha:$s, force:true}')"; ok "update ref"
else
  api POST "/repos/${GH_REPO}/git/refs" \
    "$(jq -n --arg r "refs/heads/${PR_BRANCH}" --arg s "${NEW_COMMIT}" '{ref:$r, sha:$s}')"; ok "create ref"
fi

# --- Create the pull request if one is not already open. --------------------
head_q="$(jq -rn --arg v "${OWNER}:${PR_BRANCH}" '$v|@uri')"
base_q="$(jq -rn --arg v "${BASE}" '$v|@uri')"
api GET "/repos/${GH_REPO}/pulls?state=open&head=${head_q}&base=${base_q}"; ok "list pulls"
NUMBER="$(jq -r '.[0].number // empty' <<<"${API_BODY}")"
if [ -z "${NUMBER}" ]; then
  api POST "/repos/${GH_REPO}/pulls" \
    "$(jq -n --arg t "${PR_TITLE}" --arg h "${PR_BRANCH}" --arg b "${BASE}" --arg d "${PR_BODY}" \
         '{title:$t, head:$h, base:$b, body:$d}')"; ok "create pull"
  NUMBER="$(jq -r '.number' <<<"${API_BODY}")"
  URL="$(jq -r '.html_url' <<<"${API_BODY}")"
  echo "Opened pull request #${NUMBER}: ${URL}"
else
  URL="$(jq -r '.[0].html_url' <<<"${API_BODY}")"
  echo "Updated existing pull request #${NUMBER}: ${URL}"
fi

# --- Labels (best effort). ---------------------------------------------------
if [ -n "${PR_LABELS:-}" ]; then
  labels_json="$(jq -Rc 'split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))' <<<"${PR_LABELS}")"
  api POST "/repos/${GH_REPO}/issues/${NUMBER}/labels" \
    "$(jq -n --argjson l "${labels_json}" '{labels:$l}')" || true
  case "${HTTP_CODE}" in 2*) : ;; *) echo "::warning::could not add labels: ${API_BODY}" ;; esac
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "pull-request-url=${URL}" >> "${GITHUB_OUTPUT}"
fi
