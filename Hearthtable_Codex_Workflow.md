# Hearthtable: Codex, Git, testing, and release workflow

Prepared October 19, 2026. This is a setup brief for Codex and a practical guide for the project owner. Recommendations below are tailored to this project; they are not requirements imposed by Codex.

## Start here — for me

1. Extract `Hearthtable_Windows.zip` once. Find `Hearthtable/Source/project.godot`.
2. Put the editable source in one permanent development folder, such as `C:\Dev\Hearthtable`. Keep the original companion download as a backup. Do not develop inside a ZIP, Downloads, or a folder that is replaced whenever a new release arrives.
3. Open that development folder in Codex. Give Codex this Markdown file and the existing `CODEX_HANDOFF.md`. Codex needs access to the source files, not just the portable executable.
4. Paste this message:

> Read Hearthtable_Codex_Workflow.md and the repository's existing AGENTS.md and CODEX_HANDOFF.md. Set up this workflow for my actual Windows/Godot project. Inspect what already exists before changing it. Complete the local setup you can do, and walk me through only the steps that need my input. Use the phases and completion criteria in the guide. Do not change gameplay while setting up the workflow. Start with the project-folder and Git audit.

Keep this guide in `docs/workflow.md` after setup. Keep `AGENTS.md` short and link to the detailed documents from it. [1]

---

## Instructions for Codex

You are helping me maintain **Hearthtable**, a native multiplayer D&D virtual tabletop. I am learning the development workflow. Explain terms when they first matter, give exact Windows commands when needed, and do the routine work that you can perform directly.

The desired result is one reliable source checkout, a useful Git history, a private off-machine copy, repeatable tests, and reproducible portable releases. Complete setup in manageable phases. Do not simply repeat this document or leave me with a list of suggestions.

### Working agreement

- Inspect the current files and tools first. Reuse working configuration and preserve my uncommitted changes.
- Use Windows PowerShell examples by default. Keep Bash/WSL examples separate and clearly labeled. Prefer native Windows for this Windows game; do not introduce WSL, containers, or an engine migration just to organize the workflow.
- Proceed with reversible local configuration inside the selected workspace. Do not ask again for decisions already established here or in the repository.
- Ask only for information that blocks a real step: the correct folder, my Git commit identity, the GitHub account/destination, login, or a genuine conflict. Bundle related missing information. Do not ask me to paste passwords or access tokens into chat.
- Before any first remote publication, establish the destination account and **private** visibility. Do not purchase services, change repository visibility, overwrite a remote, rewrite shared history, or change router/firewall settings as an assumed part of setup.
- Finish local preparation even if an external login step is blocked. Report the exact remaining step and how I can complete it.
- Use current repository evidence as the source of truth. Existing tests and historical reports describe coverage; they do not prove a new checkout passes today.
- Show me an outcome after each phase: what changed, how it was checked, what I need to do next. At the end, separate completed work from work still waiting on me.

## 1. Preserve the project requirements

The last delivered baseline was **Hearthtable 0.11.0**, **Godot 4.5.1**, campaign schema **1**, multiplayer protocol **9**. Verify those values locally; do not overwrite a newer project with this baseline.

Keep these requirements in the repository's durable project guidance:

- Original **2014 D&D 5e**, with the current automation limitations documented. Do not silently switch to 2024 rules or BG3's rules.
- A rotatable isometric DM board and a tactical player view. Preserve Shift-drag rotation, the gilded HUD, and sharp, readable rendering.
- The host validates ownership, actions, attack range, resources, movement and dice. A speed-30 character normally has 30 feet of cumulative movement during a turn; other speeds, terrain and Dash still apply.
- Walls and closed doors control connected-room concealment. Open doorway clicks move through; closing is explicit; occupied doorways cannot close; paired gates change together.
- Joining players automatically receive the active custom scene's image and designs. Future scenes, DM notes and private battle boundaries remain private.
- Scene exports, reusable imported designs and portable campaign copies stay self-contained.
- Players receive a single directly runnable Windows program. Developer tooling can use multiple files; it does not need to be bundled into the player download.

Read `CODEX_HANDOFF.md`, `tests/README.md`, `assets/help/play.txt` and `assets/help/automation.txt`. Keep existing instructions; merge useful additions instead of replacing them wholesale. Do not start a gameplay rewrite during workflow setup.

