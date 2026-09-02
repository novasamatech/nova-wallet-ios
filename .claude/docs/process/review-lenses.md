# Review Lenses

The criteria each reviewer applies. This file is **pure criteria** — it contains nothing about
rounds, panels, teammates, convergence, or how a review was commissioned. That is deliberate: it is
read by agents that must not know any of it, and adding process language here would leak straight
into them.

Every reviewer is assigned one or more lenses by name. The named lens is the whole assignment.

---

## Spec lenses — applied to `.claude/SPEC.md` and `.claude/CONTRACTS.md`

### Lens `contract` — is the document a contract, or a description?

You own §2 Scope, §3 Functional Requirements, §4 Non-Functional Requirements, **all of
`.claude/CONTRACTS.md`**, §10 Verification, §11 Open Questions — and traceability across both
documents.

`CONTRACTS.md` carries an obligation the rest of the spec does not: **it must stand alone.** The
executor, `plan-exec` and the cold `executability` reader are handed that file and never `SPEC.md`,
so any `§N` reference surviving inside it is a `gap` — the reader cannot follow it, and on a funds
path the thing behind the reference is usually the rounding rule or the amount. Grep it for `§` and
treat every hit as a finding.

Hunt for:

- **Requirements that two implementations can both satisfy differently.** Take each FR and try to
  satisfy it wrongly. If you succeed, name implementation A and implementation B and the observable
  difference. This is the single highest-value thing you do.
- **Non-atomic requirements.** "and", "as appropriate", "if needed" — each hides an unstated decision.
- **Contracts missing their obligations.** A signature is not a contract until it states its error
  cases, which queue it calls back on, who owns it, and what cancelling it does. A protocol returning
  `CompoundOperationWrapper` with no stated cancellation semantics is a finding.
- **Absent non-functional requirements.** The common absences: what happens when the user leaves
  mid-flight; what happens with no network or a disconnected node; how many round-trips this costs;
  what is allowed on the main thread; localization; backwards compatibility. An NFR section that
  omits one without saying "not applicable, because…" is incomplete.
- **Unverifiable criteria.** "Responsive", "smooth", "fast", "handled gracefully", "no flicker" —
  quote the line and say what an agent would be unable to check.
- **Tautological equality.** An acceptance criterion asserting that two values are equal when both
  are derived from the same source or the same computation. Ask: what change to the underlying input
  would make this check fail? If the answer is "nothing" — both sides move together no matter what
  the input is — it is decoration, not verification, and it arrives looking rigorous because it cites
  a real `file:line`. "The displayed fee equals `AssetExchangeOperationFee.submissionFee.amount`"
  passes even when the user is overcharged, because both sides read the same wrong value; an
  assertion like `amountOut == args.amount` for a `.buy` quote is tautological because the
  initializer just copies its argument into `amountOut` — the check verifies the copy, not the quote.
- **Contradictions.** Between §2 and §3, between an FR and an NFR, between a contract's signature and
  its stated semantics. Quote both lines.
- **Traceability holes.** An FR no contract implements. A contract no FR asked for. An FR absent from
  §10. An edge case citing a requirement that does not exist.
- **Scope doing dishonest work.** An "out of scope" bullet that removes the hard part of the problem
  while §1 still claims to solve it.
- **Assumptions in §11 that are really decisions.** If the design changes when the assumption is
  wrong, it needed to be a question, not a footnote.

Reference: [review/architecture-checklist.md](../review/architecture-checklist.md) §Module
Structure, §Cross-Cutting; [code/error-handling.md](../code/error-handling.md).

### Lens `reality` — does this survive contact with the codebase?

You own §1 Problem, §6 High-Level Design, §7 Low-Level Design, §8 Edge Cases, §9 Migration — and
every factual claim about existing code, anywhere in the document.

You are the only reviewer who reads the source. Do it.

Hunt for:

- **Ungrounded claims.** Every type, protocol, method, and field the spec names as existing:
  `Grep` for it. Does it exist? Does it have that signature? Does that method really return that?
  Cite `file:line` for what is actually there. This is your highest-value work — a spec built on a
  type that does not exist takes the whole downstream chain with it.
- **Architectural infeasibility.** `async`/`await`, actors, or new Combine where this codebase uses
  `CompoundOperationWrapper` from an `*OperationFactory`. Business logic in a Presenter, networking
  in a View, navigation outside a Wireframe. A long-lived service with no `setup()`/`throttle()`
  registration in `ServiceCoordinator`. Load
  [architecture/viper.md](../architecture/viper.md),
  [code/concurrency.md](../code/concurrency.md), and
  [architecture/services-lifecycle.md](../architecture/services-lifecycle.md) before you judge.
