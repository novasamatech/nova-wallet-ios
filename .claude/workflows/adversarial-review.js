export const meta = {
  name: 'adversarial-review',
  description: 'Split-context adversarial review of a Nova Wallet diff: scope, N blind reviewers, refutation panel, optional fixer',
  whenToUse: 'Before merging any Nova Wallet change. Mandatory for signing, extrinsics, fees, keystore, CoreData migrations, and XCM.',
  phases: [
    { title: 'Scope', detail: 'classify the diff and set the risk tier' },
    { title: 'Review', detail: 'blind reviewers, one lens each' },
    { title: 'Refute', detail: 'independent skeptics try to kill each finding' },
    { title: 'Fix', detail: 'single fixer applies survivors (only when fix: true)' },
  ],
}

// ---------------------------------------------------------------------------
// args: { target?: string, fix?: boolean, tier?: 'critical'|'standard'|'low' }
//   target — PR number, or 'local' (default) for git diff develop...HEAD
//   fix    — apply confirmed findings with a single fixer agent (default false)
//   tier   — force a tier; otherwise derived, and never below the path floor
// ---------------------------------------------------------------------------

const opts = args || {}
const target = opts.target || 'local'
// EVERY diff command excludes .claude/ — the design artefacts live there, and a
// reviewer that receives SPEC.md/CONTRACTS.md/PLAN.md inside a mandated command cannot decline
// them. .gitignore is layer 1; this is layer 2; the assertion below is layer 3.
const PATHSPEC = "-- . ':(exclude).claude/'"
const diffCmd =
  target === 'local'
    ? `git diff develop...HEAD ${PATHSPEC} (fall back to \`git diff ${PATHSPEC}\` if that is empty)`
    : `gh pr diff ${target} | grep -v '^+++ b/\\.claude/'  # and skip any .claude/ file section`

// The contamination prohibition, verbatim in every prompt that fetches or reads.
// It is not enough to put this in one agent definition: skeptics, scope and fixer
// are spawned by bare agent() calls that load no definition at all.
const NO_DESIGN_DOCS = `
NEVER read \`.claude/SPEC.md\`, \`.claude/CONTRACTS.md\`, \`.claude/PLAN.md\`, \`.claude/REVIEW-LOG.md\`,
\`.claude/design.excalidraw.json\`, the PR description, or commit messages describing intent.
Those are the author's reasoning, and it is exactly what made any bug in this diff look correct
while it was being written. A document stating that the behaviour was intended is NOT evidence that
the code is correct, and is NOT grounds to refute a finding. Read the code, the tests, and the
checklists under \`.claude/docs/review/\`.

If the diff you fetch contains any of those files, STOP and report contamination instead of
reviewing — do not attempt to read past them.`

// PR mode: the branch is not checked out and must not be. Reading the working
// tree there reviews the wrong code.
const PR_TREE_NOTE =
  target === 'local'
    ? ''
    : `

IMPORTANT — this is a PR review and the PR branch is NOT checked out. You must not check it out.
\`Read\` on the working tree gives you develop, not the change. To read a file whole as it stands
AFTER the change:

  gh pr view ${target} --json headRefName --jq .headRefName     # -> <branch>
  git fetch origin <branch>
  git show origin/<branch>:<path>

If \`git show\` fails, say so and mark every finding PLAUSIBLE rather than CONFIRMED.`

// Paths where a wrong-but-compiling change costs users money. The model may
// escalate the tier; it may never lower it below what these patterns imply.
const CRITICAL_PATTERNS = [
  /Sign(er|ing)/i, /Extrinsic/i, /Keystore/i, /Secret|Mnemonic|Seed|Derivation/i,
  /Migration|CoreData|\.xcdatamodel/i, /Fee|Amount|Balance/i, /Transfer|Xcm|CrossChain/i,
  /Swap|Exchange/i, /Proxy|Multisig|Delegat/i, /WalletConnect|DAppSigning/i,
]

const REVIEW_LENSES = [
  { key: 'correctness', why: 'wrong values, wrong payload, wrong account, swallowed failures' },
  { key: 'lifecycle', why: 'leaks, dangling subscriptions, callbacks after teardown, threading' },
  { key: 'contract', why: 'missing peer files, migrations, tests, feature-area coverage' },
]

const REVIEWERS_BY_TIER = { critical: 3, standard: 2, low: 1 }
const SKEPTICS_BY_TIER = { critical: 2, standard: 2, low: 1 }
const MAX_VERIFIED = 5