## 2. Audit before installing or initializing anything

Find the folder containing `project.godot`. Check whether it is already inside a Git repository, including a repository in a parent folder. Do not create a nested repository accidentally.

Start with read-only checks in PowerShell:

```powershell
Get-Location
Get-ChildItem -Force
git --version
git rev-parse --show-toplevel
```

If it is a Git repository, inspect:

```powershell
git status --short --branch
git branch --show-current
git log -5 --oneline
git remote -v
git worktree list
```

A failed `rev-parse` outside a repository is expected. Do not run repository-only commands until the repository exists. Redact credentials if a remote URL contains any.

Also identify the Godot executable, its version, installed export templates, any existing test/build runners, and whether GitHub authentication already works. Present a short findings table. Do not assume a `godot` command is on PATH or that the latest Godot release is appropriate.

Recommended starting tools:

| Tool | Why it belongs here | Priority |
| --- | --- | --- |
| Git for Windows | Local history and Codex Git integration | Required |
| Codex with the local source folder | Code editing, review and terminal work | Required |
| Godot 4.5.1 standard editor | Matches the existing GDScript project | Required unless the project has deliberately upgraded |
| Matching Windows export templates | Builds the portable Windows program | Required for releases |
| A private GitHub repository | Off-machine source copy and optional PR/CI workflow | Recommended |
| VS Code or another editor | Convenient manual inspection | Optional |
| GitHub Desktop | A visual alternative to terminal Git | Optional |
| Python with Pillow/NumPy | Regenerates the prepared maps with the existing authoring script | Only when that script is needed |
| Git LFS | Stores large, changing source assets outside normal Git object history | Defer until the asset inventory justifies it |

Git can be installed through its official Windows installer. If using Windows Package Manager, the documented command is `winget install Git.Git`. Restart the terminal afterward and verify `git --version`. Do not install a second competing Git/toolchain without a reason. [2]

## 3. Establish one source folder and an initial checkpoint

Use the folder containing `project.godot` as the repository root. In a fresh setup this can be `C:\Dev\Hearthtable`, with `scripts`, `assets`, `tests`, `art`, and `tools` directly beneath it. Keep existing layouts if Git is already established.

Copy or retain applicable licensing material from the companion alongside the source, including `LICENSE.txt`, `THIRD_PARTY_NOTICES.txt`, and relevant asset/rules notices under `Reference`. Do not lose attribution when copying only the `Source` folder. Do not add a new open-source license on my behalf.

Keep these categories distinct:

| Location | Contents | Version with Git? |
| --- | --- | --- |
| Project root and source directories | Godot configuration, scripts, scenes, source art, data, tests | Yes |
| `docs/` | Setup, architecture, workflow, test commands, decisions and release procedure | Yes |
| `builds/` | Generated executables and distributable scene packages | No |
| `test-results/` | Generated logs and QA screenshots | No; upload selected results as CI/release evidence when useful |
| `test-user-data/` | Disposable local test saves and caches | No |
| A separate private backup folder | My live campaigns, characters, private maps and portable DM snapshots | No |

Do not move or delete live saves during repository setup. Use the program's **Open saves folder** action to locate them. Back them up before any playtest that might modify them.

### Ignore generated and private files

Merge an appropriately scoped `.gitignore`. A starting template, to adapt after inspecting actual paths:

```gitignore
# Godot's generated cache
.godot/

# Generated output, never the source assets
/builds/
/dist/
/artifacts/
/test-results/
/test-user-data/
/logs/

# Deliberately private local material
/private/
/.env
/.env.*
!/.env.example
**/export_credentials.cfg
*.pfx
*.p12

# Optional Python authoring environment
/.venv/
__pycache__/
*.py[cod]
```

Keep `project.godot`, `export_presets.cfg`, `.gd`, `.tscn`, `.tres`, the project's `.uid` files, source-side `.import` configuration sidecars, JSON data, original assets, tests and required notices. Do not blanket-ignore PNGs, JSON, all `tools/`, `.uid`, or every scene package. Source-side import settings are different from the generated `.godot/` cache. Move a script's `.uid` sidecar with it when moving files outside the Godot editor. [3][15][16]