- **Reinvention.** Something `substrate-sdk-ios`, `Operation-iOS`, `Keystore-iOS`, or an existing
  Nova service already does, being rebuilt inside the feature. Name the existing thing.
- **The mandatory edge-case matrix, row by row.** The table in
  §Mandatory edge-case coverage below defines the minimum for each domain. Walk it. A
  missing row on a funds-critical domain is `major` at least, and `blocking` where the missing case
  produces a wrong amount or a wrong signed payload.
- **Feature-area incompleteness.** Staking has four flavours; governance has two versions; a swap
  route belongs in the exchange graph rather than as a special case. If the spec covers one and §2
  does not say why the others are excluded, that is the finding.
- **Delegated wallets.** Proxy, multisig, watch-only, hardware, Ledger. Does the design work through
  `ExtrinsicSenderResolution`, or does it assume a wallet that holds its own key?
- **Migration reality.** A schema change with no model version, enum case, `nextVersion`, and stated
  fate for existing rows. Check [code/migrations.md](../code/migrations.md).
- **Diagram divergence.** Does the mermaid diagram in §6.1 show the same components and edges the
  prose in §6.2–§6.3 and §7 describe? A diagram that has drifted from the text is a real defect —
  readers trust the picture.

Reference: [review/architecture-checklist.md](../review/architecture-checklist.md)
§Services & Lifecycle, §Data Flow, §Persistence, §Wallets & Transactions, §Feature-Area Completeness.


---

## Plan lenses — applied to `.claude/PLAN.md`

### Lens `spec-fidelity` — is this the spec, all of it, and only it?

Read `.claude/PLAN.md` whole, `.claude/CONTRACTS.md` whole, and `.claude/SPEC.md` **§2–§5 and
§7–§10** — the sections your bullets below actually walk. §1 is background, §6 is design narrative
you are not mapping, and §11 is assumptions the human owns; skip them
(`awk '/^## 2\./,/^## 11\./' .claude/SPEC.md`). You are the only lens that sees both documents.

Build the mapping in both directions and report every hole:

- **Spec → plan.** Walk SPEC §3 (FR), §4 (NFR), §7 (low-level design), §8 (edge cases), §9
  (migration) and every contract in `CONTRACTS.md`, item by item. **§7 is binding**: the architect
  is required to put in it only decisions the plan is not free to make differently, so a task that
  quietly chooses another algorithm, ordering or state placement than §7 names is a finding. If §7
  contains something that reads as narrative rather than a binding decision, that is a finding
  against the *spec* — escalate it rather than holding the plan to it. For each, find the task that implements it. An item with no task is a finding, and its
  severity is the severity the spec assigned to what it protects — a dropped edge case on a fee path
  is `blocking`, a dropped `minor` traceability requirement is `minor`.
- **Plan → spec.** Walk every task. Which requirement asked for it? A task with no requirement
  behind it is scope creep — the executor will build it, it will not be reviewed against anything,
  and nobody decided it should exist.
- **Contract drift.** The plan's `## Contracts` section is a table of `C-N` references into
  `CONTRACTS.md`, not a copy of it — so check two things. First, that the rows cite the right
  contracts and cover every one the tasks touch. Second, that every signature reproduced in a task's
  **Interface** block or code snippet matches `CONTRACTS.md` character for character. A changed
  argument label, a dropped `throws`, a swapped optional, a return type of `Thing` where the contract
  said `CompoundOperationWrapper<Thing>` — all findings, and all easy to miss because the plan's
  version reads perfectly well on its own. A plan that has started re-copying contracts wholesale is
  also a finding: it creates a second copy that will drift from the first.
- **Silent reinterpretation.** A requirement implemented in a way that satisfies its words but not
  its acceptance criterion. Quote both and say what an acceptance check would see.
- **Out-of-scope leakage.** Tasks that cross the line SPEC §2 drew.
- **Verification drift.** SPEC §10 named how a requirement would be shown to hold. Does a task
  actually verify it that way, or did the named test quietly become "build succeeds"?

### Lens `codebase-correctness` — will this compile, and does it look like Nova Wallet?

Read `.claude/PLAN.md` and the source. Do not read `SPEC.md` — whether the plan matches the spec is
another lens's job, and it will bias what you consider correct.