const SCOPE_SCHEMA = {
  type: 'object',
  required: ['files', 'summary', 'tier', 'tierReason'],
  properties: {
    files: { type: 'array', items: { type: 'string' }, description: 'repo-relative paths changed' },
    summary: { type: 'string', description: 'what the change does, 3 sentences max, mechanism not intent' },
    tier: { type: 'string', enum: ['critical', 'standard', 'low'] },
    tierReason: { type: 'string' },
    areas: { type: 'array', items: { type: 'string' }, description: 'e.g. staking, governance, swaps, dapp' },
  },
}

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['findings', 'readButClean'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'file', 'line', 'summary', 'failureScenario', 'fix', 'rule', 'confidence'],
        properties: {
          severity: { type: 'string', enum: ['blocking', 'major', 'minor'] },
          file: { type: 'string' },
          line: { type: 'integer' },
          summary: { type: 'string', description: 'one sentence stating the defect' },
          failureScenario: { type: 'string', description: 'concrete inputs -> wrong result' },
          fix: { type: 'string' },
          rule: { type: 'string', description: 'checklist section, or why the checklists miss it' },
          confidence: { type: 'string', enum: ['CONFIRMED', 'PLAUSIBLE'] },
        },
      },
    },
    readButClean: { type: 'array', items: { type: 'string' } },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['refuted', 'reasoning'],
  properties: {
    refuted: { type: 'boolean', description: 'true if the finding does not hold' },
    reasoning: { type: 'string' },
    correctedSeverity: { type: 'string', enum: ['blocking', 'major', 'minor', 'none'] },
  },
}

// --- Phase 0: contamination assertion -------------------------------------
// Layers 1 and 2 prevent the leak; this is what stops it failing SILENTLY, which
// is the difference between a bug and a false guarantee.

phase('Scope')

const GUARD_SCHEMA = {
  type: 'object',
  required: ['contaminated', 'evidence'],
  properties: {
    contaminated: { type: 'boolean', description: 'true if any design artefact appears in the diff' },
    evidence: { type: 'string', description: 'the offending paths, or a statement that none appeared' },
  },
}

const guard = await agent(
  `Run exactly this and report what it lists — do not read the file contents:

    ${target === 'local' ? "git diff develop...HEAD --name-only" : `gh pr diff ${target} --name-only`}

Set contaminated=true if ANY of these appear: .claude/SPEC.md, .claude/CONTRACTS.md, .claude/PLAN.md,
.claude/REVIEW-LOG.md, .claude/design.excalidraw.json — or any other file under .claude/ that
carries design reasoning. Otherwise contaminated=false. List the paths you saw under .claude/.`,
  { label: 'contamination-guard', schema: GUARD_SCHEMA, effort: 'low' },
)

if (guard && guard.contaminated) {
  log(`ABORTED — design artefacts are present in this diff: ${guard.evidence}`)
  return {
    error: 'contaminated-diff',
    detail: guard.evidence,
    remedy:
      'The design artefacts were committed on this branch. A blind review is impossible while they ' +
      'are in the diff. Remove them from the branch (they belong in .gitignore — see ' +
      '.claude/docs/process/design-loop.md > Files), then re-run. Do NOT proceed by asking the ' +
      'reviewers to ignore them; that is the guarantee this check exists to stop being notional.',
  }
}

const scope = await agent(
  `Get the Nova Wallet diff with: ${diffCmd}

List every repo-relative file path it changes. Summarise what the change does MECHANICALLY — which
types, layers, and call paths move — not what it is trying to achieve. Do not read .claude/PLAN.md
or the PR description; describe only what the code does.

${NO_DESIGN_DOCS}

Classify the risk tier:
- critical — touches signing, extrinsic construction, fee or amount arithmetic, keystore/secrets,
  CoreData migrations, XCM or cross-chain transfers, swaps, or delegated-wallet resolution. Anything
  where a wrong-but-compiling change can move or expose user funds.
- standard — app logic, services, data flow, subscriptions, persistence that is not a schema change.
- low — layout, copy, localization, assets, comments, tests only.

Name which feature areas are touched (staking, governance, swaps, dapp, push, wallets, none).`,
  { label: 'scope', schema: SCOPE_SCHEMA, agentType: 'nova-adversarial-reviewer', effort: 'low' },
)

if (!scope) {
  log('Scope agent returned nothing — aborting. Check that the diff target exists.')
  return { error: 'scope-failed', target }
}

const RANK = { low: 0, standard: 1, critical: 2 }
const pathFloor = (scope.files || []).some((f) => CRITICAL_PATTERNS.some((p) => p.test(f)))
  ? 'critical'
  : null