Git's ignore rules do not control Godot's asset scanner. Have setup scripts create an empty `.gdignore` inside generated output/test directories and any local Python environment so Godot does not scan screenshots, nested QA project copies or developer dependencies as game assets. Keep actual runtime assets outside those ignored directories. [17]

Ignoring a path does not untrack a file already committed. If generated files are already tracked, show the proposed cleanup and remove only those paths from the index while preserving local copies. Do not use a broad remove-and-readd operation as a routine fix. [4]

### Normalize text without changing everyone's global settings

Prefer a repository `.gitattributes`, merged with anything already present:

```gitattributes
* text=auto eol=lf
*.gd text
*.tscn text
*.tres text
*.cfg text
*.json text
*.md text
*.svg text
*.ps1 text
*.bat text eol=crlf
*.cmd text eol=crlf
*.png -text
*.jpg -text
*.jpeg -text
*.webp -text
*.glb -text
*.ttf -text
*.otf -text
*.pdf -text
```

For an existing repository, review line-ending changes separately from gameplay edits. Do not create a giant normalization diff in an unrelated feature branch. [3]

### Initialize only if no repository exists

After choosing the correct folder:

```powershell
git init -b main
git config user.name "YOUR COMMIT NAME"
git config user.email "YOUR VERIFIED OR GITHUB NOREPLY EMAIL"
```

The identity strings are placeholders to replace with my choice. Use repository-local configuration unless I request global defaults.

Review the exact files to stage. Use explicit paths or the Codex diff interface. Before committing:

```powershell
git status --short
git diff --cached --stat
git diff --cached --check
```

Check the staged file list for caches, executables, private campaigns, credentials and accidental large files. Then create the initial source checkpoint. If the actual baseline is still 0.11.0, a suitable commit and tag are:

```powershell
git commit -m "chore: import Hearthtable 0.11 source baseline"
git tag -a baseline/v0.11.0-import -m "Imported source baseline; native Windows validation pending"
```

Use the current version if it differs. An import tag records the source checkpoint; it does not certify that a release is tested.

## 4. Add a private remote and verify the backup

Explain once: **Git** is local version history; **GitHub** hosts an off-machine copy. A commit is local until it is pushed.

Default to a private GitHub repository named `hearthtable`, unless I choose otherwise. Establish the account and repository before the first push. If creating it in the GitHub website, make it empty: no generated README, license or `.gitignore`, because the local project already has its own files.

Use an existing authenticated connection or the normal browser/credential-manager login. Never put a token in a remote URL or a committed file.

After replacing the account placeholder and verifying there is no existing `origin` to preserve:

```powershell
git remote add origin https://github.com/YOUR_ACCOUNT/hearthtable.git
git push -u origin main
git push origin baseline/v0.11.0-import
```

If the remote already has history, inspect and reconcile it. Do not force-push or replace it to make setup easier. Verify that the intended commit is visible remotely, then check a fresh clone into a separate temporary folder. [5]

Keep supplied/private map references private unless I have decided to distribute them. A private repository is a useful access boundary, not an asset license.

### Large files and Git LFS

The inspected 0.11 source was about **15 MB**, with its largest individual source file about **4.4 MB**. Ordinary Git is a reasonable default for that baseline. Recheck current sizes before deciding.

The delivered portable executable was about **117 MB**, above GitHub's **100 MiB** normal Git file limit. Keep compiled programs in release attachments or other distribution storage, not source commits. Releases can carry binaries separately from the tracked source. [6][7]

Reconsider LFS if large textures, models, audio or authored binary assets start growing substantially. Select actual asset paths, set up LFS before committing new large assets, and explain its storage/download implications first. Do not apply LFS to every SVG, script or small JSON file by default. A fresh clone must fetch the real LFS content before Godot imports. Never rewrite existing history into LFS without a separate migration plan. [8]

Existing prepared-scene JSON embeds image bytes. Track the current authored packages, but avoid adding redundant copies of the same image to source history just because exports are self-contained. Any future authoring-format change must preserve the self-contained player download and `.hearthscene` behavior.

## 5. Make Codex remember the project through files

Create or improve a small set of documents. Do not create dozens of overlapping planning files.

