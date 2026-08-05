# Testing

Two test targets, XCTest, Cuckoo for mocks.

| Target                        | Runs in PR CI | Purpose                                             |
|-------------------------------|---------------|-----------------------------------------------------|
| `novawalletTests`             | yes           | Unit tests — presenters, factories, mappers, helpers |
| `novawalletIntegrationTests`  | no            | Live chain/backend tests, run manually               |

PR CI runs `bundle exec fastlane run_unit_tests`, which builds and tests the `novawallet` scheme.

## Layout

```
novawalletTests/
  Modules/<same shape as novawallet/Modules>/   # module tests mirror the source tree
  Common/                                       # tests for Common/ subsystems
  Helper/                                       # generators and test facades
  Mocks/                                        # hand-written stubs + generated Cuckoo mocks
  Resources/, KeystoreDefinition/               # fixtures (keystore JSONs, runtime metadata)
  Constants.swift                               # shared test constants
```

New tests go in the folder mirroring the file under test. Do not create a parallel structure.

## Helpers & Fixtures

`novawalletTests/Helper/`:

| Helper                          | Provides                                             |
|---------------------------------|------------------------------------------------------|
| `ChainModelGenerator`           | Synthetic `ChainModel`/`AssetModel` (staking flags, precision, prefix) |
| `AccountGenerator`, `AccountCreationHelper` | Wallets and chain accounts, real keystore entries |
| `SubstrateStorageTestFacade`, `UserDataStorageTestFacade` | In-memory CoreData stores    |
| `RuntimeHelper`, `WestendStub`  | Real runtime metadata + coder factories for decoding tests |
| `AssetTransactionGenerator`     | Transaction history fixtures                          |
| `WalletsFetchHelper`, `CloudBackupFetchHelper` | Query helpers over the test stores     |
| `AnyProviderAutoCleaner`        | Provider cleanup in teardown                          |

Use these instead of building fixtures inline — they keep tests consistent and short.

## Cuckoo Mocks

Protocol mocks are **generated** from `Cuckoofile.toml` (root) into
`novawalletTests/Mocks/ModuleMocks.swift` and `CommonMocks.swift`, and are checked in.

```toml
[modules.NovaModules]
imports = ["Foundation", "Foundation_iOS", "Keystore_iOS", "SubstrateSdk"]
testableImports = ["novawallet"]
sources = [ "novawallet/.../SomeProtocols.swift", ... ]
exclude = [ "SomeViewFactoryProtocol", ... ]
```

**When you add a protocol that a test needs to mock, add its file to `sources` and regenerate.**
`ViewFactory` protocols are excluded (they are static factories, not injectable seams).

Typical usage:

```swift
let view = MockStakingUnbondSetupViewProtocol()
let wireframe = MockStakingUnbondSetupWireframeProtocol()

stub(view) { stub in
    when(stub.didReceiveInput(viewModel: any())).then { _ in expectation.fulfill() }
    when(stub.didReceiveFee(viewModel: any())).thenDoNothing()
}
```

Every method a test path touches must be stubbed — an unstubbed Cuckoo call traps. Hand-written
stubs exist for things Cuckoo cannot express well: `ChainRegistryStub`, `ExtrinsicServiceStub`,
`SigningWrapperFactoryStub`, `CurrencyManagerStub`, `ExtrinsicSenderResolutionStub`,
`TestSecretStoreManager`, `TestJSONRPCEngine`. Prefer extending an existing stub over forking one.

## Test Shape

```swift
class SomeTests: XCTestCase {
    func testSomething() throws {
        // given
        let view = MockSomeViewProtocol()
        let wireframe = MockSomeWireframeProtocol()

        // when
        let presenter = try setupPresenter(for: view, wireframe: wireframe)
        let expectation = XCTestExpectation()
        stub(view) { ... }

        presenter.proceed()

        // then
        wait(for: [expectation], timeout: 10.0)
    }
}
```

Conventions:

- `// given` / `// when` / `// then` section comments — used consistently across the suite.
- Presenter tests drive the real Presenter with mocked view/wireframe and a real-ish Interactor built
  on in-memory storage facades.
- Async assertions use `XCTestExpectation` + `wait(for:timeout:)`. **No `sleep()`**.
- `Constants.defaultExpectationDuration` for short waits; longer explicit timeouts where operations
  are involved.
- The app skips its whole launch sequence when the `-UNITTEST` argument is present
  (`AppDelegate.isUnitTesting`), so tests never hit the real Root flow.

## What to Test

| Layer                            | Test it because…                                    |
|----------------------------------|-----------------------------------------------------|
| Presenters                       | View-model assembly and wireframe routing are the app's logic |
| Operation factories / services   | Wrapper composition and error propagation             |
| CoreData mappers                 | Round-trip fidelity and corrupt-data throwing        |
| Reward/fee/balance maths         | Silent numeric regressions are expensive              |
| Migrations                       | Data loss is unrecoverable                            |
| Parsing (SCALE, JSON, QR, links) | Format drift                                          |

Every behaviour change in a module with existing tests must update those tests — Presenter and
mapper suites are the usual peers.

## Integration Tests

`novawalletIntegrationTests/` hits real nodes and backends: chain registry setup, extrinsic
construction, storage/state calls, staking calculators, swaps routing, XCM transfers, NFT sync,
governance fetching, cloud backup.

- They are slow and network-dependent; not part of PR CI. Run the relevant file locally when you
  change chain interaction.
- `ChainRegistry+Setup.swift` builds a real registry for these tests.
- Any change to reward maths, exchange routing, XCM, or runtime-call factories should be validated
  against the matching integration test (`CalculatorServiceTests`, `AssetsExchangeTests`,
  `XcmTransfers`, `StateCall`, …).

## Hard Rules

1. **Mirror the source tree** when placing a test file.
2. **Reuse the generators and shared stubs**; no ad-hoc fixture duplication.
3. **Regenerate Cuckoo mocks** and update `Cuckoofile.toml` when protocols change.
4. **No `sleep()`, no arbitrary delays.** Expectations only.
5. **In-memory storage facades** for anything touching CoreData — never the real store.
6. **Update tests in the same PR as the behaviour change.**

## Related

- code/build-and-tooling.md — how to run the suites
- code/migrations.md — why migration tests matter