// --tier can only RAISE. A caller-supplied tier that is lower than the derived one
// is ignored — /nova-review documents the tier as "can only be raised, never
// lowered", and that has to be true in the code, not just in the prose.
const derivedTier = scope.tier || 'standard'
let tier = derivedTier
let tierReason = scope.tierReason
if (opts.tier) {
  if (RANK[opts.tier] > RANK[derivedTier]) {
    tier = opts.tier
    tierReason = `raised to ${opts.tier} by --tier (derived: ${derivedTier}, "${scope.tierReason}")`
  } else if (RANK[opts.tier] < RANK[derivedTier]) {
    log(`--tier ${opts.tier} IGNORED: below the derived tier ${derivedTier}. The tier can only be raised.`)
  }
}
if (pathFloor && RANK[tier] < RANK.critical) {
  const hit = scope.files.find((f) => CRITICAL_PATTERNS.some((p) => p.test(f)))
  log(`Tier raised ${tier} -> critical by path floor: ${hit}`)
  tierReason = `path floor — ${hit} matches a funds-critical pattern (was: ${tier}, "${scope.tierReason}")`
  tier = 'critical'
}

const reviewerCount = REVIEWERS_BY_TIER[tier]
const skepticCount = SKEPTICS_BY_TIER[tier]
const lenses = REVIEW_LENSES.slice(0, reviewerCount)

log(`${scope.files.length} files | tier: ${tier} (${tierReason}) | ${reviewerCount} reviewers, ${skepticCount} skeptics per finding`)
if (reviewerCount < REVIEW_LENSES.length) {
  const skipped = REVIEW_LENSES.slice(reviewerCount).map((l) => l.key).join(', ')
  log(`Lenses NOT run at this tier: ${skipped}. Re-run with tier:'critical' to cover them.`)
}

// --- Phases 2+3: review, each finding refuted as soon as it lands ----------

phase('Review')

const reviewed = await pipeline(
  lenses,

  // Stage 1 — a blind reviewer. Fresh context: it never sees the implementer's
  // reasoning, and it fetches the diff itself rather than being handed a summary.
  (lens) =>
    agent(
      `Review the Nova Wallet diff under the "${lens.key}" lens (${lens.why}).

Fetch the diff yourself: ${diffCmd}${PR_TREE_NOTE}

You are the nova-adversarial-reviewer. Follow that agent definition exactly: assume the code is
wrong and prove it, read whole files rather than hunks, never read .claude/PLAN.md or the PR
description, never modify the working tree.

Risk tier for this change: ${tier}. Areas touched: ${(scope.areas || []).join(', ') || 'unclassified'}.

Every finding must carry concrete inputs and the wrong result they produce. If you cannot state
those, discard the finding. Returning zero findings is a valid outcome — do not manufacture filler.
Also list what you examined under this lens and found sound, so coverage can be told from silence.`,
      { label: `review:${lens.key}`, phase: 'Review', agentType: 'nova-adversarial-reviewer', schema: FINDINGS_SCHEMA },
    ),

  // Stage 2 — refute. Skeptics are independent and default to refuted.
  (review, lens) => {
    if (!review) {
      log(`[${lens.key}] reviewer returned nothing — THIS LENS DID NOT RUN. Not a clean result.`)
      return { lens: lens.key, failed: true, verified: [], killed: [], unverified: [], minor: [], clean: [] }
    }
    if (!review.findings || review.findings.length === 0) {
      return { lens: lens.key, verified: [], minor: [], clean: review.readButClean || [] }
    }

    const worthVerifying = review.findings.filter((f) => f.severity !== 'minor')
    const minor = review.findings.filter((f) => f.severity === 'minor')
    const batch = worthVerifying.slice(0, MAX_VERIFIED)

    if (worthVerifying.length > MAX_VERIFIED) {
      log(`[${lens.key}] ${worthVerifying.length} non-minor findings, verifying the first ${MAX_VERIFIED}. ${worthVerifying.length - MAX_VERIFIED} reported unverified.`)
    }

    return parallel(
      batch.map((f) => () =>
        parallel(
          Array.from({ length: skepticCount }, (_, i) => () =>
            agent(
              `Refute this review finding about the Nova Wallet codebase. You are skeptic ${i + 1}; another skeptic is working independently, so do not assume a consensus.

FINDING (${f.severity}) ${f.file}:${f.line}
${f.summary}

Claimed failure: ${f.failureScenario}
Claimed rule broken: ${f.rule}
Proposed fix: ${f.fix}

Read the actual code at that location and everything the claim depends on. Then decide whether the
finding HOLDS or is REFUTED. Refute it if any of these are true:

- The failure scenario cannot actually be reached (guarded upstream, unreachable state, the caller
  already validates it, the type makes it impossible).
- The claim misreads the code — the value, ownership, threading, or lifetime is not what it says.
- The behaviour is pre-existing and untouched by this diff.
- It is a preference with no behavioural consequence and no checklist rule behind it.
- The proposed fix would not change the outcome.

Do NOT refute merely because the defect is unlikely, cosmetic in most cases, or "probably fine in
practice". Reachable-but-rare still holds — this is a wallet.
${NO_DESIGN_DOCS}${PR_TREE_NOTE}

Default to refuted=true when you genuinely cannot verify the claim from the code. State what you
read. If it holds but the severity is wrong, set correctedSeverity.`,
              { label: `refute:${f.file.split('/').pop()}#${i + 1}`, phase: 'Refute', agentType: 'nova-adversarial-reviewer', schema: VERDICT_SCHEMA },
            ),
          ),
        ).then((votes) => {
          const real = votes.filter(Boolean)
          const holds = real.filter((v) => !v.refuted).length
          // No surviving skeptic is NOT a refutation — nobody looked. Carry the
          // finding through as unverified rather than silently killing it.
          const unjudged = real.length === 0
          const survives = unjudged ? true : holds * 2 >= real.length
          const corrected = real.map((v) => v.correctedSeverity).filter((s) => s && s !== 'none')
          return {
            ...f,
            severity: corrected.length ? corrected[0] : f.severity,
            survives,
            unjudged,
            votes: unjudged ? 'NOT VERIFIED — every skeptic failed' : `${holds}/${real.length} hold`,
            refutations: real.filter((v) => v.refuted).map((v) => v.reasoning),
          }
        }),
      ),
    ).then((judged) => ({
      lens: lens.key,
      verified: judged.filter(Boolean).filter((f) => f.survives),
      killed: judged.filter(Boolean).filter((f) => !f.survives),
      unverified: worthVerifying.slice(MAX_VERIFIED),
      minor,
      clean: review.readButClean || [],
    }))
  },
)