| File | Purpose |
| --- | --- |
| `AGENTS.md` | Concise instructions Codex reads: rules baseline, authority boundaries, actual commands, links to deeper docs |
| `CODEX_HANDOFF.md` | Current architecture, project entry points and important limitations |
| `README.md` | Open, run, test and build the project |
| `docs/workflow.md` | This guide, adapted to the installed environment |
| `docs/testing.md` | Verified test suites, isolation, graphical/network setup and failure handling |
| `docs/releases.md` | Rebuild, native Windows QA, tagging, checksums and distribution |
| `CHANGELOG.md` | Concise user-visible changes by version |

An optional `docs/NEXT.md` can hold a short current priority list and known blockers. Keep it factual and small; use Git history for historical detail.

`AGENTS.md` is recognized by Codex. The other filenames are project conventions; Codex will need instructions linking to them. Do not assume an arbitrary attached Markdown file becomes permanent instructions automatically. [1]

Use a setup script and named actions in the Codex local-environment settings when available. Useful actions are **Run game**, **Quick tests**, **Full tests**, and **Export Windows**. Have these call repository scripts, so terminal use and CI use the same implementation. Check in portable configuration, not machine paths, credentials or session/auth caches. Verify the installed Codex interface instead of inventing configuration keys. [9]

Keep Godot pinned to 4.5.1 for this baseline. Record installation steps and the matching export-template version. Store machine-specific paths in local configuration or a documented parameter such as `-GodotPath`; provide an example file without secrets.

## 6. Use a small daily development loop

Use `main` for integrated, working source. Use one short-lived branch for one coherent change. There is no need for a permanent `develop` branch at this stage.

Once the remote exists, begin from a clean checkout:

```powershell
git status --short --branch
git fetch origin
git switch main
git pull --ff-only
git switch -c fix/door-traversal
```

`fix/door-traversal` is an example branch name; use the actual task. Do not switch branches over unresolved local edits. Save them deliberately first. If `--ff-only` fails, inspect the divergence instead of forcing a reset.

For each task:

1. State the intended behavior and a few observable acceptance criteria.
2. Inspect the relevant code and reproduce the problem, if it is a bug.
3. Make a focused change. Keep unrelated formatting, renames and engine upgrades separate.
4. Run the tests that can detect this change breaking. Add a regression test for meaningful new behavior or a bug that could recur; do not write tests that merely restate trivial code.
5. For UI, inspect the native rendered screen. For multiplayer, use real host/player processes. A screenshot alone does not establish that a button or network action works.
6. Review the diff for correctness, changed rules, private-data exposure and save/protocol compatibility.
7. Commit a coherent result with a clear message, then push the branch to back it up.

Useful inspection commands:

```powershell
git diff --stat
git diff
git diff --check
git status --short
```

After explicitly staging the intended files:

```powershell
git diff --cached
git commit -m "fix: allow movement through open doorways"
git push -u origin fix/door-traversal
```

Use a pull request when a review record is useful. A solo developer does not need a second person to review every tiny change, but still needs to inspect the diff and test evidence. If integrating locally, use `git merge --ff-only BRANCH_NAME` only when `main` can fast-forward to that branch. If it cannot, inspect and resolve the histories; do not discard commits. Recheck the integrated result when conflict resolution or other integration changes affect it. [10]

### Optional worktrees

A worktree is another checkout sharing the repository's history. Use one for an independent experiment or a second concurrent task, rather than having two chats edit the same files. It is optional for ordinary single-task work. [11]

For a manually managed worktree, after confirming `main` is the desired base:

```powershell
git worktree add -b feat/lighting-polish ..\Hearthtable-lighting main
```

Open that folder separately in Codex and Godot. Keep one branch per worktree. A Codex-managed worktree may start in detached HEAD; create a branch or use the app's handoff controls before integrating work. Verify the actual state rather than assuming it is on a named branch. [12]

Each worktree needs its own imports and isolated test data. Do not assume separate checkout folders mean separate Godot `user://` folders. Do not remove a worktree until its useful work is committed and retained. Use the managing app's cleanup controls or Git's worktree commands, not casual folder deletion.

## 7. Make testing safe and repeatable first

**The existing tests reset campaigns. Build the isolation mechanism before running them on my Windows machine.** Normal player saves must never be test fixtures.

Create a PowerShell test runner, for example `tools/test.ps1`, which accepts a suite name and Godot executable path. It must:

