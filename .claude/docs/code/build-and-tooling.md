# Build, Tooling & CI

## Prerequisites

```bash
brew bundle          # mint, brew-gem
mint bootstrap       # SwiftLint 0.59.1, SwiftFormat 0.47.13, Sourcery 2.3.0
bundle install       # fastlane
gem install generamba # VIPER module scaffolding
```

Open `novawallet.xcodeproj` — the `.xcworkspace` in the repo has no contents and is not the build
entry point. Dependencies are resolved by SPM from the project.

Deployment target iOS 16.0; Swift language version 5.0.

## Build & Test

```bash
set -o pipefail && xcodebuild -project novawallet.xcodeproj -scheme novawallet \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | xcbeautify --quiet
```

Targeted tests first — the full suite is slow:

```bash
set -o pipefail && xcodebuild test -project novawallet.xcodeproj -scheme novawallet \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:novawalletTests/StakingUnbondSetupTests 2>&1 | xcbeautify --quiet
```

Full unit suite (what CI runs):

```bash
bundle exec fastlane run_unit_tests
```

Integration tests are a separate scheme and are **not** part of CI:

```bash
set -o pipefail && xcodebuild test -project novawallet.xcodeproj -scheme novawalletIntegrationTests \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcbeautify --quiet
```

Schemes: `novawallet`, `novawalletIntegrationTests`, `NovaPushNotificationServiceExtension`.
Test device in CI is iPhone 16 (`fastlane/Scanfile`).

### Local Package Suites

`NovaAnalytics` and `NovaAppAttest` sources import UIKit/CoreData/DeviceCheck and every SDK
dependency is iOS-only, so `swift test` builds for macOS and fails — test them through
`xcodebuild` against a simulator destination instead. `NovaOperationSupport` has no test target
(it mirrors app-only helper code — see project-layout.md); build it rather than testing it.

```bash
(cd Packages/NovaAppAttest && RUN_IN_CI=true xcodebuild test -scheme NovaAppAttest \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/dd-NovaAppAttest)
(cd Packages/NovaAnalytics && RUN_IN_CI=true xcodebuild test -scheme NovaAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/dd-NovaAnalytics)
(cd Packages/NovaOperationSupport && RUN_IN_CI=true xcodebuild build -scheme NovaOperationSupport \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/dd-NovaOperationSupport)
```

Pin `-derivedDataPath` outside the shared DerivedData folder used by the app build.

## Build Configurations

Four configurations, each with an xcconfig in `novawallet/Configs/`:

| Configuration | Swift flags                                     | App name           | Bundle id                            |
|---------------|--------------------------------------------------|--------------------|--------------------------------------|
| `Debug`       | `ENABLE_UITUNNEL`, `F_DEV`, `F_APPCHECK_DEBUG`   | Nova Dev           | `io.novafoundation.novawallet.dev`   |
| `Dev`         | `F_DEV`                                          | Nova Dev           | `io.novafoundation.novawallet.dev`   |
| `Staging`     | `F_RELEASE`                                      | Nova Early Access  | `io.novafoundation.novawallet.staging` |
| `Release`     | `F_RELEASE`                                      | Nova               | `io.novafoundation.novawallet`       |

Flag semantics in code:

- `#if F_RELEASE` — production behaviour: hide testnets, restrict delegated-account discovery to
  non-watch-only wallets, `.info` log level.
- `#if F_DEV` — development affordances and `.verbose` logging.
- `#if F_APPCHECK_DEBUG` — Firebase App Check debug provider.
- `#if DEBUG` — standard Xcode debug flag.

Gate temporary behaviour behind these at the **factory/registration** level, not with early returns
inside a feature (see architecture/services-lifecycle.md).

## Code Generation & Build Phases

Build phases on the app target, in order:

| Phase                         | Script                          | Notes                                            |
|-------------------------------|----------------------------------|--------------------------------------------------|
| Firebase plist selection      | inline                           | Copies `GoogleService-Info-Dev/Release.plist` → `GoogleService-Info.plist` per configuration |
| SwiftLint                     | `Scripts/lint.sh`                | Skipped when `RUN_IN_CI=true`                     |
| SwiftFormat                   | `Scripts/format.sh`              | Skipped when `RUN_IN_CI=true`                     |
| Sourcery key injection        | `Scripts/inject-keys.sh`         | Generates `CIKeys.generated.swift` from `novawallet/env-vars.sh` or CI env |
| R.swift                       | `RswiftGenerateInternalResources` SPM plugin | Generates `R.generated.swift` for app and extension |

Generated files (`R.generated.swift`, `CIKeys.generated.swift`) are committed but must never be
hand-edited.

Cuckoo mocks (`novawalletTests/Mocks/ModuleMocks.swift`, `CommonMocks.swift`) are generated from
`Cuckoofile.toml` and also committed — regenerate when protocol sources change
(see code/testing.md).

## Scaffolding

```bash
./generamba-module.sh ModuleName
```

Generates the 7-file VIPER module under `novawallet/Modules/` plus a test stub under
`novawalletTests/Modules/`, from `Templates/viper-code-layout/` (paths configured in `Rambafile`).

## Lint & Format Manually

```bash
Scripts/lint.sh
Scripts/format.sh
```