const results = reviewed.filter(Boolean)
const SEV = { blocking: 0, major: 1, minor: 2 }
const confirmed = results
  .flatMap((r) => r.verified || [])
  .sort((a, b) => SEV[a.severity] - SEV[b.severity])
const killed = results.flatMap((r) => r.killed || [])
const unverified = results.flatMap((r) => r.unverified || [])
const minor = results.flatMap((r) => r.minor || [])

log(`${confirmed.length} confirmed, ${killed.length} refuted by the panel, ${unverified.length} unverified, ${minor.length} minor`)

// --- Phase 4: fix (opt-in, single agent — no parallel mutation) ------------

let fixReport = null
if (opts.fix && confirmed.length > 0) {
  phase('Fix')
  fixReport = await agent(
    `Apply these confirmed review findings to the Nova Wallet codebase. They survived an independent
refutation panel, so treat them as real.

${confirmed.map((f, i) => `${i + 1}. [${f.severity}] ${f.file}:${f.line} — ${f.summary}
   Failure: ${f.failureScenario}
   Fix: ${f.fix}`).join('\n\n')}

Rules:
- Fix ONLY these findings. No refactors, no drive-by improvements, no reformatting.
- Read the whole file before editing it.
- Follow .claude/docs/ conventions — Operation-iOS wrappers (no async/await), no force unwraps,
  localized strings, VIPER layer boundaries.
- Update peer files the fix implies: Protocols.swift, ViewFactory, Cuckoo mocks, tests.
- Do NOT run git stash, reset, checkout, or commit. Leave the changes in the working tree.
- Do NOT run the full test suite; it is slow. Targeted tests only, if any apply.

Report per finding: fixed / skipped (with the reason) / no change needed.`,
    { label: 'fixer', phase: 'Fix', agentType: 'nova-adversarial-reviewer' },
  )
  log('Fixer edits are UNREVIEWED. Re-run this workflow without fix over the new working tree before merge.')
}

return {
  target,
  tier,
  tierReason,
  summary: scope.summary,
  filesChanged: scope.files.length,
  lensesRun: lenses.map((l) => l.key),
  confirmed,
  refuted: killed.map((f) => ({ file: f.file, summary: f.summary, votes: f.votes, why: f.refutations })),
  unverified,
  minor,
  coverage: results.flatMap((r) => r.clean || []),
  failedLenses: results.filter((r) => r.failed).map((r) => r.lens),
  fixReport,
  needsRereview: Boolean(fixReport),
}