- **Symbol reality.** Every existing type, protocol, method, property, and argument label the
  snippets reference: `Grep` for it. Does it exist? Is the signature what the snippet assumes? Is the
  argument label right? Cite `file:line` for what is actually there. This is your highest-value work
  and most of your findings will come from it.
- **Internal signature consistency.** The linter has already compared each "Produces" head against
  the "Consumes" that cites it. What it cannot do is read the *bodies*: check that the code inside
  each task actually calls those signatures with the right labels, types and generic parameters, and
  that a type's members are consistent everywhere the task bodies construct or destructure it.
- **Convention violations**, against [review/code-checklist.md](../review/code-checklist.md):
  `async`/`await`, actors, or new Combine instead of `CompoundOperationWrapper`; a missing
  `[weak self]` in an operation callback; a Presenter callback not marshalled to `.main`; a force
  unwrap; `try?` or `?? 0` turning a failure into a number; a hardcoded user-visible string; a
  `waitUntilFinished: true` on the main thread; a provider re-subscribed without
  `AnyProviderAutoCleaning`; a `CancellableCallStore` never cancelled on teardown.
- **Layer placement**, against [architecture/viper.md](../architecture/viper.md): business logic
  in a Presenter, networking in a View, navigation outside a Wireframe, layout outside a ViewLayout,
  a module assembled anywhere but its ViewFactory.
- **Missing peer files.** §Peer-file obligations below is the checklist.
  A changed protocol with no `*Protocols.swift` edit and no Cuckoo regeneration; a new service with
  `setup()` but no `throttle()`; a CoreData change with no model version, enum case, `nextVersion`,
  or migration test; a new file added outside Generamba with no `project.pbxproj` edit; a new string
  with no `Localizable.strings` entry.
- **Compile order.** Read the tasks in sequence. At each task boundary, does the tree build? A task
  referencing a symbol a later task creates is a finding — name both tasks.

### Lens `executability` — can someone with no context run this?

Read `.claude/PLAN.md` and `.claude/CONTRACTS.md`. Two whole files, and no others — **never
`.claude/SPEC.md`**, not any part of it, and not the design rationale anywhere else. Those two files
are exactly what the executor is handed, which is why the restriction is two file names rather than
a section range: a section range is not enforceable, and this lens is worthless the moment it is
breached.

You are simulating the executor, and the executor has nothing else. If you need something that is in
neither file, that absence *is* the finding — and so is a plan step that sends you into `SPEC.md`,
because the executor cannot follow it there.

Read it as if you were doing it. At every step ask: could I do this right now, without deciding
anything?

- **Steps that require a decision.** "Implement the fee calculation", "add error handling",
  "update the tests accordingly", "similar to Task 3", "wire it up". Name the step number and the
  decision you would be forced to make.
- **Unlocatable edits.** A "modify" step with no quoted surrounding context, no line reference, and
  no statement of what it goes after — in a file with several plausible insertion points. Say which
  points are plausible.
- **Placeholders the linter cannot pattern-match.** It catches `TBD`, bare `...`, "similar to",
  "as needed". It does not catch an empty function body, a comment standing in for logic, or a step
  whose code block is real Swift that quietly omits the interesting case. Those are yours.
- **Undefined names.** A symbol used in a task that no earlier task and no cited `file:line`
  introduces. You cannot check whether it exists in the codebase — that is `codebase-correctness`'s
  job — but you *can* check whether the plan told you where it comes from. It must. The linter checks
  this for **Interface** blocks only; symbols appearing first in a step's code are yours.
- **Test tasks specified as case tables.** A test task states each case's test class, method,
  fixture, inputs and expected value rather than pasting the body. Read it as the executor: can you
  write that assertion from the row without deciding anything? Findings, and name the row:
  - an expected value you cannot derive or reproduce;
  - **a row that does not name the type and method under test** — the executor will pick one, and a
    row that passes against a helper while the shipped path is wrong is the exact defect a test
    exists to prevent;
  - a fixture named but never defined anywhere in the task.
- **Boilerplate delegated to a precedent.** The planner is allowed to replace boilerplate with a
  named precedent plus an explicit member list, rather than pasting it. That is executable **only**
  when both halves are there: a `file:line` precedent *and* the list of members to produce. A step
  that names a precedent without listing the members is a finding. So is any delegation that leaves
  you a choice about a call, a flag, an amount, an ordering, or a keep-alive — that is not
  boilerplate, whatever the step calls it.
- **Verification that cannot be run or cannot fail.** A missing command, a command with a
  placeholder in it, an "Expected:" that any outcome satisfies, a task whose only verification is
  reading the code. Also: a task that changes behaviour and verifies only that the build succeeds —
  say what it would take to actually observe the change.
