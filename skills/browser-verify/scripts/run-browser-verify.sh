#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run-browser-verify.sh --url <url> [options]

Options:
  --url <url>                Page URL to verify (required)
  --text <text>              Assert visible text appears on the page (repeatable)
  --selector <selector>      Assert a selector is visible (repeatable)
  --click-text <text>        Click the first visible element matching the text (repeatable)
  --click-selector <sel>     Click the first visible element matching the selector (repeatable)
  --wait-for <selector>      Wait for selector before continuing (repeatable)
  --screenshot <file>        Save a screenshot to this path
  --timeout-ms <ms>          Action/assert timeout in milliseconds (default: 10000)
EOF
}

URL=""
SCREENSHOT=""
TIMEOUT_MS="10000"
TEXTS=()
SELECTORS=()
CLICK_TEXTS=()
CLICK_SELECTORS=()
WAIT_FORS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      URL="$2"
      shift 2
      ;;
    --text)
      TEXTS+=("$2")
      shift 2
      ;;
    --selector)
      SELECTORS+=("$2")
      shift 2
      ;;
    --click-text)
      CLICK_TEXTS+=("$2")
      shift 2
      ;;
    --click-selector)
      CLICK_SELECTORS+=("$2")
      shift 2
      ;;
    --wait-for)
      WAIT_FORS+=("$2")
      shift 2
      ;;
    --screenshot)
      SCREENSHOT="$2"
      shift 2
      ;;
    --timeout-ms)
      TIMEOUT_MS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$URL" ]]; then
  echo "Error: --url is required." >&2
  usage >&2
  exit 1
fi

CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/codex-browser-verify"
RUNNER_DIR="$CACHE_ROOT/runner"
mkdir -p "$RUNNER_DIR"

if [[ ! -f "$RUNNER_DIR/package.json" ]]; then
  (
    cd "$RUNNER_DIR"
    npm init -y >/dev/null 2>&1
    npm install --silent @playwright/test >/dev/null 2>&1
  )
fi

(
  cd "$RUNNER_DIR"
  npx playwright install chromium >/dev/null 2>&1
)

SPEC_FILE="$RUNNER_DIR/browser-verify.spec.js"
CONFIG_FILE="$RUNNER_DIR/playwright.config.js"

json_array() {
  if [[ $# -eq 0 ]]; then
    printf '[]'
    return
  fi

  printf '%s\n' "$@" | node -e 'const fs=require("fs");const items=fs.readFileSync(0,"utf8").split("\n").filter(Boolean);process.stdout.write(JSON.stringify(items));'
}

TEXTS_JSON="[]"
SELECTORS_JSON="[]"
CLICK_TEXTS_JSON="[]"
CLICK_SELECTORS_JSON="[]"
WAIT_FORS_JSON="[]"

if (( ${#TEXTS[@]} )); then
  TEXTS_JSON="$(json_array "${TEXTS[@]}")"
fi

if (( ${#SELECTORS[@]} )); then
  SELECTORS_JSON="$(json_array "${SELECTORS[@]}")"
fi

if (( ${#CLICK_TEXTS[@]} )); then
  CLICK_TEXTS_JSON="$(json_array "${CLICK_TEXTS[@]}")"
fi

if (( ${#CLICK_SELECTORS[@]} )); then
  CLICK_SELECTORS_JSON="$(json_array "${CLICK_SELECTORS[@]}")"
fi

if (( ${#WAIT_FORS[@]} )); then
  WAIT_FORS_JSON="$(json_array "${WAIT_FORS[@]}")"
fi
SCREENSHOT_JSON="$(printf '%s' "$SCREENSHOT" | node -e 'const fs=require("fs");process.stdout.write(JSON.stringify(fs.readFileSync(0,"utf8")));')"
URL_JSON="$(printf '%s' "$URL" | node -e 'const fs=require("fs");process.stdout.write(JSON.stringify(fs.readFileSync(0,"utf8")));')"

cat > "$CONFIG_FILE" <<EOF
module.exports = {
  testDir: '.',
  timeout: ${TIMEOUT_MS},
  use: {
    headless: true,
    actionTimeout: ${TIMEOUT_MS},
    navigationTimeout: ${TIMEOUT_MS}
  }
};
EOF

cat > "$SPEC_FILE" <<EOF
const { test, expect } = require('@playwright/test');

const url = ${URL_JSON};
const screenshotPath = ${SCREENSHOT_JSON};
const texts = ${TEXTS_JSON};
const selectors = ${SELECTORS_JSON};
const clickTexts = ${CLICK_TEXTS_JSON};
const clickSelectors = ${CLICK_SELECTORS_JSON};
const waitFors = ${WAIT_FORS_JSON};

test('browser verify', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(String(error)));
  page.on('console', message => {
    if (message.type() === 'error') pageErrors.push(message.text());
  });

  await page.goto(url, { waitUntil: 'networkidle' });

  for (const selector of waitFors) {
    await page.locator(selector).first().waitFor({ state: 'visible' });
  }

  for (const text of clickTexts) {
    await page.getByText(text, { exact: false }).first().click();
  }

  for (const selector of clickSelectors) {
    await page.locator(selector).first().click();
  }

  for (const text of texts) {
    await expect(page.getByText(text, { exact: false }).first()).toBeVisible();
  }

  for (const selector of selectors) {
    await expect(page.locator(selector).first()).toBeVisible();
  }

  if (screenshotPath) {
    await page.screenshot({ path: screenshotPath, fullPage: true });
  }

  expect(pageErrors, 'page console/page errors').toEqual([]);
});
EOF

mkdir -p "$(dirname "$SCREENSHOT")" 2>/dev/null || true

(
  cd "$RUNNER_DIR"
  npx playwright test "$SPEC_FILE" --config "$CONFIG_FILE" --reporter=line
)
