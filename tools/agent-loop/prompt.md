Perform ONE bounded improvement cycle on Hearthtable Lite, then stop.

Read AGENTS.md, CODEX_HANDOFF.md, docs/lite.md,
docs/campaign-experience.md and tests/README.md. This task
explicitly authorizes exactly three worker agents: Builder, Tester and Critic,
managed by you as coordinator. If worker tools are unavailable, report blocked;
do not silently substitute a single-agent run. Do not create further workers.
After prerequisites pass, actually launch each worker and retain its agent ID
with its findings. If blocked before launching workers, say they were not
started; never invent worker findings or report your own review as independent.
The owner explicitly requires GPT-6 Luna: gpt-6-luna for the coordinator and all
three workers. The launcher pins model and agents.default_subagent_model for
this invocation. Use the default worker type, preserving that model; if the
spawn tool requires an explicit model, select gpt-6-luna. Do not override it
with another model or use a role with a different model configuration. Report
unavailable model access as blocked; never silently fall back. Record actual
worker IDs and model metadata when exposed; distinguish requested settings
from observed metadata rather than inventing model verification.

On Windows, use shell tools with login=false and an explicit project workdir.
If invoking PowerShell yourself, use -NoProfile and Set-Location -LiteralPath
with the supplied project path; a profile may otherwise reset the location.
For ripgrep file filters, use `rg -n 'pattern' scripts -g '*.gd'`; Windows does
not expand `scripts/*.gd` as a shell wildcard. A search error is distinct from
a native Godot crash and must not be reported as its cause without evidence.

Before editing, Critic inspects the current program and recent Git history to
identify missing campaign capabilities, concrete defects or usability problems.
Tester reproduces a campaign scenario and checks that relevant validation is
available safely. Select at most ONE coherent, useful improvement. A feature
may span several files; it is not limited to a small bug fix. Builder alone edits
application source; Tester and Critic are independent and do not change it.
Coordinate tests so fixed network ports and test data are never shared at once.

The owner's goal is a polished multiplayer 2014 5e homebrew VTT and character
sheet, not merely fewer bugs. Build missing, useful capabilities as well as
fixing defects. Follow the campaign brief's class/scenario rotation and record
evidence-backed coverage there when accepting an app improvement. Audit at least
one class-specific situation and one shared campaign interaction each cycle;
use recent history/coverage to visit different classes rather than repeatedly
polishing spell wording. Prioritize the highest-impact interruption to real play.
Start with the owner's Druid -> Dire Wolf Wild Shape scenario unless the current
checkout already supports it with end-to-end evidence. An existing use counter
or a feature description is not working transformation support. Implement safe,
tested feature slices without exposing unfinished controls. A larger feature
can take several cycles; keep its remaining work in the campaign brief. Do not
replace requested feature development with repeated documentation-only edits.

Use D&D Beyond as a usability reference: familiar sheet sections and precise
labels, discoverable actions/bonus actions/reactions, readable spell/feature
text, equipped/prepared choices, clear resource and active-effect state. Keep
Hearthtable's own design and DM-led workflow. Use the 2014 SRD reference identified
in the campaign brief for rules; keep homebrew/custom overrides explicit and
distinguish 2024 rules.
Use synthetic campaigns for tests. Public, accessible play examples may inform
scenarios when their source is recorded; never claim to have played/watched a
campaign you have not inspected or access private campaigns/accounts.

Continue auditing missing, incomplete or inaccessible spell information.
Audit assets/spells.json (desc and higher_level) and trace the actual
sheet's Read full spell view, casting proposal and DM inbox. Check casting time,
range, components/material costs, duration, concentration/ritual, effects,
saves/attacks and higher-slot effects where applicable against the existing
2014 reference sources. A populated JSON field alone does not prove the player
or DM can read it. Optional fields and spells without upcasting are not defects.
Preserve imported/custom spell text; do not invent rules or substitute 2024/BG3
rules. Improve reference information and proposals while keeping resolution
and resource spending under the DM's control.

Also inspect broken/incomplete controls, awkward existing workflows, PDF import
reliability, readable DM/player screens, keyboard/accessibility and clear
interactions. Tie each change to a concrete player/DM benefit and test the
affected interaction; avoid refactoring just to create activity. Use actual
rendered before/after screens for visual changes. New features consistent with
the owner's campaign brief are authorized. Do not add unrelated features or
churn the design merely to make a change. A well-supported no_change result is
valid only after considering missing campaign capabilities as well as bugs.

Preserve DM authority, packet privacy, player movement rules, DM-only doors,
PDF-only review, cosmetic customization and save/update compatibility. A DM-approved
transformation is a rules-state change, separate from cosmetic customization;
update the usable sheet after approval without authorizing player-side stat
mutation or automatic outcomes. Compatible optional fields must load older saves
and survive save/reload/reconnect; if a protocol/schema break is essential,
report the required migration plan as blocked rather than silently changing it.
No new character creator, automated combat, protocol/schema/engine change, licensing
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
cycle; missing tools mean blocked with setup instructions.
The launcher passes a verified absolute interpreter as HEARTHTABLE_PYTHON.
The helper uses it automatically, avoiding py.exe/WindowsApps lookup; use the
same path with --python if an environment setting is absent. If it cannot run,
retain the actual error and report a session/permission blocker rather than
assuming the owner must reinstall Python. Never disable the sandbox.
The launcher also probes pinned Godot startup/isolation before model usage.
It also checks actual Git metadata writability without changing the index or
refs. If committing later fails, preserve the real index.lock path/error and
candidate edits. Permission denied is not a stale lock; do not remove locks,
change ACLs or disable sandboxing. Return the specific blocker and approvals.
The helper retains a Windows ROOT-store diagnostic but accepts it only when
the same official 4.5.1 process proves its bundled trusted CA fallback loaded.
This does not disable TLS checks. Use the helper's result and isolation report;
do not treat that verified fallback alone as a blocker or broaden its exception.
Missing fallback proof and all other engine/test errors remain failures.

Run tests through
`node tools/lite-local.mjs test --output <run-report-dir>/unique-test-name`.
Use --suite lite/updates/pdf_import or --ui for rendered checks; network changes
also require the `network` action (add --ui for rendered player controls).
Features that change a player's usable sheet or state require real DM/two-player
network coverage as well as relevant core/rendered checks: only the assigned
player receives their full sheet, observers receive permitted visuals, and
unauthorized requests cannot change state. Exercise save/load/reconnect where
the feature persists. Test a complete usable scenario, not just that a new
button or text field exists.
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
The owner authorizes an installer release every five accepted improvements.
The parent launcher counts successful cycles and runs local full UI/network/build
validation plus the existing GitHub release pipeline at that checkpoint. This
does not authorize workers to push/tag/publish or change the counter. Failed
and no-change cycles do not count. Known unresolved native crashes are blockers;
never replace a crashed check with source inspection or suppress its diagnostics.

Commit accepted changes only on automation/lite-improvements. Do not discard
uncommitted work, reset, clean or force anything. If edits remain unresolved,
report blocked and preserve them. The launcher pauses future cycles on failure.
Keep logs, reports, builds and synthetic data outside tracked player assets.

Return the required JSON report. revision must equal the final full Git HEAD.
For no_change, make no commit or edits. For accepted, a new commit, passing tests
and both approvals are required. For blocked, explain the missing tool or failed
check and the next step. Each role_reports entry must summarize that worker's
actual findings. Review previous reports/history to avoid repeating the same
work. Identify the class/scenarios inspected, rules source actually consulted,
and any remaining feature slice in the report. Never hide a missing test, worker
or approval behind a success status.