- Validate the engine version and script paths.
- Use unique disposable user-data locations for every run and every network role.
- Prove which `user://` directory Godot will use before allowing a test that resets or saves a campaign. Fail closed if it overlaps the real game directory.
- Capture exit codes and logs, enforce a useful timeout, and stop on failures. A missing expected completion summary or a GDScript parse/runtime error must fail the run even if an engine process happens to exit with code zero.
- Run fixed-port network suites serially and clean up only the processes and temporary directories created by that run.
- Put output under ignored test-result directories. Never clean a broad OS user-data folder.

On Linux, the existing workflow uses an isolated `XDG_DATA_HOME`. **Do not assume that variable isolates native Windows Godot.** A practical Windows approach is a disposable project copy with a unique application user-data identity. Inspect `project.godot` and any custom-user-directory settings, establish and verify the resulting path before loading `World`, and keep the production project untouched. Use a minimal preflight probe with no game autoloads to check the resolved user-data path before starting the real test project. Exclude `.git`, `.godot`, generated outputs, private data and existing QA copies from the source-copy operation so it cannot copy itself recursively. If isolation cannot be proven safe, use a dedicated test Windows account until it is implemented.

Do not launch an ordinary second development copy of the game and assume its saves are independent. Do not run tests against the production campaign as a shortcut.

Current relevant suites, to verify against the actual checkout:

| Change area | Existing tests to consider |
| --- | --- |
| General state/save behavior | `smoke.gd` |
| Range, reach, barriers and combat resources | `combat_range.gd`, `encounter.gd` |
| Spell behavior | `magic.gd` |
| Connected rooms and doors | `rooms.gd`, `prepared.gd`, `maps_ui.gd` |
| Build objects and placement | `build.gd`, `build_ui.gd` |
| Initiative, encounter triggers and lighting | `director.gd`, `director_ui.gd` |
| Prepared maps and imported designs | `prepared.gd`, `maps_ui.gd` |
| Actual player map downloads and caches | `maps_network.gd` host/client, UDP 24720 |
| Actual lobby, ownership and casting | `magic_network.gd` host/client, UDP 24705 |
| Actual encounter authority and privacy | `director_network.gd` host/client, UDP 24711 |
| Portable campaign embedding/restoration | `portable.gd`, following its required arguments |

The current scripts are under `tests/`. Read their setup and `tests/README.md`. Scripts under `tests/archive/` include removed camera modes and are not automatically current requirements. Headless tests, graphical tests, networking and portable-copy restoration require different launch procedures.

After isolation is verified, the underlying Godot command pattern is:

```powershell
# $Godot is the verified executable; $QaProject is an isolated project copy.
& $Godot --headless --path $QaProject --import
& $Godot --headless --path $QaProject --script res://tests/combat_range.gd
```

Check `$LASTEXITCODE` after each native invocation in the runner. Do not combine source parsing, engine import and a successful game launch into one vague claim that tests passed. [13]

The earlier release reported **654 passing assertions** across its chosen suites. Record that as historical evidence only. For each new build report the suites actually run, their results, skipped checks and reasons. Never copy the old count into new release notes without rerunning the matching suites.

## 8. Make builds reproducible

Create `tools/build.ps1` with a Godot path parameter. It should verify the pinned engine/templates, create the output directory, export using the tracked preset, check failures, and write a small build manifest with source commit, dirty/clean state, engine version, product version, protocol, filename and SHA-256.

Use official matching export templates. The companion's preset clears the earlier machine-specific template path; verify that the checkout has not retained an absolute `/workspace/...` path. Keep signing credentials and other machine secrets outside version control.

Example export pattern once `$Godot` is established, from the source root:

```powershell
New-Item -ItemType Directory -Force -Path .\builds | Out-Null
& $Godot --headless --path . --export-release "Windows Desktop" builds/Hearthtable_Portable.exe
Get-FileHash .\builds\Hearthtable_Portable.exe -Algorithm SHA256
```

The output directory must exist. The runner must stop on export failure before hashing or presenting an old executable. Retain embedded-pack settings so players receive one program. Use one output location consistently; do not overwrite an older release or a private campaign snapshot accidentally. [13]

Test exported resources as well as source. Preserve the ability to save a new portable campaign copy containing custom map art/designs, and restore it without external asset folders. Campaign copies contain private DM content; they are not the public/player release build.

## 9. Add CI after the local commands work