- **Ordering and dependencies.** A task whose "Depends on" is wrong or absent. A task that cannot
  start because its input is produced later.
- **Missing stop conditions.** What the executor does when a verification fails, and what is out of
  scope. Without an "Out of scope" section, the executor improvises.
- **Granularity.** A task so large it cannot be reviewed as one change, or so small it leaves the
  tree uncompilable. Both are findings; name the task and say which.


---

## The falsification bar

Applies to every lens above.

### The falsification test

Every finding must fit one shape from the protocol doc — `ambiguity`, `gap`, `contradiction`,
`ungrounded`, `unverifiable`, or `infeasible` — and carry the evidence that shape demands. Work
through it before reporting:

1. **Which shape is it?** If none fits, it is a preference. **Discard it silently.**
2. **What is the concrete evidence?** For `ambiguity`: implementations A and B, and how a user could
   tell them apart. For `gap`: the specific input or state. For `contradiction`: both quoted lines.
   For `ungrounded`: `file:line` of what is actually there. For `infeasible`: the doc and rule.
3. **Would fixing it change the implementation?** If both the current and the fixed spec produce the
   same code, it is a `minor` at best, and probably nothing.
4. **Did you read enough?** If your finding depends on a file you did not open, open it.

Suppress, always: style and wording preferences; a section being shorter than you would have written
it; "this might not scale" with no stated load; "someone could later misread this" without showing
the second reading; the same root cause reported once per section it appears in — report it once and
list the sections.

**Zero findings is a valid outcome.** Say so. A long list of soft findings buries the one that
mattered, and costs the author the attention that one deserved.

---

## Reference tables

### Mandatory edge-case coverage (used by lens `reality`)

If the design touches the left column, §8 **must** answer every question in the right one. Missing
rows are what `spec-reality` looks for first.

| If it touches…            | §8 must answer                                                                                                                     |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Amounts or balances       | Zero. Dust below existential deposit. Maximum. Free vs transferable vs locked. Decimal shift between chain and display units. Rounding direction, and who benefits from it. `BigUInt` overflow and `String` round-tripping. |
| Fees                      | Balance covers the amount but not amount + fee. Fee changes between estimate and submission. Fee asset ≠ transfer asset. Fee estimation fails. Fee for the exact call or batch actually submitted, not an approximation. |
| Signing or extrinsics     | Is the payload signed the payload the user was shown? Nonce and mortality. Batch vs single call. Proxy and multisig via `ExtrinsicSenderResolution`. Watch-only, hardware, and Ledger wallets. `canPerformOperations` before the action is offered. |
| Chain interaction         | Chain absent from the registry. Runtime metadata not yet synced. Node disconnects mid-flow. Reconnection. Slow node vs timeout. Two chains selected in sequence. |
| Subscriptions or providers | View dismissed while in flight. User re-triggers before the first result. Re-subscribe without clearing the old provider. Callback arriving after teardown. |
| Persistence               | Migration forward. No downgrade path. Partial write interrupted. Record absent. Record corrupt. |
| Staking                   | All four flavours, or one with the reason the other three are excluded stated in §2. |
| Governance                | Both `governanceV1` and `governanceV2`. |
| Swaps or XCM              | Route unavailable. Slippage bound. Quote expiry. Origin and destination fees. Partial failure on the destination chain. |
| Anything user-visible     | Longest plausible string. RTL. Plural forms. Missing localization key. |

### Peer-file obligations (used by lens `codebase-correctness`)

| Situation | The plan must also contain |
|-----------|-----------------------------|
| New VIPER module | The `./generamba-module.sh ModuleName` invocation, the target directory the folder is moved to afterwards, and the group-placement check. All seven files in one task. |
| New file added outside Generamba | The `project.pbxproj` edit, by hand. Never the `xcodeproj` gem. |
| Protocol source changed | Cuckoo mock regeneration, and the `Cuckoofile.toml` entry if the source file is new. |
| New long-lived service | Registration in `ServiceCoordinator` with **both** `setup()` and `throttle()`. |
| CoreData change | New model version, the version enum case, `nextVersion`, the mapper, and a migration test — in that order, in one task. |
| New user-visible string | The `Localizable.strings` key in every localization present in the repo, and the `R.string(preferredLanguages:)` call site. |
| Submission path | The `DataValidationRunner` setup, with each validator named. |
| Feature with four staking flavours or two governance versions | A task per flavour, or an explicit "out of scope" line naming the ones excluded. |
