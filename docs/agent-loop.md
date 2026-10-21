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
It prints the actual interpreter path/version. Discovery checks python.org's
per-user installation directly, then PATH and the launcher, and verifies the
resolved `python.exe` without its launcher. If Python works in normal PowerShell
but fails in Codex, do not reinstall it: use the actual error to diagnose that
session. `--python "C:\absolute\path\python.exe"` or the current terminal's
`HEARTHTABLE_PYTHON` environment variable selects an explicit interpreter;
an invalid explicit selection fails without silently switching versions.
If Python is actually absent, install it from
[python.org](https://www.python.org/downloads/windows/), reopen PowerShell and
retry Doctor. No pip packages are required. Then run the baseline:

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

Before spending model allowance, check Python, Godot and Git metadata writes inside the **actual Codex sandbox**:

```powershell
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\agent-loop.mjs" probe
```

This uses Codex’s command sandbox, without starting a model or any worker. The
probe verifies the pinned Godot editor and starts only a tiny project without
game autoloads to prove its disposable save path and certificate initialization.
It does not load a campaign or run the application/UI suites. The
per-invocation `hearthtable_loop` permission profile extends Codex’s built-in
`:workspace` profile (the workspace-write baseline). It grants read access to
only the Python installation and pinned Godot toolchain folders; source, reports,
the Git common directory and the current worktree's exact Git admin directory
have write access. It does not grant Python-folder
write access, disable the sandbox or change account-wide Codex configuration.
The same profile is used for the probe and subsequent model cycle.
The parent pins the existing Godot folder as `HEARTHTABLE_TOOLCHAIN` for the
probe and workers, so a sandbox account's different LocalAppData does not make
the installed tools appear missing. `--toolchain` still takes precedence.

If ordinary Python verification succeeds but the sandbox reports the executable
is invisible (`exists: false`, `ENOENT`), its Windows folder ACL may not allow
Codex’s sandbox account to read that per-user installation. For the owner’s
confirmed python.org 3.13 installation, run this **outside Codex**, in ordinary
PowerShell:

```powershell
icacls "$env:LOCALAPPDATA\Programs\Python\Python313" /grant "CodexSandboxUsers:(OI)(CI)(RX)" /T /Q
```

This adds read/execute permissions for Codex’s own Windows sandbox group to the
Python installation and its children, retaining existing permissions. It grants
no write access and does not change Windows security policy or remove the
sandbox. Use only the verified installation folder, never the whole profile or
AppData. If the group is missing or access is denied, stop and retain the error.
A different Python installation needs its own verified folder path. Then retry
the no-model probe. See the pinned Codex 0.163
[sandbox group definition](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/windows-sandbox-rs/src/winutil.rs)
and [read/execute ACL setup](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/windows-sandbox-rs/src/setup_provisioning.rs).

A successful probe prints `PROBE_PASSED`. It does not enable a schedule, create
a successful-cycle checkpoint or clear an existing pause. Results and errors
are retained as private `prerequisite.json` / `prerequisite.log` in the run
folder, including whether the Python path is visible inside the sandbox. A
failed probe stops before model usage; preserve its diagnostics.

The Git check exclusively creates and removes randomly named temporary files
in the current Git admin directory, common directory and object-store directory.
It does not touch the index, refs, commits or application source. A linked
worktree has its own admin directory under the main checkout's `.git/worktrees`.
Codex 0.163 protects that exact directory separately; granting only the broader
common directory leaves `index.lock` creation denied. The launcher explicitly
grants the current admin directory while keeping the worktree's `.git` pointer
protected. A permission-denied `index.lock` message is not evidence of a stale
lock: do not delete a lock or disable sandboxing as a repair.
See Codex's pinned
[worktree carveout handling](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/protocol/src/permissions.rs#L1684).

Godot 4.5.1 can print `Failed to read the root certificate store` under the
Windows sandbox account even though it then loads its bundled trusted CA set.
The helpers now request verbose startup evidence and accept only that exact
pinned-engine diagnostic, with its exact source location, when the same process
also confirms `Loaded builtin CA certificates`. The original diagnostic stays
in the private log and the isolation report records the fallback. Missing
fallback proof, a different engine/source location, repeated failures, TLS
certificate parsing failures and every other engine/test error still block the
run. Exit codes, assertion summaries and save-path checks remain mandatory.
This follows Godot's existing fallback; it does not disable certificate checks,
change trusted certificates or grant access to Windows certificate stores.
See the pinned engine's
[Windows ROOT lookup](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/windows/os_windows.cpp#L2546)
and [bundled CA fallback](https://github.com/godotengine/godot/blob/4.5.1-stable/modules/mbedtls/crypto_mbedtls.cpp#L353).

Once tools and baseline checks pass, start **one manual cycle**:

```powershell
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\agent-loop.mjs" run
```

This consumes Codex allowance. The prompt requires all three worker agents and
real validation before accepting code. Before any model call, the launcher
verifies the actual Python interpreter and supplies its absolute path to Codex
and its shell environment as `HEARTHTABLE_PYTHON`, then runs the actual sandbox
Python/Godot probe before launching the coordinator. It records the interpreter in the private
run's `runtime.json`; the safe test/build helper rechecks that same interpreter.
The agent process starts in the project directory; Windows shell commands must
also avoid profiles that change directory. Runtime lookup failures pause the
loop with their actual diagnostics, without using model allowance.

Read the final summary/report. If the
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
The first successful manual cycle and enabling the local schedule remain pending confirmation.

One separate Linux network run on that source logged `Unable to send packet on
channel 0, max channels: 0` when both guests left together. Although all 37
assertions passed, the runner correctly rejected the engine error. The native
Windows run did not reproduce it. Keep this intermittent shutdown defect as a
concrete first-cycle investigation candidate; do not weaken error detection or
claim networking is universally clean. No gameplay source was changed by this
tooling setup.

The Python handoff fix at `9ac9b36eda3a5350538d2646509927b146c8c13b` passed
all **24 native Windows launcher/runtime checks** in
[run 39565904566](https://github.com/WonderingMage/Hearthtable/actions/runs/39565904566),
including empty-PATH Python discovery, explicit-path failure diagnostics,
interpreter handoff and failure before agent invocation.
[Run 39565904592](https://github.com/WonderingMage/Hearthtable/actions/runs/39565904592)
passed 154 source, 37 network and 154 compiled Windows assertions plus update
packaging and unchanged ordinary-user-data/source checks with the new resolver.
These use fake agents or direct tools, not real model cycles. The owner confirmed
Python 3.13.7 is already installed; a fresh manual cycle must confirm its use
inside the actual Codex sandbox. No reinstall or schedule activation occurred.

The actual pinned Codex 0.163 Windows sandbox check passed on
`b9e7e71efc6dfec72fa38013a9f9bf5bb1b6b3f4` in
[run 39570420518](https://github.com/WonderingMage/Hearthtable/actions/runs/39570420518),
alongside all 27 launcher/runtime checks. It started Python from a disposable
per-user AppData installation after the scoped RX grant above. Earlier real
sandbox checks reproduced the invisible executable and then an AppData-parent
`lstat EPERM`; native file resolution fixed that second failure without granting
parent-directory access. Ordinary Windows helper checks also passed on
`0d742102cf43e7e87e417146b0e6e597a9ca8a9e` in
[run 39569786442](https://github.com/WonderingMage/Hearthtable/actions/runs/39569786442):
154 source, 37 network and 154 compiled assertions, matching update packaging
and unchanged normal data/source. None of these start real agents or schedules.
The owner must still apply the scoped permission and pass the probe on their PC.

The owner subsequently passed the real Python probe after that scoped repair,
then a worker's Godot isolation probe failed on the Windows ROOT-store message
despite proving the correct disposable save path. The verified bundled-CA
handling and expanded free prerequisite probe passed on helper source
`d9eb2ad7c15b6699228a5482d4c1d93e6e2795a1` in
[real Windows sandbox run 39574388306](https://github.com/WonderingMage/Hearthtable/actions/runs/39574388306):
29 launcher/runtime checks, actual Python/Godot prerequisites, 233 source/UI
assertions, 37 multiplayer assertions and 154 compiled-EXE assertions, matching
update preparation and unchanged ordinary-save sentinel/source. This reproduced
the certificate-store diagnostic and verified Godot's existing bundled fallback
inside the restricted account, including compiled execution. Only on this fresh
hosted VM, the test grants Codex's group read/execute on its installed Godot
folder and disposable Python copy. It does not change the owner's ACLs or trust
stores. Missing/inaccessible-tool errors now include the exact manifest path;
do not reinstall a working Godot installation based on a sandbox lookup failure.
[Normal Windows run 39574388325](https://github.com/WonderingMage/Hearthtable/actions/runs/39574388325)
passed source, networking, compiled execution and update packaging separately.
The owner must still update the worktree and pass the expanded free probe locally.
No model cycle, active schedule, installation or release was started by these checks.
