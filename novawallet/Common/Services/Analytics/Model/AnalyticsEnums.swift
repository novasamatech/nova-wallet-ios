import Foundation

// The ten enums below carry raw values transcribed verbatim from
// `analytics/src/main/java/io/novafoundation/nova/analytics/AnalyticsEvent.kt`.

enum AssetCategory: String, AnalyticsPropertyConvertible {
    case nativeToken = "native_token"
    case stablecoin
    case wrappedToken = "wrapped_token"
    case other
}

enum WalletCreationMethod: String, AnalyticsPropertyConvertible {
    case create
    case importMnemonic = "import_mnemonic"
    case importSeed = "import_seed"
    case importJson = "import_json"
    case importLedger = "import_ledger"
    case importParitySigner = "import_parity_signer"
    case importPolkadotVault = "import_polkadot_vault"
    case importWatchOnly = "import_watch_only"
    case cloudBackup = "cloud_backup"
}

enum SwapSource: String, AnalyticsPropertyConvertible {
    case assetDetails = "asset_details"
    case mainScreen = "main_screen"
    case operationDetails = "operation_details"
    case retry
}

enum SwapFailureReason: String, AnalyticsPropertyConvertible {
    case networkError = "network_error"
    case executionReverted = "execution_reverted"
    case userCancelled = "user_cancelled"
    case unknown
}

enum StakingStage: String, AnalyticsPropertyConvertible {
    case landing
    case setup
    case typeSelection = "type_selection"
    case confirm
}

enum SwapStage: String, AnalyticsPropertyConvertible {
    case setup
    case confirm
}

enum FeatureId: String, AnalyticsPropertyConvertible {
    case staking
    case governance
    case crowdloans
    case dapps
    case nft
    case swap
    case buy
    case send
    case receive
    case settings
}

enum OnboardingSource: String, AnalyticsPropertyConvertible {
    case freshInstall = "fresh_install"
    case addWallet = "add_wallet"
}

enum WalletCreationStep: String, AnalyticsPropertyConvertible {
    case welcome
    case backup
    case confirmMnemonic = "confirm_mnemonic"
    case pinSetup = "pin_setup"
    case seedEntry = "seed_entry"
    case jsonUpload = "json_upload"
    case ledgerConnect = "ledger_connect"
    case other
}

enum SignSource: String, AnalyticsPropertyConvertible {
    case dappBrowser = "dapp_browser"
    case walletConnect = "walletconnect"
}

// The sets below are closed on iOS. Android sends bare string literals for these
// properties; the raw values match what its call sites emit.

enum AnalyticsTab: String, AnalyticsPropertyConvertible {
    case assets
    case vote
    case dapps
    case staking
    case settings
}

enum StakingAnalyticsType: String, AnalyticsPropertyConvertible {
    case direct
    case pool
    case mythos
    case unsupported
}

/// Android sends the exception class simple name; Swift type names would never match it
/// and are unbounded, so the vocabulary is a closed set agreed jointly with Android.
enum TransactionFailureReason: String, AnalyticsPropertyConvertible {
    case userCancelled = "user_cancelled"
    case networkError = "network_error"
    case unknown
}

enum SignFailureReason: String, AnalyticsPropertyConvertible {
    case signingFailed = "signing_failed"
    case noSession = "no_session"
    case unsupportedRequest = "unsupported_request"
}

enum DAppOpenSource: String, AnalyticsPropertyConvertible {
    case catalog
    case favorites
    case search
    case manualUrl = "manual_url"
}

enum VoteDirection: String, AnalyticsPropertyConvertible {
    case aye
    case nay
    case abstain
}

/// `noLockup` rather than `none`, so a call site passing `.none` for an optional
/// conviction can never silently resolve to `Optional.none` and omit the key.
enum ConvictionLevel: String, AnalyticsPropertyConvertible {
    case noLockup = "0.1x"
    case locked1x = "1x"
    case locked2x = "2x"
    case locked3x = "3x"
    case locked4x = "4x"
    case locked5x = "5x"
    case locked6x = "6x"
}

/// Android sends only `dashboard`; iOS has a second entry point, so the enum carries
/// both and `dashboard` stays byte-identical.
enum StakingFlowSource: String, AnalyticsPropertyConvertible {
    case dashboard
    case assetDetails = "asset_details"
}

/// Mirrors the raw values of `Banners.Domain`, plus `unknown` for Android's fallback.
/// The `Banners.Domain -> AnalyticsBannerScreen` mapper belongs to `Modules`, so no
/// `Modules` raw value crosses into `Common`.
enum AnalyticsBannerScreen: String, AnalyticsPropertyConvertible {
    case dApps = "dapps"
    case assets
    case ahmKusama = "ahm_kusama"
    case ahmPolkadot = "ahm_polkadot"
    case unknown
}
