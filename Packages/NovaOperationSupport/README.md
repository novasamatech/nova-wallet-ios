# NovaOperationSupport

A temporary mirror of the operation helpers the app declares in `novawallet/Common/Operation/`
and `novawallet/Common/Extension/Operation/`, so that local packages pinned to the same
Operation-iOS `2.1.2` the app pins can compile against them.

`OperationCombiningService`, the `Longrun` primitives and the `CompoundOperationWrapper`
conveniences (`createWithError`, `createWithResult`, `addDependency`, `insertingHead`,
`insertingTail`) are absent from Operation-iOS `2.1.2`. Both `NovaAppAttest` and, next,
`NovaAnalytics` are built out of them, so without this package the same file would be copied
into each of them.

## Why this package has no tests

Its single source file is a verbatim mirror of app code that the app's own suite already
exercises — nothing here is new logic, and there is nothing to specify that the app does not
already specify. Tests written against a copy would only pin the copy, and would go stale in
the one direction that matters: if the mirror ever drifts from the original, tests of the
mirror still pass.

What guards this package instead is the rule stated in `OperationSupport.swift`'s header:
every member present is byte-identical to its app original, so `diff` against the app files
is the check. `NovaAppAttest`'s and `NovaAnalytics`' own suites cover the behaviour through
their use of it.

## Lifetime

These helpers already ship in Operation-iOS **2.5.0**, including
`compoundNonOptionalWrapper(operationQueue:)` in `OperationCombiningService+Init.swift` —
nothing here needs upstreaming. What blocks the bump is transitive: `substrate-sdk-ios` 4.5.2
declares `.package(url: "https://github.com/novasamatech/Operation-iOS", exact: "2.1.2")` in
its own `Package.swift`, and because that is an `exact:` pin rather than a range, there is no
overlap and SwiftPM refuses to resolve any other Operation-iOS version app-wide. **5.7.3** is
the earliest substrate-sdk tag that permits 2.5.0.

The trigger is the substrate-sdk v5 migration (local branch `tech/substrate-sdk-v5`, which pins
substrate-sdk 5.10.0, Operation-iOS 2.5.0, Keystore-iOS 1.1.0 and Foundation-iOS 1.5.0).
`NovaAppAttest` (55 tests) and `NovaAnalytics` (106 tests) both already pass against
Operation-iOS 2.5.0 with zero failures, and no package call site needs to change.

When that migration lands, delete this package **and** the app's own copies —
`novawallet/Common/Operation/OperationCombiningService.swift`, `Common/Operation/Longrun/*`,
and `Common/Extension/Operation/CompoundOperationWrapper+{Result,Dependency,Add}.swift` —
since otherwise the app's extensions collide with the SDK's identically-named ones. Two
members have no 2.5.0 equivalent and must be kept on the app side:
`addDependencyIfExists(wrapper:)` and `insertingHeadIfExists(operations:)`. Consumers then
drop `.package(path: "../NovaOperationSupport")` and their `import NovaOperationSupport`
lines, and everything else stays as written — the SDK versions are identical in behaviour,
only `public`.
