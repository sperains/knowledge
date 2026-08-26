---
name: find-simplifications
description: Find and document evidence-backed opportunities to remove, merge, or narrow unnecessary ICCE canvas code and architecture surface. Use when auditing Plan/Commit migration leftovers, duplicate ChangeSet or collaboration logic, legacy transaction collectors, unused APIs, speculative abstractions, redundant tests, or hand-rolled utilities; also use when consolidating simplification decisions or reviewing a branch for simplification candidates.
---

# Find ICCE Simplifications

Turn a broad request to “simplify ICCE” into a small, evidence-backed set of candidates. Follow the code and current architecture; do not delete or redesign a surface merely because it looks old, duplicated, or verbose.

## Read ICCE context first

Read the repository root `AGENTS.md`, the current ICCE architecture documents under `src/views/icce/docs/`, the owning application/domain/infrastructure code, and the relevant Vitest tests before judging a candidate. Treat the Plan → Commit → ChangeSet → Publish architecture as the current direction and preserve its stated boundaries and invariants.

For the canvas migration, map the layers explicitly:

```text
UI intent / interaction preview
  → application command
  → domain plan
  → commit executor
  → CanvasChangeSet
  → collaboration / persistence publisher
```

Do not confuse interaction preview, selection state, or UI state with persistent model changes. Only the latter belongs in the persisted ChangeSet unless the owning architecture document says otherwise.

## Survey the right ICCE surfaces

Search broadly with `rg`, then read every relevant call site. Begin with the largest production-code areas and the most duplicated lifecycle logic, not just the first unused symbol found.

Prioritize:

- legacy transaction collection: `runTransaction`, `scopeStack`, `beginCanvasOperation`, and `record*` entry points;
- Plan, Commit, and ChangeSet contracts and their application executors;
- shape, line, relation, parent-field, region, descendant, and submitted-state mutations;
- operation publication, collaboration payload projection, and replay or remote-apply paths;
- application commands, domain services, Store writes, and infrastructure adapters;
- duplicated tests, snapshots, compatibility branches, and generated or hand-maintained inventories.

Useful searches include exact symbol names, event names, operation identifiers, Store methods, collaboration wire fields, and both direct and member-style method calls. Inspect dynamic registration, configuration, and adapter paths; static search alone is not proof of absence.

## What counts as a strong candidate

A strong candidate removes, folds, or narrows a real ICCE surface and has evidence that its maintenance cost exceeds its current value. Examples include:

- a public command, event, helper, or configuration option with no production consumer;
- a legacy collector that every migrated command has stopped using;
- the same shape, line, relation, or parent-field fact represented in multiple change records;
- a command that re-derives a domain result already present in its Plan;
- a generic application or service method used by only one consumer and replaceable by a private capability;
- a test, snapshot, or invariant that protects only a removed or unsupported behavior;
- duplicate ChangeSet-to-collaboration projection paths;
- a hand-written utility that a maintained dependency or Node builtin covers while deleting owned implementation, tests, and documentation;
- a speculative abstraction with no current user-facing or persistence contract.

The goal is net deletion or a materially smaller contract. A wrapper that merely relocates the same complexity is not a simplification.

## Prove each candidate before proposing it

Classify every consumer:

- **Production:** `src/views/icce`, runtime configuration, Store wiring, collaboration adapters, persistence paths, and real entry points.
- **Non-production:** tests, snapshots, docs, comments, and development-only helpers.
- **Ambiguous:** examples, scripts, dynamic loaders, and compatibility code that may still be part of a shipped path.

For each candidate, record:

1. The current owner and all direct and indirect consumers.
2. Whether the surface affects persistent data, collaboration messages, replay, or compatibility.
3. The exact implementation, tests, docs, and generated artifacts that become deletable.
4. The behavior or capability that would be given up.
5. The acceptance evidence that proves the simplified end state.

Reject or defer a candidate when a production caller still exists, when the change is actually a new product decision, when an ICCE architecture document protects the boundary, or when the deletion causes unrelated churn without reducing the owned surface.

