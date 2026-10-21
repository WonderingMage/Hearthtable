# A local three-agent development loop

This is an **opt-in Windows development tool**, not part of the installed VTT.
Nothing schedules itself when you fetch the source, run `doctor` or run one
manual cycle. The launcher uses Node.js (already installed with npm), avoiding
PowerShell `.ps1` execution-policy problems. It never changes that policy.

The coordinator explicitly delegates to Builder, Tester and Critic. Builder
alone edits app source. Tester validates independently; Critic reviews the
actual result. Each cycle selects at most one supported improvement, allows two
revision rounds, then stops. No-change is valid. Commits stay on
`automation/lite-improvements`; pushing/merging/releases remain manual. These
role/action limits are agent instructions; the launcher's branch/status/report
checks add safeguards, not a guarantee against every possible agent mistake.

The owner prioritizes improvements to the actual VTT: missing, incomplete or
inaccessible spell descriptions and useful fixes to existing functions. Workers
trace spell data through the player sheet, casting proposal and DM inbox,
preserve the 2014 reference and imported/homebrew text, and verify the affected
interaction. Optional spell fields are not automatically omissions. The DM
continues to decide outcomes. Each cycle still tackles one supported change.

## Continue setup in PowerShell

After creating the source copy and `Hearthtable-Autopilot` worktree, fetch these
launcher files into that worktree (stop and report an error instead of forcing):

```powershell
git -C "$env:USERPROFILE\Dev\Hearthtable-Autopilot" fetch origin
git -C "$env:USERPROFILE\Dev\Hearthtable-Autopilot" merge --ff-only origin/edition/lite
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\agent-loop.mjs" doctor
```

`doctor` only checks the branch, clean source, expected repository, Git commit identity and Codex
installation/login. It makes no model calls and does not start a task. It does
**not** prove Godot or testing/build tools are ready.

Set up local validation **before** spending Codex allowance on a cycle:

```powershell
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\lite-local.mjs" setup
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\lite-local.mjs" doctor
```

Setup downloads the official pinned Godot **4.5.1** Windows editor and export
templates (about **1.4 GB** total), verifies their official SHA-512 checksums and
records extracted file hashes. They live outside the repository under
`%LOCALAPPDATA%\HearthtableCodexTools`. It does not install the VTT, run tests,
start agents, change Windows security policy or enable a schedule. An existing
verified toolchain is reused. If a failed setup leaves a `.setup-lock`, first
verify no setup process is still running; report the path rather than deleting
files blindly.

