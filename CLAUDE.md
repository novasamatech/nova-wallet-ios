# CLAUDE.md

Nova Wallet iOS. This file is a router only — read the doc that matches the task before doing
anything else. Docs live in `.claude/docs/`.

**Start here if you have no context:** [.claude/docs/architecture/overview.md](.claude/docs/architecture/overview.md)
**Full index and glossary:** [.claude/docs/README.md](.claude/docs/README.md)

## Read This For That

| Task                                                             | Read                                                    |
|------------------------------------------------------------------|---------------------------------------------------------|
| Orienting in the codebase, stack, targets, launch sequence        | `.claude/docs/architecture/overview.md`                 |
| New screen or flow; changing a VIPER layer; module structure      | `.claude/docs/architecture/viper.md`                    |
| Deciding where a new file/type belongs                            | `.claude/docs/code/project-layout.md`                   |
| Chains, node connections, runtime metadata, sync modes            | `.claude/docs/architecture/chain-registry.md`           |
| App startup, `ServiceCoordinator`, background/sync services, config | `.claude/docs/architecture/services-lifecycle.md`      |
| Local subscriptions, data providers, remote subscriptions, `EventCenter` | `.claude/docs/architecture/data-flow.md`          |
| Wallets, accounts, keystore, signing, proxy/multisig, backup      | `.claude/docs/architecture/wallets-accounts.md`         |
| Extrinsics, fees, validation, submission tracking, transfers, XCM | `.claude/docs/architecture/transactions.md`             |
| Staking (relaychain, pools, parachain, Mythos), rewards, eras     | `.claude/docs/architecture/staking.md`                  |
| Governance, referenda, voting, delegation, locks, SwipeGov        | `.claude/docs/architecture/governance.md`               |
| Swaps, exchange graph, Hydration, AssetHub, cross-chain routing   | `.claude/docs/architecture/swaps-exchange.md`           |
| DApp browser, JS bridges, WalletConnect, dApp signing             | `.claude/docs/architecture/dapp-walletconnect.md`       |
| Push notifications, Firebase, notification extension              | `.claude/docs/architecture/push-notifications.md`       |
| Any async work: operations, wrappers, cancellation, queues        | `.claude/docs/code/concurrency.md`                      |
| CoreData, repositories, mappers, `SettingsManager`, keychain      | `.claude/docs/code/data-persistence.md`                 |
| Changing a CoreData model, settings, or keystore layout           | `.claude/docs/code/migrations.md`                       |
| JSON-RPC, storage queries, runtime calls, HTTP, EVM RPC           | `.claude/docs/code/networking.md`                       |
| Building views, layout, colors, fonts, styles, cells, view models | `.claude/docs/code/ui-uikit.md`                         |
| Wireframes, presentables, sheets, deep links, tab bar             | `.claude/docs/code/navigation.md`                       |
| Strings, locale handling, formatting amounts and dates            | `.claude/docs/code/localization.md`                     |
| Errors, validation runners, logging                               | `.claude/docs/code/error-handling.md`                   |
| Naming, comments, file size, lint/format rules                    | `.claude/docs/code/naming-and-hygiene.md`               |
| Writing or fixing tests, Cuckoo mocks, integration tests          | `.claude/docs/code/testing.md`                          |
| Build commands, configurations, flags, codegen, CI, dependencies  | `.claude/docs/code/build-and-tooling.md`                |
| Reviewing a PR — structure and mechanism                          | `.claude/docs/review/architecture-checklist.md`         |
| Reviewing a PR — line by line                                     | `.claude/docs/review/code-checklist.md`                 |
| How the design agents talk, argue, and escalate                   | `.claude/docs/process/design-loop.md`                   |

## How To Work

The table above routes knowledge. This one routes process — invoke these, don't reimplement them.

| Situation                                                      | Invoke          |
|----------------------------------------------------------------|-----------------|
| Designing a non-trivial feature — requirements, contracts, edge cases | `/nova-spec` |
| Turning an approved spec into an implementation plan            | `/nova-plan`    |
| Reviewing a diff or PR before merge                             | `/nova-review`  |
| Signing, extrinsics, fees, keystore, migrations, XCM            | `/nova-review` — not optional |

`/nova-spec` → **you approve** → `/nova-plan` → **you approve** → implement → `/nova-review`. The two
approval gates are hard: neither command proceeds past its own artefact. The protocol the design
agents follow is [.claude/docs/process/design-loop.md](.claude/docs/process/design-loop.md).

**Never review your own diff in the session that wrote it.** Review runs in a fresh context that
sees the diff and the checklists, not the reasoning that produced the diff. The reasoning is what
made the bug look right in the first place. For the same reason the diff reviewers never read
`.claude/SPEC.md`, `.claude/PLAN.md`, `.claude/REVIEW-LOG.md`, or `.claude/design.excalidraw.json` —
that reasoning, written down. All four are gitignored so they cannot reach a reviewer through the
diff itself.

A review finding must name a concrete failure scenario — inputs, and the wrong result they produce.
A finding that cannot do that is a preference, not a defect; drop it.