CI means automated checks on a remote runner. Introduce it after the scripts work locally, rather than debugging GitHub Actions and the gameplay at the same time.

Start with a small workflow that runs on pull requests and manual request. Reuse `tools/test.ps1`; avoid a second, divergent set of test commands in YAML. Install a pinned Godot build from the official source, run imports and selected headless suites with isolated data, and retain useful failure logs as temporary artifacts.

Use minimal repository permissions. Verify current action versions and pin third-party actions to reviewed commit SHAs. Do not add paid services or self-hosted runners as the default. Explain any required account settings or usage limits before enabling them.

Add a Windows export check when the basics are reliable. A headless CI pass does not prove native graphical playability, GPU performance, full portable restoration or real internet port forwarding. Local host/client tests validate transport logic; they do not establish that a residential router is reachable.

If LFS is introduced later, fetch LFS content before import in both CI and fresh worktrees. Preserve license notices in packaged output. Keep private campaign/map data out of uploaded logs and artifacts.

## 10. Release from a known source commit

Write a short release checklist in `docs/releases.md`:

1. Choose the release version and update its actual product display/configuration. Change the multiplayer protocol only when compatibility requires it; change the save schema only with a migration/compatibility plan. These are different version numbers.
2. Review changes and finish the relevant checks on the intended release source. Commit it. Build from that known clean commit; generated output stays outside source history.
3. Exercise the exported pack and run the relevant graphical, host/player and portable-copy checks. Fix failures on a branch and rebuild from the resulting commit.
4. Perform a native Windows smoke test of the actual executable: launch, create/load campaign, doors, scene import, a spell/attack, host/player join, cold custom-scene download, cached revisit and a portable save/restore. Confirm that development-machine files are not required.
5. For an internet-play release claim, test with a player outside the host's LAN using the intended UDP forwarding setup. Record what was actually tested. Do not change my router automatically as part of the build.
6. Record known limitations and any checks not completed. The 0.11 baseline was validated through a matching Linux Godot runtime and local UDP sessions; it had **not** been launched natively on Windows.
7. Tag the exact tested commit with a version tag such as `v0.11.1`. Do not move an existing published tag to different code. Push the intended branch and that specific tag once the release destination is established.
8. Attach the portable executable, optional self-contained scene packages, release notes and SHA-256 manifest to the chosen release location. Keep the source companion optional for players. GitHub Releases supports binary assets attached to a tagged release. [7]
9. Verify a downloaded copy's hash and launch it from a clean folder. Keep the previous working release available for rollback. Host and guests should use a compatible release; for the current build, use the same release on every computer.

Do not claim “all D&D rules,” BG3-quality parity, native Windows validation or performance targets without evidence. Measure rendering/frame-time changes with a repeatable scene, camera, resolution and hardware description before drawing conclusions.

## 11. Back up code and campaigns separately

- Push source branches you want retained. Commits that exist only on this computer are not an off-machine backup.
- Keep a second backup outside the working drive. Include necessary large-file content if using LFS; Git pointer files alone are not the assets. A remote is not the only backup worth having.
- Back up live campaigns and portable DM snapshots in a separate private location. They are not in the source repository just because source is pushed.
- Store the original supplied map references where the authoring process can find them, with attribution/source notes. Avoid committing private characters or purchased content as generic test fixtures.
- Occasionally restore a backup into a temporary location and verify it opens. A backup is useful only if it can be restored.

When something breaks, preserve the current state before attempting recovery. Prefer a new corrective commit or `git revert COMMIT_ID` for a normal already-shared commit; inspect merge commits separately because their reversal needs a mainline choice. `revert` records the reversal in history. [14]

Useful low-impact recovery commands:

```powershell
git status
git log --oneline -12
git diff
git restore --staged PATH_TO_FILE
```

The last command unstages the file while keeping its working copy. Do not use hard resets, forced pushes, blanket restores or cleanup that deletes ignored files as routine troubleshooting. Give me the affected files/commits and a preservation plan before a destructive recovery operation.

## 12. Keep requests focused so Codex can verify them

Describe behavior, a concrete reproduction, and success conditions. Avoid asking for simultaneous engine, network, rules and visual rewrites in one task. Use short milestone changes that each leave the game runnable.

Useful task templates:

**Bug fix**

