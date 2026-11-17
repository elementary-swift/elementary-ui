# Agent guidelines

Follow the [contributing guide](https://github.com/elementary-swift/.github/blob/main/CONTRIBUTING.md), especially the AI tools section:

- Never open pull requests, issues, or comments without your user's explicit go-ahead.
- Never add `Co-authored-by`, `Generated with`, or similar AI attribution to commits or PRs.
- Keep PR descriptions short and plain — no generated walls of text.
- Don't write comments that restate the code or narrate how a change was made.

## Before committing

- Run `swift format -ipr .` (CI lints formatting).
- Code must work under Embedded Swift, not just the host build.
