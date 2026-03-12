---
name: browser-verify
description: "Verify UI changes in a real browser using Playwright. Use when the user wants to check a local app in the browser, validate a frontend story, capture a screenshot, confirm text is visible, click through a UI flow, or run a lightweight browser smoke test. Triggers on: verify in browser, browser check, Playwright smoke test, UI verification, screenshot the app."
user-invocable: true
---

# Browser Verify

Use a real browser to verify UI changes with Playwright.

## The Job

1. Start or identify the app URL to verify.
2. Run the helper script:

```bash
scripts/run-browser-verify.sh --url <url> [options]
```

3. Use options to match the story:
   - `--text <expected-text>` to assert visible text
   - `--selector <css-selector>` to assert a visible element
   - `--click-text <button-or-link-text>` to click by visible text
   - `--click-selector <css-selector>` to click a specific element
   - `--wait-for <css-selector>` to wait for async UI
   - `--screenshot <file>` to save a screenshot

4. Report:
   - verified URL
   - assertions performed
   - whether the browser check passed
   - screenshot path if one was captured

## Notes

- This skill uses a cached temporary Playwright workspace under the user's cache directory so target repositories do not need Playwright installed.
- If the app is not already running, start the project dev server first.
- If the browser check fails, include the failing assertion or page error in the report.