## Audit data ownership and lifecycle

For every defensive copy, freeze, validator, callback capture, and cached value, identify where the value came from and who owns it next. Same-process typed calls generally borrow readonly values; Store state, serialized collaboration payloads, queued work, persistence, and worker or process boundaries require explicit ownership or validation.

For asynchronous interaction and publication flows, map each state flag, readiness promise, cancellation path, disposer, and error path to one owner and one transition. If multiple mechanisms mirror the same liveness or settlement fact, consider one controller or transaction boundary. Preserve mechanisms that protect synchronous publication and rollback, callback containment, first-terminal-outcome arbitration, operation ownership, or dispose-to-quiescence.

Apply ICCE's data rule: never fill a missing field with another field's value. If a required value is absent, keep it empty or null and let the contract expose the absence.

## Use the right outcome

### Durable simplification proposal

Use a project-appropriate design or migration document when the change affects a public contract, persistent format, collaboration protocol, command boundary, shared event model, package or module ownership, or a migration stage. The proposal should state:

- **Problem:** current surface and consumer evidence;
- **Proposal:** exactly what to remove, merge, narrow, or rehome;
- **What is given up:** the strongest counterargument and lost capability;
- **Acceptance criteria:** observable final behavior and required checks;
- **Risks:** user behavior, collaboration, persistence, compatibility, and future reintroduction conditions.

Prefer updating an existing ICCE architecture or migration document when it already owns the decision. Do not create a duplicate decision record.

### Local TODO/FIXME/XXX

Use an inline note only for a small, local cleanup that does not require a durable architecture decision. Make it actionable, name the smell, and state why it is safe to revisit. Do not use TODOs for speculative complaints or behavior changes that need product or architecture approval.

### No change

Report candidates that were inspected and rejected when that evidence prevents future repeated investigation. A passing test or an unused-looking symbol is not, by itself, proof that removal is correct.

## ICCE migration examples

Use the current Plan/Commit migration as the reference model:

- `recordSnapshot` was removable only after proving it had no callers and that explicit ChangeSet entries covered its facts.
- `runTransaction` remains necessary while unmigrated commands depend on its collection scope; treat its deletion as a later migration acceptance criterion, not an immediate cleanup.
- `scopeStack` and remaining `record*` paths should be removed only after all persistent commands publish through explicit ChangeSets and their alternate callers are covered.
- A simple command may keep lightweight Plan and Commit logic in one application command; do not create abstractions solely for visual uniformity.
- A single ChangeSet should remain the source for local commit results and collaboration projection; do not preserve parallel facts without a documented boundary.

These are investigation patterns, not permission to bypass the current architecture document or to assume that every old symbol is already obsolete.

## Consolidate superseded decisions

When an ICCE simplification makes an older design or migration record obsolete:

1. Identify the current owner from code, configuration, docs, tests, and inbound links.
2. Classify the older record as fully superseded, partially superseded, still current, or historical.
3. Move unique rationale, alternatives, consequences, compatibility obligations, and verification evidence into the current owner before removing the old record.
4. Keep any record that still protects a live behavior, persistent format, collaboration contract, or meaningful rejected alternative.
5. Repair inbound references and verify exact symbols, event names, fields, and paths after the change.

Do not edit a frozen historical record if ICCE later introduces such an archive policy; update its current owner instead.

## Validate and report

Select checks from the actual outgoing scope. At minimum, for code or architecture changes use the narrowest relevant Vitest tests, then run:

```text
pnpm run type-check
pnpm run test:unit
pnpm run build
git diff --check
```

Do not claim a check passed unless it ran. Keep test documentation under the repository's ICCE test documentation location and use Vitest for maintained tests.

Report:

- areas surveyed and intentionally excluded;
- candidates accepted, deferred, or rejected with consumer evidence;
- code, tests, docs, generated files, and contracts that would change;
- architecture or migration records updated or consolidated;
- checks actually run and any remaining risk.

Prefer a few well-proven candidates over a long list of guesses.