Both run pinned versions through Mint, so results match CI and the build phases.

## Dependencies

Mostly SPM, remote — plus three local packages under `Packages/`: `NovaAnalytics`,
`NovaAppAttest`, and `NovaOperationSupport` (see project-layout.md). Versions are pinned in
one place, `novawallet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`,
which also carries `logger-ios`, added when the local packages arrived. Testing a package on
its own makes it write a `Packages/<Name>/Package.resolved`; those are git-ignored
(`.gitignore:60-65`) and must not be committed — a package manifest pins exact versions, so
a second resolved file adds nothing but a way for the two to disagree.

Core (novasama-maintained):

| Package                  | Version | Role                                        |
|--------------------------|---------|---------------------------------------------|
| `substrate-sdk-ios`      | 4.5.2   | Substrate RPC, SCALE, runtime, extrinsics   |
| `Operation-iOS`          | 2.1.2   | Operations, providers, repositories, network |
| `Foundation-iOS`         | 1.2.0   | Localization, common foundation utilities    |
| `UIKit-iOS`              | 1.1.3   | UI primitives, modal presentation            |
| `Keystore-iOS`           | 1.0.1   | Keychain + `SettingsManager`                 |
| `Crypto-iOS` (NovaCrypto) | 0.4.1  | Keypairs, signing, mnemonics                 |
| `metadata-shortener-ios` | 0.2.1   | Metadata hash for hardware signing           |
| `hydra-math-swift`       | 0.5.0   | Hydration pool maths                         |
| `logger-ios`             | 0.0.1   | `SDKLogger`, used by the app + local packages |
| `WalletConnectSwiftV2`   | 1.9.9   | WalletConnect (fork)                         |
| `web3swift`              | 3.3.1   | EVM (fork)                                   |
| `Starscream`             | 4.0.13  | WebSocket (fork)                             |

Third-party: `SnapKit` 5.0.1, `Kingfisher` 6.3.0, `SwiftyBeaver` 2.1.1, `R.swift` 7.8.0,
`Cuckoo` 2.1.1, `Charts` 5.1.0 (DGCharts), `lottie-spm` 4.5.2, `SwiftDraw` 0.18.0,
`firebase-ios-sdk` 11.3.0, `BigInt` 5.5.1, `CryptoSwift` 1.9.0, `QRCode` 18.6.0,
`Reachability.swift` 5.2.4, `CDMarkdownKit` 2.5.2, `ZMarkupParser` 1.6.1,
`ios-branch-sdk-spm` 3.10.0, `swift-algorithms` 1.2.1, `EthereumSignTypedDataUtil` 0.1.3,
`SwiftRLP` 1.2.0.

Bumping a dependency touches `project.pbxproj` **and** `Package.resolved` — both belong in the diff.

## CI/CD

GitHub Actions (`.github/workflows/`), runners `macos-26`, Xcode 26.2, shared setup in
`.github/actions/install` (Mint cache, Scaleway secrets, SPM cache, Google plist).

| Workflow                | Trigger              | Does                                                    |
|-------------------------|----------------------|---------------------------------------------------------|
| `pull_request.yml`      | PR                   | `build_app_ci` + `run_unit_tests`                       |
| `push_develop.yml`      | push to `develop`    | Builds `Dev` and distributes to Firebase (`dev-team`)   |
| `bump_version.yml`      | manual/tagging       | Version bump                                            |
| `update_signing_data.yml` | manual             | `fastlane update_signing` (match)                        |
| `pr_workflow.yml`       | PR to `main`         | Maintains the release-notes comment on the PR            |

`RUN_IN_CI=true` disables the lint/format build phases in CI (they run as their own concern) —
so lint failures show locally, not on the CI build.

Fastlane lanes (`fastlane/Fastfile` + `fastlane/lanes/`):

| Lane                         | Purpose                                        |
|------------------------------|------------------------------------------------|
| `run_unit_tests`             | `scan` over the `novawallet` scheme, Debug     |
| `build_app_ci`               | Signed CI build                                |
| `distribute_app_to_firebase` | Build + Firebase App Distribution              |
| `distribute_testflight`      | Build Release + upload to TestFlight           |
| `update_signing`             | Refresh match certificates/profiles            |

Signing uses fastlane `match`; secrets come from Scaleway secret manager, not from the repo.

## Secrets

Third-party keys (Mercuryo, Acala, Moonbeam, Etherscan, Infura, WalletConnect, Dwellir,
Polkassembly) are injected by Sourcery from `novawallet/env-vars.sh` (local) or CI env vars into
`CIKeys.generated.swift`. Adding a key means editing `Scripts/inject-keys.sh`, the Sourcery template
in `novawallet/SourceryTemplates/`, and the CI secret list — never committing the value.

## Hard Rules

1. **Build the project, not the workspace.**
2. **Run targeted tests during development**; the full suite before handoff.
3. **Never hand-edit generated files.**
4. **Configuration-specific behaviour goes through xcconfig flags**, not runtime checks on bundle id.
5. **Dependency bumps include `Package.resolved`.**
6. **No secrets in the repo.** Sourcery + CI secret store only.

## Related

- code/testing.md — what the suites cover
- code/project-layout.md — the generated-files list
