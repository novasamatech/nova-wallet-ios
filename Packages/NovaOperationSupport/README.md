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

Delete this package when the Operation-iOS pin moves to a release that ships these types.
Its consumers then drop `.package(path: "../NovaOperationSupport")` and their
`import NovaOperationSupport` lines, and everything else stays as written — the SDK versions
are identical in behaviour, only `public`.