Doctor also checks **Python 3.11+**, needed for real networking and packaging.
If missing, install Python from [python.org](https://www.python.org/downloads/windows/)
with the Python launcher, reopen PowerShell and retry Doctor. No pip packages
are required. Then run the baseline:

```powershell
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\lite-local.mjs" test
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\lite-local.mjs" network
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\lite-local.mjs" test --ui
```

The headless baseline expects 154 core assertions; networking uses one real DM
and two player processes (37 assertions). `--ui` includes the core and rendered
suites and opens temporary QA windows. Run checks serially. First-run Windows
firewall permission, physical GPU/audio and residential internet play still
need the owner's observations; headless CI cannot prove them.

The helper copies tracked **working** source into a fresh folder outside the
checkout. Stage new code files first; untracked files are intentionally omitted.
It refuses overrides/custom application identity and verifies the engine's
resolved user-data path using a tiny project with no autoloads. Native Windows
gets **child-only** APPDATA/LOCALAPPDATA/TEMP overrides; Linux gets disposable
XDG locations. Your account settings and real campaign folders are unchanged.
Ordinary results live under `%LOCALAPPDATA%\HearthtableCodexQA`; agents instead
pass a new `--output` folder under their writable cycle report directory.
Existing result folders are never overwritten. Keep these QA folders private.

Once tools and baseline checks pass, start **one manual cycle**:

```powershell
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\agent-loop.mjs" run
```

This consumes Codex allowance. The prompt requires all three worker agents and
real validation before accepting code. Read the final summary/report. If the
local Godot editor, safe validation, GUI access for a visual change or packaging
tools are missing, the cycle must report BLOCKED before editing. A clean approved
candidate is packaged with `lite-local.mjs build`: EXE plus compatible Settings
update, source commit/hashes and native compiled core checks. It does not create
an installer, tag, release or install that update into your game. Publication
remains a separate requested release using the established installer pipeline.

Correct any blocker and rerun the manual command. Existing edits are preserved;
review them rather than using reset/clean. A manual retry clears a prior pause
only after the workspace/login preflight passes. If authentication or sandbox
initialization needs interaction, complete that normally; this tool does not
bypass sandboxing or silently approve actions.

## Only after reviewing a successful manual cycle

Enable the schedule explicitly:

```powershell
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\agent-loop.mjs" enable
```

The launcher requires a successful manual-cycle checkpoint matching the current
clean commit. It registers a task for the current logged-in user, without stored
passwords or elevated privileges. It starts at the next 30-minute interval and
repeats every 30 minutes while you are signed in and the PC is awake. Missed
runs are not queued. Overlaps are skipped. Each cycle has a 40-minute process
timeout, so a longer run can skip the next scheduled start. Do not run tests or
edit this same worktree in a separate session during a cycle.

At 48 starts/day, three workers plus a coordinator can consume substantial Codex
allowance. The tool uses your existing Codex model/account configuration, with
no separate API key, paid service or forced model selection. Monitor usage.

Pause future agent calls at any time:

```powershell
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\agent-loop.mjs" pause
```

Pause lets an existing cycle finish. To resume, run a manual cycle successfully
and explicitly `enable` again. `status` prints the local reports/pause/lock
location. `unlock` removes a stale lock only if its recorded process no longer
exists. Never delete a live lock or run two coordinators on this workspace.
To remove the schedule entirely, open Windows Task Scheduler and delete the
`Hearthtable Lite agents ...` task printed by `enable` or `status`.

Reports live outside source under `%LOCALAPPDATA%\HearthtableCodexLoop`, in a
folder specific to this worktree. Each run has its own console log and JSON
report, with a latest report and checkpoint. Failures, invalid reports or
unfinished work pause subsequent scheduled model calls. A paused task still
performs lightweight preflight checks; it does not launch model work. Abrupt
shutdown can leave a lock, which intentionally blocks further cycles pending
review. No campaign/PDF/build data or reports are uploaded automatically.

## Launcher verification

`node --test tools/agent-loop.test.mjs` uses temporary Git repositories and a
**fake Codex executable**. It makes no model/API calls, does not touch normal
campaign data, and never activates a repeating agent loop. The native Windows
case briefly registers a uniquely named **disabled** task, verifies its
30-minute cadence/limited-user settings, then removes that test task. The
separate `Agent loop launcher checks` workflow runs these tests on Windows.
Game/UI/build validation is separate from testing this launcher.

The launcher at commit `9393717dd75f100c2f77bbc13f205de502a53729` passed
all **13 native Windows checks** in [run 39556168335](https://github.com/WonderingMage/Hearthtable/actions/runs/39556168335).
This includes disabled-task registration and the actual scheduled command with
a fake npm Codex launcher, quoted paths, branch/identity/dirty-work guards,
report validation, pause/lock handling and process timeout. No real model loop
or task on the owner's PC has been activated or validated by these tests.

The local Godot helper at `d50ece5dd8c3f1df237ba7d2e4cde0375c8cc97b`
passed [native Windows run 39561758442](https://github.com/WonderingMage/Hearthtable/actions/runs/39561758442):
7 harness checks, official download/checksum/extraction setup, 154 source
assertions, 37 real DM/two-player network assertions and 154 assertions against
the compiled Windows EXE. It prepared a matching candidate `.hearthupdate`
and verified the normal AppData campaign sentinel and source checkout stayed
unchanged. No installer, release, model cycle or active schedule was created.
The launcher also passed all 13 Windows checks on that source in
[run 39561758352](https://github.com/WonderingMage/Hearthtable/actions/runs/39561758352).
The owner subsequently reported successful local Windows checks: 233 core/UI
assertions, 37 real network assertions and a separate 154-core-assertion run.
The first real cycle and enabling the local schedule remain pending confirmation.

One separate Linux network run on that source logged `Unable to send packet on
channel 0, max channels: 0` when both guests left together. Although all 37
assertions passed, the runner correctly rejected the engine error. The native
Windows run did not reproduce it. Keep this intermittent shutdown defect as a
concrete first-cycle investigation candidate; do not weaken error detection or
claim networking is universally clean. No gameplay source was changed by this
tooling setup.
