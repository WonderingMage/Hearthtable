# A local three-agent development loop

This is an **opt-in Windows development tool**, not part of the installed VTT.
Nothing schedules itself when you fetch the source, run `doctor` or run one
manual cycle. The launcher uses Node.js (already installed with npm), avoiding
PowerShell `.ps1` execution-policy problems. It never changes that policy.

The coordinator explicitly delegates to Builder, Tester and Critic. Builder
alone edits app source. Tester validates independently; Critic reviews the
actual result. Each cycle selects at most one supported improvement, allows two
revision rounds, then stops. No-change is valid. Application commits stay on
`automation/lite-improvements`. The owner authorizes a verified installer release
after every five accepted improvements; the launcher handles that checkpoint
outside the worker sandbox. Workers never push, tag or publish. These
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
For an existing loop, first pause future starts and wait for `status` to show
`Lock present: false`. Preserve/review uncommitted changes before merging.
The owner's accepted app commits may diverge from the tooling branch; a normal
merge preserves both histories.

```powershell
$repo="$env:USERPROFILE\Dev\Hearthtable-Autopilot";
git -C $repo fetch origin;
if ($LASTEXITCODE -eq 0) { git -C $repo merge --no-edit origin/edition/lite };
if ($LASTEXITCODE -eq 0) { node "$repo\tools\agent-loop.mjs" doctor };
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
the current worktree's exact Git admin directory and shared Git objects/refs/logs
have write access. The linked worktree's shared config/hooks and other worktrees'
admin directories stay read-only. It does not grant Python-folder
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
in the current Git admin directory and shared objects/refs/logs directories.
It does not touch the index, refs, commits or application source. A linked
worktree has its own admin directory under the main checkout's `.git/worktrees`.
Codex 0.163 protects that exact directory separately; granting only the broader
common directory leaves `index.lock` creation denied. The launcher explicitly
grants the current admin directory and uses separate objects/refs/logs grants,
without reusing the old broader common-directory capability. It keeps the
worktree's `.git` pointer protected. A permission-denied `index.lock` message is not evidence of a stale
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
real validation before accepting code. The coordinator and Builder, Tester and
Critic are pinned to **GPT-6 Luna** (`gpt-6-luna`) for this invocation via `model`
and `agents.default_subagent_model` (Codex 0.163 configuration). Your global
Codex settings are unchanged. `doctor` and cycle startup print the requested
model; private `runtime.json` records both settings. Free prerequisite probes
test tools/sandbox access, not account entitlement to this model. If the account
cannot use Luna, the cycle fails and pauses instead of switching models.

The product brief in [campaign-experience.md](campaign-experience.md) directs
feature development as well as bug fixes. First priority is a DM-approved
Druid/Dire Wolf transformation with a usable effective sheet and safe reversion.
Subsequent cycles examine different classes and campaign situations, using
2014 references and D&D Beyond-style sheet organization. Accepted work needs
real evidence and independent reviews; the brief is not a claim that those
features already exist. A larger feature can take several tested slices.

Before any model call, the launcher
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
an installer, tag, release or install that update into your game during the
worker cycle. The parent launcher handles the authorized five-improvement
release checkpoint using the established installer pipeline.

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
clean commit. After merging tooling updates, run one manual cycle again before
enabling: the previous checkpoint belongs to the previous commit. It registers
a task for the current logged-in user, without stored
passwords or elevated privileges. Its first start is 10 minutes after enabling,
then it repeats every 10 minutes while you are signed in and the PC is awake. Missed
runs are not queued. Overlaps are skipped. Each cycle has a 40-minute process
timeout, so a longer run can skip the next scheduled start. Do not run tests or
edit this same worktree in a separate session during a cycle.

At up to 144 starts/day, three workers plus a coordinator can consume substantial Codex
allowance. The tool uses your existing Codex account, with
no separate API key or service, and pins GPT-6 Luna as requested. Monitor usage.

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
review. Publication uploads only tested player assets and tracked source;
private campaigns, PDFs and QA reports stay local.

## Release after five accepted improvements

The owner explicitly authorizes publication after every **five accepted**
improvements. Failed/blocked/no-change cycles do not count. Counting starts with
accepted cycles run by this updated launcher; historical reports are not
retroactively counted. Earlier unreleased app changes still enter the first
release because its source includes them. `status` prints the current count.
The private `release-progress.json` survives restarts and deduplicates commits.

After the fifth accepted cycle, the **next run** is a release checkpoint rather
than another model cycle. It:

1. Verifies GitHub CLI authentication/write access and a clean, unchanged
   development source. Creates an external detached worktree for the release
   metadata, leaving existing development commits and private data intact.
2. Selects the next unused Lite patch version (initially 1.0.2 if still unused),
   updates runtime/guide version metadata, records the five commit IDs in
   `docs/release-batches.json` and prepares release-specific highlights. Existing
   tags and published assets are never replaced.
3. Runs the safe full rendered suites, rendered DM/two-player network suite and
   native candidate build against that exact clean commit. Any crash/error stops
   before a release tag is pushed. Logs and failed candidates remain available.
4. Pushes **only the new Lite tag**, transferring its source history, and lets
   `release.yml` rebuild/test the application, portable/update lifecycle and
   native Windows installer before publishing the installer ZIP, matching
   `.hearthupdate`, checksums and build manifest. Development branches are not
   automatically merged into `main` or `edition/lite`.
5. On subsequent scheduled runs, checks the matching workflow/release without
   starting more improvement agents. Downloads the four published assets and
   verifies their GitHub digests, payload checksums, exact source/version and
   required native installer/test evidence before consuming the five entries.
   If a finished workflow retained a fully verified draft because its token
   could not publish, the owner-authenticated CLI can finish that publication.
6. Advances the clean local development branch to the verified release metadata
   commit with `--ff-only`, records the public URL, then resumes improvements on
   later runs. Independent local edits halt this transition for review.

This makes the release source publicly available through its tag. It never
installs the new app/update on the owner's PC. Releases retain prerelease status
and the existing signing limitations. Publication errors pause the loop; the
counter resets only after verified publication, never on a tag push or queued
workflow. Overlap protection applies to release checks too.

The **Codex app Review button is not required**. GitHub CLI and Actions handle
this path. The website can also inspect runs and retained drafts:

- [Release pipeline](https://github.com/WonderingMage/Hearthtable/actions/workflows/release.yml)
- [Releases and drafts](https://github.com/WonderingMage/Hearthtable/releases)

Before the first release checkpoint, install GitHub CLI on the owner's PC if
`gh --version` is unavailable:

```powershell
winget install --id GitHub.cli --exact
```

Open a new PowerShell window and sign in through the browser as an account with
write access to this repository. This is a manual account login, not a request
for credentials in chat; it is separate from `codex login`:

```powershell
gh auth login --hostname github.com --git-protocol https --web --scopes "repo,workflow"
```

The launcher uses these existing credentials per command without changing
global Git configuration or passing credentials to workers. The free `doctor`
reports whether the CLI is installed without contacting GitHub. Authentication
and write access are checked at the checkpoint. Missing release login does not
block the first four improvement cycles. It does block publication.

Retry/check a due batch without starting any agents:

```powershell
node "$env:USERPROFILE\Dev\Hearthtable-Autopilot\tools\agent-loop.mjs" release
```

A queued workflow is checked again by the schedule. After a paused failure,
correct its actual cause and run `release` manually; diagnostic state, source
commits and existing tags must be preserved. A failed Actions run can be rerun
on the website for the same immutable source. If repairing the app requires a
different source commit, retain the batch/report for review rather than moving
its tag or editing the counter. Do not merge tooling updates or run a second
editor/test session while an existing cycle/checkpoint holds `running.json`.

## Launcher verification

`node --test tools/agent-loop.test.mjs tools/agent-loop/releases.test.mjs` uses temporary Git repositories and a
**fake Codex executable**. It makes no model/API calls, does not touch normal
campaign data, and never activates a repeating agent loop. The native Windows
case briefly registers a uniquely named **disabled** task, verifies its
10-minute cadence/limited-user settings, then removes that test task. The
separate `Agent loop launcher checks` workflow runs these tests on Windows.
Game/UI/build validation is separate from testing this launcher.
Release tests replace **every** GitHub/API/tag-push operation with a test double.
They check counting, resumable queues, failures, immutable tags, draft completion,
download digests, native installer evidence and exact source transitions without
publishing. A separate opt-in hosted Windows test runs real local rendered,
network and versioned EXE/update validation, with those remote operations still
replaced. It does not create a real tag/release on GitHub or start model agents.

Implementation source `c21fdde4b54efac3522e381584431ebdbe81bd53` passed the
[Windows controller checks](https://github.com/WonderingMage/Hearthtable/actions/runs/39699389271):
46 ordinary checks plus real sandbox validation and a version-bumped release
checkpoint with 233 rendered/source, 43 rendered multiplayer and 154 compiled
assertions. Remote publishing operations remained test doubles. The separate
[installer build](https://github.com/WonderingMage/Hearthtable/actions/runs/39699451875)
also passed with publication skipped. These validate the implementation, not
the owner's GitHub CLI login or their separate native memory-access crash.

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

The owner next preserved a spell-preview fix in local commit `564eba1` (237
native assertions). An actual three-worker cycle then produced a ritual/innate
proposal fix, 250 passing assertions and both independent approvals, but Git
could not create the linked-worktree index lock. The work remained in three
modified files; no matching build/update was produced for that second change.
The Git permission repair passed on tooling source
`eb362737ca4efc94919156f98f00845c05780e5c` in
[run 39642938728](https://github.com/WonderingMage/Hearthtable/actions/runs/39642938728):
32 launcher/runtime checks, a real Windows Codex 0.163 failure-then-commit test
in a linked Dev worktree outside TEMP, and the full sandbox app workflow
(233 baseline source/UI, 37 multiplayer, 154 compiled assertions plus matching
update preparation and unchanged normal-save sentinel/source). The test keeps
the `.git` pointer protected and verifies the main checkout's HEAD is unchanged.
It uses Node evaluation for its builtin-only harness so Node 22 does not need
to list private Dev/AppData ancestors just to load a test entry file.

For this owner checkpoint, first commit only the reviewed sheet, UI tests and
release highlights in normal PowerShell. Then fetch and merge origin/edition/lite
with `git merge --no-edit` to retain the separate local app commits and updated
tooling. A fast-forward is no longer possible across those two lines; do not
reset or discard either. Pass the expanded free probe and matching candidate
build before starting another manual cycle. This does not create a successful
agent-cycle checkpoint or enable scheduling by itself.

The owner subsequently reported an ACCEPTED manual cycle at
`2026-10-21T17-31-29-163Z-9590b488`: Shield's missing 2014 reaction trigger was
restored across the full spell view, casting proposal and DM inbox, committed,
and built into matching local EXE/update artifacts. Nothing was published or
installed. The requested cadence is now 10 minutes; schedule activation on the
owner's PC remains unconfirmed.
