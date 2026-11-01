# Environments and repo workflow

This project is worked on from cloud sessions and from a Windows PC. What each
can do differs, so check here before assuming a step will work.

## What each environment can reach

| | Cloud session | Windows PC |
| --- | --- | --- |
| Flutter | Installed by `.claude/hooks/session-start.sh` | On `PATH`, shared with other projects |
| Run the app | No Chrome or GTK: use the screenshot test | `flutter run -d chrome` |
| warcraftlogs.com API | Blocked | Works |
| lorrgs.io | Blocked | Works |
| Wowhead tooltips and icons | Blocked | Works |
| Wowhead full pages | Blocked | 403 to scripts: open in a browser |
| raw.githubusercontent.com | Works, used for SimC data | Works |
| gnu.org | Blocked | Blocked |
| `.env` credentials | Absent | Present, git-ignored |
| GitHub | MCP tools; pushes work | `gh` CLI, signed in |

If a host looks unreachable in a new session, test it before planning around it.
Both environments can sit behind an agent proxy, and a blocked host fails with a
403 or a connection error.

## GitHub

- **Default branch:** `main` is protected by a ruleset: changes need a pull request
  and a green `test` check. Required approvals are 0.
- **Merging:** the owner usually squash-merges, and head branches are deleted
  automatically.
- **Deployment:** merging to `main` runs tests, then publishes to GitHub Pages.
- **Settings:** repository settings can't be changed from a cloud session, and
  neither can branches be deleted there. Ask the owner to do those, or use `gh`
  on the PC where allowed.

### Stacked pull requests

Squash-merging the lower PR gives `main` a new copy of its commits, so the upper
PR then shows conflicts even though nothing is wrong. To fix it, merge `main` into
the upper branch, resolve in favour of the upper branch's newer changes, then run
all checks. Prefer separate PRs when the work doesn't overlap.

Force-pushing is blocked in cloud sessions. Use a merge commit.

## Windows notes

- **Line endings:** `flutter pub get` rewrites the generated plugin files under
  `linux/`, `macos/` and `windows/`, which then show as modified with no real
  change. Stage files by name, and leave those out.
- **Screenshot test:** use an absolute path for `SCREENSHOT_DIR`.
- **Shared Flutter:** the SDK at `E:\arbejde\flutterdev\flutter` also serves other
  projects, so an upgrade affects them.

## Worktrees

Parallel agents work in `.claude/worktrees/`. Each gets its own branch, and needs
`flutter pub get` before running anything. `.env` isn't copied there.
