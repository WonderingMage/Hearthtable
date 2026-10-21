Perform ONE bounded improvement cycle on Hearthtable Lite, then stop.

Read AGENTS.md, CODEX_HANDOFF.md, docs/lite.md and tests/README.md. This task
explicitly authorizes exactly three worker agents: Builder, Tester and Critic,
managed by you as coordinator. If worker tools are unavailable, report blocked;
do not silently substitute a single-agent run. Do not create further workers.

Before editing, Critic inspects the current program and recent Git history to
identify concrete defects or usability problems. Tester checks whether the
problem can be reproduced and whether relevant validation is available safely.
Select at most ONE well-supported improvement. Builder alone edits application
source; Tester and Critic are independent and do not change application files.
Coordinate tests so fixed network ports and test data are never shared at once.

Prefer reproducible bugs, PDF import reliability, readable DM/player screens,
keyboard/accessibility and clear interactions. Use actual rendered before/after
screens for visual changes when possible. Do not invent features or churn the
design merely to make a change. A well-supported no_change result is valid.

Preserve DM authority, packet privacy, player movement rules, DM-only doors,
PDF-only review, cosmetic miniatures and save/update compatibility. No new
character creator, automated combat, protocol/schema/engine change, licensing
change, signing change, paid service or external messages. Do not merge, push,
create PRs, tag, release, install updates, change Windows security settings,
modify scheduled tasks, or edit these loop controls/instructions. Operate only
on automation/lite-improvements. Leave other branches and checkouts alone.

Prove disposable user-data isolation BEFORE campaign-resetting tests. Use the
approved tools/lite-local.mjs helper; never run test scripts directly against
the normal game. A worktree alone does NOT isolate saves. Native Windows
requires child-only APPDATA/LOCALAPPDATA overrides, which the helper verifies
with an autoload-free probe before loading World. Installer tests remain
restricted to fresh hosted VMs. Never use private campaigns/PDFs.

Before edits, run `node tools/lite-local.mjs doctor`. Godot 4.5.1, matching export
templates and Python 3.11+ must be ready. Do not install/download tools during a
cycle; missing tools mean blocked with setup instructions. Run tests through
`node tools/lite-local.mjs test --output <run-report-dir>/unique-test-name`.
Use --suite lite/updates/pdf_import or --ui for rendered checks; network changes
also require the `network` action (add --ui for rendered player controls).
All outputs must be new folders under this cycle's writable run-report directory.
The helper snapshots tracked working files without modifying source; Builder
must git add new source files before tests so the snapshot includes them.
Serialize tests/builds across workers. Never claim a screenshot, an unexecuted
command or source inspection proves a runtime test passed. If GUI access or
needed validation is unavailable, report blocked before editing.

After Builder's change, Tester runs relevant checks and Critic reviews the
actual diff/results. Allow at most TWO revision rounds. Aim to finish in
20 minutes; report a blocker if the task is too large. An accepted application
change needs both independent approvals and actual passing test evidence.
Follow AGENTS.md's compatible-update/highlights requirements. After approvals,
commit the candidate, then use `node tools/lite-local.mjs build --output
<run-report-dir>/unique-build-name` to prepare the matching EXE and .hearthupdate
from that clean commit. Windows compiled core checks must pass. These are local
candidate artifacts, not a publication or permission to install an unpublished
update. Record their paths/hashes in the report. Build failure means blocked,
even if a candidate commit exists; preserve it and the diagnostics.

Commit accepted changes only on automation/lite-improvements. Do not discard
uncommitted work, reset, clean or force anything. If edits remain unresolved,
report blocked and preserve them. The launcher pauses future cycles on failure.
Keep logs, reports, builds and synthetic data outside tracked player assets.

Return the required JSON report. revision must equal the final full Git HEAD.
For no_change, make no commit or edits. For accepted, a new commit, passing tests
and both approvals are required. For blocked, explain the missing tool or failed
check and the next step. Each role_reports entry must summarize that worker's
actual findings. Review previous reports/history to avoid repeating the same
work. Never hide a missing test, worker or approval behind a success status.
