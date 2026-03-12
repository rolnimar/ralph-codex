#!/bin/bash

set -euo pipefail

EXPECTED_UPSTREAM_URL="${EXPECTED_UPSTREAM_URL:-git@github.com:snarktank/ralph.git}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not inside a git repository." >&2
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
UPSTREAM_URL="$(git remote get-url upstream 2>/dev/null || true)"

if [[ -z "$UPSTREAM_URL" ]]; then
  git remote add upstream "$EXPECTED_UPSTREAM_URL"
  UPSTREAM_URL="$EXPECTED_UPSTREAM_URL"
elif [[ "$UPSTREAM_URL" != "$EXPECTED_UPSTREAM_URL" ]]; then
  git remote set-url upstream "$EXPECTED_UPSTREAM_URL"
  UPSTREAM_URL="$EXPECTED_UPSTREAM_URL"
fi

git fetch upstream --prune >/dev/null

UPSTREAM_HEAD="$(git symbolic-ref refs/remotes/upstream/HEAD 2>/dev/null || true)"
if [[ -n "$UPSTREAM_HEAD" ]]; then
  UPSTREAM_DEFAULT_BRANCH="${UPSTREAM_HEAD#refs/remotes/upstream/}"
else
  UPSTREAM_DEFAULT_BRANCH="$(git remote show upstream | sed -n '/HEAD branch/s/.*: //p' | head -n 1)"
fi

if [[ -z "$UPSTREAM_DEFAULT_BRANCH" ]]; then
  echo "Error: could not determine upstream default branch." >&2
  exit 1
fi

COUNTS="$(git rev-list --left-right --count "HEAD...upstream/$UPSTREAM_DEFAULT_BRANCH")"
read -r AHEAD BEHIND <<< "$COUNTS"

echo "Current branch: $CURRENT_BRANCH"
echo "Origin: ${ORIGIN_URL:-<missing>}"
echo "Upstream: $UPSTREAM_URL"
echo "Upstream default branch: $UPSTREAM_DEFAULT_BRANCH"
echo "Ahead of upstream/$UPSTREAM_DEFAULT_BRANCH: $AHEAD"
echo "Behind upstream/$UPSTREAM_DEFAULT_BRANCH: $BEHIND"
