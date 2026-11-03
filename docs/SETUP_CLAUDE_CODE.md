# Claude Code setup (Windows)
1. Install Node.js LTS (or the native installer from the official Claude Code docs: https://docs.claude.com/en/docs/claude-code/overview).
2. PowerShell: `npm install -g @anthropic-ai/claude-code` (or the official installer), then `claude --version`.
3. `cd` to the Flutter project root, run `claude`, log in with your Claude account.
4. Copy `CLAUDE.md` to repo root and `docs/` folder (PROJECT_CONTEXT.md + reference/) into the project. If `/init` was already run, merge instead of overwriting.
5. First prompt: "Read CLAUDE.md and docs/PROJECT_CONTEXT.md, look at docs/reference/s00-s08.jpg, then summarise the app and what is pending."
6. Work on a branch: `git switch -c feat/grid-viewer-options`. Review with `git diff`; you commit.
