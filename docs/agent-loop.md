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

Then start **one manual cycle**:

```powershell
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\agent-loop.mjs" run
```

This consumes Codex allowance. The prompt requires all three worker agents and
real validation before accepting code. Read the final summary/report. If the
local Godot 4.5.1 editor, isolated test harness or compatible-update build tools
are missing, the cycle must report BLOCKED before editing. We must finish that
local testing setup before unattended improvement can work. A worktree alone
does not isolate Godot campaign saves; never run the destructive suites against
ordinary Windows user data. The existing installer tests require a fresh hosted
VM and cannot simply be used on a player's normal desktop.

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