> On branch `fix/SHORT_NAME`, reproduce this issue: [steps]. Expected: [behavior]. Actual: [behavior]. Read the host-authority and 2014 rules requirements first. Fix the cause, add a useful regression check, and run the relevant existing suites. Report changed behavior, evidence and limitations. Preserve unrelated work.

**Visual improvement**

> Improve [specific screen/scene] against these references. Preserve the fixed DM/player camera roles and existing mechanics. Keep controls readable at the minimum window and high DPI. Show native screenshots at stated resolution and check the actual interactions. Measure performance using the same scene before and after if rendering changes.

**Review**

> Review this branch against `main`. Prioritize concrete defects, ownership/privacy failures, 2014 rules regressions, save/protocol incompatibility and missing meaningful checks. Give file references and reproduction details. Distinguish confirmed bugs from unverified concerns.

**Resume in a new chat**

> Read AGENTS.md, CODEX_HANDOFF.md, docs/NEXT.md if present, and the current Git status/diff. State the current branch and unfinished work. Continue [specific task]. Treat the current files as authoritative, preserve unrelated edits and do not rely on a missing earlier chat.

**Release**

> Prepare the next portable Windows release using docs/releases.md. Build from the intended commit and retain tests/checksums. Prepare the concrete artifacts and draft notes. Identify anything not actually tested, especially native Windows launch and external networking. Use the previously established repository and visibility; do not publish to a new destination by assumption.

Do not generate a fresh giant “project summary” after every tiny edit. Update durable docs when decisions, commands or architecture change; keep status messages and final reports short. Use Git diffs and commits to carry the implementation history.

## 13. Setup completion criteria

Codex should work through these phases and mark each **done**, **blocked**, or **deferred**, with evidence:

| Phase | Finished when |
| --- | --- |
| A — Locate and preserve | Correct source root, current version, existing Git state and private save location identified; original download retained |
| B — Local Git foundation | Ignore/attribute rules reviewed, notices retained, identity configured and source checkpoint committed without generated/private files |
| C — Remote copy | Intended private remote established, source pushed and a separate fresh clone checked |
| D — Repeatable local work | Documented Godot pin, safe test isolation, working test/build scripts and useful Codex actions |
| E — Continuous checks | Small CI workflow validates the same scripts, or a precise account/tool blocker is documented |
| F — Release and recovery | Tested build procedure, checksum manifest, release checklist and separate campaign backup/restore procedure |

On the first response, perform the audit and report only the next missing decisions. On completion, give me:

1. The exact folder to open and commands/actions to run the game, quick tests, full tests and Windows export.
2. The source commit, branch and remote status, including whether changes are actually pushed.
3. What I should do at the start and end of a normal session, in a short checklist.
4. Any remaining manual login, native Windows, external multiplayer or backup validation step.

Do not mark a phase complete merely because its instructions were written. Do not introduce extra services or complex branching until the simple workflow is working.

---

## Official references

These support tool behavior and commands. Folder names, phase structure and the recommended workflow are project-specific choices. Interface details can change; verify against the installed version when executing this guide.

1. OpenAI — [Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
2. OpenAI — [Windows app and native Git setup](https://learn.chatgpt.com/docs/windows/windows-app)
3. Godot 4.5 — [Version control systems](https://docs.godotengine.org/en/4.5/tutorials/best_practices/version_control_systems.html)
4. Git — [gitignore](https://git-scm.com/docs/gitignore)
5. Git — [Working with remotes](https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes)
6. GitHub — [About large files](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)
7. GitHub — [About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
8. GitHub — [About Git Large File Storage](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage)
9. OpenAI — [Local environments and actions](https://learn.chatgpt.com/docs/environments/local-environment)
10. Git — [Recording changes](https://git-scm.com/book/en/v2/Git-Basics-Recording-Changes-to-the-Repository)
11. Git — [git-worktree](https://git-scm.com/docs/git-worktree)
12. OpenAI — [Codex worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees)
13. Godot 4.5 — [Command line tutorial](https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html)
14. Git — [git-revert](https://git-scm.com/docs/git-revert)
15. Godot — [UID files and version control](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/)
16. Godot 4.5 — [Import process and source-side metadata](https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/import_process.html)
17. Godot 4.5 — [Project organization and .gdignore](https://docs.godotengine.org/en/4.5/tutorials/best_practices/project_organization.html)
